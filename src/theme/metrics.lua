-- src/theme/metrics.lua
-- Layout metrics as RAW pre-dpi numbers (require as:
--   local mt = require("src.theme.metrics")).
--
-- dpi policy:
--   * These are RAW numbers. Consumers call dpi(mt.x) AT THE USE-SITE
--     (matches existing style; avoids needing beautiful.xresources before
--     beautiful.init).
--   * STRUTS are NOT dpi-wrapped (bar_strut / bar_strut_first). On the 165Hz
--     DP-0 ultrawide, dpi()-wrapping them changes bar clearance — a visual
--     change masquerading as a bugfix. They stay RAW 55/100 unless gated
--     behind explicit Xephyr-on-real-display proof (R10).
--
-- Where a de-facto LIVE ACTUAL diverges from the kit spec deliberately, BOTH
-- are stored (paired spec/actual) so the divergence is greppable; flipping to
-- spec is a one-token edit.
--
-- Requires nothing (pure table). Poll intervals are NOT theme tokens — behavior
-- tunables stay in user_vars.performance (this branch's convention).

return {
  -- radii / pad / border (kit spec) --------------------------------------
  radius_panel = 4, radius_chip = 3, radius_bar = 2,
  radius_pill  = 5,                     -- de-facto (13-copy pill); no kit equivalent
  pad_panel = 8, pad_header_x = 8, pad_row_y = 3, gap = 8,
  body_top_pad = 6, body_top_pad_spec = 7,   -- de-facto 6 ratified (kit.css says 7); flip = 1 edit
  border_panel = 1, border_focus = 2,
  corner_tick = 10, tick_stroke = 1.4, divider_h = 2, header_h = 20,

  -- heights: KIT SPEC alongside RATIFIED LIVE ACTUAL (greppable ultrawide/165Hz divergence) --
  bar_h = 26,     bar_h_actual = 48,    -- radical_bar row
  bar_popup_h = 56,                     -- control_center dashboard bar
  lozenge_h = 20, lozenge_h_actual = 44,
  mon_h = 80,                           -- promoted OUT of monitor_bar.lua:32 (popups anchor above it)
  row_h = 18, row_header_h = 16, row_gap = 2, visible_rows = 6,

  -- lists / scroll -------------------------------------------------------
  gutter = 10, sb_w = 4, thumb_min_pct = 14, kill_w = 28, kill_icon = 14,

  -- widths ---------------------------------------------------------------
  panel_w = 520, panel_w_sm = 260, panel_w_md = 300, osd_w = 280, clock_row_w = 504,

  -- segments / shape geometry -------------------------------------------
  seg_pad_x = 10, seg_pad_y = 4, seg_overlap = 18,
  powerline_tip = 12, powerline_tip_lg = 16, chamfer = 7, chamfer_lg = 11,
  chip_px = 104,                        -- military powermenu chip (chip_button)

  -- struts: RAW px — do NOT dpi-wrap (R10; Xephyr-gated) -----------------
  bar_strut = 55, bar_strut_first = 100,

  -- icons ----------------------------------------------------------------
  icon_sm = 12, icon_md = 14, icon_lg = 16, icon_row = 18, icon_stat = 30,

  -- graphs ---------------------------------------------------------------
  graph_h = 40, graph_samples = 30, mon_samples = 40, net_floor_kbps = 64,

  -- semantic thresholds (the >=90 rule x4, temp rule x2) -----------------
  pct_hot = 90, temp_hot = 80,
}
