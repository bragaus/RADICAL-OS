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

  -- ── Papéis DE FACTO: por defeito = a cadeia ao vivo; a spec do kit anotada p/ futura "ratificação" ──
  panel_title = uf.extrabold or (mono..", ExtraBold 14"), -- AO VIVO ExtraBold 14 (panel.lua:49); spec do kit 11
  cell        = mono..", 9",            -- células de taboa/lista (usage/process/connections/ip/calendar); kit 10
  cell_bold   = mono..", Bold 9",       -- célula de taboa/lista com ênfase; kit 10
  lozenge     = mono..", Bold 18",      -- control_center MONO (dockbar); ampliação de ~200%, ao vivo
  readout     = mono..", ExtraBold 20", -- MonitorBar valor grande (monitor_bar READOUT); spec do kit 16
  mon_sub     = mono..", Bold 9",       -- MonitorBar sub-rótulo (SUB), ao vivo
  mon_micro   = mono..", Bold 8",       -- MonitorBar rodapé/micro (MICRO); spec do kit 9
  notif_title = mono..", ExtraBold 16", notif_body = mono..", Regular 12",

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
