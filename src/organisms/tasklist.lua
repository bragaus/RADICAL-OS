---------------------------------
-- This is the tasklist widget --
---------------------------------

local awful = require("awful")
local p = require("src.theme.palette")
local wibox = require("wibox")
local dpi = require("beautiful").xresources.apply_dpi
local shapes = require("src.tools.shapes")              -- lozenge geometry
local list_buttons = require("src.tools.list_buttons")  -- shared buttons
local signals = require("src.core.signals")             -- hover_stateful
require("src.tools.icon_handler")

local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
local tab_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.tab or 0.88)
local hover_alpha = math.min(1, tab_alpha + 0.08)

local palette = {
  active_bg = p.a(p.panel_hi, tab_alpha),
  inactive_bg = p.a(p.base, tab_alpha),
  active_fg = p.text_bright,
  inactive_fg = p.text_muted
}

-- Symmetric double-pointed hexagon (kit lozenge); live slant was min(dpi(8), h*0.35) and
-- shapes.lozenge clamps to h/2, so dpi(8) reproduces the same tab.
local tab_shape = shapes.lozenge(dpi(8)) -- live tasklist slant; no metric token fits

local function shorten_text(text, max_len)
  if not text or text == "" then
    return "Sem titulo"
  end

  if #text <= max_len then
    return text
  end

  return text:sub(1, max_len - 3) .. "..."
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

    task_widget:buttons(list_buttons.create(buttons, object))
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

    -- Hover: darker/lighter fill on enter, deeper on press; restore the resting fill on
    -- leave. hover_stateful wires enter/leave/press/release ONCE + manages the hand1 cursor.
    signals.hover_stateful(task_widget, {
      hover_bg = is_focused and p.a(p.raised, hover_alpha) or p.a(p.inset, hover_alpha),
      press_bg = is_focused and p.a(p.v700, tab_alpha) or p.a(p.panel, tab_alpha),
      restore  = { bg = bg, fg = fg },
    })

    widget:add(task_widget)
  end

  return widget
end

return function(s)
  local tasklist = awful.widget.tasklist(
    s,
    awful.widget.tasklist.filter.currenttags,
    list_buttons.tasklist(),
    {},
    list_update,
    wibox.layout.fixed.horizontal()
  )

  tasklist._preserve_colors = true

  return tasklist
end
