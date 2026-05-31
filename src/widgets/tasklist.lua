---------------------------------
-- This is the tasklist widget --
---------------------------------

local awful = require("awful")
local color = require("src.theme.colors")
local p = require("src.theme.palette")
local wibox = require("wibox")
local dpi = require("beautiful").xresources.apply_dpi
require("src.tools.icon_handler")

local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
local tab_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.tab or 0.88)
local hover_alpha = math.min(1, tab_alpha + 0.08)

local palette = {
  active_bg = color.with_alpha(p.panel_hi, tab_alpha),
  inactive_bg = color.with_alpha(p.base, tab_alpha),
  active_fg = p.text_bright,
  inactive_fg = p.text_muted
}

local function tab_shape(cr, width, height)
  local slant = math.min(dpi(8), math.floor(height * 0.35))

  cr:move_to(slant, 0)
  cr:line_to(width - slant, 0)
  cr:line_to(width, height / 2)
  cr:line_to(width - slant, height)
  cr:line_to(slant, height)
  cr:line_to(0, height / 2)
  cr:close_path()
end

local function shorten_text(text, max_len)
  if not text or text == "" then
    return "Sem titulo"
  end

  if #text <= max_len then
    return text
  end

  return text:sub(1, max_len - 3) .. "..."
end

local function create_buttons(buttons, object)
  if not buttons then
    return nil
  end

  local btns = {}

  for _, b in ipairs(buttons) do
    btns[#btns + 1] = awful.button {
      modifiers = b.modifiers,
      button = b.button,
      on_press = function()
        b:emit_signal("press", object)
      end,
      on_release = function()
        b:emit_signal("release", object)
      end
    }
  end

  return btns
end

local list_update = function(widget, buttons, _, _, objects)
  widget:reset()
  widget:set_spacing(dpi(4))

  for _, object in ipairs(objects) do
    local is_focused = object == client.focus
    local bg = is_focused and palette.active_bg or palette.inactive_bg
    local fg = is_focused and palette.active_fg or palette.inactive_fg

    local icon = wibox.widget {
      resize = true,
      widget = wibox.widget.imagebox
    }

    local title = wibox.widget {
      text = is_focused and shorten_text(object.name or object.class, 42) or "",
      align = "left",
      valign = "center",
      widget = wibox.widget.textbox
    }

    local body = wibox.widget {
      {
        {
          {
            icon,
            id = "icon_place",
            widget = wibox.container.place
          },
          forced_width = is_focused and dpi(28) or dpi(22),
          margins = dpi(3),
          widget = wibox.container.margin
        },
        title,
        spacing = dpi(4),
        layout = wibox.layout.fixed.horizontal
      },
      left = is_focused and dpi(6) or dpi(4),
      right = is_focused and dpi(10) or dpi(4),
      top = dpi(3),
      bottom = dpi(3),
      widget = wibox.container.margin
    }

    local task_widget = wibox.widget {
      body,
      bg = bg,
      fg = fg,
      shape = tab_shape,
      widget = wibox.container.background
    }

    task_widget:buttons(create_buttons(buttons, object))
    icon:set_image(Get_icon(user_vars.icon_theme, object))

    local task_tool_tip = awful.tooltip {
      objects = { task_widget },
      mode = "inside",
      preferred_alignments = "middle",
      preferred_positions = "bottom",
      margins = dpi(10),
      gaps = 0,
      delay_show = 1
    }

    task_tool_tip:set_text(object.name or object.class or "Sem titulo")

    local old_wibox, old_cursor, old_bg

    task_widget:connect_signal("mouse::enter", function()
      old_bg = task_widget.bg
      task_widget.bg = is_focused and color.with_alpha(p.raised, hover_alpha) or color.with_alpha(p.inset, hover_alpha)

      local current_wibox = mouse.current_wibox
      if current_wibox then
        old_cursor, old_wibox = current_wibox.cursor, current_wibox
        current_wibox.cursor = "hand1"
      end
    end)

    task_widget:connect_signal("button::press", function()
      task_widget.bg = is_focused and color.with_alpha(p.v700, tab_alpha) or color.with_alpha(p.panel, tab_alpha)
    end)

    task_widget:connect_signal("button::release", function()
      task_widget.bg = bg
    end)

    task_widget:connect_signal("mouse::leave", function()
      task_widget.bg = old_bg or bg

      if old_wibox then
        old_wibox.cursor = old_cursor
        old_wibox = nil
      end
    end)

    widget:add(task_widget)
  end

  return widget
end

return function(s)
  local tasklist = awful.widget.tasklist(
    s,
    awful.widget.tasklist.filter.currenttags,
    awful.util.table.join(
      awful.button({}, 1, function(c)
        if c == client.focus then
          c.minimized = true
        else
          c.minimized = false
          if not c:isvisible() and c.first_tag then
            c.first_tag:view_only()
          end
          c:emit_signal("request::activate")
          c:raise()
        end
      end),
      awful.button({}, 3, function(c)
        c:kill()
      end)
    ),
    {},
    list_update,
    wibox.layout.fixed.horizontal()
  )

  tasklist._preserve_colors = true

  return tasklist
end
