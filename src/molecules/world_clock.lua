------------------------------------
-- This is the world_clock widget --
------------------------------------
-- VIOLET HUD: rebuilt on shared building blocks.
--   * FLAG  -> src/atoms/flag (the ~80-line inline cairo make_flag_widget is gone;
--              the atom is a verbatim extraction, same national-color island).
--   * ROW   -> src/molecules/info_row{ variant = "rule" } — the "CITY ....... HH:MM"
--              expanding label/value rule. The time is fed via :set_value on a 30s
--              tick using the SAME GLib DateTime/TimeZone calls wibox.widget.textclock
--              uses internally, so the per-timezone / DST behavior is preserved
--              (refresh 30 == the retired textclock's refresh).
--   * SELF-set _preserve_colors: this widget OWNS its palette (muted city, bright
--     time) — it must survive the radical_bar recolor pass (R6). It previously did
--     NOT set the flag; now it does.
--
-- Public API unchanged: function(args{ city, timezone, country, width, text_color })
-- -> widget.

-- Awesome Libs
local awful    = require("awful")
local dpi      = require("beautiful").xresources.apply_dpi
local gears    = require("gears")
local wibox    = require("wibox")
local p        = require("src.theme.palette")
local mt       = require("src.theme.metrics")
local flag     = require("src.atoms.flag")
local info_row = require("src.molecules.info_row")
local glib     = require("lgi").GLib

return function(args)
  args = args or {}

  local city        = args.city or "BRASIL"
  local timezone    = args.timezone or "America/Sao_Paulo"
  local country     = args.country or "br"
  local label_width = args.width or dpi(82)
  local text_color  = args.text_color or p.text_bright

  -- Timezone-correct clock string (identical mechanism to wibox.widget.textclock).
  local tz = glib.TimeZone.new(timezone)
  local function now_str()
    local dt = glib.DateTime.new_now(tz)
    return dt and dt:format("%H:%M") or nil -- nil -> info_row:set_value keeps last (no blank)
  end

  local flag_w = flag { country = country }

  -- "CITY ....... HH:MM" rule. info_row uppercases + mutes the key and right-aligns
  -- the colored value for life via atoms/txt :set_span (R2 markup-owner).
  local row = info_row {
    variant     = "rule",
    key         = city,
    value       = now_str() or "--:--",
    value_color = text_color,
  }
  -- Fill the width left of the flag + gap so the time still pins to the far right.
  -- dpi(24) == atoms/flag intrinsic width (no metric token); dpi(mt.gap) == 8px gap.
  row.forced_width = label_width - dpi(24) - dpi(mt.gap)

  -- Row: FLAG  [ CITY ........ HH:MM ]
  local widget = wibox.widget {
    {
      flag_w,
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    row,
    spacing      = dpi(mt.gap),
    forced_width = label_width,
    layout       = wibox.layout.fixed.horizontal,
  }

  -- Owns its palette — do NOT let radical_bar recolor it (R6).
  widget._preserve_colors = true

  -- 30s tick (mirrors the ex-textclock refresh). NOT a control_center-gated poller
  -- — world_clocks are explicitly ungated (they carry no start/stop methods).
  gears.timer {
    timeout   = 30,
    call_now  = true,
    autostart = true,
    callback  = function() row:set_value(now_str()) end,
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
