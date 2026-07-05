------------------------------------------------------------------------------------------
-- src/molecules/chip_button.lua — 104x104 "military-tech" power chip (VIOLET HUD).       --
--                                                                                        --
-- Faithful Lua port of kit.css `.pm__chip` (ferramentas .../radical-hud/kit.css:287-305):--
--   * chamfered shell (top-left + bottom-right cut, 11px) painted in the RIM colour;      --
--   * inset FILL (chamfered too) = vertical v700->v900 gradient under a hex-mesh texture; --
--   * a small 45deg HAZARD badge near the top-left corner;                                --
--   * a 30px icon recoloured to v50 + an uppercase label below it.                        --
--   * hover: rim -> p.glow_core, fill -> v600->v800 (both swapped from cached values).    --
--                                                                                        --
-- Distinct anatomy from icon_button (chamfer + mesh + hazard) => its own molecule.        --
-- SELF-SETS `_preserve_colors = true` (R6). Hover wired once at construction (R7).        --
-- Replaces powermenu.button (organism keeps its show/hide + keygrabber).                  --
--                                                                                        --
--   local chip_button = require("src.molecules.chip_button")                             --
--   chip_button{ icon = "shutdown", label = "Shutdown", on_click = shutdown_cmd }         --
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

-- kit .pm__chip clip-path: chamfer top-left + bottom-right only.
local CHIP_CORNERS = { tl = true, tr = false, br = true, bl = false }

local function fill_gradient(top, bottom)
  return gears.color {
    type  = "linear",
    from  = { 0, 0 }, to = { 0, dpi(mt.chip_px) },
    stops = { { 0, top }, { 1, bottom } },
  }
end

local function chip_button(args)
  args = args or {}

  local chamfer    = shapes.chamfer(dpi(mt.chamfer_lg), CHIP_CORNERS)
  local RIM_REST   = p.line_bright
  local RIM_HOVER  = p.glow_core
  local FILL_REST  = fill_gradient(p.v700, p.v900)
  local FILL_HOVER = fill_gradient(p.v600, p.v800)

  -- content column: 30px icon (recoloured v50) over an uppercase label.
  local content = wibox.widget {
    {
      icon { name = args.icon, color = p.v50, size = dpi(mt.icon_stat) },
      halign = "center", valign = "center", widget = wibox.container.place,
    },
    txt { role = "bar", text = args.label, align = "center", valign = "center", upper = true },
    spacing = dpi(mt.gap),   -- kit gap 10; mt.gap (8) is the nearest token
    layout  = wibox.layout.fixed.vertical,
  }

  -- INNER fill: gradient bg + (hex-mesh + hazard badge) texture drawn in bgimage.
  local inner = wibox.widget {
    { content, halign = "center", valign = "center", widget = wibox.container.place },
    bg      = FILL_REST,
    fg      = p.v50,       -- the label (plain txt) inherits this
    shape   = chamfer,
    bgimage = function(_, cr, w, h)
      -- kit ::before hex mesh (glow_core @ .10, 8px pitch)
      shapes.hex_mesh(cr, w, h, { color = p.glow_core, alpha = 0.10, spacing = dpi(8) })
      -- kit ::after hazard badge — top:8 left:12, 26x5 (raw px: decorative, no token)
      cr:save()
      cr:translate(dpi(12), dpi(8))
      shapes.hazard(cr, dpi(26), dpi(5), {
        color = p.glow_core, color2 = p.bevel_lo, band = dpi(2), gap = dpi(2),
      })
      cr:restore()
    end,
    widget  = wibox.container.background,
  }

  -- OUTER shell: the RIM colour shows through the ~2px inset around `inner`.
  local outer = wibox.widget {
    {
      inner,
      margins = dpi(mt.border_focus),   -- rim thickness (~kit 1.5px)
      widget  = wibox.container.margin,
    },
    bg            = RIM_REST,
    shape         = chamfer,
    forced_width  = dpi(mt.chip_px),
    forced_height = dpi(mt.chip_px),
    widget        = wibox.container.background,
  }

  -- R6: opt out of the bar recolor pass (belt-and-suspenders; menus aren't in the bar).
  outer._preserve_colors = true

  outer:connect_signal("mouse::enter", function()
    outer.bg = RIM_HOVER
    inner.bg = FILL_HOVER
    local wb = mouse.current_wibox
    if wb then wb.cursor = "hand1" end
  end)
  outer:connect_signal("mouse::leave", function()
    outer.bg = RIM_REST
    inner.bg = FILL_REST
    local wb = mouse.current_wibox
    if wb then wb.cursor = "left_ptr" end
  end)

  if args.on_click then
    outer:buttons(gears.table.join(
      awful.button({}, 1, function() args.on_click() end)
    ))
  end

  return outer
end

return chip_button
