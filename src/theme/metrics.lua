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
  gutter = 10, sb_w = 4, thumb_min_pct = 14, kill_w = 26, kill_icon = 14,   -- kill_w 28->26 (kit .killbtn)

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

  -- ══ ACCRÉSCIMOS DA FIDELIDADE (px CRÚS verbatim do kit; consumam-se via dpi) ══
  -- Os tokens que se seguem transpõem, medida a medida, o kit.css para a lavra do
  --   redesenho pixel-fiel. Os *_actual supra permanecem por ora (os consumidores
  --   ainda os invocam); ao termo da migração, órfãos, serão dados por extirpados.

  -- Etiquetas da barra superior (kit .tags / .tag) ----------------------
  tag_h = 24, tag_pad_l = 18, tag_pad_r = 20, tag_icon = 13,

  -- Concha dos controles de aba (kit .tagctl / .tagctl__*) --------------
  tagctl_h = 24, tagctl_pad_l = 31, tagctl_pad_r = 13, tagctl_gap = 5,
  tagctl_edge = 1, tagctl_tuck = 22, tagctl_btn_w = 22, tagctl_btn_h = 14,
  tagctl_btn_chamfer = 3, haz_w = 7, haz_h = 14, haz_band = 2,

  -- Fita de lozangos (kit .seg / .lozstrip = 24px; NÃO o token stale lozenge_h=20) --
  seg_h = 24, seg_pad_l = 22, seg_pad_l_first = 26, seg_pad_r = 18, seg_gap = 5,

  -- Dock inferior de telemetria (kit .monitorbar / .monbar__* / .monmod__*) --
  mon_strip_h = 17, mon_row_pad_x = 8, mon_row_pad_t = 3, mon_row_pad_b = 4,
  mon_overlap = 16, mon_edge = 1.6, mon_rail_w = 152, mon_strip_pad_x = 13,
  mon_haz_w = 40, mon_haz_h = 8,

  -- Menus, lançador, titulares e janelas (kit .ctx / .iconpick / .launcher / .win) --
  ctx_w = 208, ctx_w_sub = 150, ctx_band_h = 26, sig_row_h = 18,
  iconpick_tile = 20, iconpick_pad = 8, iconpick_gap = 4,
  launcher_orbit_r = 168, launcher_app_r = 27, launcher_app_focus_r = 35,
  launcher_edge = 18, win_btn = 9,
  -- Barra de busca do lançador: base COLADA no topo da monitorbar, cauda SOBE e crava no hub.
  -- A ALTURA não é token — deriva-se (centro-do-hub → topo-da-monitorbar), pinando os dois
  -- extremos por construção (vide app_launcher SEARCH_POPUP_H). Largura = search_w_pct% da tela. --
  search_w_pct = 15, search_body_h = 24, search_tail = 64,

  -- Espaçamento de célula das taboas (kit gap:6px) e larguras exactas dos painéis --
  cell_gap = 6,
  panel_w_236 = 236, panel_w_264 = 264, panel_w_300 = 300, panel_w_252 = 252,
}
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
