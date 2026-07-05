------------------------------------------------------------------------------------------
-- src/atoms/chip.lua — Chip/pill surface shell: one background + margin around one child. --
--                                                                                        --
-- Size args are PIXELS (dpi already applied); the defaults dpi-wrap the raw metric        --
-- tokens so a bare chip{ child = w } renders to spec. bg/border_color default to the      --
-- kit chip recipe (v500 @ chip_bg / @ chip_border). border_width defaults to 1px          --
-- (mt.border_panel); pass 0 for a borderless surface.                                     --
--                                                                                        --
--   local chip = require("src.atoms.chip")                                               --
--   chip{ child = some_widget, bg = p.a(p.v700, p.alpha.segment), pad_x = dpi(10) }       --
------------------------------------------------------------------------------------------

local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

local function build(opts)
  opts = opts or {}
  local child        = opts.child or wibox.widget.base.make_widget()
  local bg           = opts.bg or p.a(p.v500, p.alpha.chip_bg)
  local border_color = opts.border_color or p.a(p.v500, p.alpha.chip_border)
  local radius       = opts.radius or dpi(mt.radius_bar)
  local pad_x        = opts.pad_x or dpi(7)
  local pad_y        = opts.pad_y or dpi(3)
  local border_w     = opts.border_width or dpi(mt.border_panel)

  return wibox.widget {
    {
      child,
      left   = pad_x,
      right  = pad_x,
      top    = pad_y,
      bottom = pad_y,
      widget = wibox.container.margin,
    },
    bg                 = bg,
    shape              = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, radius) end,
    shape_border_width = border_w,
    shape_border_color = border_color,
    widget             = wibox.container.background,
  }
end

return build
