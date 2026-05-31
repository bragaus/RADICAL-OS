--------------------------------------------------------------------------------------------------------------
-- This is the statusbar, every widget, module and so on is combined to all the stuff you see on the screen --
--------------------------------------------------------------------------------------------------------------
local awful = require("awful")
local color = require("src.theme.colors")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")

return function(s, widgets)
  widgets = widgets or {}
  local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
  local segment_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.segment or 0.90)
  local segment_edge_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.segment_edge or 0.96)
  local segment_border_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.segment_border or segment_edge_alpha)

  -- Se quiser que seja só o gráfico, deixe assim:
  -- widgets = { cyber_chart }

  local top_right = awful.popup {
    screen = s,
    widget = wibox.container.background,
    ontop = false,
    bg = "#00000000",
    visible = true,
    placement = function(c)
      awful.placement.top_right(c, { margins = dpi(10) })
    end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(6))
    end
  }

  top_right:struts {
    top = dpi(110)
  }

  local segment_palette = {
    { edge = "#5b21b6", fill = "#130a24" },
    { edge = "#5b21b6", fill = "#1b1030" },
    { edge = "#5b21b6", fill = "#241640" },
    { edge = "#5b21b6", fill = "#2e1065" },
    { edge = "#5b21b6", fill = "#130a24" },
  }

  local function segment_bg_for(index)
    return segment_palette[((index - 1) % #segment_palette) + 1]
  end

  local function segment_style_for(widget, index)
    local fallback = segment_bg_for(index)
    local edge = widget._segment_edge or widget._segment_bg or fallback.edge
    local fill = widget._segment_bg or fallback.fill
    local border_color = widget._segment_border_color or edge

    return {
      edge = color.with_alpha(edge, segment_edge_alpha),
      fill = color.with_alpha(fill, segment_alpha),
      border_width = widget._segment_border_width,
      border_color = color.with_alpha(border_color, segment_border_alpha),
    }
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
        w.fg = "#9d6ff6"
      end

      if w.set_image and w.get_image then
        local img = w:get_image()
        if img then
          w:set_image(gears.color.recolor_image(img, "#9d6ff6"))
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

  local function maybe_size_widget(widget)
    if widget._preferred_segment_width or widget._preferred_segment_height then
      return wibox.widget {
        widget,
        forced_width = widget._preferred_segment_width,
        forced_height = widget._preferred_segment_height,
        strategy = "exact",
        widget = wibox.container.constraint
      }
    end

    return widget
  end

  local function create_powerline_segment(widget, index)
    local current_bg = segment_style_for(widget, index)

    normalize_widget_colors(widget)
    widget = maybe_size_widget(widget)

    return wibox.widget {
      {
        {
          text = "",
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
      {
        {
          widget,
          left = dpi(10),
          right = dpi(10),
          top = dpi(6),
          bottom = dpi(6),
          widget = wibox.container.margin
        },
        bg = current_bg.fill,
        border_width = current_bg.border_width or 0,
        border_color = current_bg.border_color or current_bg.edge,
        shape = function(cr, width, height)
          gears.shape.rounded_rect(cr, width, height, dpi(6))
        end,
        widget = wibox.container.background
      },
      layout = wibox.layout.fixed.horizontal
    }
  end

  local function prepare_widgets(widget_list)
    local layout = wibox.layout.fixed.horizontal()
    layout.spacing = dpi(6)

    local max_h = dpi(48)

    for i, widget in ipairs(widget_list) do
      max_h = math.max(max_h, widget._preferred_segment_height or dpi(48))
      layout:add(create_powerline_segment(widget, i))
    end

    return wibox.widget {
      layout,
      forced_height = max_h + dpi(12),
      widget = wibox.container.constraint
    }
  end

  top_right:setup {
    nil,
    nil,
    prepare_widgets(widgets),
    layout = wibox.layout.align.horizontal
  }
end
