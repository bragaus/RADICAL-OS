---@diagnostic disable: undefined-field
-- Awesome Libs
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")

local function client_transparency_config()
  return (user_vars.transparency and user_vars.transparency.clients) or {}
end

local function resolve_default_client_opacity(c)
  local transparency = client_transparency_config()
  if transparency.enabled == false then
    return 1
  end

  local class_defaults = transparency.class_defaults or {}
  if c.class and class_defaults[c.class] ~= nil then
    return class_defaults[c.class]
  end

  if c.instance and class_defaults[c.instance] ~= nil then
    return class_defaults[c.instance]
  end

  return transparency.default_opacity or 1
end

local function apply_default_client_opacity(c)
  c._opacity_default = resolve_default_client_opacity(c)

  if not c._opacity_toggle_active then
    c.opacity = c._opacity_default
  end
end

-- Restart on screen change AFTER startup settles. Guards against
-- xrandr-in-autostart triggering an infinite restart loop on boot.
local screen_change_settle_timer = nil
local startup_settled = false

gears.timer.start_new(8, function()
  startup_settled = true
  return false
end)

local function schedule_restart_on_screen_change()
  if not startup_settled then
    return
  end
  if screen_change_settle_timer then
    screen_change_settle_timer:stop()
  end
  screen_change_settle_timer = gears.timer.start_new(2, function()
    awesome.restart()
    return false
  end)
end

screen.connect_signal("added", schedule_restart_on_screen_change)
screen.connect_signal("removed", schedule_restart_on_screen_change)

client.connect_signal(
  "manage",
  function(c)
    if awesome.startup and not c.size_hints.user_porition and not c.size_hints.program_position then
      awful.placement.no_offscreen(c)
    end
    c.shape = function(cr, width, height)
      if c.fullscreen or c.maximized then
        gears.shape.rectangle(cr, width, height)
    else
      gears.shape.rounded_rect(cr, width, height, 10)
    end
  end

    apply_default_client_opacity(c)
  end
)

client.connect_signal("property::class", apply_default_client_opacity)
client.connect_signal("property::instance", apply_default_client_opacity)

awesome.connect_signal("client::transparency:toggle", function(c)
  local target = c or client.focus
  if not target then
    return
  end

  local transparency = client_transparency_config()
  if transparency.enabled == false then
    return
  end

  local default_opacity = target._opacity_default or resolve_default_client_opacity(target)
  local toggle_opacity = transparency.toggle_opacity or 0.86

  target._opacity_toggle_active = not target._opacity_toggle_active
  target.opacity = target._opacity_toggle_active and toggle_opacity or default_opacity
end)

client.connect_signal(
  'unmanage',
  function(c)
    if #awful.screen.focused().clients > 0 then
      awful.screen.focused().clients[1]:emit_signal(
        'request::activate',
        'mouse_enter',
        {
          raise = true
        }
      )
    end
  end
)

client.connect_signal(
  'tag::switched',
  function(c)
    if #awful.screen.focused().clients > 0 then
      awful.screen.focused().clients[1]:emit_signal(
        'request::activate',
        'mouse_enter',
        {
          raise = true
        }
      )
    end
  end
)

-- Sloppy focus
client.connect_signal(
  "mouse::enter",
  function(c)
    c:emit_signal(
      "request::activate",
      "mouse_enter",
      {
        raise = false
      }
    )
  end
)

-- Prevents fullscreen window cutoff.  
client.connect_signal(
  "property::fullscreen",
  function(c)
    if c.fullscreen then
      c.floating = true
      c:geometry(screen.primary.geometry)
    else
      c.floating = false
    end
  end
)

-- Workaround for focused border color, why in the love of god doesnt it work with
-- beautiful.border_focus
client.connect_signal(
  "focus",
  function(c)
    c.border_width = beautiful.border_width
    c.border_color = "#9C27B0"
  end
)

client.connect_signal(
  "unfocus",
  function(c)
    c.border_color = beautiful.border_normal
  end
)

--- Takes a wibox.container.background and connects four signals to it
---@param widget widget.container.background
---@param bg string
---@param fg string
function Hover_signal(widget, bg, fg)
  local old_wibox, old_cursor, old_bg, old_fg

  local mouse_enter = function()
    if bg then
      old_bg = widget.bg
      if string.len(bg) == 7 then
        widget.bg = bg .. 'dd'
      else
        widget.bg = bg
      end
    end
    if fg then
      old_fg = widget.fg
      widget.fg = fg
    end
    local w = mouse.current_wibox
    if w then
      old_cursor, old_wibox = w.cursor, w
      w.cursor = "hand1"
    end
  end

  local button_press = function()
    if bg then
      if bg then
        if string.len(bg) == 7 then
          widget.bg = bg .. 'bb'
        else
          widget.bg = bg
        end
      end
    end
    if fg then
      widget.fg = fg
    end
  end

  local button_release = function()
    if bg then
      if bg then
        if string.len(bg) == 7 then
          widget.bg = bg .. 'dd'
        else
          widget.bg = bg
        end
      end
    end
    if fg then
      widget.fg = fg
    end
  end

  local mouse_leave = function()
    if bg then
      widget.bg = old_bg
    end
    if fg then
      widget.fg = old_fg
    end
    if old_wibox then
      old_wibox.cursor = old_cursor
      old_wibox = nil
    end
  end

  widget:disconnect_signal("mouse::enter", mouse_enter)

  widget:disconnect_signal("button::press", button_press)

  widget:disconnect_signal("button::release", button_release)

  widget:disconnect_signal("mouse::leave", mouse_leave)

  widget:connect_signal("mouse::enter", mouse_enter)

  widget:connect_signal("button::press", button_press)

  widget:connect_signal("button::release", button_release)

  widget:connect_signal("mouse::leave", mouse_leave)

end
