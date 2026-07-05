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

  -- gpu_temp hover wired ONCE at construction. It was previously re-registered on
  -- every 3s temp poll inside the watch (the historic gpu_info Hover_signal-in-watch
  -- leak, R7). gpu_temp's bg tracks the temperature band, so this reads the LIVE bg
  -- on enter and restores it on leave.
  do
    local pre_bg
    gpu_temp_widget:connect_signal("mouse::enter", function()
      pre_bg = gpu_temp_widget.bg
      if type(pre_bg) == "string" and #pre_bg == 7 then
        gpu_temp_widget.bg = pre_bg .. "dd"
      end
      gpu_temp_widget.fg = p.base
      local w = mouse.current_wibox; if w then w.cursor = "hand1" end
    end)
    gpu_temp_widget:connect_signal("mouse::leave", function()
      if pre_bg then gpu_temp_widget.bg = pre_bg end
      local w = mouse.current_wibox; if w then w.cursor = "left_ptr" end
    end)
  end

  -- ONE combined nvidia-smi feeds BOTH readouts (was two separate `nvidia-smi -q`
  -- spawns every 3s). --query-gpu emits "<util>, <temp>" (nounits); every raw value
  -- is tonumber-guarded before use so a missing/failed nvidia-smi keeps the last
  -- reading instead of crashing on nil arithmetic (R4).
  watch(
    [[ nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits ]],
    3,
    function(_, stdout)
      local usage_s, temp_s = stdout:match("(%d+)%s*,%s*(%d+)")
      local usage_num = tonumber(usage_s)
      local temp_num = tonumber(temp_s)

      -- Utilization
      if usage_num then
        gpu_usage_widget.container.gpu_layout.label.text = tostring(usage_num) .. "%"
        awesome.emit_signal("update::gpu_usage_widget", usage_num)
      end

      -- Temperature (band -> color + thermometer icon)
      local temp_icon, temp_color
      if temp_num then
        if temp_num < 50 then
          temp_color = p.ok
          temp_icon = icon_dir .. "thermometer-low.svg"
        elseif temp_num < 80 then
          temp_color = p.warn
          temp_icon = icon_dir .. "thermometer.svg"
        else
          temp_color = p.crit
          temp_icon = icon_dir .. "thermometer-high.svg"
        end
      else
        temp_color = p.ok
        temp_icon = icon_dir .. "thermometer-low.svg"
      end
      gpu_temp_widget.container.gpu_layout.icon_margin.icon_layout.icon:set_image(temp_icon)
      gpu_temp_widget:set_bg(temp_color)
      gpu_temp_widget.container.gpu_layout.label.text = tostring(temp_num or "NaN") .. "°C"
      awesome.emit_signal("update::gpu_temp_widget", temp_num or "NaN", temp_icon)
    end
  )

  if widget == "usage" then
    return gpu_usage_widget
  elseif widget == "temp" then
    return gpu_temp_widget
  end
end
