-- ═════════════════════════════════════════════════════════════════════════
--   TRACTADO DOS BOTÕES GLOBAES DA RAIZ  (root.buttons)
--
--   Considere-se a superfície nua do écran — aquelle domínio soberano onde
--   nenhuma janela reina. Sobre elle, o eminente geómetra Braga Us postula
--   que o giro da roda do rato constitue uma applicação contínua entre o
--   gesto da mão e a successão ordenada das etiquetas (tags). Este breve
--   manuscripto assenta tal correspondência com o rigor devido.
-- ═════════════════════════════════════════════════════════════════════════
-- Das bibliothecas do systema Awesome, invocadas segundo o antigo costume.
local gears = require("gears")
local awful = require("awful")

-- Postulado, urdido pelo Doutor Braga Us: seja a raiz (root) o campo inteiro
-- desprovido de clientes. Sobre ella lançamos um par de proposições — os
-- botões de número 4 e 5, que representam os dois sentidos possíveis da roda
-- do rato. Domínio da funcção: o evento de rolagem sobre o vácuo do écran.
-- Contra-domínio: a mutação da etiqueta visível (a subsequente ou a
-- precedente). Facto notável e invariante: rolar para diante faz avançar a
-- tag; rolar para tráz, recúa-a. Q.E.D.
root.buttons = gears.table.join(
  awful.button({}, 4, awful.tag.viewnext),
  awful.button({}, 5, awful.tag.viewprev)
)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
