--------------------------------------------------------------------------------------------------------------
-- This is the statusbar, every widget, module and so on is combined to all the stuff you see on the screen --
--------------------------------------------------------------------------------------------------------------

local awful = require("awful")
local color = require("src.theme.colors")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")

return function(s, widgets_top, widgets_bottom)
  widgets_top = widgets_top or {}
  widgets_bottom = widgets_bottom or {}
  local has_bottom_widgets = #widgets_bottom > 0
  local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
  local segment_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.segment or 0.90)
  local top_left = awful.popup {
    screen = s,
    widget = wibox.container.background,
    ontop = false,
    bg = "#00000000",
    visible = true,
    maximum_width = dpi(980),
    placement = function(c)
      awful.placement.top_left(c, {
        margins = { top = dpi(10), left = dpi(10) }
      })
    end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(4))
    end
  }

  if s._radical_bar_top_left and s._radical_bar_top_left ~= top_left then
    s._radical_bar_top_left.visible = false
  end

  s._radical_bar_top_left = top_left

  local top_first = nil

  if has_bottom_widgets then
    top_first = awful.popup {
      screen = s,
      widget = wibox.container.background,
      ontop = false,
      bg = "#00000000",
      visible = true,
      maximum_width = dpi(980),
      placement = function(c)
        awful.placement.top_left(c, {
          margins = { top = dpi(70), left = dpi(10) }
        })
      end,
      shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(4))
      end
    }

    if s._radical_bar_top_first and s._radical_bar_top_first ~= top_first then
      s._radical_bar_top_first.visible = false
    end

    s._radical_bar_top_first = top_first
  elseif s._radical_bar_top_first then
    s._radical_bar_top_first.visible = false
    s._radical_bar_top_first = nil
  end

  top_left:struts {
    top = 55
  }

  if top_first then
    top_first:struts {
      top = 100
    }
  end

  local accent_color = "#9d6ff6" -- p.v400
  local segment_palette = {
    "#130a24", -- panel
    "#1b1030", -- panel_hi
    "#241640", -- raised
    "#2e1065", -- v950
  }

  local function segment_bg_for(index)
    return color.with_alpha(segment_palette[((index - 1) % #segment_palette) + 1], segment_alpha)
  end

  local function normalize_widget_colors(widget)
    if widget._preserve_colors then
      return
    end

    local function tint_one(w)
      if w._preserve_colors then
        return
      end

      if w.bg ~= nil then
        w.bg = "#00000000"
      end

      if w.fg ~= nil then
        w.fg = accent_color
      end

      if w.set_image and w.get_image then
        local img = w:get_image()
        if img then
          w:set_image(gears.color.recolor_image(img, accent_color))
        end
      end
    end

    tint_one(widget)

    if widget.get_all_children then
      for _, child in ipairs(widget:get_all_children()) do
        tint_one(child)
      end
    end
  end

  local function create_powerline_segment(widget, index)
    local current_bg = segment_bg_for(index)

    normalize_widget_colors(widget)

    if widget._preserve_segment then
      return wibox.widget {
        widget,
        layout = wibox.layout.fixed.horizontal
      }
    end

    return wibox.widget {
      {
        {
          widget,
          left = dpi(10),
          right = dpi(10),
          top = dpi(4),
          bottom = dpi(4),
          widget = wibox.container.margin
        },
        bg = current_bg,
        border_width = dpi(1),
        border_color = "#5b21b6", -- line_base
        shape = function(cr, w, h)
          gears.shape.rounded_rect(cr, w, h, dpi(4))
        end,
        widget = wibox.container.background
      },
      {
        {
          text = "",
          align = "center",
          valign = "center",
          font = "JetBrainsMono Nerd Font, ExtraBold 30",
          widget = wibox.widget.textbox
        },
        fg = "#00000000", -- powerline arrow neutralizado (HUD plano)
        bg = "#00000000",
        forced_width = dpi(2),
        widget = wibox.container.background
      },
      layout = wibox.layout.fixed.horizontal
    }
  end

  local function prepare_widgets(widget_list)
    local layout = wibox.layout.fixed.horizontal()
    layout.spacing = dpi(6)

    for i, widget in ipairs(widget_list) do
      layout:add(create_powerline_segment(widget, i))
    end

    return wibox.widget {
      layout,
      forced_height = dpi(48),
      widget = wibox.container.constraint
    }
  end

  top_left:setup {
    prepare_widgets(widgets_top),
    layout = wibox.layout.fixed.horizontal
  }

  if top_first then
    top_first:setup {
      prepare_widgets(widgets_bottom),
      layout = wibox.layout.fixed.horizontal
    }
  end
end
