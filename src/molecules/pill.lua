------------------------------------------------------------------------------------------
-- src/molecules/pill.lua — Icon (+ optional value/label) capsule (VIOLET HUD).           --
--                                                                                        --
-- The single shared "icon + text" bar widget. Replaces the ~13 hand-rolled icon+label    --
-- pills scattered across the leaf molecules (audio, bluetooth, clock, cpu/gpu/ram_info,  --
-- date, kblayout, network, power). Composes atoms only: icon + txt inside a rounded-rect  --
-- background.                                                                             --
--                                                                                        --
-- Presentational: data arrives via :set_text / :set_icon; the pill spawns nothing.        --
--   :set_text(s)          -> update the value/label textbox (nil-guarded via txt).        --
--   :set_icon(name,color) -> swap the SVG icon.                                           --
--   :set_label_visible(b) -> show/hide the text (icon-only pills, e.g. power).            --
--   :set_on_click(fn)     -> rebind the click target in place.                            --
--                                                                                        --
-- segment=true self-sets `_preserve_colors` so the radical_bar recolor pass leaves the    --
-- pill's palette intact (R6), and mirrors power.lua's vestigial `_segment_*` hints so a    --
-- segment pill is a drop-in for the old power widget. (Current radical_bar reads only      --
-- `_preserve_colors`/`_preserve_segment`; the `_segment_*` fields are forward-compat.)     --
--                                                                                        --
--   local pill = require("src.molecules.pill")                                           --
--   local cpu = pill{ icon = "cpu", text = "--" }; cpu:set_text("42%")                    --
--   local pw  = pill{ icon = "power", segment = true, on_click = fn, label = "" }         --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local icon  = require("src.atoms.icon")
local txt   = require("src.atoms.txt")

local function pill(args)
  args = args or {}
  local bg       = args.bg or p.v500
  local fg       = args.fg or p.v50
  local radius   = args.radius or dpi(mt.radius_pill)
  local pad_x    = args.pad_x or dpi(mt.pad_header_x)          -- 8px, kit segment padding
  local pad_y    = args.pad_y or dpi(mt.pad_row_y)             -- 3px, matches power.lua
  local spacing  = args.spacing or dpi(6)                      -- icon↔text gap; no metric token
  local hover    = args.hover                                  -- { bg=, fg= } or nil
  local on_click = args.on_click

  -- Direct refs (never queried back through get_children_by_id — R1).
  local icon_place, value_box, label_wrap

  local content = wibox.layout.fixed.horizontal()
  content.spacing = spacing

  if args.icon then
    local img = icon { name = args.icon, color = args.icon_color, size = args.icon_size or dpi(mt.icon_md) }
    icon_place = wibox.widget { img, valign = "center", halign = "center", widget = wibox.container.place }
    content:add(icon_place)
  end

  -- The value/label textbox. role "value" (ExtraBold 12) matches the kit seg__v.
  value_box = txt { role = args.text_role or "value", text = args.label or args.text or "", valign = "center" }
  label_wrap = wibox.widget { value_box, visible = (args.label_visible ~= false), widget = wibox.container.background }
  content:add(label_wrap)

  local w = wibox.widget {
    {
      { content, valign = "center", halign = "center", widget = wibox.container.place },
      left = pad_x, right = pad_x, top = pad_y, bottom = pad_y,
      widget = wibox.container.margin,
    },
    bg                 = bg,
    fg                 = fg,
    shape              = function(cr, ww, hh) gears.shape.rounded_rect(cr, ww, hh, radius) end,
    shape_border_width = args.border_width or 0,
    shape_border_color = args.border_color or p.line_base,
    widget             = wibox.container.background,
  }

  -- ---- update surface --------------------------------------------------------
  function w:set_text(s) value_box:set_text(s) end
  function w:set_span(s, color) value_box:set_span(s, color) end
  function w:set_icon(name, color)
    if not icon_place then return end
    icon_place.widget = icon { name = name, color = color, size = args.icon_size or dpi(mt.icon_md) }
  end
  function w:set_label_visible(v) label_wrap.visible = v and true or false end

  -- ---- hover (wired ONCE at construction — never in a watch/timer, R7) --------
  if hover then
    w:connect_signal("mouse::enter", function()
      if hover.bg then w.bg = hover.bg end
      if hover.fg then w.fg = hover.fg end
      local wb = mouse.current_wibox; if wb then wb.cursor = "hand1" end
    end)
    w:connect_signal("mouse::leave", function()
      w.bg = bg; w.fg = fg
      local wb = mouse.current_wibox; if wb then wb.cursor = "left_ptr" end
    end)
  end

  local function attach_click()
    if on_click then
      w:buttons(gears.table.join(awful.button({}, 1, function() on_click() end)))
    else
      w:buttons({})
    end
  end
  attach_click()
  function w:set_on_click(fn) on_click = fn; attach_click() end

  -- ---- segment mode (R6): survive the radical_bar recolor pass ----------------
  if args.segment then
    w._preserve_colors = true
    -- Vestigial hints mirrored from the old power widget (radical_bar ignores these
    -- today; kept so a segment pill is a byte-faithful power.lua replacement).
    w._segment_bg = bg
    w._segment_edge = bg
    w._segment_border_width = 0
    w._preferred_segment_width  = dpi(mt.lozenge_h_actual)  -- 44, ex-power preferred w
    w._preferred_segment_height = dpi(46)                   -- ex-power preferred h; no token
  end

  return w
end

return pill
