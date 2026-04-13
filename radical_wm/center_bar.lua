--------------------------------------------------------------------------------------------------------------
-- This is the statusbar, every widget, module and so on is combined to all the stuff you see on the screen --
--------------------------------------------------------------------------------------------------------------
-- Awesome Libs
local awful = require("awful")
local color = require("src.theme.colors")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")

return function(s, widgets)
  widgets = widgets or {}

  local max_width = dpi(500)
  local max_height = dpi(45)
  local popup_ontop = true
  local popup_type = "dock"
  local popup_opacity = 1
  local reserve_space = true
  local input_passthrough = false

  for _, widget in ipairs(widgets) do
    max_width = math.max(max_width, widget._preferred_segment_width or dpi(500))
    max_height = math.max(max_height, widget._preferred_segment_height or dpi(45))

    if widget._popup_ontop == false then
      popup_ontop = false
    end

    if widget._popup_type then
      popup_type = widget._popup_type
    end

    if widget._popup_opacity then
      popup_opacity = math.min(popup_opacity, widget._popup_opacity)
    end

    if widget._reserve_space == false then
      reserve_space = false
    end

    if widget._input_passthrough then
      input_passthrough = true
    end
  end

  local top_center = awful.popup {
    screen = s,
    widget = wibox.container.background,
    ontop = popup_ontop,
    bg = "#00000000",
    visible = true,
    opacity = popup_opacity,
    type = popup_type,
    input_passthrough = input_passthrough,
    maximum_width = max_width + dpi(36),
    placement = function(c) awful.placement.top(c, { margins = dpi(10) }) end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end
  }

  if reserve_space then
    top_center:struts {
      top = math.max(dpi(55), math.min(max_height + dpi(24), dpi(132)))
    }
  end

  local function prepare_widgets(widgets)
    local layout = {
      forced_height = max_height,
      layout = wibox.layout.fixed.horizontal
    }
    for i, widget in pairs(widgets) do
      if i == 1 then
        table.insert(layout,
          {
          widget,
          left = dpi(6),
          right = dpi(6),
          top = dpi(6),
          bottom = dpi(6),
          widget = wibox.container.margin
        })
      elseif i == #widgets then
        table.insert(layout,
          {
          widget,
          left = dpi(3),
          right = dpi(6),
          top = dpi(6),
          bottom = dpi(6),
          widget = wibox.container.margin
        })
      else
        table.insert(layout,
          {
          widget,
          left = dpi(3),
          right = dpi(3),
          top = dpi(6),
          bottom = dpi(6),
          widget = wibox.container.margin
        })
      end
    end
    return layout
  end

  top_center:setup {
    nil,
    prepare_widgets(widgets),
    nil,
    layout = wibox.layout.align.horizontal
  }

  local function update_visibility()
    local selected_tag = s.selected_tag
    local always_visible = false

    for _, widget in ipairs(widgets) do
      if widget._always_visible then
        always_visible = true
        break
      end
    end

    top_center.visible = always_visible or (selected_tag and #selected_tag:clients() > 0 or false)
  end

  client.connect_signal("manage", update_visibility)
  client.connect_signal("unmanage", update_visibility)
  client.connect_signal("tagged", update_visibility)
  client.connect_signal("untagged", update_visibility)
  tag.connect_signal("property::selected", update_visibility)
  awesome.connect_signal("refresh", update_visibility)
update_visibility()

end
