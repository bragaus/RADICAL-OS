local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local p = require("src.theme.palette")

local function make_flag_widget(country)
  local width = dpi(24)
  local height = dpi(16)

  local widget = wibox.widget.base.make_widget()

  function widget:fit(_, _, _)
    return width, height
  end

  function widget:draw(_, cr, w, h)
    local function rounded_clip()
      gears.shape.rounded_rect(cr, w, h, dpi(4))
      cr:clip()
    end

    cr:save()
    rounded_clip()

    if country == "br" then
      cr:set_source_rgba(0.0, 0.61, 0.26, 1)
      cr:paint()

      cr:set_source_rgba(1.0, 0.83, 0.0, 1)
      cr:move_to(w * 0.5, h * 0.08)
      cr:line_to(w * 0.9, h * 0.5)
      cr:line_to(w * 0.5, h * 0.92)
      cr:line_to(w * 0.1, h * 0.5)
      cr:close_path()
      cr:fill()

      cr:set_source_rgba(0.02, 0.23, 0.56, 1)
      cr:arc(w * 0.5, h * 0.5, math.min(w, h) * 0.18, 0, 2 * math.pi)
      cr:fill()
    elseif country == "fr" then
      cr:set_source_rgba(0.0, 0.22, 0.62, 1)
      cr:rectangle(0, 0, w / 3, h)
      cr:fill()

      cr:set_source_rgba(0.95, 0.95, 0.95, 1)
      cr:rectangle(w / 3, 0, w / 3, h)
      cr:fill()

      cr:set_source_rgba(0.84, 0.13, 0.19, 1)
      cr:rectangle(2 * w / 3, 0, w / 3, h)
      cr:fill()
    elseif country == "jp" then
      cr:set_source_rgba(0.97, 0.97, 0.97, 1)
      cr:paint()

      cr:set_source_rgba(0.8, 0.0, 0.12, 1)
      cr:arc(w * 0.5, h * 0.5, math.min(w, h) * 0.22, 0, 2 * math.pi)
      cr:fill()
    else
      local stripes = 7
      local stripe_height = h / stripes

      for i = 0, stripes - 1 do
        if i % 2 == 0 then
          cr:set_source_rgba(0.7, 0.05, 0.14, 1)
        else
          cr:set_source_rgba(0.95, 0.95, 0.95, 1)
        end
        cr:rectangle(0, i * stripe_height, w, stripe_height)
        cr:fill()
      end

      cr:set_source_rgba(0.0, 0.19, 0.46, 1)
      cr:rectangle(0, 0, w * 0.45, h * 0.58)
      cr:fill()
    end

    cr:restore()

    gears.shape.rounded_rect(cr, w, h, dpi(4))
    cr:set_source_rgba(1, 1, 1, 0.18)
    cr:set_line_width(1)
    cr:stroke()
  end

  return widget
end

return function(args)
  args = args or {}

  local city = args.city or "BRASIL"
  local timezone = args.timezone or "America/Sao_Paulo"
  local country = args.country or "br"
  local label_width = args.width or dpi(82)
  local text_color = args.text_color or p.text_bright

  local flag = make_flag_widget(country)
  flag.forced_height = dpi(16)
  flag.forced_width = dpi(24)

  -- Row: FLAG  CITY ........  HH:MM  (time pinned right via align.horizontal)
  local left = wibox.widget {
    {
      flag,
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    {
      markup = "<span foreground='" .. p.text_muted .. "'>" .. city:upper() .. "</span>",
      font = user_vars.font.bold,
      valign = "center",
      widget = wibox.widget.textbox,
    },
    spacing = dpi(8),
    layout = wibox.layout.fixed.horizontal,
  }

  local time = wibox.widget {
    {
      format = "%H:%M",
      timezone = timezone,
      refresh = 30,
      font = user_vars.font.extrabold,
      align = "right",
      valign = "center",
      widget = wibox.widget.textclock,
    },
    fg = text_color,
    widget = wibox.container.background,
  }

  local widget = wibox.widget {
    left,
    nil,
    time,
    expand = "inside",
    forced_width = label_width,
    layout = wibox.layout.align.horizontal,
  }

  awful.tooltip {
    objects = { widget },
    text = city .. "  //  " .. timezone,
    mode = "outside",
    preferred_positions = { "bottom" },
    margins = dpi(8),
  }

  return widget
end
