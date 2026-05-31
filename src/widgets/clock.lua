------------------------------
-- This is the clock widget --
------------------------------

-- Awesome Libs
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
require("src.core.signals")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/clock/"

-- Returns the clock widget
return function()

  local clock_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              image = gears.color.recolor_image(icondir .. "clock.svg", p.v400),
              widget = wibox.widget.imagebox,
              resize = false
            },
            id = "icon_layout",
            widget = wibox.container.place
          },
          id = "icon_margin",
          top = dpi(2),
          widget = wibox.container.margin
        },
        spacing = dpi(10),
        {
          id = "label",
          align = "center",
          valign = "center",
          format = "%H:%M",
          widget = wibox.widget.textclock
        },
        id = "clock_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.panel,
    fg = p.text_bright,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  Hover_signal(clock_widget, p.v700, p.text_bright)

  return clock_widget
end

