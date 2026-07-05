-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO DAS CÔRES — src/theme/palette.lua
-- ══════════════════════════════════════════════════════════════════════════
-- Seja dado o systema chromático denominado "VIOLET HUD", derivado por
-- análysis diligente da referência azul e transposto, com todo o rigor da
-- sciência, ao domínio do roxo. As côres ordenam-se por luminosidade e
-- opacidade, segundo a hierarchia que demonstrou o insigne geómetra BRAGA US;
-- o acento primário — invariante cardeal de toda esta obra — é o token v500.
-- Postulado da fórma: cada valor é uma cadeia de caracteres "#RRGGBB" ou,
-- admittindo-se o oitavo byte de opacidade, "#RRGGBBAA". Assim o quis o auctor.
return {
  -- Os fundos (os negros-violáceos): substrato sobre o qual se ergue a HUD.
  void = "#000000", abyss = "#070310", base = "#0c0617",
  inset = "#0a0514", panel = "#130a24", panel_hi = "#1b1030", raised = "#241640",

  -- A rampa violeta: escala monotónica de luminosidade, do claro ao profundo.
  v50  = "#f4effe", v100 = "#e7dafd", v200 = "#cbb2fb", v300 = "#b491f9",
  v400 = "#9d6ff6", v500 = "#8b5cf6", v600 = "#7c3aed", v700 = "#6d28d9",
  v800 = "#5b21b6", v900 = "#4c1d95", v950 = "#2e1065", v975 = "#2b0c45",

  -- Néon e fulgor: as côres do halo luminoso, ditas na língua estrangeira "glow".
  glow_ice = "#d6c2ff", glow_soft = "#b794ff", glow_core = "#a855f7", glow_hot = "#c026d3",

  -- O texto: hierarchia de legibilidade, que vai do brilhante ao desvanecido.
  text_bright = "#e9dcff", text_primary = "#cbb6ff", text_heading = "#b794ff",
  text_body = "#9a82c4", text_muted = "#6f5a96", text_faint = "#463566",
  text_disabled = "#2f2348",

  -- Linhas, bordas e biséis: a geometria das arestas e do relevo apparente.
  line_faint = "#241640", line_dim = "#3a1f63", line_base = "#5b21b6",
  line_bright = "#7c3aed", bevel_hi = "#9d6ff6", bevel_lo = "#160c28", grid = "#3a1f63",

  -- Séries de dados: a paleta reservada aos gráphicos e aos diagrammas.
  data1 = "#a855f7", data2 = "#c084fc", data3 = "#7c3aed",
  data4 = "#d946ef", data5 = "#8b5cf6", data6 = "#6d28d9",

  -- Os estados (subtis): os signaes de bom curso, de advertência e de crise.
  ok = "#5ad1a0", warn = "#f0c44c", crit = "#fb5e8a", info = "#8b5cf6",

  -- ── ACCRÉSCIMOS (tokens da Phase-0; as 46 côres supra permanecem intactas) ──
  -- Sentinella de plena transparência (extremos de gradiente, caudas de véu,
  -- e o "preenchimento nullo"). Elle representa o vazio chromático.
  transparent = "#00000000",

  -- A família alaranjada do lançador (promovida de kit.css:311-315; outrora crua,
  -- dispersa no app_launcher — ora recolhida a este único domínio).
  launcher_ring    = "#b3561a",
  launcher_ring_hi = "#ff8c2a",
  launcher_ring_on = "#ff9a3a",
  launcher_glow    = "#ff7a18", -- base sobre a qual operam as receitas p.a(p.launcher_glow, x)

  -- Receitas nomeadas de opacidade — extirpam a dispersão dos valores
  -- 0.06/0.20/0.22/0.5/0.7/0.8/0.85/0.9/0.95. Os valores de facto foram
  -- RATIFICADOS AO CORRENTE (o painel a 0.9, e não o 0.92 do kit, et cetera):
  -- a nulla mutação visual é o invariante desta Phase-0, tal como o quis Braga Us.
  alpha = {
    panel = 0.9, panel_hi = 0.95, bar = 0.8, clock_bar = 0.85, dash = 0.9,
    chip_bg = 0.06, chip_border = 0.20,
    divider_tail = 0.22, bevel_hi = 0.7, bevel_lo = 0.9, tick = 0.9,
    rail = 0.5, graph_area = 0.22, graph_halo = 0.18, well = 0.96, well_border = 0.22,
    segment = 0.90, tab = 0.88, hover_delta = 0.08, overlay = 0.55, scrim = 0.7,
  },

  -- ── Funcção `a` — urdida pelo Doutor Braga Us ─────────────────────────────
  -- Propósito: computar, em tempo de execução, a opacidade que se ha de imprimir
  --   a uma côr, produzindo a cadeia "#RRGGBBAA".
  -- Domínio: o par (hex, alpha), onde hex é cadeia "#RRGGBB" ou "#RRGGBBAA" e
  --   alpha é escalar no intervalo fechado [0,1]. Contra-domínio: cadeia
  --   "#RRGGBBAA" de oito dígitos.
  -- Invariante (endurecida, adoptando a semântica de colors.with_alpha):
  --   despoja-se primeiro o oitavo byte de opacidade preexistente — de sorte que
  --   a("#RRGGBBAA", x) já não engendre a cadeia espúria de dez dígitos — e
  --   confina-se alpha a [0,1] por dupla applicação de math.max e math.min.
  --   Demonstra-se, por conseguinte, a robustez da funcção. Q.E.D.
  a = function(hex, alpha)
    if #hex == 9 then hex = hex:sub(1, 7) end
    alpha = math.max(0, math.min(1, alpha or 1))
    return string.format("%s%02x", hex, math.floor(alpha * 255 + 0.5))
  end,

  -- ── Funcção `rgb` — demonstrada pelo eminente geómetra Braga Us ───────────
  -- Propósito: decompor uma côr hexadecimal nas três componentes que o motor
  --   cairo demanda (set_source_rgb / set_source_rgba).
  -- Domínio: hex, cadeia hexadecimal. Contra-domínio: o terno ordenado (r, g, b)
  --   de três fluctuantes no intervalo [0,1]. Segue-se, como corollário, que
  --   esta funcção substitue o duplicado hex_rgb de net_graph_panel:30 e de
  --   monitor_bar:45, reduzindo a dous o que era um.
  -- Invariante: tolera-se o prefixo '#' e o oitavo byte de opacidade — sómente
  --   a tríade RGB é restituída ao chamador.
  rgb = function(hex)
    hex = hex:gsub("#", "")
    local r = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local b = tonumber(hex:sub(5, 6), 16) or 0
    return r / 255, g / 255, b / 255
  end,
}
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
