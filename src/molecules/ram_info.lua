---------------------------------
-- This is the RAM Info widget --
---------------------------------

-- Awesome Libs
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local watch = awful.widget.watch
local wibox = require("wibox")
require("src.core.signals")

local icon_dir = awful.util.getdir("config") .. "src/assets/icons/cpu/"

return function()
  local ram_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              image = gears.color.recolor_image(icon_dir .. "ram.svg", p.data2),
              resize = false
            },
            id = "icon_layout",
            widget = wibox.container.place
          },
          top = dpi(2),
          widget = wibox.container.margin,
          id = "icon_margin"
        },
        spacing = dpi(10),
        {
          id = "label",
          align = "center",
          valign = "center",
          widget = wibox.widget.textbox
        },
        id = "ram_layout",
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

  Hover_signal(ram_widget, p.panel, p.data2)

  watch(
    [[ bash -c "cat /proc/meminfo| grep Mem | awk '{print $2}'" ]],
    3,
    function(_, stdout)
      -- grep Mem -> MemTotal, MemFree, MemAvailable (file order), awk $2 = KB.
      -- Guard EVERY parsed value before arithmetic: a failed match leaves nils and
      -- `MemTotal - MemAvailable` on nil crashes the widget (R4). nil -> keep last.
      local total_s, _free_s, avail_s = stdout:match("(%d+)%s+(%d+)%s+(%d+)")
      local MemTotal = tonumber(total_s)
      local MemAvailable = tonumber(avail_s)
      if not (MemTotal and MemAvailable) then return end

      local used_gb  = (MemTotal - MemAvailable) / 1024 / 1024
      local total_gb = MemTotal / 1024 / 1024
      ram_widget.container.ram_layout.label.text =
        (string.format("%.1f/%.1fGB", used_gb, total_gb)):gsub(",", ".")
    end
  )

  return ram_widget
end
