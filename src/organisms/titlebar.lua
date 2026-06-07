-----------------------------------
-- This is the titlebar module --
-----------------------------------

-- Awesome Libs
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local p = require("src.theme.palette")
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)
require("src.core.signals")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/titlebar/"
-- VIOLET HUD icon set (icons/svg/) — close / fullscreen p/ os botões de chrome (§3.13.1).
local hud_svg = awful.util.getdir("config") .. "icons/svg/"

awful.titlebar.enable_tooltip = true
awful.titlebar.fallback_name = 'Client'

local double_click_event_handler = function(double_click_event)
  if double_click_timer then
    double_click_timer:stop()
    double_click_timer = nil
    double_click_event()
    return
  end
  double_click_timer = gears.timer.start_new(
    0.20,
    function()
      double_click_timer = nil
      return false
    end
  )
end

local create_click_events = function(c)
  local buttons = gears.table.join(
    awful.button(
      {},
      1,
      function()
        double_click_event_handler(function()
          if c.floating then
            c.float = false
            return
          end
          c.maximized = not c.maximized
          c:raise()
        end)
        c:activate { context = 'titlebar', action = 'mouse_move' }
      end
    ),
    awful.button(
      {},
      3,
      function()
        c:activate { context = 'titlebar', action = 'mouse_resize' }
      end
    )
  )
  return buttons
end

-- Textual chrome button: a glyph in p.text_muted that recolors on hover.
--   glyph        the label text (e.g. "_", "[]" , "x")
--   hover_fg     foreground when hovered/pressed
--   action       function run on left click
local create_chrome_button = function(c, glyph, hover_fg, action)
  local label = wibox.widget {
    markup = glyph,
    font   = (user_vars.font and user_vars.font.bold) or "JetBrainsMono Nerd Font, bold 14",
    align  = "center",
    valign = "center",
    widget = wibox.widget.textbox,
  }

  local button = wibox.widget {
    label,
    fg            = p.text_muted,
    bg            = "#00000000",
    forced_width  = dpi(26),
    widget        = wibox.container.background,
  }

  button:buttons(gears.table.join(
    awful.button({}, 1, nil, function()
      action()
    end)
  ))

  Hover_signal(button, nil, hover_fg)

  return button
end

-- Botão de chrome com ÍCONE SVG (set icons/) em vez de glyph. Repouso text_muted,
-- hover -> hover_fg (recolor da imagem; imagebox não muda cor via fg).
local create_icon_button = function(c, icon_name, hover_fg, action)
  local svg = hud_svg .. icon_name .. ".svg"
  local ib = Icon(icon_name, { size = dpi(14), color = p.text_muted })

  local button = wibox.widget {
    { ib, widget = wibox.container.place },
    bg           = "#00000000",
    forced_width = dpi(26),
    widget       = wibox.container.background,
  }

  button:buttons(gears.table.join(
    awful.button({}, 1, nil, function()
      action()
    end)
  ))

  button:connect_signal("mouse::enter", function() ib.image = gears.color.recolor_image(svg, hover_fg) end)
  button:connect_signal("mouse::leave", function() ib.image = gears.color.recolor_image(svg, p.text_muted) end)
  Hover_signal(button, nil, hover_fg)

  return button
end

local create_titlebar = function(c, bg, size)
  local titlebar = awful.titlebar(c, {
    position = "top",
    bg = bg,
    size = size
  })

  -- STICKY (fixar em todas as tags) e ONTOP (manter acima) — toggles do set icons/.
  local sticky_button = create_icon_button(c, "sticky", p.v400, function()
    c.sticky = not c.sticky
  end)

  local ontop_button = create_icon_button(c, "visible", p.v400, function()
    c.ontop = not c.ontop
  end)

  local minimize_button = create_chrome_button(c, "_", p.v400, function()
    gears.timer.delayed_call(function()
      c.minimized = not c.minimized
    end)
  end)

  local maximize_button = create_icon_button(c, "fullscreen", p.v400, function()
    c.maximized = not c.maximized
    c:raise()
  end)

  local close_button = create_icon_button(c, "close", p.crit, function()
    c:kill()
  end)

  local title = wibox.widget {
    awful.titlebar.widget.titlewidget(c),
    fg     = p.text_primary,
    widget = wibox.container.background,
  }

  titlebar:setup {
    {
      {
        title,
        buttons = create_click_events(c),
        left    = dpi(10),
        widget  = wibox.container.margin,
      },
      {
        buttons = create_click_events(c),
        layout  = wibox.layout.flex.horizontal,
      },
      {
        sticky_button,
        ontop_button,
        minimize_button,
        maximize_button,
        close_button,
        spacing = dpi(2),
        layout  = wibox.layout.fixed.horizontal,
        id      = "spacing",
      },
      layout = wibox.layout.align.horizontal,
      id     = "main",
    },
    widget  = wibox.container.background,
    bg      = p.panel .. "e6",
    bgimage = function(_, cr, width, height)
      -- bottom 1px divider in line_base
      cr:set_source(gears.color(p.line_base))
      cr:rectangle(0, height - dpi(1), width, dpi(1))
      cr:fill()
    end,
  }
end

local create_titlebar_dialog = function(c, bg, size)
  local titlebar = awful.titlebar(c, {
    position = "top",
    bg = bg,
    size = size
  })

  local minimize_button = create_chrome_button(c, "_", p.v400, function()
    gears.timer.delayed_call(function()
      c.minimized = not c.minimized
    end)
  end)

  local close_button = create_icon_button(c, "close", p.crit, function()
    c:kill()
  end)

  local title = wibox.widget {
    awful.titlebar.widget.titlewidget(c),
    fg     = p.text_primary,
    widget = wibox.container.background,
  }

  titlebar:setup {
    {
      {
        title,
        buttons = create_click_events(c),
        left    = dpi(10),
        widget  = wibox.container.margin,
      },
      {
        buttons = create_click_events(c),
        layout  = wibox.layout.flex.horizontal,
      },
      {
        minimize_button,
        close_button,
        spacing = dpi(2),
        layout  = wibox.layout.fixed.horizontal,
        id      = "spacing",
      },
      layout = wibox.layout.align.horizontal,
      id     = "main",
    },
    widget  = wibox.container.background,
    bg      = p.panel .. "e6",
    bgimage = function(_, cr, width, height)
      -- bottom 1px divider in line_base
      cr:set_source(gears.color(p.line_base))
      cr:rectangle(0, height - dpi(1), width, dpi(1))
      cr:fill()
    end,
  }
end

local draw_titlebar = function(c)
  if c.type == 'normal' and not c.requests_no_titlebar then
    if c.class == 'Firefox' then
      create_titlebar(c, p.panel .. "e6", dpi(22))
    elseif c.name == "Steam" then
      create_titlebar(c, p.panel .. "e6", 0)
    elseif c.name == "Settings" then
      create_titlebar(c, p.panel .. "e6", 0)
    elseif c.class == "gcr-prompter" or c.class == "Gcr-prompter" then
      create_titlebar(c, p.panel .. "e6", 0)
    else
      create_titlebar(c, p.panel .. "e6", dpi(22))
    end
  elseif c.type == 'dialog' then
    create_titlebar_dialog(c, p.panel .. "e6", dpi(22))
  end
end

client.connect_signal(
  "property::maximized",
  function(c)
    if c.maximized then
      Theme.titlebar_maximized_button_normal = icondir .. "unmaximize.svg"
      Theme.titlebar_maximized_button_active = icondir .. "unmaximize.svg"
      Theme.titlebar_maximized_button_inactive = icondir .. "unmaximize.svg"
    elseif not c.minimized then
      Theme.titlebar_maximized_button_normal = icondir .. "maximize.svg"
      Theme.titlebar_maximized_button_active = icondir .. "maximize.svg"
      Theme.titlebar_maximized_button_inactive = icondir .. "maximize.svg"
    end
  end
)

client.connect_signal(
  "request::titlebars",
  function(c)
    if c.maximized then
      Theme.titlebar_maximized_button_normal = icondir .. "unmaximize.svg"
      Theme.titlebar_maximized_button_active = icondir .. "unmaximize.svg"
      Theme.titlebar_maximized_button_inactive = icondir .. "unmaximize.svg"
      draw_titlebar(c)
    elseif not c.minimized then
      Theme.titlebar_maximized_button_normal = icondir .. "maximize.svg"
      Theme.titlebar_maximized_button_active = icondir .. "maximize.svg"
      Theme.titlebar_maximized_button_inactive = icondir .. "maximize.svg"
      draw_titlebar(c)
    end
    if not c.floating or c.maximized then
      awful.titlebar.hide(c, 'left')
      awful.titlebar.hide(c, 'right')
      awful.titlebar.hide(c, 'top')
      awful.titlebar.hide(c, 'bottom')
    end
  end
)

client.connect_signal(
  'property::floating',
  function(c)
    if c.floating or (c.floating and c.maximized) then
      awful.titlebar.show(c, 'top')
      awful.titlebar.hide(c, 'left')
      awful.titlebar.hide(c, 'right')
      awful.titlebar.hide(c, 'bottom')
    else
      awful.titlebar.hide(c, 'left')
      awful.titlebar.hide(c, 'right')
      awful.titlebar.hide(c, 'top')
      awful.titlebar.hide(c, 'bottom')
    end
  end
)
