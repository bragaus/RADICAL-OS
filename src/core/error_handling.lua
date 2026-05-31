--------------------------------------------------------------------
-- Fail-loud error handling with on-screen rescue popup.
--
-- Goals (in order of priority):
--   1. The user sees the error BEFORE the WM appears frozen.
--   2. The user can always spawn a terminal to fix things, even if
--      the bars / dock / mappings never finish loading.
--   3. The user can request a full awesome restart from the popup.
--
-- The popup is built with raw awful.popup + wibox so it does NOT
-- depend on src/core/notifications.lua, src/theme/init.lua or any
-- other module that could itself be the source of the error.
--------------------------------------------------------------------
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local M = {}

local FALLBACK_TERMINAL = "alacritty"
local FALLBACK_MODKEY = "Mod4"

local function get_terminal()
  if rawget(_G, "user_vars") and user_vars.terminal then
    return user_vars.terminal
  end
  return FALLBACK_TERMINAL
end

local function get_modkey()
  if rawget(_G, "user_vars") and user_vars.modkey then
    return user_vars.modkey
  end
  return FALLBACK_MODKEY
end

local function spawn_terminal()
  local term = get_terminal()
  local ok = pcall(awful.spawn, term)
  if not ok then
    pcall(awful.spawn.with_shell, term)
  end
end

local function pango_escape(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;")
  s = s:gsub("<", "&lt;")
  s = s:gsub(">", "&gt;")
  return s
end

local active_popup = nil

local function close_popup()
  if active_popup then
    active_popup.visible = false
    active_popup = nil
  end
end

local function make_button(label, bg, on_click)
  local bg_widget
  local btn = wibox.widget {
    {
      {
        markup = "<b>" .. pango_escape(label) .. "</b>",
        align = "center",
        valign = "center",
        font = "JetBrainsMono Nerd Font 11",
        widget = wibox.widget.textbox,
      },
      left = 18,
      right = 18,
      top = 10,
      bottom = 10,
      widget = wibox.container.margin,
    },
    bg = bg,
    fg = "#ffffff",
    shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 6) end,
    widget = wibox.container.background,
  }
  bg_widget = btn
  btn:buttons(gears.table.join(
    awful.button({}, 1, function() pcall(on_click) end)
  ))
  btn:connect_signal("mouse::enter", function() bg_widget.bg = "#ffffff22" end)
  btn:connect_signal("mouse::leave", function() bg_widget.bg = bg end)
  return btn
end

--- Show a centered error popup with rescue actions.
-- @tparam string title  Short banner (no Pango markup).
-- @tparam string body   Long body / stack trace (rendered as plain text).
function M.notify(title, body)
  title = tostring(title or "ERROR")
  body = tostring(body or "")

  -- Always log to stderr so journalctl gets it even if the popup itself fails.
  io.stderr:write("[awesome-error] " .. title .. ": " .. body .. "\n")

  if active_popup then
    -- One popup at a time; the journal still has the rest.
    return
  end

  local s = awful.screen.focused() or screen.primary
  if not s then
    for sc in screen do s = sc; break end
  end
  if not s then return end

  local ok, popup_or_err = pcall(function()
    return awful.popup {
      screen = s,
      visible = true,
      ontop = true,
      placement = awful.placement.centered,
      shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 10) end,
      bg = "#120822",
      border_width = 3,
      border_color = "#ff3860",
      widget = {
        {
          {
            {
              markup = "<span foreground='#ff3860'><b>⚠  " .. pango_escape(title) .. "</b></span>",
              font = "JetBrainsMono Nerd Font Bold 14",
              widget = wibox.widget.textbox,
            },
            {
              text = body,
              font = "JetBrainsMono Nerd Font 10",
              widget = wibox.widget.textbox,
              forced_width = 780,
              wrap = "word_char",
            },
            {
              {
                markup = "<span foreground='#bbbbbb' font='JetBrainsMono Nerd Font 9'><i>Atalho de emergência: "
                  .. pango_escape(get_modkey()) .. "+Shift+Return abre o terminal a qualquer momento.</i></span>",
                widget = wibox.widget.textbox,
              },
              top = 4,
              widget = wibox.container.margin,
            },
            {
              make_button("Abrir Terminal (" .. get_terminal() .. ")", "#1f8f52", function()
                spawn_terminal()
              end),
              make_button("Recarregar Awesome", "#191338", function()
                close_popup()
                awesome.restart()
              end),
              make_button("Dispensar", "#3a2840", function()
                close_popup()
              end),
              spacing = 12,
              layout = wibox.layout.fixed.horizontal,
            },
            spacing = 14,
            layout = wibox.layout.fixed.vertical,
          },
          margins = 24,
          widget = wibox.container.margin,
        },
        widget = wibox.container.background,
      },
    }
  end)

  if not ok then
    io.stderr:write("[awesome-error] popup itself failed: " .. tostring(popup_or_err) .. "\n")
    return
  end

  active_popup = popup_or_err
end

--- pcall-protected require.
-- Returns the module on success, nil on failure (with popup shown).
function M.safe_require(name)
  local ok, mod = pcall(require, name)
  if not ok then
    M.notify("Falha ao carregar módulo: " .. name, mod)
    return nil
  end
  return mod
end

--- pcall-protected function call with traceback.
-- @return true on success, false on failure (with popup shown).
function M.safe_call(label, fn, ...)
  local args = { n = select("#", ...), ... }
  local ok, err = xpcall(function() return fn(table.unpack(args, 1, args.n)) end, debug.traceback)
  if not ok then
    M.notify("Erro em " .. tostring(label), err)
    return false
  end
  return true
end

-- ─── Runtime error signal ────────────────────────────────────────
do
  local in_error = false
  awesome.connect_signal("debug::error", function(err)
    if in_error then return end
    in_error = true
    M.notify("AWESOME debug::error", err)
    in_error = false
  end)
end

-- ─── Failsafe keybinding ─────────────────────────────────────────
-- Installed via delayed_call so we run AFTER mappings/bind_to_tags.lua
-- which calls root.keys(globalkeys) and would otherwise overwrite us.
local function install_failsafe_keys()
  local modkey = get_modkey()
  local existing = root.keys() or {}
  root.keys(gears.table.join(
    existing,
    awful.key(
      { modkey, "Shift" }, "Return",
      spawn_terminal,
      { description = "failsafe: abrir terminal", group = "emergency" }
    ),
    awful.key(
      { modkey, "Shift" }, "r",
      awesome.restart,
      { description = "failsafe: recarregar awesome", group = "emergency" }
    ),
    awful.key(
      { modkey, "Control", "Shift" }, "Escape",
      function() if active_popup then close_popup() end end,
      { description = "failsafe: fechar popup de erro", group = "emergency" }
    )
  ))
end

gears.timer.delayed_call(install_failsafe_keys)

return M
