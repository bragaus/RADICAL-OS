------------------------------------------------------------------------------------------
-- src/molecules/tag_tab.lua — One-way powerline tag tab (VIOLET HUD §7.2, kit .tag).      --
--                                                                                        --
-- A right-pointing arrow tab (flat left, sharp right tip — NOT a bidirectional lozenge)   --
-- carrying icon + index + label. Two-tone rim = edge (outer, via shape border) over a     --
-- vertical gradient fill (inner, painted via bgimage with the real height). Replaces the  --
-- inline tab body hand-rolled per-update in taglist.lua; the taglist owns the awful       --
-- taglist widget + buttons and drives one tag_tab per object.                             --
--                                                                                        --
-- Presentational + reusable (pool-friendly):                                              --
--   :set_state{ selected=, occupied=, urgent=, hover= } -> recolor edge/fill/content.     --
--   :set_label(index, name, icon_name)                  -> update index + name + icon.     --
--                                                                                        --
-- States (kit .tag--*): empty/occupied share one fill; only selected is lighter; urgent    --
-- is hot; hover forces a glow_ice edge. Icons are SVG via atoms/icon (MDI codepoints       --
-- render blank here — R11). Uppercase content per kit.                                    --
------------------------------------------------------------------------------------------

local wibox  = require("wibox")
local gears  = require("gears")
local dpi    = require("beautiful").xresources.apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local icon   = require("src.atoms.icon")
local txt    = require("src.atoms.txt")
local shapes = require("src.tools.shapes")

-- Per-state palette (kit colors_and_type.css / kit.css .tag--*).
local STATES = {
  empty    = { edge = p.glow_soft, fill = { { 0, p.v700 }, { 0.6, p.v800 }, { 1, p.v900 } }, fg = p.glow_ice },
  occupied = { edge = p.glow_soft, fill = { { 0, p.v700 }, { 0.6, p.v800 }, { 1, p.v900 } }, fg = p.glow_ice },
  selected = { edge = p.glow_ice, fill = { { 0, p.v400 }, { 0.6, p.v600 }, { 1, p.v700 } }, fg = p.v50 },
  urgent   = { edge = p.glow_hot, fill = { { 0, p.glow_hot }, { 1, p.v700 } }, fg = p.v50 },
}

local function tag_tab(args)
  args = args or {}
  local tip = dpi(mt.powerline_tip) -- 12

  -- Direct refs (R1).
  local icon_img = wibox.widget { resize = true, forced_width = dpi(mt.icon_md), forced_height = dpi(mt.icon_md), widget = wibox.widget.imagebox }
  local icon_place = wibox.widget { icon_img, valign = "center", halign = "center", widget = wibox.container.place }
  local index_box = txt { role = "label", align = "center", valign = "center" }
  local name_box  = txt { role = "label", align = "center", valign = "center", upper = true }

  local state = STATES.empty
  local icon_name = args.icon or "term"

  local content = wibox.widget {
    icon_place, index_box, name_box,
    spacing = dpi(mt.pad_row_y) * 2, -- ~6, kit .tag__content gap
    layout  = wibox.layout.fixed.horizontal,
  }

  -- fg-carrying wrapper: plain txt boxes inherit this fg; recolored on state change.
  local fg_wrap = wibox.widget { content, fg = state.fg, widget = wibox.container.background }

  local shape_fn = shapes.powerline { tip = tip, flat_left = true }

  -- Vertical gradient fill painted under the content, clipped to the powerline shape.
  local function paint_fill(_, cr, w, h)
    local grad = gears.color { type = "linear", from = { 0, 0 }, to = { 0, h }, stops = state.fill }
    cr:save()
    shape_fn(cr, w, h)
    cr:clip()
    cr:set_source(grad)
    cr:paint()
    cr:restore()
  end

  local w = wibox.widget {
    {
      fg_wrap,
      left = dpi(mt.pad_header_x), right = dpi(mt.seg_overlap), -- extra right room for the tip
      top = dpi(mt.pad_row_y), bottom = dpi(mt.pad_row_y),
      widget = wibox.container.margin,
    },
    bg                 = p.transparent,
    bgimage            = paint_fill,
    shape              = shape_fn,
    shape_border_width = dpi(mt.tick_stroke), -- 1.4, the outer edge rim
    shape_border_color = state.edge,
    widget             = wibox.container.background,
  }

  local function apply()
    fg_wrap.fg = state.fg
    w.shape_border_color = state.edge
    w:emit_signal("widget::redraw_needed")
  end

  -- ---- update surface --------------------------------------------------------
  function w:set_state(st)
    st = st or {}
    local key = st.urgent and "urgent"
      or st.selected and "selected"
      or st.occupied and "occupied"
      or "empty"
    state = STATES[key]
    -- hover forces the bright edge without changing the fill (kit .tag:hover).
    if st.hover then
      state = { edge = p.glow_ice, fill = state.fill, fg = state.fg }
    end
    icon_img.image = icon.surface(icon_name, state.fg)
    apply()
  end

  function w:set_label(index, name, name_icon)
    if index ~= nil then index_box:set_text(tostring(index)) end
    if name ~= nil then name_box:set_text(name) end
    if name_icon ~= nil then icon_name = name_icon end
    icon_img.image = icon.surface(icon_name, state.fg)
  end

  -- initial paint
  icon_img.image = icon.surface(icon_name, state.fg)
  apply()

  return w
end

return tag_tab
