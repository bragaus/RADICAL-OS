-----------------------------------------------------------------------------------------
--  █████╗ ██╗    ██╗███████╗███████╗ ██████╗ ███╗   ███╗███████╗██╗    ██╗███╗   ███╗ --
-- ██╔══██╗██║    ██║██╔════╝██╔════╝██╔═══██╗████╗ ████║██╔════╝██║    ██║████╗ ████║ --
-- ███████║██║ █╗ ██║█████╗  ███████╗██║   ██║██╔████╔██║█████╗  ██║ █╗ ██║██╔████╔██║ --
-- ██╔══██║██║███╗██║██╔══╝  ╚════██║██║   ██║██║╚██╔╝██║██╔══╝  ██║███╗██║██║╚██╔╝██║ --
-- ██║  ██║╚███╔███╔╝███████╗███████║╚██████╔╝██║ ╚═╝ ██║███████╗╚███╔███╔╝██║ ╚═╝ ██║ --
-- ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝ ╚══╝╚══╝ ╚═╝     ╚═╝ --
-----------------------------------------------------------------------------------------
-- Initialising, order is important!

local awful = require("awful")

-- 0. Locale for time strings — set a VALID UTF-8 LC_TIME GLOBALLY and EARLY, before any
--    widget lays out. Otherwise an early calendar/clock layout pass can run while LC_TIME is
--    still a Latin-1 codeset, so month/weekday names ("sáb", "março") reach Pango as invalid
--    bytes and set_markup throws. Prefer pt_BR (Portuguese); fall back to C UTF-8 / ASCII.
for _, loc in ipairs({ "pt_BR.UTF-8", "pt_BR.utf8", "C.UTF-8", "C.utf8", "C" }) do
  if os.setlocale(loc, "time") then break end
end

-- 1. user_vars first (defines global `user_vars` used by error_handling for terminal/modkey).
require("src.theme.user_variables")

-- 2. error_handling SECOND: installs the rescue popup, the debug::error
--    signal handler, and the failsafe Mod+Shift+Return → terminal binding
--    BEFORE anything that can crash. Everything below routes failures
--    through `err.safe_call` so a single broken module no longer freezes
--    the whole session.
local err = require("src.core.error_handling")

err.safe_call("plano_gif.preload", function()
  local plano_gif = require("src.widgets.plano_gif")
  plano_gif.preload(math.max(72, (user_vars.dock_icon_size or 64) + 36))
end)
err.safe_call("theme.init", function() require("src.theme.init") end)
err.safe_call("alacritty_lain_overlay", function() require("src.widgets.alacritty_lain_overlay") end)
err.safe_call("signals", function() require("src.core.signals") end)
err.safe_call("notifications", function() require("src.core.notifications") end)
err.safe_call("rules", function() require("src.core.rules") end)
err.safe_call("global_buttons", function() require("mappings.global_buttons") end)
err.safe_call("bind_to_tags", function() require("mappings.bind_to_tags") end)
err.safe_call("radical_wm.init", function() require("radical_wm.init") end)
err.safe_call("auto_starter", function() require("src.tools.auto_starter")(user_vars.autostart) end)
awful.spawn.with_shell("xset s off")
awful.spawn.with_shell("xset -dpms")
awful.spawn.with_shell("xset s noblank")
--local cyber = require("cyber_hotkeys_dashboard")
--
--cyber.setup({
  --modkey = modkey,
  --terminal = terminal,
  --browser = "firefox",
  --file_manager = "thunar",
  --launcher = "rofi -show drun",
--})
--
--globalkeys = gears.table.join(globalkeys, cyber.keys)
--root.keys(globalkeys)
