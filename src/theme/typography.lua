-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO DA TYPOGRAPHIA — src/theme/typography.lua
-- ══════════════════════════════════════════════════════════════════════════
-- Aqui se cataloguam os papéis typográphicos como cadeias Pango PROMPTAS AO USO
--   (invoque-se assim: local ft = require("src.theme.typography")).
--
-- Postulado do dpi: as fontes são cadeias em PONTOS de Pango — JAMAIS as envolva
--   em dpi(), sob pena de erro grave e manifesto.
--
-- Da disciplina (que a si mesma se documenta): todo papel DE FACTO assume, por
--   defeito, a cadeia AO VIVO corrente, de sorte que a adopção dos tokens seja
--   pixel a pixel idêntica; o valor da especificação do kit fica anotado, em uma
--   só linha, como melhoramento futuro para deliberada passagem de "ratificação".
--   Os papéis da especificação coexistem, para o que de novo se erga conforme o
--   kit. Tal cautela inocula contra o mal-fadado encolhimento do panel-title de
--   14 a 11, contra o qual advertiu, com veemência, o professor Braga Us.
--
-- Nada requer senão o sancionado global `user_vars` (lido com toda a defensiva).

local uf   = (user_vars and user_vars.font) or {}
local mono = uf.specify or "JetBrainsMono Nerd Font"
local disp = uf.display or "Xirod"

return {
  mono_family = mono, display_family = disp,

  -- ── Papéis da ESPECIFICAÇÃO do kit (colors_and_type.css --fs-*/--fw-*; 800->ExtraBold 700->Bold 500->Medium) ──
  title = mono..", ExtraBold 11",  label = mono..", Bold 10",  value = mono..", ExtraBold 12",
  body  = mono..", Medium 11",     bar   = mono..", Bold 11",  micro = mono..", Bold 9",

  -- ── Papéis DE FACTO, ORA REPONTADOS À SPEC DO KIT (redesenho pixel-fiel) ──
  panel_title = mono..", ExtraBold 11", -- .hp__title 11/800 (era ExtraBold 14 ao vivo; == ft.title)
  cell        = mono..", 10",           -- .tr/.connrow/.calday 10px (era 9)
  cell_bold   = mono..", Bold 10",      -- célula de taboa/lista com ênfase (era Bold 9)
  lozenge     = mono..", Bold 18",      -- control_center MONO (dockbar); ampliação de ~200%, ao vivo
  readout     = mono..", ExtraBold 20", -- MonitorBar valor grande (órfão: supersedido por mon_big=16)
  mon_micro   = mono..", Bold 8",       -- MonitorBar rodapé/micro (MICRO); spec do kit 9
  notif_title = mono..", ExtraBold 16", notif_body = mono..", Regular 12",

  -- ── Papéis NOVOS da fidelidade (verbatim colors_and_type.css / kit.css) ──
  ir_value    = mono..", ExtraBold 11", -- .ir__v 11/800 (o token value=12 é do lozango .seg__v)
  clock_hm    = mono..", ExtraBold 13", -- .loztail__hm 13/800 (relógio HH:MM da barra)
  ctx_item    = mono..", 11",           -- .ctx__item 11px, peso normal
  ctx_sig     = mono..", 10",           -- .ctx__sig 10px (linhas do submenu SEND SIGNAL)
  win_title   = mono..", Bold 10",      -- .win__title 10/700 (titular de janela)
  iconpick_lbl= mono..", Bold 7",       -- .iconpick rótulo 7px maiúsculo

  -- ── Papéis NOVOS da MonitorBar (kit .monmod__* / .monfoot__* / .monrail__*) ──
  mon_big        = mono..", ExtraBold 16", -- .monmod__bigv (supersede readout=20)
  mon_big_prefix = mono..", Bold 11",      -- .monmod__bigp (prefixo, ex.: '↓')
  mon_big_unit   = mono..", Bold 8",       -- .monmod__bigu (unidade, ex.: '%')
  mon_sub        = mono..", Bold 7",       -- .monmod__sub 7.5px (era Bold 9 ao vivo)
  mon_foot_k     = mono..", Bold 7",       -- .monfoot__k (chave do rodapé)
  mon_foot_v     = mono..", Bold 9",       -- .monfoot__v (valor do rodapé)
  mon_rail_hd    = mono..", ExtraBold 8",  -- .monrail__hd
  mon_rail_st    = mono..", ExtraBold 8",  -- .monrail__st (~8.5px)
  mon_rail_load  = mono..", ExtraBold 22", -- .monrail__loadv (carga agregada)
  mon_rail_loadu = mono..", Bold 11",      -- .monrail__loadv i (o signo '%')
  mon_strip_lbl  = mono..", ExtraBold 9",  -- .monbar__rec / rótulos da fita (9px)

  -- ── Papel da BUSCA do lançador (Xirod; excepção deliberada ao DS §4, a pedido
  --    expresso do usuário: o prompt "BUSCAR:" é peça de marca, não dado) ──────
  search = disp.." 10",

  -- ── Funcção `display` — a fonte de marca, ao serviço de Braga Us ─────────
  -- Propósito: compor a cadeia da fonte Xirod SÓMENTE para o wordmark e para os
  --   rótulos de marca da MonitorBar — nunca para dados (vide DS §4).
  -- Domínio: size, o corpo desejado da fonte (ou nil). Contra-domínio: a cadeia
  --   "Xirod <corpo>". Invariante: à falta de size, adopta-se por defeito o corpo
  --   15, que é o rótulo de módulo ao vivo. Assim o dispôs o eminente Braga Us.
  display = function(size) return disp.." "..tostring(size or 15) end,
}
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
