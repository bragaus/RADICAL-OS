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

  -- Helper de alpha em runtime: a(hex, 0..1) -> "#RRGGBBAA"
  a = function(hex, alpha)
    return string.format("%s%02x", hex, math.floor((alpha or 1) * 255 + 0.5))
  end,
}
