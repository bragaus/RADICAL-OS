------------------------------------------------------------------------------------------
-- src/widgets/status_dock.lua — Tira HORIZONTAL de stats para o TOPO (VIOLET HUD)         --
--                                                                                        --
-- Uma única linha compacta de segmentos de sistema, pensada para o centro da barra       --
-- superior (entre tags e relógios). Inspirada na "top strip" da referência.              --
--                                                                                        --
--   CPU  NN%  ·  MEM  NN%  ·  NET  ↑/↓ KB/s  ·  VOL  NN%                                  --
--                                                                                        --
-- Cada segmento = glyph (text_muted) + valor (text_bright), mono 10, separados por um    --
-- divisor fino "·" em line_dim. Fundo transparente — NÃO é embrulhado em panel.lua,      --
-- pois vive numa barra superior fina (~dpi(22) de altura).                               --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (2s,        --
-- call_now). NUNCA io.popen/os.execute em timer — congela o WM (deadlock conhecido).     --
-- Todos os parses de stdout passam por tonumber()/guarda de nil.                         --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")

local MONO   = "JetBrainsMono Nerd Font 10"
local HEIGHT = dpi(22)

-- Glyphs Nerd Font para cada segmento.
local GLYPH_CPU = ""
local GLYPH_MEM = ""
local GLYPH_NET = ""
local GLYPH_VOL = ""

-- Formata uma taxa em bytes/s para um rótulo curto (B/KB/MB por segundo).
local function fmt_rate(bps)
  bps = tonumber(bps) or 0
  if bps < 0 then bps = 0 end
  if bps >= 1048576 then
    return string.format("%.1fM", bps / 1048576)
  elseif bps >= 1024 then
    return string.format("%.0fK", bps / 1024)
  else
    return string.format("%.0fB", bps)
  end
end

return function(args)
  args = args or {}

  -- Cria um par glyph+valor. Retorna {widget, set(value)}.
  local function make_segment(glyph, glyph_color)
    local glyph_box = wibox.widget {
      text   = glyph,
      font   = MONO,
      valign = "center",
      widget = wibox.widget.textbox,
    }
    local value_box = wibox.widget {
      text   = "--",
      font   = MONO,
      valign = "center",
      widget = wibox.widget.textbox,
    }
    local seg = wibox.widget {
      {
        glyph_box,
        fg     = glyph_color or p.text_muted,
        widget = wibox.container.background,
      },
      {
        value_box,
        fg     = p.text_bright,
        widget = wibox.container.background,
      },
      spacing = dpi(5),
      layout  = wibox.layout.fixed.horizontal,
    }
    seg._value = value_box
    return seg
  end

  -- Divisor fino "·" entre segmentos.
  local function make_divider()
    return wibox.widget {
      {
        text   = "·",
        font   = MONO,
        valign = "center",
        align  = "center",
        widget = wibox.widget.textbox,
      },
      fg     = p.line_dim,
      widget = wibox.container.background,
    }
  end

  local seg_cpu = make_segment(GLYPH_CPU, p.text_muted)
  local seg_mem = make_segment(GLYPH_MEM, p.text_muted)
  local seg_net = make_segment(GLYPH_NET, p.text_muted)
  local seg_vol = make_segment(GLYPH_VOL, p.text_muted)

  local row = wibox.widget {
    seg_cpu,
    make_divider(),
    seg_mem,
    make_divider(),
    seg_net,
    make_divider(),
    seg_vol,
    spacing = dpi(10),
    layout  = wibox.layout.fixed.horizontal,
  }

  local container = wibox.widget {
    {
      row,
      left   = dpi(10),
      right  = dpi(10),
      widget = wibox.container.margin,
    },
    forced_height = HEIGHT,
    bg            = "#00000000",
    widget        = wibox.container.background,
  }

  -- Estado entre ticks (deltas de CPU e NET).
  local prev_cpu_total, prev_cpu_idle = nil, nil
  local prev_net_rx, prev_net_tx, prev_net_time = nil, nil, nil

  --------------------------------------------------------------------------------
  -- CPU — /proc/stat primeira linha; mantém prev total/idle entre ticks.
  --------------------------------------------------------------------------------
  local function update_cpu()
    awful.spawn.easy_async_with_shell(
      "cat /proc/stat 2>/dev/null | head -n 1",
      function(stdout)
        stdout = stdout or ""
        -- cpu  user nice system idle iowait irq softirq steal ...
        local nums = {}
        for tok in stdout:gmatch("%d+") do
          nums[#nums + 1] = tonumber(tok)
        end
        if #nums < 4 then return end

        local idle = (nums[4] or 0) + (nums[5] or 0) -- idle + iowait
        local total = 0
        for i = 1, #nums do
          total = total + (nums[i] or 0)
        end

        local pct = 0
        if prev_cpu_total and prev_cpu_idle then
          local dt = total - prev_cpu_total
          local di = idle - prev_cpu_idle
          if dt > 0 then
            pct = (dt - di) / dt * 100
          end
        end
        prev_cpu_total, prev_cpu_idle = total, idle

        if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
        seg_cpu._value:set_text(string.format("%d%%", math.floor(pct + 0.5)))
      end
    )
  end

  --------------------------------------------------------------------------------
  -- MEM — /proc/meminfo; usado = (MemTotal - MemAvailable) / MemTotal.
  --------------------------------------------------------------------------------
  local function update_mem()
    awful.spawn.easy_async_with_shell(
      "cat /proc/meminfo 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local total = tonumber(stdout:match("MemTotal:%s*(%d+)"))
        local avail = tonumber(stdout:match("MemAvailable:%s*(%d+)"))
        if not total or not avail or total <= 0 then return end

        local used = total - avail
        if used < 0 then used = 0 end
        local pct = used / total * 100
        if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
        seg_mem._value:set_text(string.format("%d%%", math.floor(pct + 0.5)))
      end
    )
  end

  --------------------------------------------------------------------------------
  -- NET — /proc/net/dev; soma rx/tx de todas as ifaces exceto lo; taxa por delta.
  --------------------------------------------------------------------------------
  local function update_net()
    awful.spawn.easy_async_with_shell(
      "cat /proc/net/dev 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local rx_sum, tx_sum = 0, 0
        for line in stdout:gmatch("[^\r\n]+") do
          -- iface: rx_bytes ... tx_bytes ...
          local iface, rest = line:match("^%s*([%w%-_]+):%s*(.+)$")
          if iface and iface ~= "lo" and rest then
            local fields = {}
            for tok in rest:gmatch("%S+") do
              fields[#fields + 1] = tonumber(tok)
            end
            -- campos: 1=rx_bytes ... 9=tx_bytes
            local rx = fields[1]
            local tx = fields[9]
            if rx then rx_sum = rx_sum + rx end
            if tx then tx_sum = tx_sum + tx end
          end
        end

        local now = os.time()
        local up_rate, down_rate = 0, 0
        if prev_net_rx and prev_net_tx and prev_net_time then
          local dt = now - prev_net_time
          if dt <= 0 then dt = 1 end
          local d_rx = rx_sum - prev_net_rx
          local d_tx = tx_sum - prev_net_tx
          if d_rx < 0 then d_rx = 0 end
          if d_tx < 0 then d_tx = 0 end
          down_rate = d_rx / dt
          up_rate   = d_tx / dt
        end
        prev_net_rx, prev_net_tx, prev_net_time = rx_sum, tx_sum, now

        seg_net._value:set_text(string.format("↑%s ↓%s", fmt_rate(up_rate), fmt_rate(down_rate)))
      end
    )
  end

  --------------------------------------------------------------------------------
  -- VOL — pactl get-sink-volume @DEFAULT_SINK@; pega o primeiro "NN%".
  --------------------------------------------------------------------------------
  local function update_vol()
    awful.spawn.easy_async_with_shell(
      "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local vol = tonumber(stdout:match("(%d+)%%"))
        if not vol then return end
        if vol < 0 then vol = 0 end
        seg_vol._value:set_text(string.format("%d%%", vol))
      end
    )
  end

  gears.timer {
    timeout   = args.timeout or 2,
    call_now  = true,
    autostart = true,
    callback  = function()
      update_cpu()
      update_mem()
      update_net()
      update_vol()
    end,
  }

  return container
end
