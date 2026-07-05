------------------------------------------------------------------------------------------
-- src/molecules/date.lua — Date pill (VIOLET HUD).                                       --
--                                                                                        --
-- A thin leaf: a shared pill{ calendar icon + "%a, %b %d" } refreshed once a minute.      --
-- The old embedded year-calendar popup + LEMBRETES engine + widget geometry math was     --
-- REMOVED — the calendar UI is owned by src/organisms/calendar_panel.lua now, and the     --
-- click is wired to the control_center time toggle by the integrator (radical_wm) via     --
-- the pill's :set_on_click / the optional on_click arg below.                             --
--                                                                                        --
-- Public API (unchanged shape): function(s [, on_click]) -> widget.                        --
--   s        : screen (kept for signature parity; the pill is screen-agnostic).           --
--   on_click : optional click handler; also settable later via widget:set_on_click(fn).    --
------------------------------------------------------------------------------------------

local gears = require("gears")
local p     = require("src.theme.palette")
local pill  = require("src.molecules.pill")

return function(s, on_click)
  local date_widget = pill {
    icon       = "calendar",
    icon_color = p.v500,               -- ex: recolor_image(calendar.svg, p.v500)
    text       = os.date("%a, %b %d"),
    bg         = p.panel,
    fg         = p.text_bright,
    hover      = { bg = p.v700, fg = p.text_bright },  -- ex: Hover_signal(_, p.v700, p.text_bright)
    on_click   = on_click,
  }

  -- Updates the date every minute, dont blame me if you miss silvester
  gears.timer {
    timeout   = 60,
    autostart = true,
    call_now  = true,
    callback  = function()
      date_widget:set_text(os.date("%a, %b %d"))
    end,
  }

  return date_widget
end
