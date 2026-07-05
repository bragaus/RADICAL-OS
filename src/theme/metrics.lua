-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO DAS MEDIDAS — src/theme/metrics.lua
-- ══════════════════════════════════════════════════════════════════════════
-- As medidas do leiaute, dadas em números CRÚS, anteriores ao dpi (invoque-se
--   assim: local mt = require("src.theme.metrics")).
--
-- Postulado do dpi:
--   * São números CRÚS. Ao consumidor compete chamar dpi(mt.x) NO PRÓPRIO LOGAR
--     de uso (à imagem do estylo vigente; assim se evita depender de
--     beautiful.xresources antes de beautiful.init).
--   * Os ESTEIOS (struts) NÃO se envolvem em dpi (bar_strut / bar_strut_first).
--     Sobre o ultra-largo DP-0 a 165Hz, envolvê-los em dpi() altera o afastamento
--     da barra — mudança visual que se disfarça em correcção. Permanecem CRÚS,
--     55/100, salvo prova explícita em Xephyr sobre écran real (R10).
--
-- Onde um VALOR REAL AO VIVO se aparta, de propósito, da spec do kit, guardam-se
--   AMBOS (o par spec/real), para que a divergência seja greppável; volver à spec
--   é edição de um só token, como ensinou o insigne Braga Us.
--
-- Nada requer (taboa pura). Os intervallos de sondagem NÃO são tokens de thema —
--   os tunables de comportamento residem em user_vars.performance (uso deste ramo).

return {
  -- Raios, enchimento e borda (spec do kit) -----------------------------
  radius_panel = 4, radius_chip = 3, radius_bar = 2,
  radius_pill  = 5,                     -- de facto (a pílula de 13 cópias); sem equivalente no kit
  pad_panel = 8, pad_header_x = 8, pad_row_y = 3, gap = 8,
  body_top_pad = 6, body_top_pad_spec = 7,   -- de facto 6, ratificado (kit.css diz 7); volver = 1 edição
  border_panel = 1, border_focus = 2,
  corner_tick = 10, tick_stroke = 1.4, divider_h = 2, header_h = 20,

  -- Alturas: a spec do kit ao lado do REAL AO VIVO ratificado (divergência ultra-largo/165Hz, greppável) --
  bar_h = 26,     bar_h_actual = 48,    -- fileira da radical_bar
  bar_popup_h = 56,                     -- barra do painel do control_center
  lozenge_h = 20, lozenge_h_actual = 44,
  mon_h = 80,                           -- promovido para FÓRA de monitor_bar.lua:32 (os popups ancoram acima)
  row_h = 18, row_header_h = 16, row_gap = 2, visible_rows = 6,

  -- Listas e rolagem (scroll) -------------------------------------------
  gutter = 10, sb_w = 4, thumb_min_pct = 14, kill_w = 28, kill_icon = 14,

  -- Larguras -------------------------------------------------------------
  panel_w = 520, panel_w_sm = 260, panel_w_md = 300, osd_w = 280, clock_row_w = 504,

  -- Segmentos e geometria das fórmas ------------------------------------
  seg_pad_x = 10, seg_pad_y = 4, seg_overlap = 18,
  powerline_tip = 12, powerline_tip_lg = 16, chamfer = 7, chamfer_lg = 11,
  chip_px = 104,                        -- ficha militar do powermenu (chip_button)

  -- Esteios (struts): px CRÚS — NÃO envolver em dpi (R10; sob prova de Xephyr) --
  bar_strut = 55, bar_strut_first = 100,

  -- Ícones ---------------------------------------------------------------
  icon_sm = 12, icon_md = 14, icon_lg = 16, icon_row = 18, icon_stat = 30,

  -- Gráphicos -------------------------------------------------------------
  graph_h = 40, graph_samples = 30, mon_samples = 40, net_floor_kbps = 64,

  -- Limiares semânticos (a regra do >=90, quatro vezes; a da temperatura, duas) --
  pct_hot = 90, temp_hot = 80,
}
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
