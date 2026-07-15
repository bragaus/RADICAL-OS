-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO DAS CÔRES — src/theme/palette.lua
-- ══════════════════════════════════════════════════════════════════════════
-- Seja dado o systema chromático denominado "SUNCORE HUD", derivado por
-- contemplação diligente da estampa do eidolon — a figura que fluctua ante o
-- sol vermelho de raios amarellos, cingida de halo pontilhado, com o núcleo
-- cyâneo a arder-lhe no peito — e transposto, com todo o rigor da sciência,
-- ao domínio do cyan eléctrico sobre o índigo nocturno. As côres ordenam-se
-- por luminosidade e opacidade, segundo a hierarchia que demonstrou o insigne
-- geómetra BRAGA US; o acento primário — invariante cardeal de toda esta obra —
-- é o token v500. Os matizes do poente (amarello, laranja, vermelho, magenta)
-- admittem-se SÓMENTE como acentos contidos: séries de dados, estados, família
-- do lançador e faixas do horizonte. Tal é o Postulado do Poente Contido.
-- Postulado da fórma: cada valor é uma cadeia de caracteres "#RRGGBB" ou,
-- admittindo-se o oitavo byte de opacidade, "#RRGGBBAA". Assim o quis o auctor.
return {
  -- Os fundos (os negros-índigos): substrato nocturno sobre o qual se ergue a HUD.
  void = "#000000", abyss = "#05041a", base = "#0a0824",
  inset = "#080619", panel = "#121036", panel_hi = "#1a1747", raised = "#241f5c",

  -- A rampa cyânea: escala monotónica de luminosidade, do claro ao profundo.
  v50  = "#ecfffb", v100 = "#cffdf4", v200 = "#9ff7e9", v300 = "#66efdb",
  v400 = "#2ee6cb", v500 = "#00d9c0", v600 = "#00b3a0", v700 = "#008f83",
  v800 = "#0a6e68", v900 = "#0c5252", v950 = "#073338", v975 = "#062a31",

  -- Néon e fulgor: as côres do halo luminoso, ditas na língua estrangeira "glow".
  -- O glow_core é o próprio lume dos olhos do eidolon; o glow_hot, magenta das
  -- montanhas, reserva-se aos picos e às urgências.
  glow_ice = "#d8fff8", glow_soft = "#7df5e2", glow_core = "#2ef2da", glow_hot = "#ff2fa0",

  -- O texto: hierarchia de legibilidade, que vai do brilhante ao desvanecido.
  text_bright = "#e6fffa", text_primary = "#b8f0e4", text_heading = "#7df5e2",
  text_body = "#85c2ba", text_muted = "#5b8a84", text_faint = "#365a56",
  text_disabled = "#23403c",

  -- Linhas, bordas e biséis: a geometria das arestas e do relevo apparente.
  -- O bevel_lo é a sombra verde-nocturna da própria silhueta da estampa.
  line_faint = "#241f5c", line_dim = "#155054", line_base = "#0a6e68",
  line_bright = "#00b3a0", bevel_hi = "#2ee6cb", bevel_lo = "#081420", grid = "#155054",

  -- Séries de dados: aos gráphicos e diagrammas concede-se o espectro inteiro
  -- do poente — cyan, amarello-sol, laranja, magenta, o violeta (memória do
  -- systema antigo) e o vermelho do quadro solar. Poente contido, note-se bem.
  data1 = "#2ef2da", data2 = "#ffd319", data3 = "#ff7a1a",
  data4 = "#ff2fa0", data5 = "#8a5cf6", data6 = "#ff3d3d",

  -- Os estados (subtis): os signaes de bom curso, de advertência e de crise —
  -- o verde da vegetação, o amarello do sol, o vermelho do seu quadro.
  ok = "#2ee6a8", warn = "#ffd319", crit = "#ff3948", info = "#00d9c0",

  -- ── ACCRÉSCIMOS (tokens da Phase-0; as 46 côres supra permanecem intactas) ──
  -- Sentinella de plena transparência (extremos de gradiente, caudas de véu,
  -- e o "preenchimento nullo"). Elle representa o vazio chromático.
  transparent = "#00000000",

  -- A família alaranjada do lançador (promovida de kit.css:311-315; outrora crua,
  -- dispersa no app_launcher — ora recolhida a este único domínio), recalibrada
  -- ao exacto laranja do céu poente da estampa do eidolon.
  launcher_ring    = "#b35414",
  launcher_ring_hi = "#ff7a1a",
  launcher_ring_on = "#ff9e2c",
  launcher_glow    = "#ff7a1a", -- base sobre a qual operam as receitas p.a(p.launcher_glow, x)

  -- Traço de UPLOAD (lima-neon) do MonGraph NET — o par do laranja data3
  -- (que serve de download). Escolhido com decidido viés verde p/ separar-se
  -- tanto do laranja quanto do amarello-sol data2, mesmo sob a mescla additiva
  -- "screen". Valor tunável de uma linha. — Braga Us.
  graph_up = "#d8ff2f",

  -- Receitas nomeadas de opacidade — extirpam a dispersão dos valores
  -- 0.06/0.20/0.22/0.5/0.7/0.8/0.92/0.95. Na presente lavra de fidelidade, o
  -- painel foi RECONDUZIDO à spec do kit (0.92, .hp bg = panel@92%); a fita
  -- permanece a 0.8 (.topbar bg = base@80%), tal como o dispôs o Doutor Braga Us.
  alpha = {
    panel = 0.92, panel_hi = 0.95, bar = 0.8, clock_bar = 0.85, dash = 0.9,
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
