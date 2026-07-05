------------------------------------------------------------------------------------------
-- src/molecules/stat_lozenge.lua — Clickable hexagonal stat capsule (VIOLET HUD §7.2.1).  --
--                                                                                        --
-- The control_center's top-center ribbon lozenge: a flat double-pointed hexagon carrying  --
-- a LARGE SVG icon + a monospaced value. Replaces control_center.make_lozenge (and the    --
-- dead status_dock copy). Composes atoms only (icon + txt) inside a shapes.lozenge shell. --
--                                                                                        --
-- Presentational: the owner samples and pushes values.                                    --
--   :set_value(text, pct) -> set the value text; pct is tonumber-guarded and, unless      --
--                            never_hot, the value goes glow_hot at pct >= mt.pct_hot       --
--                            (the ≥90 rule). VOL passes never_hot=true (no red alert).     --
--                                                                                        --
-- Self-sets `_preserve_colors` + `_preserve_segment` so if ever routed through radical_bar --
-- it keeps its palette AND skips the powerline wrapper (R6). The capsule owns its violet   --
-- surface either way.                                                                     --
--                                                                                        --
--   local stat_lozenge = require("src.molecules.stat_lozenge")                           --
--   local cpu = stat_lozenge{ icon = "cpu", on_click = function() toggle("system") end }  --
--   cpu:set_value("42%", 42)                                                             --
--   local vol = stat_lozenge{ icon = "vol", never_hot = true }                           --
------------------------------------------------------------------------------------------

local awful  = require("awful")
local gears  = require("gears")
local wibox  = require("wibox")
local dpi    = require("beautiful").xresources.apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local icon   = require("src.atoms.icon")
local txt    = require("src.atoms.txt")
local shapes = require("src.tools.shapes")
require("src.core.signals") -- Hover_signal

local function stat_lozenge(args)
  args = args or {}
  local never_hot = args.never_hot and true or false
  local icon_sz   = args.icon_size or dpi(mt.icon_stat)  -- 30, big §7.2.1 icons

  -- Direct refs (R1). value uses :set_span for per-value color (txt = sole markup owner).
  local value_box = txt { role = "lozenge", text = "--", align = "center", valign = "center" }

  local content = wibox.widget {
    {
      { args.icon and icon { name = args.icon, size = icon_sz } or wibox.widget.base.make_widget(),
        valign = "center", halign = "center", widget = wibox.container.place },
      value_box,
      spacing = dpi(mt.pad_header_x) + dpi(2), -- ~10, icon↔value gap (kit .seg gap)
      layout  = wibox.layout.fixed.horizontal,
    },
    valign = "center", halign = "center", widget = wibox.container.place,
  }

  local w = wibox.widget {
    {
      content,
      left = dpi(mt.seg_overlap), right = dpi(mt.seg_overlap), -- 18, kit seg content padding
      widget = wibox.container.margin,
    },
    bg                 = p.a(p.panel, p.alpha.bar),      -- panel @0.8 (matches make_lozenge)
    shape              = shapes.lozenge(dpi(13)),        -- slant 13, byte-identical to live shape
    shape_border_width = dpi(mt.border_panel),
    shape_border_color = p.line_base,
    forced_height      = dpi(mt.lozenge_h_actual),       -- 44
    widget             = wibox.container.background,
  }

  -- ---- update surface --------------------------------------------------------
  function w:set_value(text, pct)
    pct = tonumber(pct)
    local hot = (not never_hot) and pct ~= nil and pct >= mt.pct_hot
    value_box:set_span(text or "--", hot and p.glow_hot or p.text_bright)
  end
  w:set_value("--", nil)

  -- ---- click + hover (wired ONCE — R7) ---------------------------------------
  Hover_signal(w, nil, p.glow_ice) -- cursor hand1 + glow_ice edge on hover
  if args.on_click then
    w:buttons(gears.table.join(awful.button({}, 1, function() args.on_click() end)))
  end

  -- R6: owns its palette; skip the bar recolor + powerline wrapper if ever routed there.
  w._preserve_colors  = true
  w._preserve_segment = true

  return w
end

return stat_lozenge
