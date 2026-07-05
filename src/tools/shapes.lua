-- src/tools/shapes.lua
-- Shape FUNCTIONS (geometry) + texture PAINTERS for the Violet-HUD.
--
-- Geometry is derived from the kit clip-path polygons in
--   ferramentas_para_implementacao/ui_kits/radical-hud/kit.css
-- (topbar tags .tag__edge, tag control .tagctl, powermenu .pm__chip,
--  monitorbar chevrons .monmod__edge, hazard/mesh/scanline textures).
--
-- Two families of API:
--   * builders   : shapes.powerline/lozenge/chamfer(...) -> function(cr, w, h)
--                  (use directly as a wibox `shape=`).
--   * painters   : shapes.hex_mesh/hazard/scanlines(cr, w, h[, opts])
--                  (draw straight onto a cairo context; self-clipped to w x h).
--
-- dpi policy: builder params (tip/cut/slant) and painter spacings are DEVICE
-- pixels — the same space as the (w,h) wibox hands the shape at draw time.
-- Defaults are dpi(mt.*)-applied so a bare `shapes.powerline{}` is sane.

local dpi = require("beautiful").xresources.apply_dpi
local p   = require("src.theme.palette")
local mt  = require("src.theme.metrics")

local shapes = {}

------------------------------------------------------------------------------
-- BUILDERS
------------------------------------------------------------------------------

-- powerline{ tip, socket, flat_left } -> function(cr, w, h)
-- A right-pointing arrow tab. The LEFT edge has three variants (kit):
--   socket=true                 -> concave notch (receives the previous tip):
--                                   (0 0)(w-tip 0)(w mid)(w-tip h)(0 h)(tip mid)
--   flat_left=true  (default)   -> flat left edge (plain .tag / .arrow):
--                                   (0 0)(w-tip 0)(w mid)(w-tip h)(0 h)
--   flat_left=false, socket=off -> convex left point (.seg--first / .monmod--first):
--                                   (tip 0)(w-tip 0)(w mid)(w-tip h)(tip h)(0 mid)
function shapes.powerline(opts)
  opts = opts or {}
  local tip = opts.tip or dpi(mt.powerline_tip)
  local socket = opts.socket or false
  local flat_left = opts.flat_left
  if flat_left == nil then flat_left = true end

  return function(cr, w, h)
    local mid = h / 2
    if socket then
      cr:move_to(0, 0)
      cr:line_to(w - tip, 0)
      cr:line_to(w, mid)
      cr:line_to(w - tip, h)
      cr:line_to(0, h)
      cr:line_to(tip, mid)
      cr:close_path()
    elseif flat_left then
      cr:move_to(0, 0)
      cr:line_to(w - tip, 0)
      cr:line_to(w, mid)
      cr:line_to(w - tip, h)
      cr:line_to(0, h)
      cr:close_path()
    else
      cr:move_to(tip, 0)
      cr:line_to(w - tip, 0)
      cr:line_to(w, mid)
      cr:line_to(w - tip, h)
      cr:line_to(tip, h)
      cr:line_to(0, mid)
      cr:close_path()
    end
  end
end

-- lozenge(slant) -> function(cr, w, h)
-- Symmetric double-pointed hexagon. Byte-identical geometry to the live
-- control_center.lozenge_shape / tasklist.tab_shape:
--   (slant 0)(w-slant 0)(w h/2)(w-slant h)(slant h)(0 h/2)
-- `slant` (device px) is clamped to w/2 and h/2 so it never self-intersects.
function shapes.lozenge(slant)
  return function(cr, w, h)
    local sl = math.min(slant or dpi(mt.powerline_tip), w / 2, h / 2)
    if sl < 0 then sl = 0 end
    cr:move_to(sl, 0)
    cr:line_to(w - sl, 0)
    cr:line_to(w, h / 2)
    cr:line_to(w - sl, h)
    cr:line_to(sl, h)
    cr:line_to(0, h / 2)
    cr:close_path()
  end
end

-- chamfer(cut, corners) -> function(cr, w, h)
-- Cut (45deg) corners of a rectangle. `corners` = { tl=, tr=, br=, bl= } booleans
-- (default all four). kit uses .tagctl (tr+br) and .pm__chip / .tagctl__b (tl+br).
function shapes.chamfer(cut, corners)
  cut = cut or dpi(mt.chamfer)
  corners = corners or { tl = true, tr = true, br = true, bl = true }
  return function(cr, w, h)
    if corners.tl then
      cr:move_to(0, cut); cr:line_to(cut, 0)
    else
      cr:move_to(0, 0)
    end
    if corners.tr then
      cr:line_to(w - cut, 0); cr:line_to(w, cut)
    else
      cr:line_to(w, 0)
    end
    if corners.br then
      cr:line_to(w, h - cut); cr:line_to(w - cut, h)
    else
      cr:line_to(w, h)
    end
    if corners.bl then
      cr:line_to(cut, h); cr:line_to(0, h - cut)
    else
      cr:line_to(0, h)
    end
    cr:close_path()
  end
end

------------------------------------------------------------------------------
-- PAINTERS (draw on cr; each self-clips to the w x h box and restores state)
------------------------------------------------------------------------------

-- One family of parallel lines at `angle` (rad from horizontal), spaced `spacing`
-- (perpendicular, device px). Assumes source colour/width already set is fine —
-- but we set them here for isolation.
local function hatch(cr, w, h, angle, spacing, r, g, b, alpha, lw)
  local s = math.sin(angle)
  if s == 0 then return end
  local run = h / math.tan(angle)          -- horizontal displacement over full height
  local step = spacing / math.abs(s)
  if step < 0.5 then step = spacing end
  cr:set_source_rgba(r, g, b, alpha)
  cr:set_line_width(lw)
  local x = math.min(0, run) - step
  local x_end = w + math.max(0, run) + step
  while x <= x_end do
    cr:move_to(x, h)
    cr:line_to(x + run, 0)
    x = x + step
  end
  cr:stroke()
end

-- hex_mesh(cr, w, h[, opts]) — crossing ±60deg line families (kit .tagctl__mesh
-- / .pm__chip::before). opts: { color=p.glow_core, alpha=0.12, spacing=dpi(6),
-- line_width=1 }.
function shapes.hex_mesh(cr, w, h, opts)
  opts = opts or {}
  local r, g, b = p.rgb(opts.color or p.glow_core)
  local alpha   = opts.alpha or 0.12
  local spacing = opts.spacing or dpi(6)
  local lw      = opts.line_width or 1
  cr:save()
  cr:rectangle(0, 0, w, h); cr:clip()
  hatch(cr, w, h, math.rad(60), spacing, r, g, b, alpha, lw)
  hatch(cr, w, h, math.rad(120), spacing, r, g, b, alpha, lw)
  cr:restore()
end

-- hazard(cr, w, h[, opts]) — 45deg warning stripes (kit .tagctl__haz /
-- .pm__chip::after / .monbar__haz). opts: { color=p.glow_core (stripe),
-- color2=nil (background; nil = transparent gaps), band=dpi(2), gap=band,
-- alpha=1 }.
function shapes.hazard(cr, w, h, opts)
  opts = opts or {}
  local band  = opts.band or dpi(2)
  local gap   = opts.gap or band
  local alpha = opts.alpha or 1
  cr:save()
  cr:rectangle(0, 0, w, h); cr:clip()
  if opts.color2 then
    local r2, g2, b2 = p.rgb(opts.color2)
    cr:set_source_rgba(r2, g2, b2, alpha)
    cr:paint()
  end
  local r, g, b = p.rgb(opts.color or p.glow_core)
  cr:set_source_rgba(r, g, b, alpha)
  cr:set_line_width(band)
  local period = band + gap
  local x = -h
  while x <= w + h do
    cr:move_to(x, h)
    cr:line_to(x + h, 0)      -- dx == dy -> 45deg
    x = x + period
  end
  cr:stroke()
  cr:restore()
end

-- scanlines(cr, w, h[, opts]) — faint 1px horizontal lines (kit .monitorbar::after).
-- opts: { color=p.glow_core, alpha=0.06, spacing=dpi(3), line_width=1 }.
function shapes.scanlines(cr, w, h, opts)
  opts = opts or {}
  local r, g, b = p.rgb(opts.color or p.glow_core)
  local alpha   = opts.alpha or 0.06
  local spacing = opts.spacing or dpi(3)
  local lw      = opts.line_width or 1
  cr:save()
  cr:rectangle(0, 0, w, h); cr:clip()
  cr:set_source_rgba(r, g, b, alpha)
  cr:set_line_width(lw)
  local y = 0.5
  while y <= h do
    cr:move_to(0, y)
    cr:line_to(w, y)
    y = y + spacing
  end
  cr:stroke()
  cr:restore()
end

return shapes
