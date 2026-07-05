------------------------------------------------------------------------------------------
-- src/organisms/usage_panel.lua — Painel "USAGE" (VIOLET HUD §5.1 / §7.4)                   --
--                                                                                        --
-- Tabela por núcleo de CPU (Image #6, coluna esquerda). Cabeçalho:                       --
--   "  GHz  TEMP  USED%"  e uma linha por core (C1..Cn, cap em 8).                       --
--   · GHz    — "cpu MHz" de /proc/cpuinfo por processor (MHz/1000).                      --
--   · TEMP   — "Core N:" de `sensors` (°C); ausente -> "--". >= mt.temp_hot -> p.crit.    --
--   · USED%  — busy% por núcleo via delta de (total-idle)/total de /proc/stat.           --
--             >= mt.pct_hot -> p.glow_hot (alert threshold §7.4.2).                       --
--                                                                                        --
-- Rótulos em text_muted, números right-aligned em text_bright. Cabeçalho + linhas usam    --
-- a molécula compartilhada table_row: um POOL FIXO de MAX_CORES linhas construído uma vez --
-- e atualizado com :set_cells IN PLACE (sem :reset()/rebuild por tick); cores acima da    --
-- contagem atual são apenas escondidos (.visible=false). Refs diretas às linhas (R1).     --
--                                                                                        --
-- Amostragem ASSÍNCRONA (awful.spawn.easy_async_with_shell em gears.timer 2s, call_now). --
-- NUNCA io.popen/os.execute/sync em timer — congela o WM (deadlock conhecido neste repo).--
-- prev[core] = {total, idle} guardado no closure p/ os deltas de USED% entre ticks.       --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)
local table_row = require("src.molecules.table_row") -- linha de tabela de coluna fixa

local MAX_CORES = 8

-- Comando único: per-core /proc/stat + MHz por processor + temps do sensors.
-- Delimitadores garantem parse robusto mesmo se `sensors` faltar.
local SAMPLE_CMD = table.concat({
  "echo '@@STAT'", "cat /proc/stat 2>/dev/null",
  "echo '@@CPUINFO'", "cat /proc/cpuinfo 2>/dev/null",
  "echo '@@SENSORS'", "sensors 2>/dev/null",
}, "; ")

-- Larguras das colunas (mono): rótulo do core + 3 números right-aligned.
-- Sem token de largura de coluna no metrics.lua; dpi() literal (precedente chip.lua).
local W_CORE = dpi(34)
local W_GHZ  = dpi(58)
local W_TEMP = dpi(58)
local W_USED = dpi(58)

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- prev por core: prev_total[i] / prev_idle[i] -> deltas de USED% entre ticks.
  local prev_total = {}
  local prev_idle = {}

  -- Cabeçalho estático: "  GHz  TEMP  USED%" (rótulos em text_muted, default de header).
  local header = table_row {
    header = true,
    cells  = {
      { "",      W_CORE, "left"  },
      { "GHz",   W_GHZ,  "right" },
      { "TEMP",  W_TEMP, "right" },
      { "USED%", W_USED, "right" },
    },
  }

  -- Pool fixo de linhas de core (construído uma vez; :set_cells in place por tick).
  -- Começam escondidas: nada aparece até a 1ª amostra populá-las (igual ao :reset() antigo).
  local rows = wibox.widget {
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }
  local core_rows = {}
  for i = 1, MAX_CORES do
    local row = table_row {
      cells = {
        { "", W_CORE, "left",  p.text_muted }, -- rótulo do core (muted)
        { "", W_GHZ,  "right" },               -- GHz (text_bright default)
        { "", W_TEMP, "right" },               -- TEMP (text_bright / p.crit quando quente)
        { "", W_USED, "right" },               -- USED% (text_bright / p.glow_hot quando quente)
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

  -- Parse de /proc/stat: cpuN -> busy% via delta. Guarda prev por core.
  -- Retorna tabela used[i] (i = índice 0-based do core => i+1 = C{i+1}).
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
          used[idx] = nil -- primeira amostra: sem delta confiável ainda
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

  -- Parse de /proc/cpuinfo: GHz por processor (cpu MHz / 1000), 0-based.
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

  -- Parse de `sensors`: "Core N:  +52.0°C" -> temp[N] (N = core id 0-based).
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

    -- Quantos cores existem (pelo GHz, fallback no USED%), cap em MAX_CORES.
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

        -- :set_cells muta os MESMOS textboxes in place (sem rebuild). Cor sempre passada
        -- explícita em TEMP/USED% p/ voltar a text_bright quando esfria.
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

  -- Sampling gated por visibilidade (control_center liga ao abrir / desliga ao fechar o
  -- dashboard): não amostra CPU/temp por core nem redesenha enquanto o popup está oculto (perf).
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
