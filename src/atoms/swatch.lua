-- src/atoms/swatch.lua
-- Legend swatch: one small rounded color square. A SINGLE wibox primitive
-- (a shaped background container) + tokens — no layout logic.
--
--   local swatch = require("src.atoms.swatch")
--   local w = swatch{ color = p.data1 }      -- 10x10, radius mt.radius_chip
--   w:set_color(p.data2)                      -- recolor in place
--
-- Requires only src.theme + beautiful/gears/wibox (atom layering).

local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful").xresources.apply_dpi
local mt    = require("src.theme.metrics")

-- swatch{ color, size=dpi(10), radius=dpi(mt.radius_chip) } -> widget
local function swatch(args)
  args = args or {}
  local size   = args.size or dpi(10)
  local radius = args.radius or dpi(mt.radius_chip)

  local w = wibox.widget {
    bg            = args.color,
    forced_width  = size,
    forced_height = size,
    shape         = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, radius)
    end,
    widget        = wibox.container.background,
  }

  -- :set_color(c) — recolor the swatch (bg property drives the redraw).
  function w:set_color(c)
    self.bg = c
  end

  return w
end

return swatch
