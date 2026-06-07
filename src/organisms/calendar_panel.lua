------------------------------------------------------------------------------------------
-- src/organisms/calendar_panel.lua — "VIOLET HUD" month calendar (§7.4.5)                  --
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
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)

-- ⚠️ BUG UPSTREAM (wibox.widget.calendar, calendar.lua:433-434): com `long_weekdays=false`
-- a lib trunca o nome abreviado do dia com `string.sub(os.date("%a"), 1, 2)` — corte por
-- BYTE, não por caractere. Em LC_TIME pt_BR.UTF-8 o sábado vem "sáb" = 73 c3 a1 62, e
-- sub(.,1,2) = 73 c3 (o "á" multibyte cortado ao meio) = UTF-8 inválido → o set_markup
-- interno aborta TODO o painel ("Texto … codificado em UTF-8 inválido"). Não dá p/ corrigir
-- em fn_embed (a falha é ANTES dele) nem escolhendo um pt_BR "melhor" (é justamente o UTF-8
-- pt_BR que dispara). Solução: formatar o calendário num LC_TIME ASCII (nomes em inglês,
-- sempre seguros sob o corte de 2 bytes). Combina com o resto do HUD, que já é em inglês.
-- Categoria "time" só — não mexe em números/moeda. (long_weekdays=true evitaria o sub, mas
-- nomes completos não cabem nas 7 colunas.)
for _, loc in ipairs({ "C.UTF-8", "C.utf8", "C" }) do
  if os.setlocale(loc, "time") then break end
end

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
      shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(3)) end,
      widget = wibox.container.background,
    }
  end

  -- "normal" (in-month day) and any other cell: primary text on transparent bg.
  -- Weekend cells (Sat/Sun) are dimmed to text_body. _date is a {year,month,day}
  -- table for day cells; os.date wday is 1=Sun .. 7=Sat.
  local fg = p.text_primary
  if flag == "normal" and type(_date) == "table" and _date.day then
    local t = os.date("*t", os.time({ year = _date.year, month = _date.month, day = _date.day, hour = 12 }))
    if t and (t.wday == 1 or t.wday == 7) then
      fg = p.text_body
    end
  end
  return wibox.widget {
    widget,
    fg     = fg,
    bg     = "#00000000",
    widget = wibox.container.background,
  }
end

return function(args)
  args = args or {}

  -- Build a month grid for an arbitrary {month=, year=} (defaults today).
  local function make_month(date)
    return wibox.widget {
      date          = date,
      font          = CAL_FONT,
      spacing       = dpi(2),
      start_sunday  = true,
      long_weekdays = false,
      fn_embed      = fn_embed,
      empty_color   = p.text_faint, -- cells outside the current month
      widget        = wibox.widget.calendar.month,
    }
  end

  -- The next month, wrapping Dec -> Jan of the following year.
  local function next_month_date()
    local now = os.date("*t")
    if now.month == 12 then
      return { month = 1, year = now.year + 1 }
    end
    return { month = now.month + 1, year = now.year }
  end

  local cal      = make_month(os.date("*t"))
  local cal_next = make_month(next_month_date())

  -- Optional: rebuild both dates once per hour so the focus/today cell and the
  -- two-month window follow the day rollover. No shell work, purely os.date.
  gears.timer {
    timeout   = 3600,
    autostart = true,
    call_now  = false,
    callback  = function()
      cal.date      = os.date("*t")
      cal_next.date = next_month_date()
    end,
  }

  local body = wibox.widget {
    {
      {
        cal,
        cal_next,
        spacing = dpi(8),
        layout  = wibox.layout.fixed.vertical,
      },
      halign = "center",
      widget = wibox.container.place,
    },
    bg     = "#00000000",
    widget = wibox.container.background,
  }

  return panel({
    title      = "CALENDAR",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(300),
    right_icon = Icon("calendar", { size = dpi(14), color = p.text_muted }),
  })
end
