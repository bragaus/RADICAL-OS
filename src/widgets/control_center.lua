------------------------------------------------------------------------------------------
-- src/widgets/control_center.lua — Barra superior de LOZENGES clicáveis + DASHBOARDS      --
--                                  on-click (VIOLET HUD · DESIGN_SYSTEM §5.1 §5.2 §7.2.1). --
--                                                                                        --
-- Constrói a fita TOP-CENTER de lozenges (pílulas com pontas de seta côncava, mesmo      --
-- shape/estilo do status_dock §7.2.1) com amostragem ASSÍNCRONA de cpu/mem/gpu/net/vol   --
-- + um segmento de relógio "HH:MM  Mês DD"; e os três popups de dashboard (SYSTEM /       --
-- NETWORK / TIME), fazendo o toggle on-click. Reaproveita os padrões de shape e de        --
-- coleta async de status_dock.lua.                                                       --
--                                                                                        --
--   〈 cpu% 〉〈 mem% 〉〈 gpu% 〉〈 net ↑↓ 〉〈 vol% 〉   HH:MM  Mês DD                     --
--                                                                                        --
-- Assinatura:                                                                            --
--   return function(s, opts) ... end                                                     --
--     opts.system_panels  = { widget, ... } -> dashboard SYSTEM  (INFO/USAGE/PROCESS)     --
--     opts.network_panels = { widget, ... } -> dashboard NETWORK (GRAPH/IP/CONN/...)      --
--     opts.time_panels    = { widget, ... } -> dashboard TIME    (CALENDAR/world clocks)  --
--                                                                                        --
-- TOGGLE: clicar num lozenge abre/fecha o popup do grupo; só um aberto por vez (abrir um  --
-- fecha os demais). CPU/MEM/GPU -> SYSTEM, NET -> NETWORK, relógio -> TIME, VOL ->         --
-- emite "volume_controller::toggle" (controlador de volume já existente).                --
--                                                                                        --
-- Amostragem SEMPRE assíncrona (awful.spawn.easy_async_with_shell) num único gears.timer  --
-- (2s, call_now). NUNCA io.popen/os.execute/sync — congela o WM. Todos os parses de       --
-- stdout passam por tonumber()/guarda de nil.                                            --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
require("src.core.signals") -- garante Hover_signal global

local MONO   = "JetBrainsMono Nerd Font 10"
local BAR_H  = dpi(28)
local PILL_H = dpi(20)

-- Glyphs Nerd Font para cada lozenge.
local GLYPH_CPU = ""
local GLYPH_MEM = ""
local GLYPH_GPU = "󰢮"
local GLYPH_NET = ""
local GLYPH_VOL = ""

-- Forma de lozenge: hexágono achatado (pontas de seta côncava), igual ao tab_shape
-- do taglist / status_dock. As pontas laterais apontam para fora (cápsula).
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

-- Formata uma taxa em bytes/s para um rótulo curto em KB/s (NN) ou MB/s (NNM).
local function fmt_rate(bps)
  bps = tonumber(bps) or 0
  if bps < 0 then bps = 0 end
  if bps >= 1048576 then
    return string.format("%.0fM", bps / 1048576)
  else
    return string.format("%.0f", bps / 1024)
  end
end

return function(s, opts)
  opts = opts or {}

  ----------------------------------------------------------------------------------------
  -- Cria uma lozenge (pílula hexagonal) com glyph + valor. Retorna o widget de fundo; o
  -- textbox do valor fica em ._value e o container de fg em ._value_bg (alterna glow_hot).
  ----------------------------------------------------------------------------------------
  local function make_lozenge(glyph)
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
      bg                 = p.a(p.panel, 0.8), -- panel@cc
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

  local pill_cpu = make_lozenge(GLYPH_CPU)
  local pill_mem = make_lozenge(GLYPH_MEM)
  local pill_gpu = make_lozenge(GLYPH_GPU)
  local pill_net = make_lozenge(GLYPH_NET)
  local pill_vol = make_lozenge(GLYPH_VOL)

  -- Segmento de relógio "HH:MM  Mês DD" (clicável -> dashboard TIME).
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
  local clock_segment = wibox.widget {
    {
      {
        { clock_time, fg = p.text_bright, widget = wibox.container.background },
        { clock_date, fg = p.text_muted,  widget = wibox.container.background },
        spacing = dpi(6),
        layout  = wibox.layout.fixed.horizontal,
      },
      left   = dpi(10),
      right  = dpi(2),
      widget = wibox.container.margin,
    },
    bg     = "#00000000",
    widget = wibox.container.background,
  }

  local pills = wibox.widget {
    pill_cpu,
    pill_mem,
    pill_gpu,
    pill_net,
    pill_vol,
    spacing = dpi(2),
    layout  = wibox.layout.fixed.horizontal,
  }

  local row = wibox.widget {
    pills,
    clock_segment,
    spacing = dpi(12),
    layout  = wibox.layout.fixed.horizontal,
  }

  local bar_widget = wibox.widget {
    {
      nil,
      {
        row,
        left   = dpi(10),
        right  = dpi(10),
        widget = wibox.container.margin,
      },
      nil,
      expand = "none",
      layout = wibox.layout.align.horizontal,
    },
    forced_height = BAR_H,
    bg            = "#00000000",
    widget        = wibox.container.background,
  }

  ----------------------------------------------------------------------------------------
  -- DASHBOARD POPUPS (SYSTEM / NETWORK / TIME).
  -- Cada popup empilha verticalmente os painéis daquele grupo (filtrando nil).
  ----------------------------------------------------------------------------------------
  local function stack_panels(panel_list)
    local stack = wibox.layout.fixed.vertical()
    stack.spacing = dpi(8)
    if panel_list then
      for _, panel in ipairs(panel_list) do
        if panel ~= nil then
          stack:add(panel)
        end
      end
    end
    return stack
  end

  local function make_dashboard(panel_list)
    return awful.popup {
      widget = {
        stack_panels(panel_list),
        margins = dpi(8),
        widget  = wibox.container.margin,
      },
      ontop     = true,
      visible   = false,
      screen    = s,
      bg        = "#0c0617e6", -- base@e6
      placement = function(c)
        awful.placement.top(c, { margins = { top = dpi(46) } })
      end,
    }
  end

  -- Guarda contra duplicatas em reload: esconde popups anteriores desta tela.
  if s._cc_dashboards then
    for _, old in pairs(s._cc_dashboards) do
      if old then old.visible = false end
    end
  end

  local dash_system  = make_dashboard(opts.system_panels)
  local dash_network = make_dashboard(opts.network_panels)
  local dash_time    = make_dashboard(opts.time_panels)

  local dashboards = {
    system  = dash_system,
    network = dash_network,
    time    = dash_time,
  }
  s._cc_dashboards = dashboards

  -- toggle(name): se o popup nomeado já está visível, esconde-o; senão esconde TODOS e
  -- mostra apenas esse (só um aberto por vez).
  local function toggle(name)
    local target = dashboards[name]
    if not target then return end
    local was_visible = target.visible
    for _, dash in pairs(dashboards) do
      dash.visible = false
    end
    target.visible = not was_visible
  end

  ----------------------------------------------------------------------------------------
  -- CLIQUES — cada lozenge clicável vira botão (button::press via :buttons()).
  -- Hover_signal aplica cursor hand1 + glow_ice no hover (não interfere com :buttons()).
  ----------------------------------------------------------------------------------------
  local function make_clickable(pill, on_click)
    Hover_signal(pill, nil, p.glow_ice)
    pill:buttons(gears.table.join(
      awful.button({}, 1, on_click)
    ))
  end

  make_clickable(pill_cpu, function() toggle("system") end)
  make_clickable(pill_mem, function() toggle("system") end)
  make_clickable(pill_gpu, function() toggle("system") end)
  make_clickable(pill_net, function() toggle("network") end)
  make_clickable(pill_vol, function()
    awesome.emit_signal("volume_controller::toggle", s)
  end)
  make_clickable(clock_segment, function() toggle("time") end)

  ----------------------------------------------------------------------------------------
  -- BARRA — popup fino top-center sempre visível. Guarda contra duplicata em reload.
  ----------------------------------------------------------------------------------------
  if s._control_center_bar then
    s._control_center_bar.visible = false
  end

  local bar = awful.popup {
    widget    = bar_widget,
    ontop     = false,
    visible   = true,
    screen    = s,
    bg        = "#0c0617cc", -- base@cc
    placement = function(c)
      awful.placement.top(c, { margins = { top = dpi(8) } })
    end,
  }
  s._control_center_bar = bar

  ----------------------------------------------------------------------------------------
  -- Estado entre ticks (deltas de CPU e NET).
  ----------------------------------------------------------------------------------------
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
  -- GPU — nvidia-smi utilization.gpu (%). Fallback "--" se o binário não existir
  -- ou a saída não for numérica.
  --------------------------------------------------------------------------------
  local function update_gpu()
    awful.spawn.easy_async_with_shell(
      "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local util = tonumber(stdout:match("%d+"))
        if not util then
          pill_gpu._value:set_text("--")
          pill_gpu._value_bg.fg = p.text_bright
          return
        end
        if util < 0 then util = 0 elseif util > 100 then util = 100 end
        set_value(pill_gpu, string.format("%d%%", util), util)
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
    timeout   = opts.timeout or 2,
    call_now  = true,
    autostart = true,
    callback  = function()
      update_cpu()
      update_mem()
      update_gpu()
      update_net()
      update_vol()
      update_clock()
    end,
  }

  return bar
end
