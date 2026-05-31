------------------------------------------------------------------------------------------
-- src/widgets/calendar_panel.lua — "VIOLET HUD" month calendar (§7.4.5)                  --
--                                                                                        --
-- Body = wibox.widget.calendar (type "month") restyled through fn_embed:                 --
--   month/year header   -> centered, text_heading, UPPERCASE                             --
--   weekday header       -> text_muted                                                   --
--   normal days          -> text_primary                                                 --
--   focus / today        -> v500 rounded box with v50 fg                                 --
--   empty (outside month)-> text_faint                                                   --
--                                                                                        --
-- No shell sampling. The date is read from os.date("*t") at build time; an optional      --
-- gears.timer (3600s) rebuilds the calendar so it follows the day rollover.              --
------------------------------------------------------------------------------------------

local wibox = require("wibox")
local gears = require("gears")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local panel = require("src.tools.panel")

local CAL_FONT = "JetBrainsMono Nerd Font 9"

-- Re-style each calendar cell according to its flag. Returns a wibox widget that
-- the calendar layout will add in place of the raw textbox.
local function fn_embed(widget, flag, _date)
  if flag == "month" then
    -- The whole month grid container: keep it transparent so the panel chrome shows.
    return wibox.widget {
      widget,
      bg     = "#00000000",
      widget = wibox.container.background,
    }
  end

  if flag == "header" or flag == "monthheader" then
    -- Month/year header: centered, heading color, UPPERCASE.
    if widget.set_markup and widget.text then
      widget:set_markup(tostring(widget.text):upper())
    end
    if widget.set_halign then widget:set_halign("center") end
    return wibox.widget {
      {
        widget,
        margins = dpi(2),
        widget  = wibox.container.margin,
      },
      fg     = p.text_heading,
      bg     = "#00000000",
      widget = wibox.container.background,
    }
  end

  if flag == "weekday" then
    -- SU MO TU ... weekday header row.
    return wibox.widget {
      widget,
      fg     = p.text_muted,
      bg     = "#00000000",
      widget = wibox.container.background,
    }
  end

  if flag == "focus" then
    -- Today: v500 rounded box, v50 foreground.
    return wibox.widget {
      {
        widget,
        margins = dpi(2),
        widget  = wibox.container.margin,
      },
      fg     = p.v50,
      bg     = p.v500,
      shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(4)) end,
      widget = wibox.container.background,
    }
  end

  -- "normal" (in-month day) and any other cell: primary text on transparent bg.
  return wibox.widget {
    widget,
    fg     = p.text_primary,
    bg     = "#00000000",
    widget = wibox.container.background,
  }
end

return function(args)
  args = args or {}

  local cal = wibox.widget {
    date         = os.date("*t"),
    font         = CAL_FONT,
    spacing      = dpi(2),
    start_sunday = true,
    long_weekdays = false,
    fn_embed     = fn_embed,
    empty_color  = p.text_faint, -- cells outside the current month
    widget       = wibox.widget.calendar.month,
  }

  -- Optional: rebuild the date once per hour so the focus/today cell follows the
  -- day rollover. No shell work, purely a local os.date read.
  gears.timer {
    timeout   = 3600,
    autostart = true,
    call_now  = false,
    callback  = function()
      cal.date = os.date("*t")
    end,
  }

  local body = wibox.widget {
    {
      cal,
      halign = "center",
      widget = wibox.container.place,
    },
    bg     = "#00000000",
    widget = wibox.container.background,
  }

  return panel({
    title  = "CALENDAR",
    body   = body,
    accent = p.v500,
    w      = args.w or dpi(300),
  })
end
