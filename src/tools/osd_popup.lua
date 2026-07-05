------------------------------------------------------------------------------------------
-- src/tools/osd_popup.lua — shared OSD popup shell (VIOLET HUD).                          --
--                                                                                        --
-- The volume + brightness OSDs share the SAME transient-popup mechanics: a bottom-centre  --
-- awful.popup that appears on a signal, auto-hides after `timeout`s, stays open while the --
-- pointer is over it, and re-arms its hide timer on a rerun signal. Only the panel body,  --
-- the show signal and the rerun signal differ, so that shell lives here once (DS §7.10).  --
--                                                                                        --
--   osd_popup{ s, panel_widget, show_signal, rerun_signal, timeout = 2 } -> awful.popup    --
--     s            per-screen; the show handler is gated on `s == mouse.screen`.           --
--     panel_widget the built panel() to display (the caller keeps its own direct ref, R1). --
--     show_signal  awesome signal name that makes the popup visible on the pointer screen. --
--     rerun_signal awesome signal name that re-arms (or starts) the auto-hide timer.       --
--     timeout      auto-hide seconds (default 2).                                         --
--                                                                                        --
-- Presentational shell only — never spawns/polls; the owning OSD drives the panel body.    --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

local function osd_popup(args)
  args = args or {}
  local s            = args.s
  local panel_widget = args.panel_widget
  local timeout      = args.timeout or 2

  local container = awful.popup {
    widget    = wibox.container.background,
    ontop     = true,
    bg        = p.a(p.base, 0), -- fully transparent; panel() draws its own chrome
    stretch   = false,
    visible   = false,
    screen    = s,
    placement = function(c)
      awful.placement.bottom(c, { margins = { bottom = dpi(40) } }) -- bottom clearance; no metric token fits
    end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(mt.radius_panel))
    end,
  }

  local hide = gears.timer {
    timeout   = timeout,
    autostart = true,
    callback  = function()
      container.visible = false
    end,
  }

  container:setup {
    panel_widget,
    layout = wibox.layout.fixed.horizontal,
  }

  if args.show_signal then
    awesome.connect_signal(args.show_signal, function()
      if s == mouse.screen then
        container.visible = true
      end
    end)
  end

  container:connect_signal("mouse::enter", function()
    container.visible = true
    hide:stop()
  end)

  container:connect_signal("mouse::leave", function()
    container.visible = true
    hide:again()
  end)

  if args.rerun_signal then
    awesome.connect_signal(args.rerun_signal, function()
      if hide.started then
        hide:again()
      else
        hide:start()
      end
    end)
  end

  return container
end

return osd_popup
