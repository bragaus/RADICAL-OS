------------------------------------------------------------------------------------------
-- src/atoms/divider.lua — 2px accent gradient rule (VIOLET HUD panel divider).           --
--                                                                                        --
-- The exact gradient extracted from the old src/tools/panel.lua header divider:          --
--   accent -> accent @ alpha.divider_tail (@55% stop) -> transparent, on a rounded_bar.  --
-- `width` is the gradient span (the linear `to.x`); it matches the container width the    --
-- divider fills (forced_width is intentionally left unset, exactly like the panel).       --
--                                                                                        --
--   local divider = require("src.atoms.divider")                                         --
--   local d = divider{ accent = p.v500, width = dpi(mt.panel_w) }                        --
--   d:set_accent(p.glow_core)                                                            --
------------------------------------------------------------------------------------------

local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

local function gradient(accent, width)
  return gears.color {
    type = "linear",
    from = { 0, 0 },
    to   = { width, 0 },
    stops = {
      { 0,    accent },
      { 0.55, p.a(accent, p.alpha.divider_tail) },
      { 1,    p.transparent },
    },
  }
end

local function build(opts)
  opts = opts or {}
  local accent = opts.accent or p.v500
  local width  = opts.width or dpi(mt.panel_w_md)
  local height = opts.height or dpi(mt.divider_h)

  local w = wibox.widget {
    forced_height = height,
    bg            = gradient(accent, width),
    shape         = gears.shape.rounded_bar,
    widget        = wibox.container.background,
  }
  w._divider_width = width

  function w:set_accent(c)
    if not c then return end
    self.bg = gradient(c, self._divider_width)
    self:emit_signal("widget::redraw_needed")
  end

  return w
end

return build
