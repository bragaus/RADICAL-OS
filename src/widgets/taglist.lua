--------------------------------
-- This is the taglist widget --
--------------------------------

local wibox = require("wibox")
local awful = require("awful")
local color = require("src.theme.colors")
local gears = require("gears")
local dpi = require("beautiful").xresources.apply_dpi
require("src.tools.icon_handler")

local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
local tab_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.tab or 0.88)
local hover_alpha = math.min(1, tab_alpha + 0.08)

local palette = {
  empty_bg = color.with_alpha("#0d1420", tab_alpha),
  occupied_bg = color.with_alpha("#15263d", tab_alpha),
  selected_bg = color.with_alpha("#2b5585", tab_alpha),
  urgent_bg = color.with_alpha("#6f2944", tab_alpha),
  empty_fg = "#5ba8eb",
  occupied_fg = "#79c8ff",
  selected_fg = "#eef8ff",
  separator_fg = "#33577d"
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

local function tag_state(tag)
  if tag.urgent then
    return palette.urgent_bg, palette.selected_fg
  end

  if tag.selected then
    return palette.selected_bg, palette.selected_fg
  end

  if #tag:clients() > 0 then
    return palette.occupied_bg, palette.occupied_fg
  end

  return palette.empty_bg, palette.empty_fg
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

  for index, object in ipairs(objects) do
    local bg, fg = tag_state(object)

    local background = wibox.widget {
      {
        {
          {
            markup = string.format("<span weight='bold'>%s</span>", tostring(object.index)),
            align = "center",
            valign = "center",
            widget = wibox.widget.textbox
          },
          {
            text = object.name or tostring(object.index),
            align = "center",
            valign = "center",
            widget = wibox.widget.textbox
          },
          spacing = dpi(6),
          layout = wibox.layout.fixed.horizontal
        },
        left = dpi(8),
        right = dpi(8),
        top = dpi(3),
        bottom = dpi(3),
        widget = wibox.container.margin
      },
      bg = bg,
      fg = fg,
      shape = tab_shape,
      widget = wibox.container.background
    }

    local content = wibox.layout.fixed.horizontal()
    content.spacing = dpi(4)
    content:add(background)

    if index < #objects then
      content:add(wibox.widget {
        markup = string.format("<span foreground='%s'></span>", palette.separator_fg),
        align = "center",
        valign = "center",
        widget = wibox.widget.textbox
      })
    end

    local tag_widget = wibox.widget {
      content,
      bg = "#00000000",
      widget = wibox.container.background
    }

    tag_widget:buttons(create_buttons(buttons, object))

    local old_wibox, old_cursor, old_bg, old_fg

    tag_widget:connect_signal("mouse::enter", function()
      old_bg = background.bg
      old_fg = background.fg

      if object.selected then
        background.bg = color.with_alpha("#35669e", hover_alpha)
        background.fg = palette.selected_fg
      else
        background.bg = color.with_alpha("#1b3350", hover_alpha)
        background.fg = palette.selected_fg
      end

      local current_wibox = mouse.current_wibox
      if current_wibox then
        old_cursor, old_wibox = current_wibox.cursor, current_wibox
        current_wibox.cursor = "hand1"
      end
    end)

    tag_widget:connect_signal("button::press", function()
      if object.selected then
        background.bg = color.with_alpha("#23466f", tab_alpha)
      else
        background.bg = color.with_alpha("#14263d", tab_alpha)
      end
    end)

    tag_widget:connect_signal("button::release", function()
      local new_bg, new_fg = tag_state(object)
      background.bg = new_bg
      background.fg = new_fg
    end)

    tag_widget:connect_signal("mouse::leave", function()
      background.bg = old_bg or bg
      background.fg = old_fg or fg

      if old_wibox then
        old_wibox.cursor = old_cursor
        old_wibox = nil
      end
    end)

    widget:add(tag_widget)
  end
end

return function(s)
  local taglist = awful.widget.taglist(
    s,
    awful.widget.taglist.filter.all,
    gears.table.join(
      awful.button({}, 1, function(t)
        t:view_only()
      end),
      awful.button({ modkey }, 1, function(t)
        if client.focus then
          client.focus:move_to_tag(t)
        end
      end),
      awful.button({}, 3, function(t)
        if client.focus then
          client.focus:toggle_tag(t)
        end
      end),
      awful.button({ modkey }, 3, function(t)
        if client.focus then
          client.focus:toggle_tag(t)
        end
      end),
      awful.button({}, 4, function(t)
        awful.tag.viewnext(t.screen)
      end),
      awful.button({}, 5, function(t)
        awful.tag.viewprev(t.screen)
      end)
    ),
    {},
    list_update,
    wibox.layout.fixed.horizontal()
  )

  taglist._preserve_colors = true

  return taglist
end
