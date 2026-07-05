-- src/atoms/flag.lua
-- Cairo country flag, fixed dpi(24) x dpi(16). Extracted verbatim from the old
-- world_clock.lua make_flag_widget (lines ~7-88).
--
--   local flag = require("src.atoms.flag")
--   local w = flag{ country = "br" }   -- "br" | "fr" | "jp" | <else = us>
--   w:set_country("jp")                -- optional recolor in place
--
-- Requires only beautiful/gears/wibox (atom layering; no palette — the flag
-- fills are national CONTENT, see the palette-exempt island below).

local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful").xresources.apply_dpi

-- flag{ country="br" } -> widget (fixed dpi(24) x dpi(16))
local function flag(args)
  args = args or {}
  local country = args.country or "br"

  local width  = dpi(24)
  local height = dpi(16)

  local widget = wibox.widget.base.make_widget()

  function widget:fit(_, _, _)
    return width, height
  end

  function widget:draw(_, cr, w, h)
    cr:save()
    gears.shape.rounded_rect(cr, w, h, dpi(4))
    cr:clip()

    -- ── palette-exempt ────────────────────────────────────────────────────
    -- National flag colors are CONTENT, not theme tokens: the ONE sanctioned
    -- raw-rgba island (BLUEPRINT §2). Do NOT tokenize these values. The glass
    -- bevel stroke below (white @ .18) is the flag's own highlight — also here.
    if country == "br" then
      cr:set_source_rgba(0.0, 0.61, 0.26, 1)
      cr:paint()

      cr:set_source_rgba(1.0, 0.83, 0.0, 1)
      cr:move_to(w * 0.5, h * 0.08)
      cr:line_to(w * 0.9, h * 0.5)
      cr:line_to(w * 0.5, h * 0.92)
      cr:line_to(w * 0.1, h * 0.5)
      cr:close_path()
      cr:fill()

      cr:set_source_rgba(0.02, 0.23, 0.56, 1)
      cr:arc(w * 0.5, h * 0.5, math.min(w, h) * 0.18, 0, 2 * math.pi)
      cr:fill()
    elseif country == "fr" then
      cr:set_source_rgba(0.0, 0.22, 0.62, 1)
      cr:rectangle(0, 0, w / 3, h)
      cr:fill()

      cr:set_source_rgba(0.95, 0.95, 0.95, 1)
      cr:rectangle(w / 3, 0, w / 3, h)
      cr:fill()

      cr:set_source_rgba(0.84, 0.13, 0.19, 1)
      cr:rectangle(2 * w / 3, 0, w / 3, h)
      cr:fill()
    elseif country == "jp" then
      cr:set_source_rgba(0.97, 0.97, 0.97, 1)
      cr:paint()

      cr:set_source_rgba(0.8, 0.0, 0.12, 1)
      cr:arc(w * 0.5, h * 0.5, math.min(w, h) * 0.22, 0, 2 * math.pi)
      cr:fill()
    else
      local stripes = 7
      local stripe_height = h / stripes

      for i = 0, stripes - 1 do
        if i % 2 == 0 then
          cr:set_source_rgba(0.7, 0.05, 0.14, 1)
        else
          cr:set_source_rgba(0.95, 0.95, 0.95, 1)
        end
        cr:rectangle(0, i * stripe_height, w, stripe_height)
        cr:fill()
      end

      cr:set_source_rgba(0.0, 0.19, 0.46, 1)
      cr:rectangle(0, 0, w * 0.45, h * 0.58)
      cr:fill()
    end

    cr:restore()

    gears.shape.rounded_rect(cr, w, h, dpi(4))
    cr:set_source_rgba(1, 1, 1, 0.18)
    cr:set_line_width(1)
    cr:stroke()
    -- ── end palette-exempt ────────────────────────────────────────────────
  end

  -- :set_country(c) — optional recolor in place (world_clock builds one per city).
  function widget:set_country(c)
    country = c or "br"
    self:emit_signal("widget::redraw_needed")
  end

  return widget
end

return flag
