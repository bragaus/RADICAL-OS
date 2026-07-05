------------------------------------------------------------------------------------------
-- src/molecules/donut.lua — Ring chart + swatch legend (VIOLET HUD §7.4.4)                  --
--                                                                                        --
-- A cairo ring (thick arc segments per slice, starting at 12 o'clock, clockwise) beside a  --
-- vertical legend (one swatch + label + share-% row per slice). Replaces the arcchart +    --
-- legend internals of protocols_donut.                                                     --
--                                                                                        --
-- LEGEND FROM ATOMS: the swatch/label/value row is composed from the `swatch` + `txt`      --
-- atoms directly (identical to what an info_row{variant="swatch"} yields) — this keeps the  --
-- molecule inside the "molecules require theme + atoms + tools" layering rule and lets it   --
-- render in a storybook with mock slices and no peer molecule present.                     --
--                                                                                        --
-- PRESENTATIONAL: spawns/parses nothing; data arrives via :set_slices. Every pct is        --
-- tonumber()-guarded; an all-zero total is treated as 1 so no arc/legend divides by zero.  --
-- Ring share and legend % are BOTH normalized by the SUM of the slice pcts (so raw counts  --
-- OR pre-computed percentages both work — matches the old arcchart max_value = sum).        --
-- Returns the composed widget WITH :set_slices + direct closure refs to the ring/legend     --
-- rows (never queries ids — R1).                                                           --
--                                                                                        --
-- Usage:                                                                                   --
--   local donut = require("src.molecules.donut")                                           --
--   local d = donut{ slices = {                                                            --
--     { label = "ESTABLISHED", pct = 12, color = p.data1 },                                --
--     { label = "LISTEN",      pct = 5,  color = p.data3 },                                --
--     { label = "OTHER",       pct = 3,  color = p.data5 } } }                             --
--   d:set_slices({ ... })   -- re-populate (rebuilds legend only if the slice count changes)--
------------------------------------------------------------------------------------------

local gears  = require("gears")
local wibox  = require("wibox")
local dpi    = require("beautiful.xresources").apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local swatch = require("src.atoms.swatch")
local txt    = require("src.atoms.txt")

-- background ring color decomposed once (static token)
local BG_R, BG_G, BG_B = p.rgb(p.inset)

local function donut(args)
  args = args or {}
  local size      = args.size or dpi(72)
  local thickness = args.thickness or dpi(12)

  -- Cairo ring: bg circle + one thick arc per slice (12 o'clock start, clockwise). --------
  local ring = wibox.widget.base.make_widget()
  ring._segments = {} -- { { color, a1, a2 }, ... }

  function ring:fit(_, _, _) return size, size end

  function ring:draw(_, cr, w, h)
    local dim = math.min(w, h)
    local rad = dim / 2 - thickness / 2
    if rad < 1 then return end
    local cx, cy = w / 2, h / 2
    cr:set_line_width(thickness)
    -- full background ring
    cr:new_sub_path()
    cr:arc(cx, cy, rad, 0, 2 * math.pi)
    cr:set_source_rgba(BG_R, BG_G, BG_B, 1)
    cr:stroke()
    -- slice arcs
    for _, seg in ipairs(self._segments) do
      if seg.a2 > seg.a1 then
        local sr, sg, sb = p.rgb(seg.color)
        cr:new_sub_path()
        cr:arc(cx, cy, rad, seg.a1, seg.a2)
        cr:set_source_rgba(sr, sg, sb, 1)
        cr:stroke()
      end
    end
  end

  function ring:set_segments(segs)
    self._segments = segs
    self:emit_signal("widget::redraw_needed")
  end

  local ring_box = wibox.widget {
    ring,
    strategy = "exact",
    width    = size,
    height   = size,
    widget   = wibox.container.constraint,
  }

  -- Legend: one { swatch | label | share% } row per slice. Built from atoms. --------------
  local legend_rows = {}
  local legend_layout = wibox.layout.fixed.vertical()
  legend_layout.spacing = dpi(mt.row_gap)

  local function make_legend_row()
    local sw    = swatch { color = p.text_faint }
    local label = txt { role = "cell", upper = true }
    local value = txt { role = "cell_bold", align = "right" }
    local row = wibox.widget {
      {
        { sw, valign = "center", widget = wibox.container.place },
        { label, fg = p.text_muted, widget = wibox.container.background },
        nil,
        spacing = dpi(mt.pad_row_y * 2),
        layout  = wibox.layout.fixed.horizontal,
      },
      nil,
      { value, fg = p.text_bright, widget = wibox.container.background },
      forced_height = dpi(mt.row_h),
      expand        = "inside",
      layout        = wibox.layout.align.horizontal,
    }
    return { row = row, sw = sw, label = label, value = value }
  end

  local function rebuild_legend(n)
    legend_layout:reset()
    legend_rows = {}
    for i = 1, n do
      local lr = make_legend_row()
      legend_rows[i] = lr
      legend_layout:add(lr.row)
    end
  end

  -- Body: ring left, legend right.
  local root = wibox.widget {
    { ring_box, valign = "center", widget = wibox.container.place },
    { legend_layout, valign = "center", widget = wibox.container.place },
    spacing = dpi(mt.gap),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- :set_slices(slices) — tonumber-guard pcts; all-zero total -> 1; update ring + legend.
  function root:set_slices(slices)
    slices = slices or {}
    local clean, total = {}, 0
    for i, s in ipairs(slices) do
      local pct = tonumber(s.pct) or 0
      if pct < 0 then pct = 0 end
      clean[i] = { label = s.label or "", pct = pct, color = s.color or p.v500 }
      total = total + pct
    end
    if total <= 0 then total = 1 end -- avoid div0 on all-zero

    -- ring segments (12 o'clock = -pi/2, clockwise)
    local segs = {}
    local acc = -math.pi / 2
    for i, s in ipairs(clean) do
      local sweep = (s.pct / total) * 2 * math.pi
      segs[i] = { color = s.color, a1 = acc, a2 = acc + sweep }
      acc = acc + sweep
    end
    ring:set_segments(segs)

    -- legend (rebuild only when the slice count changes)
    if #legend_rows ~= #clean then rebuild_legend(#clean) end
    for i, s in ipairs(clean) do
      local lr = legend_rows[i]
      lr.sw:set_color(s.color)
      lr.label:set_text(s.label)
      lr.value:set_text(math.floor(s.pct / total * 100 + 0.5) .. "%")
    end
  end

  root:set_slices(args.slices)

  return root
end

return donut
