------------------------------------------------------------------------------------------
-- src/molecules/icon_button.lua — Clickable icon / glyph button (VIOLET HUD).            --
--                                                                                        --
-- Transparent hit-target that carries an SVG icon (via atoms/icon), an ASCII glyph, an   --
-- optional text label, or a combination. Rest color -> hover color on pointer-enter.     --
--                                                                                        --
-- HOVER via CACHED icon.surface SWAP (never per-hover recolor_image): the two states are --
-- memoized once at construction, and enter/leave just re-point the imagebox. Glyph/label  --
-- recolor for free through the background container's `fg` (they are plain txt boxes that --
-- inherit fg — no markup). Cursor -> hand1 while hovered.                                 --
--                                                                                        --
-- SELF-SETS `_preserve_colors = true` so the radical_bar recolor pass never overwrites    --
-- our palette (R6). Hover is wired ONCE at construction (never inside a watch/timer — R7).--
--                                                                                        --
-- Replaces tag_controls.make_button + titlebar.create_icon_button/create_chrome_button.   --
--                                                                                        --
--   local icon_button = require("src.molecules.icon_button")                             --
--   icon_button{ icon = "close", danger = true, on_click = function() c:kill() end }      --
--   icon_button{ glyph = "_", hover_color = p.v400, on_click = min }                      --
--   local b = icon_button{ icon = "sticky", on_click = fn }; b:set_on_click(other)        --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local icon  = require("src.atoms.icon")
local txt   = require("src.atoms.txt")

local function icon_button(args)
  args = args or {}
  local size        = args.size or dpi(mt.icon_lg)
  local width       = args.width or dpi(22)        -- live tag_controls width; no metric token
  local rest_color  = args.rest_color or p.text_muted
  -- danger forces the crit hover; otherwise hover_color (default v400).
  local hover_color = args.danger and p.crit or (args.hover_color or p.v400)
  local on_click    = args.on_click

  -- Direct refs to sub-widgets (never queried back through get_children_by_id — R1).
  local img_widget, rest_surface, hover_surface

  local pieces = wibox.layout.fixed.horizontal()
  pieces.spacing = dpi(mt.pad_row_y)

  if args.icon then
    -- Two cached states; hover just re-points the imagebox (no recolor per event).
    rest_surface  = icon.surface(args.icon, rest_color)
    hover_surface = icon.surface(args.icon, hover_color)
    img_widget = wibox.widget {
      image         = rest_surface,
      resize        = true,
      forced_width  = size,
      forced_height = size,
      widget        = wibox.widget.imagebox,
    }
    pieces:add(wibox.widget { img_widget, valign = "center", widget = wibox.container.place })
  end

  if args.glyph then
    -- Plain ASCII glyph (Nerd-Font MDI codepoints render blank here — R11); inherits fg.
    pieces:add(txt { role = "bar", text = args.glyph, align = "center", valign = "center" })
  end

  if args.label then
    pieces:add(txt { role = "label", text = args.label, valign = "center" })
  end

  local w = wibox.widget {
    { pieces, halign = "center", valign = "center", widget = wibox.container.place },
    bg           = p.transparent,
    fg           = rest_color,   -- glyph/label inherit this; recolored on hover
    forced_width = width,
    widget       = wibox.container.background,
  }

  -- R6: opt out of the bar recolor pass.
  w._preserve_colors = true

  w:connect_signal("mouse::enter", function()
    if img_widget then img_widget.image = hover_surface end
    w.fg = hover_color
    local wb = mouse.current_wibox
    if wb then wb.cursor = "hand1" end
  end)
  w:connect_signal("mouse::leave", function()
    if img_widget then img_widget.image = rest_surface end
    w.fg = rest_color
    local wb = mouse.current_wibox
    if wb then wb.cursor = "left_ptr" end
  end)

  local function attach_click()
    if on_click then
      w:buttons(gears.table.join(
        awful.button({}, 1, function() on_click() end)
      ))
    else
      w:buttons({})
    end
  end
  attach_click()

  -- Row-pool / titlebar-reuse friendly: rebind the click target in place.
  function w:set_on_click(fn)
    on_click = fn
    attach_click()
  end

  return w
end

return icon_button
