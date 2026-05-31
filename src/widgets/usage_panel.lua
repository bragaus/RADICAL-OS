------------------------------------------------------------------------------------------
-- src/widgets/usage_panel.lua — Painel "USAGE" (VIOLET HUD §5.1 / §7.4)                   --
--                                                                                        --
-- Tabela por núcleo de CPU (Image #6, coluna esquerda). Cabeçalho:                       --
--   "  GHz  TEMP  USED%"  e uma linha por core (C1..Cn, cap em 8).                       --
--   · GHz    — "cpu MHz" de /proc/cpuinfo por processor (MHz/1000).                      --
--   · TEMP   — "Core N:" de `sensors` (°C); ausente -> "--". >=80°C -> p.crit.            --
--   · USED%  — busy% por núcleo via delta de (total-idle)/total de /proc/stat.           --
--                                                                                        --
-- Rótulos em text_muted, números right-aligned em text_bright.                           --
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

local MONO = "JetBrainsMono Nerd Font"
local MAX_CORES = 8
local HOT_TEMP = 80 -- >= -> p.crit

-- Comando único: per-core /proc/stat + MHz por processor + temps do sensors.
-- Delimitadores garantem parse robusto mesmo se `sensors` faltar.
local SAMPLE_CMD = table.concat({
  "echo '@@STAT'", "cat /proc/stat 2>/dev/null",
  "echo '@@CPUINFO'", "cat /proc/cpuinfo 2>/dev/null",
  "echo '@@SENSORS'", "sensors 2>/dev/null",
}, "; ")

-- Larguras das colunas (mono): rótulo do core + 3 números right-aligned.
local W_CORE = dpi(34)
local W_GHZ  = dpi(58)
local W_TEMP = dpi(58)
local W_USED = dpi(58)

-- Célula textbox mono com cor/alinhamento/largura fixos.
local function cell(text, color, align, width)
  return wibox.widget {
    {
      text   = text or "",
      font   = MONO .. " 9",
      align  = align or "left",
      valign = "center",
      widget = wibox.widget.textbox,
    },
    fg           = color,
    forced_width = width,
    widget       = wibox.container.background,
  }
end

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- prev por core: prev_total[i] / prev_idle[i] -> deltas de USED% entre ticks.
  local prev_total = {}
  local prev_idle = {}

  -- Lista de linhas (:reset() + repopulada a cada tick).
  local rows = wibox.widget {
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }

  -- Cabeçalho estático: "  GHz  TEMP  USED%" (rótulos em text_muted).
  local header = wibox.widget {
    cell("",      p.text_muted, "left",  W_CORE),
    cell("GHz",   p.text_muted, "right", W_GHZ),
    cell("TEMP",  p.text_muted, "right", W_TEMP),
    cell("USED%", p.text_muted, "right", W_USED),
    forced_height = dpi(16),
    spacing       = dpi(4),
    layout        = wibox.layout.fixed.horizontal,
  }

  local body = wibox.widget {
    header,
    rows,
    spacing = dpi(4),
    layout  = wibox.layout.fixed.vertical,
  }

  -- Monta a linha de um core: rótulo (muted) + GHz/TEMP/USED% (right, bright).
  -- temp_hot=true recolora a célula TEMP para p.crit.
  local function build_row(label, ghz, temp, used, temp_hot)
    return wibox.widget {
      cell(label, p.text_muted, "left",  W_CORE),
      cell(ghz,   p.text_bright, "right", W_GHZ),
      cell(temp,  temp_hot and p.crit or p.text_bright, "right", W_TEMP),
      cell(used,  p.text_bright, "right", W_USED),
      forced_height = dpi(18),
      spacing       = dpi(4),
      layout        = wibox.layout.fixed.horizontal,
    }
  end

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
    rows:reset()
    if type(stdout) ~= "string" then return end

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
    if n == 0 then n = 0 end

    for i = 0, math.min(n, MAX_CORES) - 1 do
      local label = "C" .. (i + 1)

      local ghz_str = "--"
      if tonumber(ghz[i]) then
        ghz_str = string.format("%.2f", ghz[i])
      end

      local temp_str = "--"
      local temp_hot = false
      local tv = tonumber(temp[i])
      if tv then
        temp_str = string.format("%d", math.floor(tv + 0.5))
        temp_hot = tv >= HOT_TEMP
      end

      local used_str = "--"
      if tonumber(used[i]) then
        used_str = string.format("%d", math.floor(used[i] + 0.5))
      end

      rows:add(build_row(label, ghz_str, temp_str, used_str, temp_hot))
    end
  end

  gears.timer {
    timeout   = args.timeout or 2,
    call_now  = true,
    autostart = true,
    callback  = function()
      awful.spawn.easy_async_with_shell(SAMPLE_CMD, function(stdout)
        refresh(stdout)
      end)
    end,
  }

  return panel({
    title  = "USAGE",
    body   = body,
    accent = p.v500,
    w      = args.w or dpi(260),
  })
end
