------------------------------------------------------------------------------------------
-- src/organisms/kb_menu.lua — Keyboard-layout switch popup (VIOLET HUD).                  --
--                                                                                        --
-- The popup half of the old src/molecules/kblayout.lua, extracted into an organism and     --
-- rebuilt on the shared molecules: a title_band header + one menu_item per configured      --
-- layout (user_vars.kblayout). Presentational only — clicking a row EMITS the request       --
-- ("kblayout::set"), the kblayout leaf owns the actual setxkbmap + state.                   --
--                                                                                        --
-- Signals:                                                                                --
--   in  "kblayout::menu:toggle"(scr) -> show/hide (scoped to this screen).                  --
--   in  "kblayout::hide:kbmenu"      -> hide + stop keygrabber.                             --
--   in  "kblayout::state"(layout)    -> mark the active row.                                --
--   out "kblayout::set"(code)        -> ask the kblayout leaf to apply a layout.            --
--                                                                                        --
-- Public API (NEW organism): function(s) -> awful.popup.                                   --
------------------------------------------------------------------------------------------

local awful      = require("awful")
local gears      = require("gears")
local wibox      = require("wibox")
local dpi        = require("beautiful.xresources").apply_dpi
local p          = require("src.theme.palette")
local mt         = require("src.theme.metrics")
local title_band = require("src.molecules.title_band")
local menu_item  = require("src.molecules.menu_item")

-- Pretty display names for the configured layouts; falls back to the uppercased code.
local NAMES = {
  us = "English (US)",
  br = "Portugues (BR)",
}
local function longname(code) return NAMES[code] or tostring(code):upper() end

-- Active / inactive row markers (plain UTF-8, matching menu_item's byte-escape style):
-- "\226\151\143" = ● (U+25CF), "\226\151\139" = ○ (U+25CB).
local MARK_ON, MARK_OFF = "\226\151\143 ", "\226\151\139 "

return function(s)
  local keymaps = (user_vars and user_vars.kblayout) or { "us" }
  local active  -- current layout code (nil until the first "kblayout::state")

  local function request(code)
    awesome.emit_signal("kblayout::set", code)
    awesome.emit_signal("kblayout::hide:kbmenu")
  end

  -- Rebuilt on each state change: 2-ish rows, cheap.
  local items = wibox.layout.fixed.vertical()
  local function rebuild()
    items:reset()
    for _, code in ipairs(keymaps) do
      local mark = (active == code) and MARK_ON or MARK_OFF
      items:add(menu_item {
        label    = mark .. longname(code),
        on_click = function() request(code) end,
      })
    end
  end
  rebuild()

  local popup = awful.popup {
    screen       = s,
    ontop        = true,
    visible      = false,
    bg           = p.a(p.panel, p.alpha.panel_hi),
    fg           = p.text_bright,
    border_width = dpi(mt.border_panel),
    border_color = p.line_base,
    shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_panel)) end,
    -- Bar-anchored offset (top_right, under the bar): tuned literals, no metric token fits.
    placement    = function(c)
      awful.placement.align(c, { position = "top_right", margins = { right = dpi(255), top = dpi(60) } })
    end,
    widget = {
      title_band { text = "KEYBOARD LAYOUT", width = dpi(mt.panel_w_sm) },
      items,
      layout = wibox.layout.fixed.vertical,
    },
  }

  -- Dismiss on any keypress while the popup is open.
  local keygrabber = awful.keygrabber {
    autostart          = false,
    stop_event         = "release",
    keypressed_callback = function()
      awesome.emit_signal("kblayout::hide:kbmenu")
    end,
  }

  local function hide()
    popup.visible = false
    keygrabber:stop()
  end

  awesome.connect_signal("kblayout::menu:toggle", function(scr)
    if scr ~= nil and scr ~= s then return end
    if popup.visible then
      hide()
    else
      popup.visible = true
      keygrabber:start()
    end
  end)

  awesome.connect_signal("kblayout::hide:kbmenu", hide)

  awesome.connect_signal("kblayout::state", function(layout)
    active = layout
    rebuild()
  end)

  popup:connect_signal("mouse::leave", function()
    awesome.emit_signal("kblayout::hide:kbmenu")
  end)

  return popup
end
