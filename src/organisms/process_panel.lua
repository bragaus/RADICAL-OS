------------------------------------------------------------------------------------------
-- src/organisms/process_panel.lua — Painel "PROCESS" (VIOLET HUD §7.4.7)                    --
--                                                                                        --
-- TODOS os processos por uso de CPU. Cada linha: PID (text_muted) · NOME (text_primary,  --
-- flex) · CPU% (text_bright, direita) · MEM% (text_bright) · KILL (kill_btn: skull        --
-- text_muted -> crit no hover; clique-esquerdo envia SIGTERM ao PID via awful.spawn).     --
--                                                                                        --
-- REWIRED (Stage 2): a máquina de scroll (make_scrollbar + janela + rows_area) virou o     --
-- molecule scroll_list (row-pool); cada linha é um table_row (células + kill_btn). O        --
-- header é um table_row{header=true}, recuado pela mesma calha (gutter) que as linhas       --
-- para alinhar colunas. `refresh` alimenta sl:set_data(items); set_row popula/limpa a       --
-- linha reusável (visible=false quando limpa, escondendo o skull ocioso).                   --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (3s).       --
-- NUNCA usar io.popen/os.execute em timer — trava o WM (deadlock conhecido neste repo).  --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local Icon  = require("src.tools.icons")        -- shim de atoms/icon (right_icon do header)
local table_row  = require("src.molecules.table_row")
local scroll_list = require("src.molecules.scroll_list")
local format = require("src.tools.format")

-- Amostra a lista INTEIRA, ordenada por CPU desc (sem head: o scroll mostra todos).
local SAMPLE_CMD = "ps -eo pid,comm,pcpu,pmem --sort=-pcpu --no-headers"
local NAME_MAX   = 10 -- chars máximos do nome antes de encurtar

-- Larguras de coluna: sem token de métrica equivalente (grade densa do painel), literais
-- dpi comentados (precedente chip.lua). PID/CPU/MEM em dpi(44).
local COL_W = dpi(44)

return function(args)
  args = args or {}

  -- Uma linha reusável do pool: PID | NOME(flex) | CPU% | MEM% | KILL. As cores default
  -- de cada célula ficam no construtor; set_cells só troca o texto (via txt:set_span).
  local function make_row()
    return table_row {
      cells = {
        { "", COL_W, "left",  p.text_muted },   -- PID
        { "", nil,   "left",  p.text_primary }, -- NOME (flex)
        { "", COL_W, "right", p.text_bright },  -- CPU%
        { "", COL_W, "right", p.text_bright },  -- MEM%
      },
      on_kill = function() end, -- religado por linha em set_row (pool)
    }
  end

  -- Popula (item) ou limpa+esconde (nil) a linha reusável.
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
      row:set_cells({})       -- limpa células + solta bg de hover latcheado
      row:set_on_kill(nil)     -- clique morto em linha vazia
      row.visible = false      -- esconde o skull ocioso da linha não usada
    end
  end

  -- Cabeçalho de colunas (estático). Célula final vazia com a largura do kill_btn (kill_w)
  -- para alinhar com a coluna KILL das linhas; recuado pela calha (gutter) como o pool.
  local header = wibox.widget {
    table_row {
      header = true,
      cells = {
        -- cor text_faint explícita: preserva o header original (o default do
        -- table_row header é text_muted, mais claro) — sem mudança visual.
        { "PID",  COL_W,           "left",   p.text_faint },
        { "NAME", nil,             "left",   p.text_faint },
        { "CPU%", COL_W,           "right",  p.text_faint },
        { "MEM%", COL_W,           "right",  p.text_faint },
        { "",     dpi(mt.kill_w),  "center", p.text_faint }, -- alinha com a coluna KILL
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

  local function refresh(stdout)
    local data = {}
    if type(stdout) == "string" then
      for line in stdout:gmatch("[^\r\n]+") do
        -- ps: pid comm pcpu pmem
        local pid, name, cpu, mem =
          line:match("^%s*(%d+)%s+(.-)%s+([%d%.]+)%s+([%d%.]+)%s*$")

        -- Guardas (R4): só guarda se PID/CPU/MEM forem numéricos.
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
    sl:set_data(data) -- mantém o offset entre ticks (re-clampado ao novo total)
  end

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

  -- Sampling gated por visibilidade (control_center liga ao abrir / desliga ao fechar o
  -- dashboard): não roda `ps` nem redesenha enquanto o popup está oculto (perf). Shape
  -- exato preservado (R8): guard _sampling -> amostra imediata -> timer:start()/:stop().
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    sample()
    sample_timer:start()
  end
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end
