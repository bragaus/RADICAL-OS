------------------------------------------------------------------------------------------
-- Main theming file — VIOLET HUD EDITION                                                --
-- Color tokens live in src/theme/palette.lua; this wires them into beautiful/Theme.     --
-- Hierarquia por luminosidade/alpha (roxo monocromático). Acento primário = v500.       --
------------------------------------------------------------------------------------------

-- Awesome Libs
local p = require("src.theme.palette")
local dpi = require("beautiful.xresources").apply_dpi
local gears = require("gears")
local awful = require("awful")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/titlebar/"

Theme.font = user_vars.font.bold

-- Base surfaces (violet-blacks)
Theme.bg_normal   = p.base
Theme.bg_focus    = p.panel_hi
Theme.bg_urgent   = p.glow_hot
Theme.bg_minimize = p.v950
Theme.bg_systray  = p.panel

Theme.fg_normal   = p.text_primary
Theme.fg_focus    = p.text_bright
Theme.fg_urgent   = p.v50
Theme.fg_minimize = p.text_muted

Theme.useless_gap   = dpi(6)  -- Change this to 0 if you dont like window gaps
Theme.border_width  = dpi(2)  -- referência tem borda FINA (era dpi(11))
Theme.border_normal = p.v950
-- Theme.border_focus aplicado via signals.lua (workaround) -> p.glow_core
Theme.border_marked = p.glow_hot

-- Menus (§7.5 do DESIGN_SYSTEM)
Theme.menu_height       = dpi(26)
Theme.menu_width        = dpi(220)
Theme.menu_bg_normal    = p.a(p.panel, 0.95)
Theme.menu_bg_focus     = p.v700
Theme.menu_fg_normal    = p.text_primary
Theme.menu_fg_focus     = p.v50
Theme.menu_border_color  = p.line_base
Theme.menu_border_width = dpi(1)
Theme.menu_shape = function(cr, width, heigth)
  gears.shape.rounded_rect(cr, width, heigth, dpi(3))
end

-- Taglist
Theme.taglist_fg_focus = p.v50
Theme.taglist_bg_focus = p.v500

-- Tooltip
Theme.tooltip_border_color = p.line_base
Theme.tooltip_bg           = p.a(p.panel, 0.95)
Theme.tooltip_fg           = p.text_bright
Theme.tooltip_border_width = dpi(1)
Theme.tooltip_gaps         = dpi(10)
Theme.tooltip_shape = function(cr, width, heigth)
  gears.shape.rounded_rect(cr, width, heigth, dpi(4))
end

Theme.notification_spacing = dpi(12)

-- Titlebar button icons (mantidos; recolor é feito no módulo titlebar)
Theme.titlebar_close_button_normal = icondir .. "close.svg"
Theme.titlebar_maximized_button_normal = icondir .. "maximize.svg"
Theme.titlebar_minimize_button_normal = icondir .. "minimize.svg"
Theme.titlebar_maximized_button_active = icondir .. "maximize.svg"
Theme.titlebar_maximized_button_inactive = icondir .. "maximize.svg"

Theme.systray_icon_spacing = dpi(6)

-- Hotkeys popup
Theme.hotkeys_bg = p.a(p.panel, 0.95)
Theme.hotkeys_fg = p.text_primary
Theme.hotkeys_border_width = dpi(1)
Theme.hotkeys_border_color = p.line_base
Theme.hotkeys_modifiers_fg = p.text_muted
Theme.hotkeys_shape = function(cr, width, height)
  gears.shape.rounded_rect(cr, width, height, dpi(4))
end
Theme.hotkeys_description_font = user_vars.font.bold

-- Icon directory path
local layout_path = Theme_path .. "../assets/layout/"

-- Here are the icons for the layouts defined, if you want to add more layouts go to main/layouts.lua
Theme.layout_floating = layout_path .. "floating.svg"
Theme.layout_tile = layout_path .. "tile.svg"
Theme.layout_dwindle = layout_path .. "dwindle.svg"
Theme.layout_fairh = layout_path .. "fairh.svg"
Theme.layout_fairv = layout_path .. "fairv.svg"
Theme.layout_fullscreen = layout_path .. "fullscreen.svg"
Theme.layout_max = layout_path .. "max.svg"
Theme.layout_magnifier = layout_path .. "magnifier.svg"
Theme.layout_cornerne = layout_path .. "cornerne.svg"
Theme.layout_cornernw = layout_path .. "cornernw.svg"
Theme.layout_cornerse = layout_path .. "cornerse.svg"
Theme.layout_cornersw = layout_path .. "cornersw.svg"
