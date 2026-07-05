------------------------------
-- This is the clock widget --
------------------------------
-- VIOLET HUD: rebuilt on the shared `pill` molecule (icon + label capsule). The
-- former hand-rolled imagebox + textclock + rounded background is gone. The time
-- is fed into the pill via :set_text on a 60s tick (os.date, LOCAL time), which is
-- the faithful equivalent of the retired wibox.widget.textclock (default refresh
-- 60, local timezone). Public API unchanged: `function() -> widget`.

-- Awesome Libs
local pill  = require("src.molecules.pill")
local p     = require("src.theme.palette")
local dpi   = require("beautiful").xresources.apply_dpi
local gears = require("gears")
require("src.core.signals")

-- Returns the clock widget
return function()

  local clock_widget = pill {
    icon       = "clock",       -- icons/svg/clock.svg
    icon_color = p.v400,
    text       = os.date("%H:%M"),
    bg         = p.panel,
    fg         = p.text_bright,
    -- pad_x defaults to dpi(mt.pad_header_x)==dpi(8), == ex-margin left/right.
    spacing    = dpi(10),       -- ex icon<->label gap (no metric token fits)
  }

  Hover_signal(clock_widget, p.v700, p.text_bright)

  -- Minute tick (equivalent to the old textclock's own always-on 60s timer; not a
  -- sampling surface — os.date is trivial, no gating).
  gears.timer {
    timeout   = 60,
    call_now  = true,
    autostart = true,
    callback  = function() clock_widget:set_text(os.date("%H:%M")) end,
  }

  return clock_widget
end
