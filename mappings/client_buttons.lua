-- Awesome Libs
local awful = require("awful")
local gears = require("gears")

local modkey = user_vars.modkey

return gears.table.join(
  awful.button({}, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
  end),
  awful.button({ modkey }, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    awful.mouse.client.move(c)
  end),
  awful.button({ modkey }, 3, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    awful.mouse.client.resize(c)
  end),
  -- Clique do SCROLL (botão do meio / roda) abre o menu de contexto VIOLET HUD (§7.5).
  -- Botão-direito SEM modkey continua livre p/ o app (tmux/terminal/navegador) usar o
  -- próprio menu. (Atenção: em terminais o botão-do-meio costuma colar a seleção; aqui
  -- ele é capturado p/ o menu. Resize de janela = modkey + clique-direito.)
  awful.button({}, 2, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    require("src.organisms.context_menu")(c)
  end)
)
