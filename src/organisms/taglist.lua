--------------------------------
-- This is the taglist widget --
--------------------------------

local wibox = require("wibox")
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local tag_tab = require("src.molecules.tag_tab")        -- one-way powerline tab (§7.2)
local list_buttons = require("src.tools.list_buttons")  -- shared buttons + modkey fix

-- Mapa nome-da-tag -> ícone de TIPO (set icons/, categoria "tags"). Default: term.
local TAG_ICON = {
  ["PLANO-WEB3"]   = "internet",
  ["VIBE-STUDING"] = "edit",
  ["GHOST-SIGN"]   = "develop",
  ["NEW-ICHIMOKU"] = "media",
  ["NEW"]          = "files",
}
local function tag_icon(name)
  return (name and TAG_ICON[name:upper()]) or "term"
end

-- Snapshot the awful tag object into the tag_tab state flags (empty/occupied/selected/urgent).
local function state_of(tag)
  return {
    selected = tag.selected,
    occupied = #tag:clients() > 0,
    urgent   = tag.urgent,
  }
end

local list_update = function(widget, buttons, _, _, objects)
  widget:reset()
  widget:set_spacing(dpi(4))

  for _, object in ipairs(objects) do
    -- tag_tab owns the powerline shape, gradient fill, two-tone rim, icon + index + name.
    local tab = tag_tab { icon = tag_icon(object.name) }
    tab:set_label(object.index, object.name)
    tab:set_state(state_of(object))
    tab:buttons(list_buttons.create(buttons, object))

    -- Hover is the molecule's own edge-glow (kit .tag:hover) via set_state{hover=}; the
    -- outer tag_tab paints its fill through bgimage, so hover_stateful's bg/fg would be
    -- inert here. We drive the built-in hover state + manage the cursor.
    tab:connect_signal("mouse::enter", function()
      local st = state_of(object)
      st.hover = true
      tab:set_state(st)
      local cw = mouse.current_wibox
      if cw then cw.cursor = "hand1" end
    end)

    tab:connect_signal("mouse::leave", function()
      tab:set_state(state_of(object))
      local cw = mouse.current_wibox
      if cw then cw.cursor = "left_ptr" end
    end)

    widget:add(tab)
  end
end

return function(s)
  local taglist = awful.widget.taglist(
    s,
    awful.widget.taglist.filter.all,
    list_buttons.taglist(),
    {},
    list_update,
    wibox.layout.fixed.horizontal()
  )

  taglist._preserve_colors = true

  return taglist
end
