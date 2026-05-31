--------------------------------
-- This is the taglist widget --
--------------------------------

local wibox = require("wibox")
local awful = require("awful")
local color = require("src.theme.colors")
local p = require("src.theme.palette")
local gears = require("gears")
local dpi = require("beautiful").xresources.apply_dpi
require("src.tools.icon_handler")

local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
local tab_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.tab or 0.88)
local hover_alpha = math.min(1, tab_alpha + 0.08)

local palette = {
  empty_bg = color.with_alpha(p.v975, tab_alpha),
  occupied_bg = color.with_alpha(p.v975, tab_alpha),
  selected_bg = color.with_alpha(p.v500, tab_alpha),
  urgent_bg = color.with_alpha(p.glow_hot, tab_alpha),
  empty_fg = p.text_muted,
  occupied_fg = p.text_muted,
  selected_fg = p.v50,
  separator_fg = p.line_dim
}

-- Seta powerline de UMA direção (aponta p/ DIREITA, Image #11): borda esquerda reta,
-- ponta afiada à direita. NÃO é lozângulo bidirecional.
local function tab_shape(cr, width, height)
  local tip = math.min(dpi(12), math.floor(height * 0.55))

  cr:move_to(0, 0)
  cr:line_to(width - tip, 0)
  cr:line_to(width, height / 2) -- ponta afiada (seta →)
  cr:line_to(width - tip, height)
  cr:line_to(0, height)
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
        left = dpi(10),
        right = dpi(18), -- espaço p/ a ponta afiada da seta
        top = dpi(3),
        bottom = dpi(3),
        widget = wibox.container.margin
      },
      bg = bg,
      fg = fg,
      shape = tab_shape,
      shape_border_width = dpi(1),
      shape_border_color = object.selected and p.v300 or palette.separator_fg,
      widget = wibox.container.background
    }

    local content = wibox.layout.fixed.horizontal()
    content.spacing = dpi(2)
    content:add(background)

    -- separador glyph desativado: a própria seta-tab (powerline uma direção) separa
    if false then
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
        background.bg = color.with_alpha(p.v400, hover_alpha)
        background.fg = palette.selected_fg
      else
        background.bg = color.with_alpha(p.v900, hover_alpha)
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
        background.bg = color.with_alpha(p.v600, tab_alpha)
      else
        background.bg = color.with_alpha(p.v975, tab_alpha)
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
