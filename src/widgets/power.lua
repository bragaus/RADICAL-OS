--------------------------------
-- This is the power widget --
--------------------------------

-- Awesome Libs
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
require("src.core.signals")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/power/"

return function()
  local power_icon = wibox.widget {
    {
      {
        image = gears.color.recolor_image(icondir .. "power.svg", "#ffffff"),
        resize = true,
        widget = wibox.widget.imagebox,
      },
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    forced_width = dpi(18),
    forced_height = dpi(18),
    strategy = "exact",
    widget = wibox.container.constraint,
  }

  local power_widget = wibox.widget {
    {
      {
        power_icon,
        halign = "center",
        valign = "center",
        id = "power_layout",
        widget = wibox.container.place,
      },
      id = "container",
      left = dpi(10),
      right = dpi(10),
      top = dpi(3),
      bottom = dpi(3),
      widget = wibox.container.margin
    },
    bg = "#1f1f1f",
    fg = "#ffffff",
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  power_widget._preserve_colors = true
  power_widget._segment_bg = "#1f1f1f"
  power_widget._segment_edge = "#1f1f1f"
  power_widget._segment_border_width = 0
  power_widget._preferred_segment_width = dpi(44)
  power_widget._preferred_segment_height = dpi(46)

  -- Signals
  Hover_signal(power_widget, "#1f1f1f", "#ffffff")

  power_widget:connect_signal(
    "button::release",
    function()
      awesome.emit_signal("module::powermenu:show")
    end
  )

  return power_widget
end
