------------------------------------------------------------------------------------------
-- src/molecules/kblayout.lua — Keyboard-layout pill (VIOLET HUD).                         --
--                                                                                        --
-- The bar widget: a shared pill{ keyboard icon + current layout code }. The old embedded  --
-- popup / mousegrabber / per-item highlight engine moved to src/organisms/kb_menu.lua      --
-- (title_band + menu_item). This leaf now only OWNS the layout state.                      --
--                                                                                        --
-- Consumes user_vars.kblayout (e.g. { "br", "us" }) — the hardcoded { "us","fr","jp" }     --
-- list AND the destructive constructor-time `setxkbmap us` are GONE. Boot only READS the   --
-- live layout (setxkbmap -query); exactly one query runs per layout change.                --
--                                                                                        --
-- Signals (all via awesome.emit_signal, no blocking IO):                                  --
--   in  "kblayout::toggle"        (global key) -> cycle to the next configured layout.      --
--   in  "kblayout::set"(code)     (kb_menu click) -> apply that layout.                     --
--   out "kblayout::menu:toggle"(s) (pill click) -> kb_menu shows/hides.                     --
--   out "kblayout::state"(layout)  (after every read) -> pill label + kb_menu highlight.    --
--                                                                                        --
-- Public API (unchanged shape): function(s) -> widget (the pill).                          --
------------------------------------------------------------------------------------------

local awful = require("awful")
local p     = require("src.theme.palette")
local pill  = require("src.molecules.pill")

-- Configured layouts (user_vars is a sanctioned global, present by load order; read
-- defensively with a safe fallback).
local keymaps = (user_vars and user_vars.kblayout) or { "us" }

-- Module-level state: one layout for the whole X server. Signal handlers are wired ONCE
-- (guarded) so multi-screen instantiation never multiplies queries or cycles.
local pills = {}
local current_layout
local wired = false

-- Reads the live layout ONCE and broadcasts it. nil/empty stdout keeps the last value (R4).
local function refresh()
  awful.spawn.easy_async_with_shell(
    "setxkbmap -query | grep layout: | awk '{print $2}'",
    function(stdout)
      local layout = (stdout or ""):match("[%w_-]+")
      if not layout or layout == "" then return end
      current_layout = layout
      for _, pw in ipairs(pills) do pw:set_text(layout) end
      awesome.emit_signal("kblayout::state", layout)
    end
  )
end

-- Apply a layout (argv array — no shell), then one authoritative read.
local function apply(code)
  awful.spawn.easy_async({ "setxkbmap", tostring(code) }, function() refresh() end)
end

-- Cycle to the next configured layout based on the last known current layout.
local function cycle()
  local nextmap = keymaps[1]
  if current_layout then
    for j, n in ipairs(keymaps) do
      if current_layout == n then
        nextmap = keymaps[(j % #keymaps) + 1]
        break
      end
    end
  end
  apply(nextmap)
end

local function ensure_wired()
  if wired then return end
  wired = true
  awesome.connect_signal("kblayout::toggle", cycle)
  awesome.connect_signal("kblayout::set", function(code) apply(code) end)
  refresh() -- initial READ only — never a destructive boot-time setxkbmap
end

return function(s)
  ensure_wired()

  local kb = pill {
    icon       = "keyboard",
    icon_color = p.v400,
    text       = current_layout or "",
    bg         = p.panel,
    fg         = p.text_muted,
    hover      = { bg = p.panel, fg = p.v500 }, -- ex: Hover_signal(_, p.panel, p.v500)
    on_click   = function() awesome.emit_signal("kblayout::menu:toggle", s) end,
  }

  pills[#pills + 1] = kb
  if current_layout then kb:set_text(current_layout) end

  return kb
end
