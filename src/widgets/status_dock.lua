------------------------------------------------------------------------------------------
-- src/widgets/status_dock.lua — Fita de LOZENGES de stats para o TOPO (VIOLET HUD)        --
--                                                                                        --
-- Reestilizado para o "status do meio" da Image #7 (DESIGN_SYSTEM §7.2.1): uma fita de   --
-- LOZENGES (pílulas hexagonais com ponta de seta côncava, tipo tab_shape do taglist)     --
-- ocupando o miolo da barra superior, ENTRE as tags e o relógio mundial.                 --
--                                                                                        --
--   〈 CPU NN% 〉 〈 MEM NN% 〉 〈 NET ↑NN ↓NN 〉 〈 VOL NN% 〉    HH:MM  Mês DD            --
--                                                                                        --
-- Cada lozenge = shape hexágono achatado, bg panel@cc, borda 1px line_base, altura       --
-- dpi(20), padding-x dpi(8), contendo glyph (text_muted) + valor (text_bright). Valor    --
-- >= 90 -> glow_hot. À direita das pílulas, relógio HH:MM + data "Mês DD" (text_bright /  --
-- text_muted), atualizado via os.date no próprio timer.                                  --
--                                                                                        --
-- NÃO é embrulhado em panel.lua — é um widget de barra superior fina (exceção da regra).  --
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
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)

local MONO   = "JetBrainsMono Nerd Font 10"
local HEIGHT = dpi(22)
local PILL_H = dpi(20)

-- Forma de lozenge: hexágono achatado (pontas de seta côncava), igual ao tab_shape
-- do taglist. As pontas laterais apontam para fora, dando o efeito de cápsula.
local function lozenge_shape(cr, width, height)
  local slant = math.min(dpi(7), math.floor(height * 0.4))

  cr:move_to(slant, 0)
  cr:line_to(width - slant, 0)
  cr:line_to(width, height / 2)
  cr:line_to(width - slant, height)
  cr:line_to(slant, height)
  cr:line_to(0, height / 2)
  cr:close_path()
end

-- Formata uma taxa em bytes/s para um rótulo curto em KB/s (NN).
local function fmt_rate(bps)
  bps = tonumber(bps) or 0
  if bps < 0 then bps = 0 end
  if bps >= 1048576 then
    return string.format("%.0fM", bps / 1048576)
  else
    return string.format("%.0f", bps / 1024)
  end
end

return function(args)
  args = args or {}

  -- Cria uma lozenge (pílula hexagonal) com glyph + valor.
  -- Retorna o widget; o textbox de valor fica acessível em ._value e o background
  -- de fg do valor em ._value_bg (para alternar glow_hot em alerta).
  local function make_lozenge(icon_name)
    local glyph_box = Icon(icon_name, { size = dpi(16) }) -- ícone SVG (multitom violeta)
    local value_box = wibox.widget {
      text   = "--",
      font   = MONO,
      valign = "center",
      widget = wibox.widget.textbox,
    }
    local value_bg = wibox.widget {
      value_box,
      fg     = p.text_bright,
      widget = wibox.container.background,
    }

    local pill = wibox.widget {
      {
        {
          { glyph_box, fg = p.text_muted, widget = wibox.container.background },
          value_bg,
          spacing = dpi(5),
          layout  = wibox.layout.fixed.horizontal,
        },
        left   = dpi(8),
        right  = dpi(8),
        widget = wibox.container.margin,
      },
      bg                 = p.a(p.panel, 0.8),
      shape              = lozenge_shape,
      shape_border_width = dpi(1),
      shape_border_color = p.line_base,
      forced_height      = PILL_H,
      widget             = wibox.container.background,
    }

    pill._value    = value_box
    pill._value_bg = value_bg
    return pill
  end

  -- Pinta o valor: glow_hot se >= 90, senão text_bright.
  local function set_value(pill, text, pct_for_alert)
    pill._value:set_text(text)
    if pct_for_alert and pct_for_alert >= 90 then
      pill._value_bg.fg = p.glow_hot
    else
      pill._value_bg.fg = p.text_bright
    end
  end

  local pill_cpu = make_lozenge("cpu")
  local pill_mem = make_lozenge("mem")
  local pill_net = make_lozenge("net")
  local pill_vol = make_lozenge("vol")

  -- Relógio HH:MM + data "Mês DD" à direita das pílulas.
  local clock_time = wibox.widget {
    text   = "--:--",
    font   = MONO,
    valign = "center",
    widget = wibox.widget.textbox,
  }
  local clock_date = wibox.widget {
    text   = "---",
    font   = MONO,
    valign = "center",
    widget = wibox.widget.textbox,
  }
  local clock = wibox.widget {
    { clock_time, fg = p.text_bright, widget = wibox.container.background },
    { clock_date, fg = p.text_muted,  widget = wibox.container.background },
    spacing = dpi(6),
    layout  = wibox.layout.fixed.horizontal,
  }

  local pills = wibox.widget {
    pill_cpu,
    pill_mem,
    pill_net,
    pill_vol,
    spacing = dpi(2),
    layout  = wibox.layout.fixed.horizontal,
  }

  local row = wibox.widget {
    pills,
    clock,
    spacing = dpi(12),
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
        local rounded = math.floor(pct + 0.5)
        set_value(pill_cpu, string.format("%d%%", rounded), rounded)
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
        local rounded = math.floor(pct + 0.5)
        set_value(pill_mem, string.format("%d%%", rounded), rounded)
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

        set_value(pill_net, string.format("↑%s ↓%s", fmt_rate(up_rate), fmt_rate(down_rate)))
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
        set_value(pill_vol, string.format("%d%%", vol), vol)
      end
    )
  end

  --------------------------------------------------------------------------------
  -- CLOCK — os.date no próprio timer (síncrono, mas barato; não chama shell).
  --------------------------------------------------------------------------------
  local function update_clock()
    clock_time:set_text(os.date("%H:%M"))
    clock_date:set_text(os.date("%b %d"))
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
      update_clock()
    end,
  }

  return container
end
