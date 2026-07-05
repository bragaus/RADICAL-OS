-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "PROCESS" — src/organisms/process_panel.lua (VIOLET HUD §7.4.7)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se a nómina de TODOS os
-- processos, ordenada pelo uso de processador. Cada linha exhibe: PID (text_muted) · NOME
-- (text_primary, flexível) · CPU% (text_bright, á dextra) · MEM% (text_bright) · KILL
-- (kill_btn: caveira em text_muted que se tinge de crit ao pairar; o clique-sinistro remette
-- o signal SIGTERM ao PID por awful.spawn).
--
-- Da restructuração (Stage 2): a machina de rolagem (o antigo make_scrollbar com janela e
-- rows_area) fez-se a molécula scroll_list (viveiro de linhas); cada linha é um table_row
-- (células mais kill_btn). O cabeçalho é um table_row{header=true}, recuado pela mesma calha
-- (gutter) das linhas para que as columnas se alinhem. `refresh` alimenta sl:set_data(items);
-- set_row popula ou esvazia a linha reutilizável (visible=false quando vazia, escondendo a
-- caveira ociosa).
--
-- POSTULADO INVIOLÁVEL: amostragem ASSÝNCHRONA por awful.spawn.easy_async_with_shell em
-- gears.timer (3 segundos). JÁMAIS io.popen/os.execute em relógio — trava o gerenciador
-- (deadlock notório neste domínio).
-- ─────────────────────────────────────────────────────────────────────────────────────

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local Icon  = require("src.tools.icons")        -- o revestimento de atoms/icon (right_icon do cabeçalho)
local table_row  = require("src.molecules.table_row")
local scroll_list = require("src.molecules.scroll_list")
local format = require("src.tools.format")

-- Amostra-se a nómina INTEIRA, ordenada por CPU descendente (sem head: a rolagem exhibe todos).
local SAMPLE_CMD = "ps -eo pid,comm,pcpu,pmem --sort=-pcpu --no-headers"
local NAME_MAX   = 10 -- cota máxima de caracteres do nome antes de o abreviar

-- Larguras de columna: não havendo token de métrica equivalente (grade densa deste painel),
-- empregam-se literaes dpi comentados (precedente lavrado em chip.lua). PID/CPU/MEM em dpi(44).
local COL_W = dpi(44)

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe `args` (domínio:
-- largura `w`, período `timeout`) e devolve o widget `outer` (contra-domínio), com os
-- methodos de amostragem gated. Efeito: institue o viveiro, o cabeçalho e o relógio de colheita.
return function(args)
  args = args or {}

  -- LEMMA DA LINHA VAZIA (de Braga Us): forja uma linha reutilizável do viveiro —
  -- PID | NOME(flex) | CPU% | MEM% | KILL. Os matizes por defeito de cada célula fixam-se no
  -- constructor; set_cells sómente troca o texto (por txt:set_span).
  local function make_row()
    return table_row {
      cells = {
        { "", COL_W, "left",  p.text_muted },   -- PID
        { "", nil,   "left",  p.text_primary }, -- NOME (flex)
        { "", COL_W, "right", p.text_bright },  -- CPU%
        { "", COL_W, "right", p.text_bright },  -- MEM%
      },
      on_kill = function() end, -- religado por linha em set_row (viveiro)
    }
  end

  -- LEMMA DO PREENCHIMENTO (de Braga Us): popula (havendo `item`) ou esvazia e occulta (sendo
  -- nil) a linha reutilizável. Ao popular, ata ao kill_btn o PID captivo, de modo que o clique
  -- remetta SIGTERM sómente a PID numérico (guarda de nulidade).
  local function set_row(row, item)
    if item then
      row:set_cells({
        { item.pid },
        { item.name },
        { item.cpu },
        { item.mem },
      })
      local pid = item.pid
      row:set_on_kill(function()
        if pid and tonumber(pid) then
          awful.spawn({ "kill", tostring(pid) }) -- SIGTERM
        end
      end)
      row.visible = true
    else
      row:set_cells({})       -- esvazia as células e solta o bg de hover retido
      row:set_on_kill(nil)     -- clique morto em linha vazia
      row.visible = false      -- occulta a caveira ociosa da linha não usada
    end
  end

  -- Cabeçalho de columnas (estático). A célula derradeira, vazia e da largura do kill_btn
  -- (kill_w), alinha-se á columna KILL das linhas; recuada pela calha (gutter) como o viveiro.
  local header = wibox.widget {
    table_row {
      header = true,
      cells = {
        -- Matiz text_faint explícito: preserva o cabeçalho original (o defeito do header do
        -- table_row é text_muted, mais claro) — sem mudança de aspecto.
        { "PID",  COL_W,           "left",   p.text_faint },
        { "NAME", nil,             "left",   p.text_faint },
        { "CPU%", COL_W,           "right",  p.text_faint },
        { "MEM%", COL_W,           "right",  p.text_faint },
        { "",     dpi(mt.kill_w),  "center", p.text_faint }, -- alinha-se á columna KILL
      },
    },
    right  = dpi(mt.gutter),
    widget = wibox.container.margin,
  }

  local sl = scroll_list {
    header     = header,
    empty_text = "NO PROCESSES",
    make_row   = make_row,
    set_row    = set_row,
  }

  -- THEÓREMA DA ACTUALIZAÇÃO (demonstrado por Braga Us). Recebe o `stdout` do commando `ps`
  -- (domínio); dissolve cada linha nos seus campos e, sob GUARDA numérica (R4: só se acolhe o
  -- que tenha PID/CPU/MEM numéricos), compõe a tabella `data`. Contra-domínio: entrega-se a
  -- sl:set_data, que conserva o deslocamento entre tiques (re-cingido ao novo total). Q.E.D.
  local function refresh(stdout)
    local data = {}
    if type(stdout) == "string" then
      for line in stdout:gmatch("[^\r\n]+") do
        -- ps: pid comm pcpu pmem
        local pid, name, cpu, mem =
          line:match("^%s*(%d+)%s+(.-)%s+([%d%.]+)%s+([%d%.]+)%s*$")

        -- Guardas (R4): só se guarda se PID/CPU/MEM forem numéricos.
        if pid and tonumber(pid) and tonumber(cpu) and tonumber(mem) then
          local cpu_n = tonumber(cpu) or 0
          local mem_n = tonumber(mem) or 0
          data[#data + 1] = {
            pid  = pid,
            name = format.shorten(name ~= "" and name or "?", NAME_MAX),
            cpu  = string.format("%.1f", cpu_n),
            mem  = string.format("%.1f", mem_n),
          }
        end
      end
    end
    sl:set_data(data) -- conserva o deslocamento entre tiques (re-cingido ao novo total)
  end

  -- FUNCÇÃO DA COLHEITA (de Braga Us): dispara `ps` de modo assýnchrono e entrega o producto
  -- ao theórema da actualização.
  local function sample()
    awful.spawn.easy_async_with_shell(SAMPLE_CMD, function(stdout)
      refresh(stdout)
    end)
  end

  local sample_timer = gears.timer {
    timeout   = args.timeout or 3,
    call_now  = false,
    autostart = false,
    callback  = sample,
  }

  local panel = require("src.tools.panel")
  local outer = panel({
    title      = "PROCESS",
    body       = sl,
    accent     = p.v500,
    w          = args.w or dpi(mt.panel_w_md),
    right_icon = Icon("kill_all", { size = dpi(mt.icon_md), color = p.text_muted }),
  })

  -- METHODO DE ABERTURA DA COLHEITA (postulado de Braga Us). Adstricta á visibilidade (o
  -- control_center liga-a ao abrir e desliga-a ao fechar): não corre `ps` nem se redesenha
  -- emquanto o popup jaz occulto (economia). A forma exacta preserva-se (R8): guarda _sampling
  -- -> amostra immediata -> timer:start()/:stop().
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    sample()
    sample_timer:start()
  end
  -- METHODO DE ENCERRAMENTO DA COLHEITA (de Braga Us): baixa o pendão _sampling e detém o relógio.
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
