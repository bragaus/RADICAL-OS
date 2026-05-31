--------------------------------------------------------------------------------------------------------------
-- This is the statusbar, every widget, module and so on is combined to all the stuff you see on the screen --
--------------------------------------------------------------------------------------------------------------
-- Awesome Libs
local awful = require("awful")
local color = require("src.theme.colors")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local gfs = require("gears.filesystem")
local wibox = require("wibox")

return function(s, widgets)
  widgets = widgets or {}
  local modkey = user_vars.modkey
  local widget_margin = dpi(6)

  local max_width = dpi(500)
  local max_height = dpi(45)
  local min_width = dpi(260)
  local min_height = dpi(45)
  local popup_ontop = true
  local popup_type = "dock"
  local popup_opacity = 1
  local reserve_space = true
  local input_passthrough = false
  local allow_modkey_drag = false
  local allow_modkey_resize = false
  local popup_state_key = nil

  for _, widget in ipairs(widgets) do
    max_width = math.max(max_width, widget._preferred_segment_width or dpi(500))
    max_height = math.max(max_height, widget._preferred_segment_height or dpi(45))
    min_width = math.max(min_width, widget._minimum_segment_width or math.min(widget._preferred_segment_width or dpi(260), dpi(260)))
    min_height = math.max(min_height, widget._minimum_segment_height or math.min(widget._preferred_segment_height or dpi(45), dpi(45)))

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
  
    if widget._allow_modkey_drag then
      allow_modkey_drag = true
      input_passthrough = false
    end

    if widget._allow_modkey_resize then
      allow_modkey_resize = true
      input_passthrough = false
    end

    if not popup_state_key and widget._popup_state_key then
      popup_state_key = widget._popup_state_key
    end
  end

  local current_width = max_width + widget_margin * 2
  local current_height = max_height + widget_margin * 2
  local minimum_width = min_width + widget_margin * 2
  local minimum_height = min_height + widget_margin * 2
  local state_path = popup_state_key and string.format("%scenter_bar_%s_screen_%d.state", gfs.get_cache_dir(), popup_state_key, s.index) or nil
  local popup_instance_key = popup_state_key and ("center_bar::" .. popup_state_key) or nil
  local initializing_geometry = true
  local active_grabber = nil

  local function clamp(value, lower, upper)
    return math.max(lower, math.min(upper, value))
  end

  local function notify_resize(width, height)
    local widget_width = math.max(1, width - widget_margin * 2)
    local widget_height = math.max(1, height - widget_margin * 2)

    for _, widget in ipairs(widgets) do
      if widget._handle_popup_resize then
        widget._handle_popup_resize(widget_width, widget_height)
      end
    end
  end

  local function load_saved_geometry()
    if not state_path then
      return nil
    end

    local file = io.open(state_path, "r")
    if not file then
      return nil
    end

    local geometry = {}

    for line in file:lines() do
      local key, value = line:match("^(%w+)=(-?%d+)$")
      if key and value then
        geometry[key] = tonumber(value)
      end
    end

    file:close()
    return geometry
  end

  local saved_geometry = load_saved_geometry()

  if saved_geometry then
    current_width = saved_geometry.width or current_width
    current_height = saved_geometry.height or current_height
  end

  local function place_popup(c)
    local workarea = s.workarea

    if saved_geometry and saved_geometry.x and saved_geometry.y then
      local bounded_x = clamp(math.floor(saved_geometry.x), workarea.x, workarea.x + math.max(0, workarea.width - c.width))
      local bounded_y = clamp(math.floor(saved_geometry.y), workarea.y, workarea.y + math.max(0, workarea.height - c.height))
      c:geometry {
        x = bounded_x,
        y = bounded_y,
      }
      return
    end

    awful.placement.top(c, { margins = dpi(10) })
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
    minimum_width = minimum_width,
    minimum_height = minimum_height,
    maximum_width = s.workarea.width - dpi(24),
    maximum_height = s.workarea.height - dpi(24),
    placement = place_popup,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end
  }

  local previous_active_popup = s._active_center_bar_popup
  if previous_active_popup and previous_active_popup ~= top_center then
    previous_active_popup.visible = false
  end

  s._active_center_bar_popup = top_center

  if popup_instance_key then
    s._center_bar_instances = s._center_bar_instances or {}

    local previous_popup = s._center_bar_instances[popup_instance_key]
    if previous_popup and previous_popup ~= top_center then
      previous_popup.visible = false
    end

    s._center_bar_instances[popup_instance_key] = top_center
  end

  local save_geometry_timer = gears.timer {
    timeout = 0.25,
    autostart = false,
    single_shot = true,
    callback = function()
      if initializing_geometry or not state_path then
        return
      end

      local ok = pcall(function()
        os.execute("mkdir -p " .. string.format("%q", gfs.get_cache_dir()))
        local file = assert(io.open(state_path, "w"))
        local geo = top_center:geometry()
        file:write(string.format("x=%d\ny=%d\nwidth=%d\nheight=%d\n", geo.x, geo.y, geo.width, geo.height))
        file:close()
      end)

      if not ok then
        -- Ignore cache write failures to keep the panel usable.
      end
    end,
  }

  local function queue_save_geometry()
    if initializing_geometry or not state_path then
      return
    end

    save_geometry_timer:again()
  end

  if reserve_space then
    top_center:struts {
      top = math.max(dpi(55), math.min(max_height + dpi(24), dpi(132)))
    }
  end

  local function prepare_widgets(widget_list)
    local layout = wibox.layout.fixed.horizontal()
    layout.forced_height = max_height

    for i, widget in ipairs(widget_list) do
      if i == 1 then
        layout:add(
          wibox.widget {
          widget,
          left = widget_margin,
          right = widget_margin,
          top = widget_margin,
          bottom = widget_margin,
          widget = wibox.container.margin
        }
        )
      elseif i == #widget_list then
        layout:add(
          wibox.widget {
          widget,
          left = dpi(3),
          right = widget_margin,
          top = widget_margin,
          bottom = widget_margin,
          widget = wibox.container.margin
        }
        )
      else
        layout:add(
          wibox.widget {
          widget,
          left = dpi(3),
          right = dpi(3),
          top = widget_margin,
          bottom = widget_margin,
          widget = wibox.container.margin
        }
        )
      end
    end

    return layout
  end

  local prepared_widgets = prepare_widgets(widgets)
  local content_constraint = wibox.widget {
    prepared_widgets,
    forced_width = current_width,
    forced_height = current_height,
    strategy = "exact",
    widget = wibox.container.constraint,
  }

  local interaction_surface = wibox.widget {
    content_constraint,
    bg = "#00000000",
    widget = wibox.container.background,
  }

  top_center:setup {
    nil,
    interaction_surface,
    nil,
    layout = wibox.layout.align.horizontal
  }

  local function apply_size(width, height)
    local workarea = s.workarea
    local bounded_width = clamp(math.floor(width), minimum_width, math.max(minimum_width, workarea.width - dpi(24)))
    local bounded_height = clamp(math.floor(height), minimum_height, math.max(minimum_height, workarea.height - dpi(24)))

    current_width = bounded_width
    current_height = bounded_height
    prepared_widgets.forced_height = bounded_height
    content_constraint.forced_width = bounded_width
    content_constraint.forced_height = bounded_height
    notify_resize(bounded_width, bounded_height)
    top_center:geometry { width = bounded_width, height = bounded_height }
    queue_save_geometry()
  end

  local function move_popup(button_index)
    if active_grabber then
      return
    end

    local start_geo = top_center:geometry()
    local start_coords = mouse.coords()
    active_grabber = "move"

    local ok = pcall(mousegrabber.run, function(mouse_state)
      if not mouse_state.buttons[button_index] then
        active_grabber = nil
        queue_save_geometry()
        return false
      end

      local workarea = s.workarea
      local next_x = clamp(start_geo.x + (mouse_state.x - start_coords.x), workarea.x, workarea.x + math.max(0, workarea.width - start_geo.width))
      local next_y = clamp(start_geo.y + (mouse_state.y - start_coords.y), workarea.y, workarea.y + math.max(0, workarea.height - start_geo.height))
      top_center:geometry {
        x = next_x,
        y = next_y,
      }
      return true
    end, "fleur")

    if not ok then
      active_grabber = nil
    end
  end

  local function resize_popup(button_index)
    if active_grabber then
      return
    end

    local start_geo = top_center:geometry()
    local start_coords = mouse.coords()
    active_grabber = "resize"

    local ok = pcall(mousegrabber.run, function(mouse_state)
      if not mouse_state.buttons[button_index] then
        active_grabber = nil
        queue_save_geometry()
        return false
      end

      local next_width = start_geo.width + (mouse_state.x - start_coords.x)
      local next_height = start_geo.height + (mouse_state.y - start_coords.y)
      apply_size(next_width, next_height)
      return true
    end, "sizing")

    if not ok then
      active_grabber = nil
    end
  end

  local buttons = {}

  if allow_modkey_drag then
    buttons[#buttons + 1] = awful.button({}, 1, function()
      move_popup(1)
    end)

    buttons[#buttons + 1] = awful.button({ modkey }, 1, function()
      move_popup(1)
    end)
  end

  if allow_modkey_resize then
    buttons[#buttons + 1] = awful.button({}, 3, function()
      resize_popup(3)
    end)

    buttons[#buttons + 1] = awful.button({ modkey }, 3, function()
      resize_popup(3)
    end)
  end

  if #buttons > 0 then
    local popup_buttons = gears.table.join(table.unpack(buttons))
    interaction_surface:buttons(popup_buttons)
  end

  if state_path then
    top_center:connect_signal("property::x", queue_save_geometry)
    top_center:connect_signal("property::y", queue_save_geometry)
    top_center:connect_signal("property::width", queue_save_geometry)
    top_center:connect_signal("property::height", queue_save_geometry)
  end

  apply_size(current_width, current_height)
  gears.timer.delayed_call(function()
    place_popup(top_center)
    initializing_geometry = false
    queue_save_geometry()
  end)

  local function update_visibility()
    if s._active_center_bar_popup ~= top_center then
      top_center.visible = false
      return
    end

    if popup_instance_key and s._center_bar_instances and s._center_bar_instances[popup_instance_key] ~= top_center then
      top_center.visible = false
      return
    end

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
