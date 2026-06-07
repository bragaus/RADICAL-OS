---------------------------------
-- This is the CPU Info widget --
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

return function(widget)
  local gpu_usage_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              image = gears.color.recolor_image(icon_dir .. "gpu.svg", p.base),
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
        id = "gpu_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.data3,
    fg = p.base,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }
  Hover_signal(gpu_usage_widget, p.data3, p.base)

  local gpu_temp_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              image = gears.color.recolor_image(icon_dir .. "cpu.svg", p.base),
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
        id = "gpu_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.v500,
    fg = p.base,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  -- GPU Utilization
  watch(
    [[ bash -c "nvidia-smi -q -d UTILIZATION | grep Gpu | awk '{print $3}'"]],
    3,
    function(_, stdout)
      gpu_usage_widget.container.gpu_layout.label.text = stdout:gsub("\n", "") .. "%"
      awesome.emit_signal("update::gpu_usage_widget", tonumber(stdout))
    end
  )

  -- GPU Temperature
  watch(
    [[ bash -c "nvidia-smi -q -d TEMPERATURE | grep 'GPU Current Temp' | awk '{print $5}'"]],
    3,
    function(_, stdout)

      local temp_icon
      local temp_color
      local temp_num = tonumber(stdout)

      if temp_num then

        if temp_num < 50 then
          temp_color = p.ok
          temp_icon = icon_dir .. "thermometer-low.svg"
        elseif temp_num >= 50 and temp_num < 80 then
          temp_color = p.warn
          temp_icon = icon_dir .. "thermometer.svg"
        elseif temp_num >= 80 then
          temp_color = p.crit
          temp_icon = icon_dir .. "thermometer-high.svg"
        end
      else
        temp_num = "NaN"
        temp_color = p.ok
        temp_icon = icon_dir .. "thermometer-low.svg"
      end
      Hover_signal(gpu_temp_widget, temp_color, p.base)
      gpu_temp_widget.container.gpu_layout.icon_margin.icon_layout.icon:set_image(temp_icon)
      gpu_temp_widget:set_bg(temp_color)
      gpu_temp_widget.container.gpu_layout.label.text = tostring(temp_num) .. "°C"
      awesome.emit_signal("update::gpu_temp_widget", temp_num, temp_icon)

    end
  )

  if widget == "usage" then
    return gpu_usage_widget
  elseif widget == "temp" then
    return gpu_temp_widget
  end
end
