--------------------------------
-- This is the power widget --
--------------------------------
-- VIOLET HUD: rebuilt on the shared `pill` molecule (segment mode). The former
-- hand-rolled icon+background capsule is gone; pill{ segment=true } self-flags
-- `_preserve_colors` and mirrors the vestigial `_segment_*` hints so this stays a
-- byte-faithful drop-in for the radical_bar segment (R6). Public API unchanged:
-- `function() -> widget`; still emits `module::powermenu:show` on release and still
-- glows to p.crit on hover via the legacy Hover_signal global.

-- Awesome Libs
local pill = require("src.molecules.pill")
local p    = require("src.theme.palette")
local mt   = require("src.theme.metrics")
local dpi  = require("beautiful").xresources.apply_dpi
require("src.core.signals")

return function()
  local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
  local segment_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.segment or 0.90)
  -- p.a is the hardened port of colors.with_alpha (same "#RRGGBBAA" output).
  local segment_bg = p.a(p.panel, segment_alpha)

  -- Icon-only segment pill. icon_size/pad_x pinned to the ex-power values (18 / 10)
  -- so the rendered segment is pixel-faithful; segment=true seeds the _segment_*
  -- hints (44x46 preferred, bg==edge) exactly as the old widget did.
  local power_widget = pill {
    icon          = "power",
    icon_color    = p.text_primary,
    icon_size     = dpi(mt.icon_row),  -- 18, ex-power icon constraint
    label_visible = false,
    segment       = true,
    bg            = segment_bg,
    fg            = p.text_primary,
    pad_x         = dpi(mt.seg_pad_x), -- 10, ex-power left/right margin
  }

  -- Signals (legacy global; p.crit -> "#fb5e8add" on hover, matching the original).
  Hover_signal(power_widget, p.crit, p.text_primary)

  power_widget:connect_signal(
    "button::release",
    function()
      awesome.emit_signal("module::powermenu:show")
    end
  )

  return power_widget
end
