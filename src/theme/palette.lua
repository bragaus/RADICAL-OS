-- src/theme/palette.lua
-- Paleta "VIOLET HUD" derivada da referência azul (traduzida para roxo).
-- Hierarquia por luminosidade + opacidade. Acento primário = v500.
-- Formato AwesomeWM: "#RRGGBB" ou "#RRGGBBAA" (alpha de 8 dígitos).
return {
  -- BACKGROUNDS (violet-blacks)
  void = "#000000", abyss = "#070310", base = "#0c0617",
  inset = "#0a0514", panel = "#130a24", panel_hi = "#1b1030", raised = "#241640",

  -- RAMPA VIOLETA
  v50  = "#f4effe", v100 = "#e7dafd", v200 = "#cbb2fb", v300 = "#b491f9",
  v400 = "#9d6ff6", v500 = "#8b5cf6", v600 = "#7c3aed", v700 = "#6d28d9",
  v800 = "#5b21b6", v900 = "#4c1d95", v950 = "#2e1065", v975 = "#2b0c45",

  -- NEON / GLOW
  glow_ice = "#d6c2ff", glow_soft = "#b794ff", glow_core = "#a855f7", glow_hot = "#c026d3",

  -- TEXTO
  text_bright = "#e9dcff", text_primary = "#cbb6ff", text_heading = "#b794ff",
  text_body = "#9a82c4", text_muted = "#6f5a96", text_faint = "#463566",
  text_disabled = "#2f2348",

  -- LINHAS / BORDAS / BEVEL
  line_faint = "#241640", line_dim = "#3a1f63", line_base = "#5b21b6",
  line_bright = "#7c3aed", bevel_hi = "#9d6ff6", bevel_lo = "#160c28", grid = "#3a1f63",

  -- SÉRIES DE DADOS
  data1 = "#a855f7", data2 = "#c084fc", data3 = "#7c3aed",
  data4 = "#d946ef", data5 = "#8b5cf6", data6 = "#6d28d9",

  -- STATUS (sutis)
  ok = "#5ad1a0", warn = "#f0c44c", crit = "#fb5e8a", info = "#8b5cf6",

  -- ── ADDITIONS (Stage-0 tokens; the 46 colors above are unchanged) ──────────
  -- Full-transparent sentinel (gradient stops, scrim tails, "no fill").
  transparent = "#00000000",

  -- Launcher orange family (promoted from kit.css:311-315; was raw in app_launcher).
  launcher_ring    = "#b3561a",
  launcher_ring_hi = "#ff8c2a",
  launcher_ring_on = "#ff9a3a",
  launcher_glow    = "#ff7a18", -- base for p.a(p.launcher_glow, x) recipes

  -- Named alpha recipes — kills the 0.06/0.20/0.22/0.5/0.7/0.8/0.85/0.9/0.95
  -- scatter. De-facto values are RATIFIED TO CURRENT (0.9 panel, not the kit's
  -- 0.92, etc.) — zero visual churn is the Stage-0 invariant.
  alpha = {
    panel = 0.9, panel_hi = 0.95, bar = 0.8, clock_bar = 0.85, dash = 0.9,
    chip_bg = 0.06, chip_border = 0.20,
    divider_tail = 0.22, bevel_hi = 0.7, bevel_lo = 0.9, tick = 0.9,
    rail = 0.5, graph_area = 0.22, graph_halo = 0.18, well = 0.96, well_border = 0.22,
    segment = 0.90, tab = 0.88, hover_delta = 0.08, overlay = 0.55, scrim = 0.7,
  },

  -- Helper de alpha em runtime: a(hex, 0..1) -> "#RRGGBBAA"
  -- HARDENED (adopts colors.with_alpha semantics): strips an existing 8-digit
  -- alpha byte before appending (so p.a("#RRGGBBAA", x) no longer produces a
  -- 10-digit garbage string) and clamps alpha to [0,1].
  a = function(hex, alpha)
    if #hex == 9 then hex = hex:sub(1, 7) end
    alpha = math.max(0, math.min(1, alpha or 1))
    return string.format("%s%02x", hex, math.floor(alpha * 255 + 0.5))
  end,

  -- rgb(hex) -> r, g, b as three 0..1 floats for cairo (set_source_rgb / _rgba).
  -- Replaces the duplicated hex_rgb at net_graph_panel:30 + monitor_bar:45.
  -- Tolerates a leading '#' and an 8-digit alpha byte (only RGB is returned).
  rgb = function(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    return r / 255, g / 255, b / 255
  end,
}
