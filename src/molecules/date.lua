-----------------------------
-- This is the date widget --
-----------------------------

-- Awesome Libs
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
require("src.core.signals")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/date/"

-- Returns the date widget
return function(s)

  local date_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              image = gears.color.recolor_image(icondir .. "calendar.svg", p.v500),
              widget = wibox.widget.imagebox,
              resize = false
            },
            id = "icon_layout",
            widget = wibox.container.place
          },
          id = "icon_margin",
          top = dpi(2),
          widget = wibox.container.margin
        },
        spacing = dpi(10),
        {
          id = "label",
          align = "center",
          valign = "center",
          widget = wibox.widget.textbox
        },
        id = "date_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.panel,
    fg = p.text_bright,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  local reminders_text = table.concat(
    {
      "LEMBRETES E ORGANIZAÇÃO",
      "• Planejar prioridades da semana",
      "• Revisar tarefas do dia",
      "• Registrar ideias importantes",
      "• Definir próximos passos"
    },
    "\n"
  )

  local year_calendar = wibox.widget {
    date = os.date("*t"),
    font = user_vars.font.bold,
    spacing = dpi(2),
    week_numbers = true,
    widget = wibox.widget.calendar.year
  }

  local reminders_widget = wibox.widget {
    {
      {
        text = reminders_text,
        align = "left",
        valign = "top",
        widget = wibox.widget.textbox
      },
      margins = dpi(10),
      widget = wibox.container.margin
    },
    bg = p.inset .. "dd",
    fg = p.text_muted,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  local calendar_popup = awful.popup {
    visible = false,
    ontop = true,
    bg = "#00000000",
    screen = s,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 8)
    end,
    widget = wibox.widget {
      {
        {
          year_calendar,
          reminders_widget,
          spacing = dpi(10),
          layout = wibox.layout.fixed.vertical
        },
        margins = dpi(10),
        widget = wibox.container.margin
      },
      bg = p.base .. "ee",
      fg = p.text_bright,
      shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, 8)
      end,
      border_width = dpi(1),
      border_color = p.line_bright,
      widget = wibox.container.background
    }
  }

  local function resolve_widget_geo()
    local geo = mouse.current_widget_geometry
    local current_wibox = mouse.current_wibox

    if geo and current_wibox then
      local wgeo = current_wibox:geometry()
      return {
        x = wgeo.x + geo.x,
        y = wgeo.y + geo.y,
        width = geo.width,
        height = geo.height,
        screen = current_wibox.screen
      }
    end

    return geo
  end

  local function find_date_widget_geo_in_current_wibox()
    local w = mouse.current_wibox
    if not w or not w.find_widgets then
      return nil
    end

    local m = mouse.coords()
    local wgeo = w:geometry()
    local hits = w:find_widgets(m.x - wgeo.x, m.y - wgeo.y)

    for _, item in ipairs(hits) do
      if item.widget == date_widget then
        return {
          x = wgeo.x + item.x,
          y = wgeo.y + item.y,
          width = item.width,
          height = item.height,
          screen = w.screen
        }
      end
    end

    return nil
  end

  local last_date_geo = nil

  local function place_calendar_popup()
    local geo = find_date_widget_geo_in_current_wibox() or last_date_geo or resolve_widget_geo()

    calendar_popup.screen = (geo and geo.screen) or s

    if geo and geo.width and geo.height then
      local popup_geo = calendar_popup:geometry()
      local workarea = calendar_popup.screen.workarea

      local popup_width = popup_geo.width
      local popup_height = popup_geo.height

      if (not popup_width) or popup_width < dpi(400) then
        popup_width = dpi(900)
      end

      if (not popup_height) or popup_height < dpi(250) then
        popup_height = dpi(700)
      end

      local target_x = geo.x + geo.width - popup_width
      local target_y = geo.y + geo.height + dpi(6)

      if target_x < workarea.x then
        target_x = workarea.x
      elseif target_x + popup_width > (workarea.x + workarea.width) then
        target_x = workarea.x + workarea.width - popup_width
      end

      if target_y + popup_height > (workarea.y + workarea.height) then
        target_y = geo.y - popup_height - dpi(6)
      end

      calendar_popup.x = target_x
      calendar_popup.y = target_y
      awful.placement.no_offscreen(calendar_popup, { honor_workarea = true })
    else
      awful.placement.align(
        calendar_popup,
        { position = "top_right", margins = { right = dpi(10), top = dpi(60) } }
      )
    end
  end

  local set_date = function()
    date_widget.container.date_layout.label:set_text(os.date("%a, %b %d"))
  end

  -- Updates the date every minute, dont blame me if you miss silvester
  gears.timer {
    timeout = 60,
    autostart = true,
    call_now = true,
    callback = function()
      set_date()
      year_calendar.date = os.date("*t")
    end
  }

  -- Signals
  Hover_signal(date_widget, p.v700, p.text_bright)

  date_widget:connect_signal(
    "mouse::enter",
    function()
      last_date_geo = resolve_widget_geo()
      awesome.emit_signal("widget::calendar_osd:stop", true)
    end
  )

  date_widget:connect_signal(
    "mouse::leave",
    function()
      awesome.emit_signal("widget::calendar_osd:rerun", true)
    end
  )

  date_widget:connect_signal(
    "button::press",
    function()
      if not calendar_popup.visible then
        last_date_geo = find_date_widget_geo_in_current_wibox() or last_date_geo or resolve_widget_geo()
        calendar_popup.visible = true
        place_calendar_popup()
        gears.timer.delayed_call(function()
          last_date_geo = find_date_widget_geo_in_current_wibox() or last_date_geo or resolve_widget_geo()
          place_calendar_popup()
        end)
      else
        calendar_popup.visible = false
      end
    end
  )

  calendar_popup:connect_signal(
    "mouse::leave",
    function()
      calendar_popup.visible = false
    end
  )

  return date_widget
end
