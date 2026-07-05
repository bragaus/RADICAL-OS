------------------------------------------------------------------------------------------
-- src/molecules/menu_item.lua — Dense menu row (VIOLET HUD).                              --
--                                                                                        --
-- kit.css `.ctx__item`: icon + label (+ optional right-aligned arrow for submenus).        --
--   rest  : text_primary (danger -> crit), transparent bg, muted icon;                     --
--   hover  : bg v700 (danger -> crit), fg v50, icon -> v50, cursor hand1;                   --
--   disabled: dimmed (text_disabled), no hover, no click.                                  --
-- Label/arrow are PLAIN txt inheriting the container fg (no markup, R2); the icon recolors  --
-- via TWO CACHED icon.surface states (no per-hover recolor). Hover wired once (R7).         --
--                                                                                        --
-- on_hover(): fired on pointer-enter (e.g. to open a submenu). Shared by context_menu,      --
-- tag_menu, kb_menu.                                                                       --
--                                                                                        --
-- `font` / `icon_size` are OPTIONAL overrides (defaults ft.body / dpi(mt.icon_md)):         --
-- context_menu renders its items at ~1.5x and passes its own scaled values.                --
--                                                                                        --
--   local menu_item = require("src.molecules.menu_item")                                 --
--   menu_item{ label = "Close", icon = "close", danger = true, on_click = kill }           --
--   menu_item{ label = "Change Icon", icon = "edit", arrow = true, on_hover = open_sub }    --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local icon  = require("src.atoms.icon")
local txt   = require("src.atoms.txt")

local function menu_item(args)
  args = args or {}
  local disabled  = args.disabled and true or false
  local danger    = args.danger and true or false
  local icon_size = args.icon_size or dpi(mt.icon_md)   -- kit img 15px

  local normal_fg = disabled and p.text_disabled
                    or (danger and p.crit or p.text_primary)
  local hover_fg  = p.v50
  local hover_bg  = danger and p.crit or p.v700

  -- left group: (optional) icon + label. Direct refs (R1) held for hover recolor.
  local left = wibox.layout.fixed.horizontal()
  left.spacing = dpi(mt.gap)   -- kit gap 9; mt.gap (8) is the nearest token

  local img, rest_surface, hover_surface
  if args.icon then
    local icon_rest = disabled and p.text_disabled or p.text_muted
    rest_surface  = icon.surface(args.icon, icon_rest)
    hover_surface = icon.surface(args.icon, p.v50)
    img = wibox.widget {
      image         = rest_surface,
      resize        = true,
      forced_width  = icon_size,
      forced_height = icon_size,
      widget        = wibox.widget.imagebox,
    }
    left:add(wibox.widget { img, valign = "center", widget = wibox.container.place })
  end

  local label = txt { role = "body", text = args.label, valign = "center" }
  if args.font then label.font = args.font end
  left:add(label)

  -- optional submenu arrow, pushed to the right edge (kit .ctx__arrow margin-left:auto).
  local arrow
  if args.arrow then
    arrow = txt { role = "body", text = "\226\150\184", valign = "center", align = "right" } -- "▸"
    if args.font then arrow.font = args.font end
  end

  local row = wibox.widget {
    left,
    nil,
    arrow,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  local w = wibox.widget {
    {
      row,
      left   = dpi(mt.pad_header_x),
      right  = dpi(mt.pad_header_x),
      widget = wibox.container.margin,
    },
    forced_height = dpi(30),        -- kit .ctx__item 30px; no metric token
    bg            = p.transparent,
    fg            = normal_fg,      -- label/arrow inherit this
    widget        = wibox.container.background,
  }

  if not disabled then
    w:connect_signal("mouse::enter", function()
      w.bg = hover_bg
      w.fg = hover_fg
      if img then img.image = hover_surface end
      if args.on_hover then args.on_hover() end
      local wb = mouse.current_wibox
      if wb then wb.cursor = "hand1" end
    end)
    w:connect_signal("mouse::leave", function()
      w.bg = p.transparent
      w.fg = normal_fg
      if img then img.image = rest_surface end
      local wb = mouse.current_wibox
      if wb then wb.cursor = "left_ptr" end
    end)
    if args.on_click then
      w:buttons(gears.table.join(
        awful.button({}, 1, function() args.on_click() end)
      ))
    end
  end

  return w
end

return menu_item
