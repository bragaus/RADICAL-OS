------------------------------------------------------------------------------------------
-- src/organisms/tag_menu.lua — Menu de contexto da TAG (clique-direito no taglist).      --
--                                                                                        --
-- Construído sobre context_menu.build + as moléculas title_band/menu_item. Ações:        --
--   * Rename          -> prompt transiente (awful.prompt) que renomeia a tag;            --
--   * Move Left/Right -> reordena a tag entre as tags da tela (awful.tag.move);          --
--   * Change Icon     -> drill-down para um submenu de ícones (define tag.icon).         --
--                                                                                        --
-- Sem submenus aninhados frágeis: "Change Icon" reabre um context_menu no mesmo lugar    --
-- (mesma disciplina do context_menu do cliente). Nada de IO bloqueante (R3).             --
--                                                                                        --
-- API:  local tag_menu = require("src.organisms.tag_menu")                               --
--       tag_menu.show(s, tag, geo)  -- geo (opcional) = geometria do clique p/ placement.--
------------------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local gfs   = require("gears.filesystem")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local ft    = require("src.theme.typography")
local context_menu = require("src.organisms.context_menu")

local ICON_DIR = gfs.get_configuration_dir() .. "icons/svg/"

-- Ícones oferecidos pelo submenu "Change Icon" (todos existem em icons/svg/).
local ICON_CHOICES = {
  { label = "Develop",  icon = "develop"  },
  { label = "Media",    icon = "media"    },
  { label = "Internet", icon = "internet" },
  { label = "Files",    icon = "files"    },
  { label = "Terminal", icon = "term"     },
}

-- Placement: ancora o menu logo abaixo da geometria do clique (geo), sem sair da tela.
-- nil geo -> context_menu usa seu placement default (sob o mouse).
local function placement_for(geo)
  if not geo then return nil end
  return function(d)
    awful.placement.next_to(d, {
      geometry            = geo,
      preferred_positions = "bottom",
      preferred_anchors   = "middle",
    })
    awful.placement.no_offscreen(d)
  end
end

-- Rename: popup transiente com um textbox dirigido por awful.prompt (não-bloqueante).
local function rename(tag)
  if not tag then return end
  local tb = wibox.widget { font = ft.body, widget = wibox.widget.textbox }
  local pop = awful.popup {
    widget = {
      {
        tb,
        left   = dpi(mt.pad_header_x),
        right  = dpi(mt.pad_header_x),
        widget = wibox.container.margin,
      },
      forced_width  = dpi(mt.panel_w_sm),
      forced_height = dpi(30),
      fg            = p.text_bright,
      bg            = p.a(p.panel, p.alpha.panel_hi),
      widget        = wibox.container.background,
    },
    ontop        = true,
    visible      = true,
    border_width = dpi(mt.border_panel),
    border_color = p.line_base,
    placement    = awful.placement.centered,
  }
  awful.prompt.run {
    prompt        = "RENAME: ",
    text          = tag.name,
    textbox       = tb,
    exe_callback  = function(new)
      if new and #new > 0 then tag.name = new end
    end,
    done_callback = function()
      pop.visible = false
    end,
  }
end

-- Move: reordena a tag `delta` posições entre as tags da tela (clampa nos limites).
local function move(tag, delta)
  if not tag or not tag.screen then return end
  local idx = tag.index
  if not idx then return end
  local n = #tag.screen.tags
  local target = idx + delta
  if target < 1 or target > n then return end
  awful.tag.move(target, tag)
end

local M = {}

-- Submenu "Change Icon": drill-down (reabre um context_menu no mesmo lugar).
local function show_icon_menu(tag, geo)
  local items = {}
  for _, ch in ipairs(ICON_CHOICES) do
    items[#items + 1] = {
      label    = ch.label,
      icon     = ch.icon,
      on_click = function() tag.icon = ICON_DIR .. ch.icon .. ".svg" end,
    }
  end
  context_menu.build("SET ICON", items, { placement = placement_for(geo) })
end

function M.show(s, tag, geo)
  local scr = s or (tag and tag.screen) or awful.screen.focused()
  tag = tag or (scr and scr.selected_tag)
  if not tag then return end

  local items = {
    { label = "Rename",      icon = "edit",       on_click = function() rename(tag) end },
    { label = "Move Left",   icon = "move_left",  on_click = function() move(tag, -1) end },
    { label = "Move Right",  icon = "move_right", on_click = function() move(tag,  1) end },
    { band  = "ICON" },
    { label = "Change Icon", icon = "doc", arrow = true, on_click = function() show_icon_menu(tag, geo) end },
  }

  context_menu.build("TAG · " .. tostring(tag.name), items, { placement = placement_for(geo) })
end

return M
