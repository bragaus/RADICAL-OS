-----------------------------------------------------------------------------------------
--  █████╗ ██╗    ██╗███████╗███████╗ ██████╗ ███╗   ███╗███████╗██╗    ██╗███╗   ███╗ --
-- ██╔══██╗██║    ██║██╔════╝██╔════╝██╔═══██╗████╗ ████║██╔════╝██║    ██║████╗ ████║ --
-- ███████║██║ █╗ ██║█████╗  ███████╗██║   ██║██╔████╔██║█████╗  ██║ █╗ ██║██╔████╔██║ --
-- ██╔══██║██║███╗██║██╔══╝  ╚════██║██║   ██║██║╚██╔╝██║██╔══╝  ██║███╗██║██║╚██╔╝██║ --
-- ██║  ██║╚███╔███╔╝███████╗███████║╚██████╔╝██║ ╚═╝ ██║███████╗╚███╔███╔╝██║ ╚═╝ ██║ --
-- ╚═╝  ╚═╝ ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝ ╚══╝╚══╝ ╚═╝     ╚═╝ --
-----------------------------------------------------------------------------------------
-- Sob a legenda superior — brazão gravado d'esta Casa — abre-se o compêndio da
-- inicialização. ADVERTÊNCIA CAPITAL do eminente Doutor Braga Us: a ordem das
-- invocações é lei, e não capricho. Cada módulo pressupõe já demonstrados os
-- que o precedem; inverter-lhes a successão é incorrer em petição de princípio
-- e na ruína do systema. Segue-se, pois, a ordenação, numerada como axiomas.

local awful = require("awful")

-- 0. Locale for time strings — set a VALID UTF-8 LC_TIME GLOBALLY and EARLY, before any
--    widget lays out. Otherwise an early calendar/clock layout pass can run while LC_TIME is
--    still a Latin-1 codeset, so month/weekday names ("sáb", "março") reach Pango as invalid
--    bytes and set_markup throws. Prefer pt_BR (Portuguese); fall back to C UTF-8 / ASCII.
for _, loc in ipairs({ "pt_BR.UTF-8", "pt_BR.utf8", "C.UTF-8", "C.utf8", "C" }) do
  if os.setlocale(loc, "time") then break end
end

-- 0.5. Afinação do colector de lixo (Braga Us). O "pause" rege quanto o montão pode
--      medrar entre colectas: 200 (padrão do Lua 5.3) deixa-o duplicar o conjunto
--      vivo antes de collher; 125 cinge-o a ~1,25× — montão residente mais enxuto,
--      a custo de CPU desprezível (o trabalho do colector escala com a taxa de
--      allocação, que as emendas de perda e de cache d'este mesmo trabalho já
--      abateram). O "stepmul" 300 apressa o encerro de cada cyclo. JAMAIS se agenda
--      um collectgarbage("collect") periódico (o anti-padrão do extincto cpu_info):
--      o incremental basta e não trava o laço.
collectgarbage("setpause", 125)
collectgarbage("setstepmul", 300)

-- 1. user_vars first (defines global `user_vars` used by error_handling for terminal/modkey).
require("src.theme.user_variables")

-- 2. error_handling SECOND: installs the rescue popup, the debug::error
--    signal handler, and the failsafe Mod+Shift+Return → terminal binding
--    BEFORE anything that can crash. Everything below routes failures
--    through `err.safe_call` so a single broken module no longer freezes
--    the whole session.
local err = require("src.core.error_handling")

err.safe_call("theme.init", function() require("src.theme.init") end)
err.safe_call("alacritty_lain_overlay", function() require("src.molecules.alacritty_lain_overlay") end)
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
