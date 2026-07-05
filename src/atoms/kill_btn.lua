-- src/atoms/kill_btn.lua
-- 28px SIGTERM hit-target with a centered 14px "kill" glyph. Hover swaps the
-- icon muted -> p.crit using TWO PRE-CACHED icon.surface states (NO per-hover
-- recolor_image — that leaked/reparsed the SVG on every enter).
--
-- Kill SEMANTICS stay in the caller's on_kill callback (c:kill() /
-- awful.spawn({"kill", pid}) — NEVER os.execute). This atom only fires it.
--
--   local kill_btn = require("src.atoms.kill_btn")
--   local w = kill_btn{ on_kill = function() awful.spawn({"kill", pid}) end }
--   w:set_on_kill(fn)   -- rebind target when a row-pool row is reused
--
-- Requires the icon atom (same-layer, sanctioned by §2 which mandates
-- icon.surface here); + src.theme + awful/gears/wibox.

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local icon  = require("src.atoms.icon")

-- kill_btn{ on_kill } -> widget
local function kill_btn(args)
  args = args or {}
  local kill_cb = args.on_kill

  -- Two states cached ONCE at construction (never recolored per hover).
  local rest_surface = icon.surface("kill", p.text_muted)
  local hot_surface  = icon.surface("kill", p.crit)

  local img = wibox.widget {
    image         = rest_surface,
    resize        = true,
    forced_width  = dpi(mt.kill_icon),
    forced_height = dpi(mt.kill_icon),
    widget        = wibox.widget.imagebox,
  }

  -- 28px hit-target; icon centered. Height flows from the enclosing row.
  local w = wibox.widget {
    img,
    halign       = "center",
    valign       = "center",
    forced_width = dpi(mt.kill_w),
    widget       = wibox.container.place,
  }

  w:connect_signal("mouse::enter", function()
    img.image = hot_surface
    local wb = mouse.current_wibox
    if wb then wb.cursor = "hand2" end
  end)
  w:connect_signal("mouse::leave", function()
    img.image = rest_surface
    local wb = mouse.current_wibox
    if wb then wb.cursor = "left_ptr" end
  end)

  w:buttons(gears.table.join(
    awful.button({}, 1, function()
      if kill_cb then kill_cb() end
    end)
  ))

  -- Row-pool friendly: rebind the kill target without rebuilding the widget.
  function w:set_on_kill(fn)
    kill_cb = fn
  end

  return w
end

return kill_btn
