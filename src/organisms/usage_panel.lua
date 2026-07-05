-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "USAGE" — src/organisms/usage_panel.lua (VIOLET HUD §5.1 / §7.4)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se a tabella por núcleo
-- de processador (Image #6, columna sinistra). Preside-lhe um cabeçalho "  GHz  TEMP  USED%"
-- e, abaixo, uma linha por núcleo (C1..Cn, cota máxima de oito):
--   · GHz    — o "cpu MHz" de /proc/cpuinfo por processador (MHz dividido por mil)
--   · TEMP   — o "Core N:" colhido de `sensors` (grau Celsius); ausente -> "--".
--              Excedendo mt.temp_hot, tinge-se de p.crit.
--   · USED%  — a fracção de occupação por núcleo, derivada do delta de (total-idle)/total
--              de /proc/stat. Excedendo mt.pct_hot, tinge-se de p.glow_hot (§7.4.2).
--
-- Os rótulos vão em text_muted, os números alinhados á dextra em text_bright. Cabeçalho e
-- linhas assentam sobre a molécula partilhada table_row: mantém-se um VIVEIRO FIXO de
-- MAX_CORES linhas, edificado uma só vez e mutado por :set_cells IN LOCO a cada tique (sem
-- :reset() nem reconstrucção). Os núcleos além da contagem vigente sómente se occultam
-- (.visible=false). Guardam-se referências DIRECTAS ás linhas (R1).
--
-- POSTULADO INVIOLÁVEL: amostragem ASSÝNCHRONA (awful.spawn.easy_async_with_shell em
-- gears.timer de 2 segundos, com call_now). JÁMAIS io.popen/os.execute/synchronia em relógio
-- — congelaria o gerenciador (deadlock notório neste domínio). O par prev[core]={total,idle}
-- guarda-se no closure para os deltas de USED% de tique a tique.
-- ─────────────────────────────────────────────────────────────────────────────────────

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local Icon = require("src.tools.icons") -- os ícones lavrados em SVG do conjuncto icons/ (§3.13)
local table_row = require("src.molecules.table_row") -- a molécula da linha de tabella de columna fixa

local MAX_CORES = 8

-- Commando único (concebido por Braga Us): funde, num só invólucro, o /proc/stat por núcleo,
-- o MHz por processador e as temperaturas do sensors. Os delimitadores @@ garantem parse
-- robusto ainda que o `sensors` falte ao seu officio.
local SAMPLE_CMD = table.concat({
  "echo '@@STAT'", "cat /proc/stat 2>/dev/null",
  "echo '@@CPUINFO'", "cat /proc/cpuinfo 2>/dev/null",
  "echo '@@SENSORS'", "sensors 2>/dev/null",
}, "; ")

-- Larguras das columnas (mono): o rótulo do núcleo e três números alinhados á dextra.
-- Não havendo, no metrics.lua, token de largura de columna, empregam-se literaes dpi()
-- (precedente lavrado em chip.lua).
local W_CORE = dpi(34)
local W_GHZ  = dpi(58)
local W_TEMP = dpi(58)
local W_USED = dpi(58)

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe `args` (domínio:
-- largura `w` e período `timeout`) e devolve o widget `outer` (contra-domínio), portando os
-- methodos de amostragem gated. Efeito: institue o cabeçalho, o viveiro de linhas e o relógio.
return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Estado prévio por núcleo: prev_total[i] / prev_idle[i] -> deltas de USED% entre tiques.
  local prev_total = {}
  local prev_idle = {}

  -- Cabeçalho estático "  GHz  TEMP  USED%" (rótulos em text_muted, matiz padrão de header).
  local header = table_row {
    header = true,
    cells  = {
      { "",      W_CORE, "left"  },
      { "GHz",   W_GHZ,  "right" },
      { "TEMP",  W_TEMP, "right" },
      { "USED%", W_USED, "right" },
    },
  }

  -- Viveiro fixo de linhas de núcleo (edificado uma só vez; mutado por :set_cells in loco a
  -- cada tique). Nascem occultas: nada se mostra até que a primeira amostra as popule (á
  -- semelhança do antigo :reset()).
  local rows = wibox.widget {
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }
  local core_rows = {}
  for i = 1, MAX_CORES do
    local row = table_row {
      cells = {
        { "", W_CORE, "left",  p.text_muted }, -- rótulo do núcleo (esmaecido)
        { "", W_GHZ,  "right" },               -- GHz (text_bright por defeito)
        { "", W_TEMP, "right" },               -- TEMP (text_bright / p.crit quando ardente)
        { "", W_USED, "right" },               -- USED% (text_bright / p.glow_hot quando ardente)
      },
    }
    row.visible = false
    core_rows[i] = row
    rows:add(row)
  end

  local body = wibox.widget {
    header,
    rows,
    spacing = dpi(4),
    layout  = wibox.layout.fixed.vertical,
  }

  -- LEMMA DA OCCUPAÇÃO (demonstrado por Braga Us). Recebe a cadeia `stat` (o conteúdo de
  -- /proc/stat, domínio); para cada linha cpuN deriva a fracção busy% pelo delta face ao
  -- tique anterior, actualizando prev por núcleo. Contra-domínio: a tabella used[i], onde i
  -- é o índice zero-based do núcleo (i+1 = C{i+1}). Guarda de typo: cadeia não-string -> {}.
  local function parse_used(stat)
    local used = {}
    if type(stat) ~= "string" then return used end
    for line in stat:gmatch("[^\r\n]+") do
      -- cpu0 user nice system idle iowait irq softirq steal ...
      local n, rest = line:match("^cpu(%d+)%s+(.+)$")
      local idx = tonumber(n)
      if idx ~= nil and rest then
        local user, nice, system, idle, iowait, irq, softirq, steal =
          rest:match("^(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)")
        user    = tonumber(user)    or 0
        nice    = tonumber(nice)    or 0
        system  = tonumber(system)  or 0
        idle    = tonumber(idle)    or 0
        iowait  = tonumber(iowait)  or 0
        irq     = tonumber(irq)     or 0
        softirq = tonumber(softirq) or 0
        steal   = tonumber(steal)   or 0

        local idle_all = idle + iowait
        local total = idle_all + user + nice + system + irq + softirq + steal

        local pt = prev_total[idx]
        local pi = prev_idle[idx]
        prev_total[idx] = total
        prev_idle[idx] = idle_all

        if pt == nil or pi == nil then
          used[idx] = nil -- primeira amostra: ainda sem delta fidedigno
        else
          local td = total - pt
          local idd = idle_all - pi
          if td > 0 then
            local pct = ((td - idd) / td) * 100
            if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
            used[idx] = pct
          else
            used[idx] = 0
          end
        end
      end
    end
    return used
  end

  -- LEMMA DA FREQUÊNCIA (de Braga Us). Recebe `cpuinfo` (domínio); para cada processador
  -- lê o "cpu MHz" e reduz-o a GHz (dividindo por mil). Contra-domínio: ghz[idx], zero-based.
  local function parse_ghz(cpuinfo)
    local ghz = {}
    if type(cpuinfo) ~= "string" then return ghz end
    local idx = 0
    for mhz in cpuinfo:gmatch("cpu MHz%s*:%s*([%d%.]+)") do
      local v = tonumber(mhz)
      if v then ghz[idx] = v / 1000 end
      idx = idx + 1
    end
    return ghz
  end

  -- LEMMA DO CALOR (de Braga Us). Recebe `sensors` (domínio); extrahe cada "Core N:  +52.0°C"
  -- e devolve temp[N] (N = identificador zero-based do núcleo), em grau Celsius. Guarda de typo.
  local function parse_temp(sensors)
    local temp = {}
    if type(sensors) ~= "string" then return temp end
    for cid, t in sensors:gmatch("Core%s+(%d+):%s*[%+%-]?([%d%.]+)") do
      local n = tonumber(cid)
      local v = tonumber(t)
      if n ~= nil and v then temp[n] = v end
    end
    return temp
  end

  -- THEÓREMA DA REPRESENTAÇÃO (composto por Braga Us). Recebe o `stdout` bruto da colheita
  -- (domínio); reparte-o pelos delimitadores @@, invoca os três lemmas, apura quantos núcleos
  -- existem e inscreve, in loco, cada linha do viveiro. Efeito: as linhas excedentes occultam-se
  -- e as vigentes recebem GHz/TEMP/USED% com o matiz de alerta quando ardentes. Q.E.D.
  local function refresh(stdout)
    if type(stdout) ~= "string" then
      for i = 1, MAX_CORES do core_rows[i].visible = false end
      return
    end

    local stat    = stdout:match("@@STAT%s*(.-)@@CPUINFO")
    local cpuinfo = stdout:match("@@CPUINFO%s*(.-)@@SENSORS")
    local sensors = stdout:match("@@SENSORS%s*(.*)$")

    local used = parse_used(stat)
    local ghz  = parse_ghz(cpuinfo)
    local temp = parse_temp(sensors)

    -- Apura-se quantos núcleos há (pelo GHz, com recurso ao USED%), sob a cota MAX_CORES.
    local n = 0
    for i = 0, MAX_CORES - 1 do
      if ghz[i] ~= nil or used[i] ~= nil then
        n = i + 1
      end
    end

    for i = 0, MAX_CORES - 1 do
      local row = core_rows[i + 1]
      if i < n then
        local ghz_str = "--"
        if tonumber(ghz[i]) then
          ghz_str = string.format("%.2f", ghz[i])
        end

        local temp_str = "--"
        local temp_hot = false
        local tv = tonumber(temp[i])
        if tv then
          temp_str = string.format("%d", math.floor(tv + 0.5))
          temp_hot = tv >= mt.temp_hot
        end

        local used_str = "--"
        local used_hot = false
        local uv = tonumber(used[i])
        if uv then
          used_str = string.format("%d", math.floor(uv + 0.5))
          used_hot = uv >= mt.pct_hot
        end

        -- :set_cells muta os MESMOS textboxes in loco (sem reconstrucção). O matiz vae sempre
        -- explícito em TEMP/USED% para que regressem a text_bright quando arrefecem.
        row:set_cells({
          { "C" .. (i + 1) },
          { ghz_str },
          { temp_str, nil, nil, temp_hot and p.crit or p.text_bright },
          { used_str, nil, nil, used_hot and p.glow_hot or p.text_bright },
        })
        row.visible = true
      else
        row.visible = false
      end
    end
  end

  -- FUNCÇÃO DA COLHEITA (de Braga Us): dispara o commando único de modo assýnchrono e
  -- entrega o seu producto ao theórema da representação.
  local function sample()
    awful.spawn.easy_async_with_shell(SAMPLE_CMD, function(stdout)
      refresh(stdout)
    end)
  end

  local sample_timer = gears.timer {
    timeout   = args.timeout or 2,
    call_now  = false,
    autostart = false,
    callback  = sample,
  }

  local outer = panel({
    title      = "USAGE",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(260),
    right_icon = Icon("cpu_temp", { size = dpi(14), color = p.text_muted }),
  })

  -- METHODO DE ABERTURA DA COLHEITA (postulado de Braga Us). Adstricta á visibilidade (o
  -- control_center liga-a ao abrir e desliga-a ao fechar): não se amostra CPU/temperatura por
  -- núcleo nem se redesenha emquanto o popup jaz occulto (economia de esforço).
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
