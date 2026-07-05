------------------------------------------------------------------------------------------
-- src/tools/list_buttons.lua — Shared awful taglist/tasklist button helpers.             --
--                                                                                        --
-- DRY home for the awful.button plumbing that was hand-copied into BOTH taglist.lua and   --
-- tasklist.lua (the identical `create_buttons` wrapper) plus the taglist/tasklist button   --
-- SETS handed to awful.widget.{taglist,tasklist}.                                         --
--                                                                                        --
-- BUGFIX (nil modkey): the live taglist bound `awful.button({ modkey }, ...)` against a    --
-- bare `modkey` global that this config never defines — it is only `user_vars.modkey`.     --
-- `{ modkey }` was therefore `{ nil }` == `{}`, so the "modkey+click" bindings fired on a   --
-- PLAIN click (modkey+1 "move focused client to tag" triggered on every left-click that    --
-- also ran view_only). We now read `user_vars.modkey` so the modifier actually gates.      --
--                                                                                        --
--   local list_buttons = require("src.tools.list_buttons")                               --
--   awful.widget.taglist(s, filter, list_buttons.taglist(), {}, upd, layout)             --
--   -- inside list_update:  widget:buttons(list_buttons.create(buttons, object))          --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")

local list_buttons = {}

-- create(buttons, object) — the awful.button wrapper a taglist/tasklist list_update uses to
-- bind press/release on the per-object widget. Extracted verbatim from the duplicated
-- create_buttons in taglist.lua + tasklist.lua (identical behavior).
function list_buttons.create(buttons, object)
  if not buttons then
    return nil
  end

  local btns = {}

  for _, b in ipairs(buttons) do
    btns[#btns + 1] = awful.button {
      modifiers = b.modifiers,
      button    = b.button,
      on_press  = function() b:emit_signal("press", object) end,
      on_release = function() b:emit_signal("release", object) end,
    }
  end

  return btns
end

-- taglist() — the taglist button set. modkey now read from user_vars (see BUGFIX above).
-- Right-click opens the VIOLET-HUD tag context menu (tag_menu, published by C5); modkey+
-- right-click keeps the legacy toggle_tag. tag_menu is required LAZILY inside the callback
-- so this module loads even before C5's file lands, and so no blocking require runs at
-- construction (R3).
function list_buttons.taglist()
  local modkey = user_vars.modkey or "Mod4"

  return gears.table.join(
    awful.button({}, 1, function(t)
      t:view_only()
    end),
    awful.button({ modkey }, 1, function(t)
      if client.focus then
        client.focus:move_to_tag(t)
      end
    end),
    awful.button({}, 3, function(t)
      require("src.organisms.tag_menu").show(t.screen, t)
    end),
    awful.button({ modkey }, 3, function(t)
      if client.focus then
        client.focus:toggle_tag(t)
      end
    end),
    awful.button({}, 4, function(t)
      awful.tag.viewnext(t.screen)
    end),
    awful.button({}, 5, function(t)
      awful.tag.viewprev(t.screen)
    end)
  )
end

-- tasklist() — the tasklist button set (minimize/restore on left, kill on right).
-- Behavior preserved verbatim from tasklist.lua.
function list_buttons.tasklist()
  return gears.table.join(
    awful.button({}, 1, function(c)
      if c == client.focus then
        c.minimized = true
      else
        c.minimized = false
        if not c:isvisible() and c.first_tag then
          c.first_tag:view_only()
        end
        c:emit_signal("request::activate")
        c:raise()
      end
    end),
    awful.button({}, 3, function(c)
      c:kill()
    end)
  )
end

return list_buttons
