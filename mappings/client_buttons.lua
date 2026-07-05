-- ═════════════════════════════════════════════════════════════════════════
--   TRACTADO DAS PROPOSIÇÕES DO RATO SOBRE O CLIENTE  (client_buttons)
--
--   Seja dado um cliente — uma janela particular, elemento do domínio de
--   todas as janelas governadas pelo systema. Demonstra-se, na doutrina do
--   insigne geómetra Braga Us, que a acção do rato sobre esse cliente admitte
--   distincção rigorosa segundo o botão premido e o modificador que o
--   acompanha. Reune-se aqui, num só feixe (gears.table.join), o systema
--   completo de taes correspondências.
-- ═════════════════════════════════════════════════════════════════════════
-- Das bibliothecas do systema Awesome, invocadas segundo o antigo costume.
local awful = require("awful")
local gears = require("gears")

-- Seja `modkey` a tecla modificadora eleita pelo utente em user_variables;
-- ella figura como constante nas proposições que se seguem.
local modkey = user_vars.modkey

-- Da penna do professor Braga Us — o systema das quatro proposições do rato.
-- Domínio commum a todas: um cliente `c`. Contra-domínio: um effeito sobre
-- esse cliente (activação, translação, dilatação, ou abertura de menu).
-- Devolve-se o feixe reunido, para que a raiz o adopte como lei geral.
return gears.table.join(
  -- Lemma primeiro: o simples toque (botão 1, sem modificador) apenas
  -- desperta o cliente, requerendo sua activação e elevação ao proscénio.
  awful.button({}, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
  end),
  -- Corollário do toque com o modkey (botão 1): além de despertar o cliente,
  -- inicia-se a translação — o arrastar da janela pela mão do operador.
  awful.button({ modkey }, 1, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    awful.mouse.client.move(c)
  end),
  -- Corollário análogo (modkey + botão 3): desperta o cliente e principia a
  -- dilatação de suas dimensões — a operação de redimensionamento.
  awful.button({ modkey }, 3, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    awful.mouse.client.resize(c)
  end),
  -- Proposição derradeira, demonstrada por Braga Us: o premir da roda (botão
  -- do meio, nº 2) evoca o menu de contexto do VIOLET HUD (vide §7.5). Nota
  -- de prudência: reserva-se o botão-direito SEM modificador para que a
  -- própria applicação (tmux, terminal, navegador) faça uso do seu menu.
  -- Adverte-se que, nos terminaes, o botão-do-meio costuma verter a selecção;
  -- aqui, porém, elle é captado para o menu. O redimensionar da janela dá-se
  -- por modkey conjugado ao clique-direito.
  awful.button({}, 2, function(c)
    c:emit_signal("request::activate", "mouse_click", { raise = true })
    require("src.organisms.context_menu")(c)
  end)
)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
