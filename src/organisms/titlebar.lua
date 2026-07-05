-----------------------------------
-- This is the titlebar module --
-----------------------------------

-- Awesome Libs
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local icon_button = require("src.molecules.icon_button") -- chrome buttons (§3.13.1)

awful.titlebar.enable_tooltip = true
awful.titlebar.fallback_name = 'Client'

-- Double-click detection for the titlebar body. double_click_timer is a MODULE-LOCAL
-- upvalue (it was an accidental IMPLICIT GLOBAL before the rewire).
local double_click_timer
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
            c.floating = false
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

-- Chrome button width — matches the pre-rewire create_*_button factories (live 26px;
-- no metric token, same precedent as icon_button's own default width comment).
local BTN_W = dpi(26)

-- Single titlebar builder (merged create_titlebar + create_titlebar_dialog).
--   minimal = true -> DIALOG variant: only minimize + close (no sticky/ontop/maximize).
-- Every chrome button is the shared icon_button molecule (cached-surface hover swap,
-- self-set _preserve_colors) — replaces the old create_chrome_button/create_icon_button.
local create_titlebar = function(c, bg, size, minimal)
  local titlebar = awful.titlebar(c, {
    position = "top",
    bg = bg,
    size = size
  })

  local controls = wibox.layout.fixed.horizontal()
  controls.spacing = dpi(2)

  if not minimal then
    -- STICKY (fixar em todas as tags) e ONTOP (manter acima) — toggles do set icons/.
    controls:add(icon_button {
      icon = "sticky", size = dpi(mt.icon_md), width = BTN_W, hover_color = p.v400,
      on_click = function() c.sticky = not c.sticky end,
    })
    controls:add(icon_button {
      icon = "visible", size = dpi(mt.icon_md), width = BTN_W, hover_color = p.v400,
      on_click = function() c.ontop = not c.ontop end,
    })
  end

  controls:add(icon_button {
    glyph = "_", width = BTN_W, hover_color = p.v400,
    on_click = function()
      gears.timer.delayed_call(function() c.minimized = not c.minimized end)
    end,
  })

  if not minimal then
    controls:add(icon_button {
      icon = "fullscreen", size = dpi(mt.icon_md), width = BTN_W, hover_color = p.v400,
      on_click = function()
        c.maximized = not c.maximized
        c:raise()
      end,
    })
  end

  controls:add(icon_button {
    icon = "close", size = dpi(mt.icon_md), width = BTN_W, danger = true,
    on_click = function() c:kill() end,
  })

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
      controls,
      layout = wibox.layout.align.horizontal,
      id     = "main",
    },
    widget  = wibox.container.background,
    bg      = p.a(p.panel, p.alpha.panel),
    bgimage = function(_, cr, width, height)
      -- bottom 1px divider in line_base
      cr:set_source(gears.color(p.line_base))
      cr:rectangle(0, height - dpi(mt.border_panel), width, dpi(mt.border_panel))
      cr:fill()
    end,
  }
end

local draw_titlebar = function(c)
  local bg = p.a(p.panel, p.alpha.panel)
  if c.type == 'normal' and not c.requests_no_titlebar then
    if c.class == 'Firefox' then
      create_titlebar(c, bg, dpi(22))
    elseif c.name == "Steam" then
      create_titlebar(c, bg, 0)
    elseif c.name == "Settings" then
      create_titlebar(c, bg, 0)
    elseif c.class == "gcr-prompter" or c.class == "Gcr-prompter" then
      create_titlebar(c, bg, 0)
    else
      create_titlebar(c, bg, dpi(22))
    end
  elseif c.type == 'dialog' then
    create_titlebar(c, bg, dpi(22), true) -- minimal (dialog): minimize + close only
  end
end

client.connect_signal(
  "request::titlebars",
  function(c)
    if c.maximized or not c.minimized then
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
