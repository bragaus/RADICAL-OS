-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE A MONITORBAR — DOCA DE TELEMETRIA INFERIOR (VIOLET HUD §7.3.1)
--   src/organisms/monitor_bar.lua
--
--   Seja dada a tela primária: no seu rodapé instale-se esta barra FIXA e
--   sempre patente, que coexiste com a barra superior e com os dashboards de
--   clique — e a nenhum delles substitue. Espelha, ora com fidelidade pixel a
--   pixel, o `MonitorBar` do toolkit (.monitorbar / monitorbar.jsx). A sua
--   TOPOLOGIA é de COLUNA (não mais uma fila única): uma fita horizontal rasa
--   (17px) que corre por toda a largura POR CIMA da fileira de módulos, e esta
--   a preencher o restante da altura canónica:
--
--     ┌──────────────────────────────────────────────────────────────┐
--     │  ● REC · LIVE TELEMETRY // SYSMON   ▨      0xhex  NODE: ONLINE │  <- strip 17px
--     ├──────────────────────────────────────────────────────────────┤
--     │ ⟨ GPU ⟩⟨ CPU ⟩⟨ MEM ⟩⟨ NET ⟩            ⟨ MONRAIL 152px ⟩      │  <- fila
--     └──────────────────────────────────────────────────────────────┘
--
--   NOTA DE ARCHITECTURA: este manuscripto é o organismo `monitor_bar`; os
--   edificadores locaes `make_module` (molécula `mon_module`) e `make_rail`
--   (organismo `mon_rail`) seguem o estylo dos builders-internos de
--   control_center.lua e net_graph_panel.lua — e PERMANECEM internos a este
--   arquivo, não sendo promovidos a módulos próprios.
--
--   Cada MonModule = um chevron powerline INTERLIGADO (aresta em gradiente +
--   miolo escuro) sobre um gráphico de área (line_graph, grelha+halo+mescla
--   "screen") + rótulo de marca em `Xirod` + sub-rótulo com ícone + leitura
--   grande de três peças (prefixo/valor/unidade) + quatro células de rodapé.
--   O 1º módulo abre a fita (vértice convexo); os demais encaixam a concha
--   côncava na ponta do anterior (sobreposição negativa de 16px). O MonRail é
--   a cauda que fecha a fita (socket_tail): NODE//STATUS + VOLUME + LOAD.
--
--   POSTULADO DA ASSYNCRONIA: a amostragem é SEMPRE assíncrona (um só
--   gears.timer que invoca awful.spawn.easy_async_with_shell); JÁMAIS
--   io.popen/os.execute/sync, que enregelam o gerente de janellas (deadlock
--   já conhecido neste repositório). Todo o parse de stdout passa por
--   tonumber() e por guarda de nil. Fontes inexistentes (nvidia-smi,
--   sensores) recahem em "--" sem quebra. O `Xirod`, se não instalado,
--   degrada com graça para a fonte padrão. Este relógio de 1s é PERMANENTE
--   (não é das oito superfícies "gated" do control_center) — não toca em
--   set_group_sampling.
--
--   Manuscripto da lavra do Doutor Braga Us, Geómetra desta Casa.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local ft    = require("src.theme.typography")
local mt    = require("src.theme.metrics")
local shapes     = require("src.tools.shapes")
local format     = require("src.tools.format")
local line_graph = require("src.molecules.line_graph")
local Icon  = require("src.tools.icons") -- glyphos SVG colhidos do conjuncto icons/ (§3.13)

local MON_H    = dpi(mt.mon_h)         -- altura canónica, do symbolo --mon-h (§7.3.1)
local SAMPLES  = mt.mon_samples        -- profundidade do histórico de cada série
local INTERVAL = 1                     -- segundos que medeiam entre duas amostras (gráfico vivo)

-- O ESPECTRO DO POENTE (SUNCORE, edição violeta): a cada módulo, o SEU matiz —
-- CPU o violeta soberano (glow_core), GPU o magenta das montanhas
-- (data4), MEM o amarello-sol (data2), NET o laranja do céu (data3). GPU/CPU/MEM
-- traçam UMA só série — a métrica REAL primária (uso%) — sem as accessórias
-- (temp/swap) que d'antes toldavam o grapho. EXCEPÇÃO deliberada: o NET traça
-- DUAS séries sobrepostas — download (laranja MOD_ACCENT.net) e upload
-- (lima-neon MOD_ACCENT.net_up) — na MESMA escala partilhada, com mescla
-- aditiva "screen" (o cruzamento acende em néon). O gradient_fill do line_graph
-- produz o degradê pedido: opaco junto á linha, diáphano no fundo. — Braga Us.
local MOD_ACCENT = {
  gpu    = p.data4,     -- magenta das montanhas
  cpu    = p.glow_core, -- violeta soberano (o accento da casa)
  mem    = p.data2,     -- amarello-sol
  net    = p.data3,     -- laranja do céu (download)
  net_up = p.graph_up,  -- lima-neon (upload), par do laranja sob o "screen"
}

-- IDENTIFICADOR HEXADECIMAL do nó, cunhado uma só vez no carregamento (os.time
-- é de custo ínfimo e não bloqueia o systema).
local NODE_ID = string.format("0x%04X", os.time() % 0x10000)

-- ── LEMMA zeros ───────────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que produz um arranjo de N zeros — o
-- histórico inicial de uma série, isento de degrau.
--   DOMÍNIO........: n — a cardinalidade desejada do arranjo.
--   CONTRA-DOMÍNIO.: uma taboa {0, 0, …, 0} de exactamente n elementos.
--   INVARIANTE.....: funcção pura; a cardinalidade do producto iguala n. Q.E.D.
local function zeros(n)
  local t = {}
  for i = 1, n do t[i] = 0 end
  return t
end

-- ── LEMMA fmt_gib ─────────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us para a conversão de octetos á escala dos
-- gibibytes, em fórma abreviada (v.g. "1.2G").
--   DOMÍNIO........: bytes — a grandeza em octetos (número, ou coisa nenhuma).
--   CONTRA-DOMÍNIO.: cadeia textual com uma casa decimal seguida do symbolo G.
--   INVARIANTE.....: argumento não-numérico é tomado por zero (guarda de nil).
local function fmt_gib(bytes)
  return string.format("%.1fG", (tonumber(bytes) or 0) / 1073741824)
end

-- ── LEMMA make_cell ───────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que edifica uma célula de rodapé. Ao
-- contrário do arranjo antigo (chave EMPILHADA sobre o valor), o kit dispõe
-- .monfoot como par HORIZONTAL na mesma linha: a chave (7px esmaecida) á
-- esquerda, o valor (9px do corpo) á dextra, separados de 4px.
--   DOMÍNIO........: key — o rótulo fixo da célula.
--   CONTRA-DOMÍNIO.: dois productos — o widget da célula e o textbox do valor,
--                    devolvido este último para que o chamador o possa mutar.
--   EFFEITOS.......: nenhum estado global; sómente compõe widgets.
local function make_cell(key)
  local val = wibox.widget {
    text = "--", font = ft.mon_foot_v, valign = "center", widget = wibox.widget.textbox,
  }
  local w = wibox.widget {
    {
      { text = key, font = ft.mon_foot_k, valign = "center", widget = wibox.widget.textbox },
      fg = p.text_faint, widget = wibox.container.background,
    },
    { val, fg = p.text_body, widget = wibox.container.background },
    spacing = dpi(4),
    layout  = wibox.layout.fixed.horizontal,
  }
  return w, val
end

-- ══════════════════════════════════════════════════════════════════════════
-- LEMMA MAIOR make_module — o edificador de um MonModule (a molécula do painel).
-- Como demonstrou o insigne geómetra Braga Us, esta funcção compõe um módulo
-- completo de telemetria (.monmod) a partir da sua configuração.
--   DOMÍNIO........: s (a tela, para o clique preguiçoso) e cfg = { label, lbl,
--                    sub, icon, colors={frente,...,trás}, group, fixed100, first,
--                    cells={k1,k2,k3,k4} } — os attributos que o particularizam.
--   CONTRA-DOMÍNIO.: taboa { widget, push, set_big, set_cells, set_cell } — o
--                    widget e os punhos que o chamador manobra.
--   NOTA GEOMÉTRICA: duas camadas empilhadas por aninhamento — a ARESTA exterior
--                    (gradiente glow_soft->v700) recortada ao chevron powerline,
--                    e, inset de 1.6px, o MIOLO (gradiente v950->abyss) que
--                    encerra o gráphico, o véu de escurecimento e o overlay de
--                    texto. As séries dispõem-se {trás->frente}, e push(i,v)
--                    alimenta a i-ésima cor do manifesto (1 = accento, na frente).
--   NOTA DE CLIQUE.: onOpen do kit — o clique abre o dashboard do grupo, lido
--                    de s.dashboard_toggle PREGUIÇOSAMENTE (o control_center o
--                    exporta antes; se ainda ausente, o clique é inócuo).
-- ══════════════════════════════════════════════════════════════════════════
local function make_module(s, cfg)
  -- séries do grapho, na ordem de DESENHO (trás -> frente): a última cor do
  -- manifesto pinta-se ao fundo; a primeira (o accento) sobrepõe-se por cima.
  local ncolors = #cfg.colors
  local sdefs = {}
  for i = 1, ncolors do
    sdefs[i] = { color = cfg.colors[ncolors - i + 1], data = zeros(SAMPLES) }
  end
  local graph = line_graph({
    series        = sdefs,
    fill          = true,
    gradient_fill = true,   -- degradê vertical laranja: opaco junto à linha -> diáphano no fundo
    fixed100      = cfg.fixed100,
    blend         = cfg.blend, -- nil na maioria; "screen" só no NET (mescla aditiva das 2 séries)
    grid          = true,   -- grelha faint (kit MonGraph)
    halo          = true,   -- halo do traço (kit MonGraph)
    well          = false,
  })

  -- o véu de escurecimento (.monmod__bg::after): gradiente vertical de abyss, do
  -- topo tênue ao fundo mais denso — dá legibilidade ao texto sobreposto.
  local darken = wibox.widget.base.make_widget()
  function darken:fit(_, w, h) return w, h end
  function darken:draw(_, cr, w, h)
    -- Véu MUITO mais tênue que d'antes (0.22->0.72 apagava a parte baixa do grapho, donde
    -- este parecia "cortado" à esquerda). Agora quasi-diáphano no topo, ténue no fundo: o
    -- grapho laranja lê-se de borda a borda, e o texto (brilhante) continua legível. — Braga Us.
    cr:set_source(gears.color({
      type = "linear", from = { 0, 0 }, to = { 0, h },
      stops = { { 0, p.transparent }, { 0.55, p.a(p.abyss, 0.10) }, { 1, p.a(p.abyss, 0.38) } },
    }))
    cr:rectangle(0, 0, w, h); cr:fill()
  end

  -- ── bloco identificador (rótulo de marca Xirod + sub-rótulo com ícone) ──
  -- refs directas aos textboxes internos (para os rótulos dynâmicos do hardware real).
  local label_inner = wibox.widget { text = cfg.label, font = ft.display(cfg.lbl), valign = "top", widget = wibox.widget.textbox }
  local sub_inner   = wibox.widget { text = cfg.sub, font = ft.mon_sub, valign = "center", widget = wibox.widget.textbox }
  local label_tb = wibox.widget { label_inner, fg = p.text_bright, widget = wibox.container.background }
  local sub_tb = wibox.widget {
    { Icon(cfg.icon, { size = dpi(9), color = p.text_muted }), valign = "center", widget = wibox.container.place },
    { sub_inner, fg = p.text_muted, widget = wibox.container.background },
    spacing = dpi(4),
    layout  = wibox.layout.fixed.horizontal,
  }
  local id_block = wibox.widget {
    label_tb, sub_tb,
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }

  -- ── leitura grande em três peças (prefixo / valor / unidade) ──
  local bigp    = wibox.widget { text = "",   font = ft.mon_big_prefix, valign = "center", widget = wibox.widget.textbox }
  local bigv    = wibox.widget { text = "--", font = ft.mon_big,        valign = "center", widget = wibox.widget.textbox }
  local bigu    = wibox.widget { text = "",   font = ft.mon_big_unit,   valign = "center", widget = wibox.widget.textbox }
  local bigv_bg = wibox.widget { bigv, fg = p.text_bright, widget = wibox.container.background }
  local big = wibox.widget {
    { bigp, fg = p.text_muted, widget = wibox.container.background },
    bigv_bg,
    { bigu, fg = p.text_muted, widget = wibox.container.background },
    spacing = dpi(2),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- HEAD (.monmod__head): id á esquerda | leitura grande á dextra.
  local head = wibox.widget {
    { id_block, valign = "top", widget = wibox.container.place },
    nil,
    { big, valign = "top", halign = "right", widget = wibox.container.place },
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  -- ── as quatro células do rodapé (.monmod__foot: flex, gap 12) ──
  local cells, cell_widgets = {}, {}
  for i = 1, 4 do
    local cw, cv = make_cell(cfg.cells[i] or "")
    cell_widgets[i] = cw
    cells[i]        = cv
  end
  local footer = wibox.widget {
    cell_widgets[1], cell_widgets[2], cell_widgets[3], cell_widgets[4],
    spacing = dpi(12),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- OVERLAY (.monmod__overlay): coluna com HEAD no topo e FOOTER no fundo.
  local overlay = wibox.widget {
    {
      head, nil, footer,
      expand = "inside",
      layout = wibox.layout.align.vertical,
    },
    top = dpi(4), bottom = dpi(4), right = dpi(20),
    left = cfg.first and dpi(26) or dpi(24),
    widget = wibox.container.margin,
  }

  -- a fórma do chevron: o 1º módulo abre convexo; os demais recebem a concha.
  local shape_fn = cfg.first
    and shapes.powerline({ tip = dpi(mt.powerline_tip_lg), flat_left = false })
    or  shapes.powerline({ tip = dpi(mt.powerline_tip_lg), socket = true })

  -- MIOLO (.monmod__inner): gradiente v950->abyss, encerra grapho+véu+overlay.
  local inner = wibox.widget {
    {
      graph, darken, overlay,
      layout = wibox.layout.stack,
    },
    bg      = p.transparent,
    shape   = shape_fn,
    bgimage = function(_, cr, w, h)
      cr:set_source(gears.color({
        type = "linear", from = { 0, 0 }, to = { 0, h },
        stops = { { 0, p.a(p.v950, 0.94) }, { 1, p.a(p.abyss, 0.97) } },
      }))
      cr:rectangle(0, 0, w, h); cr:fill()
    end,
    widget = wibox.container.background,
  }

  -- ARESTA (.monmod__edge): gradiente glow_soft->v700; o miolo, inset de 1.6px,
  -- deixa transparecer 1.6px de orla — a "seta" que o kit desenha.
  local frame = wibox.widget {
    { inner, margins = dpi(mt.mon_edge), widget = wibox.container.margin },
    bg      = p.transparent,
    shape   = shape_fn,
    bgimage = function(_, cr, w, h)
      cr:set_source(gears.color({
        type = "linear", from = { 0, 0 }, to = { 0, h },
        stops = { { 0, p.a(p.glow_soft, 0.8) }, { 1, p.a(p.v700, 0.8) } },
      }))
      cr:rectangle(0, 0, w, h); cr:fill()
    end,
    widget = wibox.container.background,
  }

  -- CLIQUE (onOpen): abre o dashboard do grupo, lido preguiçosamente em runtime.
  frame:buttons(gears.table.join(
    awful.button({}, 1, function()
      if s.dashboard_toggle then s.dashboard_toggle(cfg.group) end
    end)
  ))
  Hover_signal(frame, nil, p.glow_ice) -- cursor de mão + realce (à feição de make_clickable)

  return {
    widget = frame,
    -- push(i, v): alimenta a i-ésima cor do manifesto (1 = accento, na frente).
    push = function(i, v) graph:push(ncolors - i + 1, v) end,
    -- set_big(prefix, value, unit, alert): as três peças; o valor cora de glow_hot
    -- ao ultrapassar o limiar pct_hot (>=90), do contrário fica brilhante.
    set_big = function(prefix, value, unit, alert)
      bigp:set_text(prefix or "")
      bigv:set_text(value or "--")
      bigu:set_text(unit or "")
      bigv_bg.fg = (alert and alert >= mt.pct_hot) and p.glow_hot or p.text_bright
    end,
    -- set_cells(vals): povoa as quatro células; entrada nil deixa a célula intacta
    -- (permitte que dois callbacks assíncronos partilhem o rodapé sem se atropelarem).
    set_cells = function(vals)
      for i = 1, 4 do if vals[i] ~= nil then cells[i]:set_text(vals[i]) end end
    end,
    -- set_cell(i, text): muta uma única célula (o valor nulo recahe em "--").
    set_cell = function(i, text)
      if cells[i] then cells[i]:set_text(text or "--") end
    end,
    -- set_label / set_sub: rótulos dynâmicos do hardware real (marca em Xirod / sub-rótulo).
    set_label = function(text) if text and text ~= "" then label_inner:set_text(text) end end,
    set_sub   = function(text) if text and text ~= "" then sub_inner:set_text(text) end end,
  }
end

-- ── LEMMA make_strip ──────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que ergue a FITA de telemetria
-- (.monbar__strip): fila HORIZONTAL rasa (17px) que corre por toda a largura,
-- com bg em gradiente, orla inferior e aresta néon no topo. Ordem dos elementos
-- (monitorbar.jsx): [rec][id][haz]  …flex…  [hex][node].
--   DOMÍNIO........: nenhum.
--   CONTRA-DOMÍNIO.: o widget da fita.
--   EFFEITOS.......: instala um gears.timer interno (1.4s) que faz pulsar o REC.
local function make_strip()
  local function lbl(text, color)
    return wibox.widget {
      { text = text, font = ft.mon_strip_lbl, valign = "center", widget = wibox.widget.textbox },
      fg = color, widget = wibox.container.background,
    }
  end

  -- REC: ponto circular de 7px (fill crítico) + a legenda "REC".
  local rec_dot = wibox.widget {
    bg = p.crit, shape = gears.shape.circle,
    forced_width = dpi(7), forced_height = dpi(7),
    widget = wibox.container.background,
  }
  local rec = wibox.widget {
    { rec_dot, valign = "center", widget = wibox.container.place },
    lbl("REC", p.crit),
    spacing = dpi(5),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- HAZ: listras de advertência a 45º (.monbar__haz), 40x8.
  local haz = wibox.widget {
    bg = p.transparent,
    forced_width = dpi(mt.mon_haz_w), forced_height = dpi(mt.mon_haz_h),
    bgimage = function(_, cr, w, h)
      shapes.hazard(cr, w, h, { color = p.glow_core, band = dpi(3), gap = dpi(3), alpha = 0.55 })
    end,
    widget = wibox.container.background,
  }

  local left_group = wibox.widget {
    rec,
    lbl("LIVE TELEMETRY · RADICAL-WM // SYSMON", p.text_muted),
    { haz, valign = "center", widget = wibox.container.place },
    spacing = dpi(10),
    layout  = wibox.layout.fixed.horizontal,
  }

  local node = wibox.widget {
    lbl("NODE STATUS:", p.text_muted),
    lbl("ONLINE", p.ok),
    spacing = dpi(4),
    layout  = wibox.layout.fixed.horizontal,
  }
  local right_group = wibox.widget {
    lbl(NODE_ID, p.glow_soft),
    node,
    spacing = dpi(10),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- fila: [esquerda]  …flex (.monbar__flex)…  [direita].
  local row = wibox.widget {
    left_group, nil, right_group,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  local strip = wibox.widget {
    { row, left = dpi(mt.mon_strip_pad_x), right = dpi(mt.mon_strip_pad_x), widget = wibox.container.margin },
    bg            = p.transparent,
    forced_height = dpi(mt.mon_strip_h),
    bgimage = function(_, cr, w, h)
      -- enchimento: gradiente horizontal v950@0.72 (0%) -> diáphano (58%)
      cr:set_source(gears.color({
        type = "linear", from = { 0, 0 }, to = { w, 0 },
        stops = { { 0, p.a(p.v950, 0.72) }, { 0.58, p.transparent } },
      }))
      cr:rectangle(0, 0, w, h); cr:fill()
      -- orla inferior de 1px (border-bottom line_faint)
      local lr, lg, lb = p.rgb(p.line_faint)
      cr:set_source_rgba(lr, lg, lb, 1)
      cr:rectangle(0, h - dpi(1), w, dpi(1)); cr:fill()
      -- aresta néon superior de 1.5px (transparente -> glow_core -> glow_ice -> glow_core -> transparente)
      cr:set_source(gears.color({
        type = "linear", from = { 0, 0 }, to = { w, 0 },
        stops = {
          { 0,    p.transparent },
          { 0.18, p.a(p.glow_core, 0.85) },
          { 0.5,  p.a(p.glow_ice, 0.85) },
          { 0.82, p.a(p.glow_core, 0.85) },
          { 1,    p.transparent },
        },
      }))
      cr:rectangle(0, 0, w, dpi(1.5)); cr:fill()
    end,
    widget = wibox.container.background,
  }

  -- pulsação do REC (kit .monrec: 1.4s, dois estados): alterna a plenitude do ponto.
  local on = true
  gears.timer {
    timeout = 1.4, autostart = true, call_now = true,
    callback = function()
      on = not on
      rec_dot.bg = on and p.crit or p.a(p.crit, 0.2)
    end,
  }

  return strip
end

-- ── LEMMA make_rail ───────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que ergue o MONRAIL (.monrail): a cauda
-- de 152px que FECHA a fita — um rectângulo cuja aresta esquerda se recolhe em
-- entalhe côncavo (socket_tail), recebendo a ponta do último módulo. Contém
-- NODE // STATUS + VOLUME (barra fina) + AGGREGATE LOAD (número grande).
--   DOMÍNIO........: s — a tela (para o signal do controlador de volume).
--   CONTRA-DOMÍNIO.: taboa { widget, set_vol, set_load } — o widget e os dois
--                    punhos que ajustam o volume e a carga aggregada.
--   EFFEITOS.......: nenhum estado global; sómente compõe widgets.
local function make_rail(s)
  local function lbl(text, color, font)
    return wibox.widget {
      { text = text, font = font, valign = "center", widget = wibox.widget.textbox },
      fg = color, widget = wibox.container.background,
    }
  end

  -- TOP: NODE // STATUS  ·  ● ONLINE
  local ok_dot = wibox.widget {
    bg = p.ok, shape = gears.shape.circle,
    forced_width = dpi(6), forced_height = dpi(6),
    widget = wibox.container.background,
  }
  local top = wibox.widget {
    lbl("NODE // STATUS", p.text_heading, ft.mon_rail_hd),
    nil,
    {
      { ok_dot, valign = "center", widget = wibox.container.place },
      lbl("ONLINE", p.ok, ft.mon_rail_st),
      spacing = dpi(5),
      layout  = wibox.layout.fixed.horizontal,
    },
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  -- VOL: ícone + barra fina (gradiente v700->glow_core) + valor. A barra flexiona
  -- para preencher o vão; o gradiente approxima-se á largura útil do rail.
  local track = wibox.widget {
    max_value        = 100, value = 0,
    forced_height    = dpi(5),
    color            = gears.color({
      type = "linear", from = { 0, 0 }, to = { dpi(60), 0 },
      stops = { { 0, p.v700 }, { 1, p.glow_core } },
    }),
    background_color = p.inset,
    border_width     = 0,
    bar_shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_bar)) end,
    shape            = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_bar)) end,
    widget           = wibox.widget.progressbar,
  }
  local volv_text = wibox.widget { text = "--", font = ft.mon_strip_lbl, valign = "center", widget = wibox.widget.textbox }
  local volv = wibox.widget { volv_text, fg = p.text_bright, widget = wibox.container.background }
  local vol_row = wibox.widget {
    { Icon("vol", { size = dpi(12), color = p.text_muted }), valign = "center", widget = wibox.container.place },
    { track, valign = "center", content_fill_horizontal = true, widget = wibox.container.place },
    volv,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }
  local vol = wibox.widget { vol_row, bg = p.transparent, widget = wibox.container.background }
  vol:buttons(gears.table.join(
    awful.button({}, 1, function() awesome.emit_signal("volume_controller::toggle", s) end)
  ))

  -- LOAD: rótulo esmaecido á esquerda | valor grande (22px) + signo "%" á dextra.
  local load_value = wibox.widget { text = "--", font = ft.mon_rail_load, valign = "center", widget = wibox.widget.textbox }
  local load = wibox.widget {
    lbl("AGGREGATE LOAD", p.text_faint, ft.mon_big_unit),
    nil,
    {
      { load_value, fg = p.glow_ice, widget = wibox.container.background },
      {
        { text = "%", font = ft.mon_rail_loadu, valign = "center", widget = wibox.widget.textbox },
        fg = p.text_muted, widget = wibox.container.background,
      },
      spacing = dpi(1),
      layout  = wibox.layout.fixed.horizontal,
    },
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  local content = wibox.widget {
    {
      top, vol, load,
      spacing = dpi(4),
      layout  = wibox.layout.fixed.vertical,
    },
    top = dpi(5), bottom = dpi(5), left = dpi(26), right = dpi(14),
    widget = wibox.container.margin,
  }

  local rail_shape = shapes.socket_tail({ socket = dpi(mt.mon_overlap) })
  local rail_inner = wibox.widget {
    content,
    bg     = p.a(p.panel, 0.92),
    shape  = rail_shape,
    widget = wibox.container.background,
  }
  local rail_widget = wibox.widget {
    { rail_inner, margins = dpi(mt.mon_edge), widget = wibox.container.margin },
    bg           = p.transparent,
    shape        = rail_shape,
    forced_width = dpi(mt.mon_rail_w),
    bgimage = function(_, cr, w, h)
      cr:set_source(gears.color({
        type = "linear", from = { 0, 0 }, to = { 0, h },
        stops = { { 0, p.a(p.glow_soft, 0.8) }, { 1, p.a(p.v700, 0.8) } },
      }))
      cr:rectangle(0, 0, w, h); cr:fill()
    end,
    widget = wibox.container.background,
  }

  return {
    widget   = rail_widget,
    set_vol  = function(v)
      v = math.max(0, math.min(100, tonumber(v) or 0))
      track.value = v
      volv_text:set_text(string.format("%d%%", math.floor(v + 0.5)))
    end,
    set_load = function(v)
      load_value:set_text(string.format("%d", math.floor((tonumber(v) or 0) + 0.5)))
    end,
  }
end

-- ══════════════════════════════════════════════════════════════════════════
-- FUNCÇÃO EDIFICADORA do organismo (a peça que este manuscripto restitue).
-- Como demonstrou o insigne geómetra Braga Us, dada uma tela, ergue a barra de
-- telemetria completa (topologia de coluna) e funda o relógio que a mantém viva.
--   DOMÍNIO........: s — a tela (screen) que hospedará a barra no seu rodapé.
--   CONTRA-DOMÍNIO.: o awful.popup da barra, já visível e ligado á geometria.
--   EFFEITOS.......: guarda-se em s._monitor_bar (previne duplicata em reload);
--                    enlaça-se a property::geometry; funda um gears.timer de
--                    amostragem assíncrona que a cada tick colhe CPU/MEM/NET
--                    (e, a cada dois, GPU/CPU-extras/NET-extras/VOL) e recalcula
--                    a carga aggregada.
-- ══════════════════════════════════════════════════════════════════════════
return function(s)
  local iface = (user_vars and user_vars.network and user_vars.network.ethernet) or "eno1"

  -- os quatro módulos de telemetria — manifesto verbatim do kit (monitorbar.jsx),
  -- cada qual no SEU matiz do espectro do poente (MOD_ACCENT, vide supra).
  -- Os rótulos partem de um valor prudente e são CORRIGIDOS ao hardware real logo abaixo.
  local mod_gpu = make_module(s, {
    label = "GPU", lbl = 24, sub = "GPU", icon = "gpu",
    colors = { MOD_ACCENT.gpu }, group = "system", fixed100 = true, first = true,
    cells = { "USE", "TEMP", "CLK", "VRAM" },
  })
  local mod_cpu = make_module(s, {
    label = "CPU", lbl = 24, sub = "CPU", icon = "cpu",
    colors = { MOD_ACCENT.cpu }, group = "system", fixed100 = true,
    cells = { "LOAD", "TEMP", "CLK", "CORES" },
  })
  local mod_mem = make_module(s, {
    label = "MEMORY", lbl = 15, sub = "RAM", icon = "mem",
    colors = { MOD_ACCENT.mem }, group = "system", fixed100 = true,
    cells = { "USED", "CACHE", "SWAP", "BUFF" },
  })
  local mod_net = make_module(s, {
    label = "NET", lbl = 22, sub = "NET // " .. iface, icon = "net",
    -- DUAS séries sobrepostas: {download (frente, laranja), upload (trás, lima-neon)}.
    -- blend "screen" acende o cruzamento; escala partilhada (fixed100=false) mede ambas igual.
    colors = { MOD_ACCENT.net, MOD_ACCENT.net_up }, blend = "screen",
    group = "network", fixed100 = false,
    cells = { "DOWN", "UP", "PING", "CONN" },
  })

  -- ── DETECÇÃO ASSÍNCRONA DO HARDWARE REAL (rótulos fiéis) ────────────────────
  -- Colhe, uma só vez, o modelo do CPU + nº de threads (/proc/cpuinfo, nproc), a
  -- memória total (/proc/meminfo) e o nome da GPU (nvidia-smi), e reescreve os
  -- rótulos — de sorte que a barra nomeie o que a máquina DE FACTO possue (aqui,
  -- v.g., Intel i5-10400F · 12T, 8G, RTX 3060), e não uma marca fixa e falaz.
  awful.spawn.easy_async_with_shell(
    "echo \"CPU:$(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')\"; " ..
    "echo \"THREADS:$(nproc 2>/dev/null)\"; " ..
    "echo \"MEMGB:$(awk '/MemTotal/{printf \"%.0f\", $2/1048576}' /proc/meminfo)\"; " ..
    "echo \"GPU:$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1)\"",
    function(out)
      out = out or ""
      local cpu_model = out:match("CPU:([^\n]*)") or ""
      local threads   = out:match("THREADS:(%d+)")
      local mem_gb    = out:match("MEMGB:(%d+)")
      local gpu_name  = out:match("GPU:([^\n]*)") or ""

      -- CPU: marca (INTEL/AMD) no rótulo grande; modelo curto + threads no sub.
      local brand = cpu_model:match("Intel") and "INTEL" or cpu_model:match("AMD") and "AMD" or "CPU"
      -- modelo curto, apurado com guarda de nil (nunca :gsub sobre nil):
      local short = cpu_model:match("(i%d%-%w+)")   -- Intel Core iN-XXXX (v.g. i5-10400F)
      if not short then
        local ryz = cpu_model:match("Ryzen[%s%w]+")  -- família Ryzen
        if ryz then short = (ryz:gsub("%s+$", "")) end
      end
      short = short or cpu_model:match("Core[%s%w%-]+") or "CPU"
      mod_cpu.set_label(brand)
      mod_cpu.set_sub("CPU // " .. short .. (threads and (" " .. threads .. "T") or ""))

      -- MEM: memória total em gibibytes no sub.
      if mem_gb then mod_mem.set_sub("RAM // " .. mem_gb .. "G") end

      -- GPU: extrahe a família curta (v.g. "RTX 3060") do nome pleno da nvidia-smi.
      if gpu_name ~= "" then
        local gshort = gpu_name:match("(RTX%s*%w+)") or gpu_name:match("(GTX%s*%w+)")
          or gpu_name:gsub("^NVIDIA%s+GeForce%s+", ""):gsub("^NVIDIA%s+", "")
        mod_gpu.set_label((gshort:match("RTX") or gshort:match("GTX")) and "RTX" or "GPU")
        mod_gpu.set_sub("GPU // " .. gshort)
      end
    end
  )

  local strip = make_strip()
  local rail  = make_rail(s)

  -- FILA DE MÓDULOS: tesselação por sobreposição negativa (-16). O 1º módulo
  -- (convexo) abre a fita; os demais encaixam a concha na ponta do anterior. Na
  -- 1ª entrega aceita-se o "direita-por-cima" pragmático (flex + margem negativa):
  -- a tesselação fica correcta (o socket é o negativo exacto da ponta); só a
  -- aresta-glow de costura fica invertida vs kit — refino p/ layout.manual depois.
  local modules_flex = wibox.widget {
    mod_gpu.widget,
    { mod_cpu.widget, left = -dpi(mt.mon_overlap), widget = wibox.container.margin },
    { mod_mem.widget, left = -dpi(mt.mon_overlap), widget = wibox.container.margin },
    { mod_net.widget, left = -dpi(mt.mon_overlap), widget = wibox.container.margin },
    layout = wibox.layout.flex.horizontal,
  }
  -- o rail (152px) fecha a fita, também recuado -16 sob a ponta do último módulo.
  local rail_wrap = wibox.widget {
    rail.widget, left = -dpi(mt.mon_overlap), widget = wibox.container.margin,
  }
  -- a fileira preenche a largura: os módulos flexionam ao centro, o rail á dextra.
  local module_row = wibox.widget {
    {
      nil, modules_flex, rail_wrap,
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    },
    top = dpi(mt.mon_row_pad_t), bottom = dpi(mt.mon_row_pad_b),
    left = dpi(mt.mon_row_pad_x), right = dpi(mt.mon_row_pad_x),
    widget = wibox.container.margin,
  }

  -- filetes do topo: 1px line_base (border-top) + 1px glow_core@0.28 (box-shadow).
  local top_edges = wibox.widget {
    { forced_height = dpi(1), bg = p.line_base,            widget = wibox.container.background },
    { forced_height = dpi(1), bg = p.a(p.glow_core, 0.28), widget = wibox.container.background },
    layout = wibox.layout.fixed.vertical,
  }

  -- COLUNA: [filetes+strip] no topo (fixo) | fileira de módulos a preencher o resto.
  local column = wibox.widget {
    { top_edges, strip, layout = wibox.layout.fixed.vertical },
    module_row,
    nil,
    expand = "inside",
    layout = wibox.layout.align.vertical,
  }
  -- fundo da doca: gradiente vertical base@0.72 -> abyss@0.94 (.monitorbar bg).
  local column_bg = wibox.widget {
    column,
    bg = gears.color({
      type = "linear", from = { 0, 0 }, to = { 0, MON_H },
      stops = { { 0, p.a(p.base, 0.72) }, { 1, p.a(p.abyss, 0.94) } },
    }),
    widget = wibox.container.background,
  }

  -- scanlines (.monitorbar::after): ténues rectas de 1px, por cima de toda a doca.
  local scan = wibox.widget.base.make_widget()
  function scan:fit(_, w, h) return w, h end
  function scan:draw(_, cr, w, h)
    shapes.scanlines(cr, w, h, { color = p.glow_core, alpha = 0.036, spacing = dpi(3) })
  end

  local bar_widget = wibox.widget {
    column_bg, scan,
    layout = wibox.layout.stack,
  }
  bar_widget.forced_height = MON_H
  bar_widget.forced_width  = s.geometry.width

  -- GUARDA contra duplicata em novo carregamento: occulta-se a barra pretérita.
  if s._monitor_bar then s._monitor_bar.visible = false end

  local bar = awful.popup {
    widget    = bar_widget,
    ontop     = false,
    visible   = true,
    screen    = s,
    type      = "dock",       -- DOCA: reserva a sua faixa na área de trabalho (struts, abaixo)
    bg        = p.transparent, -- a doca pinta o seu próprio gradiente; o popup é diáphano
    placement = function(c) awful.placement.bottom_left(c, { margins = 0 }) end,
  }
  s._monitor_bar = bar

  -- DOCKBAR (a pedido): reserva a sua faixa de MON_H no rodapé, de sorte que os clientes
  -- ladrilhados E os maximizados parem no SEU TOPO — tal qual a barra superior — em vez de
  -- correr por baixo d'ella. É a reserva de workarea (struts) que o impõe. — Braga Us.
  bar:struts({ bottom = MON_H })

  -- REAJUSTA a largura, a posição e a reserva sempre que a geometria da tela se altere.
  s:connect_signal("property::geometry", function()
    bar_widget.forced_width = s.geometry.width
    awful.placement.bottom_left(bar, { margins = 0 })
    bar:struts({ bottom = MON_H })
  end)

  -- ── ESTADO PERSISTENTE entre ticks ─────────────────────────────────────────
  -- Grandezas conservadas de um tick ao seguinte (os deltas de CPU e de NET), e
  -- as últimas percentagens colhidas, de que se serve o AGGREGATE LOAD.
  local prev_cpu_total, prev_cpu_idle = nil, nil
  local prev_rx, prev_tx, prev_net_time = nil, nil, nil
  local last_cpu, last_mem, last_gpu = 0, 0, 0
  local tick = 0

  -- ── COROLLÁRIO update_cpu ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que apura a percentagem de CPU por meio
  -- de /proc/stat (o delta entre o tempo occupado e o ocioso). Alimenta a leitura
  -- grande, a série A (accento) e a célula LOAD.
  local function update_cpu()
    awful.spawn.easy_async_with_shell("cat /proc/stat 2>/dev/null | head -n 1", function(out)
      out = out or ""
      local nums = {}
      for tok in out:gmatch("%d+") do nums[#nums + 1] = tonumber(tok) end
      if #nums < 4 then return end
      local idle = (nums[4] or 0) + (nums[5] or 0)
      local total = 0
      for i = 1, #nums do total = total + (nums[i] or 0) end
      local pct = 0
      if prev_cpu_total and prev_cpu_idle then
        local dt, di = total - prev_cpu_total, idle - prev_cpu_idle
        if dt > 0 then pct = (dt - di) / dt * 100 end
      end
      prev_cpu_total, prev_cpu_idle = total, idle
      if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
      local r = math.floor(pct + 0.5)
      last_cpu = r
      mod_cpu.set_big("", tostring(r), "%", r)
      mod_cpu.push(1, r)
      mod_cpu.set_cell(1, r .. "%") -- célula LOAD
    end)
  end

  -- ── COROLLÁRIO update_cpu_extra ─────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que colhe os predicados accessórios do
  -- CPU (temperatura, frequência, núcleos, carga de 1 minuto) num único invólucro
  -- de shell. Povoa as células TEMP/CLK/CORES e alimenta as séries B (temp) e C
  -- (carga normalizada aos núcleos).
  local function update_cpu_extra()
    local script = [[
      T=--; for h in /sys/class/hwmon/hwmon*; do n=$(cat "$h/name" 2>/dev/null); case "$n" in
        k10temp|zenpower|coretemp) T=$(cat "$h/temp1_input" 2>/dev/null); break;; esac; done
      echo "TEMP:$T"
      echo "MHZ:$(awk '/cpu MHz/{s+=$4;n++} END{if(n>0)printf "%.0f", s/n}' /proc/cpuinfo 2>/dev/null)"
      echo "CORES:$(nproc 2>/dev/null)"
      echo "LOAD:$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)"
    ]]
    awful.spawn.easy_async_with_shell(script, function(out)
      out = out or ""
      local temp_m = tonumber(out:match("TEMP:(%d+)"))
      local mhz    = tonumber(out:match("MHZ:(%d+)"))
      local cores  = tonumber(out:match("CORES:(%d+)"))
      local load1  = tonumber(out:match("LOAD:([%d%.]+)"))
      mod_cpu.set_cell(2, temp_m and string.format("%d°", math.floor(temp_m / 1000 + 0.5)) or "--")
      mod_cpu.set_cell(3, mhz and string.format("%.1fG", mhz / 1000) or "--")
      mod_cpu.set_cell(4, cores and tostring(cores) or "--")
      -- (temp/carga já não alimentam o grapho: a série única traça SÓ o uso% real do CPU;
      --  temperatura e clock vivem nas células do rodapé.) — Braga Us.
    end)
  end

  -- ── COROLLÁRIO update_mem ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que afere a memória por /proc/meminfo.
  -- Alimenta a leitura, as células USED/CACHE/SWAP/BUFF e as séries A (uso%) e B
  -- (swap%). Abstem-se á falta de MemTotal/MemAvailable ou total não-positivo.
  local function update_mem()
    awful.spawn.easy_async_with_shell("cat /proc/meminfo 2>/dev/null", function(out)
      out = out or ""
      local total   = tonumber(out:match("MemTotal:%s*(%d+)"))      -- em kibibytes
      local avail   = tonumber(out:match("MemAvailable:%s*(%d+)"))
      local cached  = tonumber(out:match("\nCached:%s*(%d+)")) or tonumber(out:match("^Cached:%s*(%d+)"))
      local buffers = tonumber(out:match("Buffers:%s*(%d+)"))
      local sw_t = tonumber(out:match("SwapTotal:%s*(%d+)"))
      local sw_f = tonumber(out:match("SwapFree:%s*(%d+)"))
      if not total or not avail or total <= 0 then return end
      local used = total - avail
      if used < 0 then used = 0 end
      local pct = math.floor(used / total * 100 + 0.5)
      last_mem = pct
      local swap_pct = 0
      if sw_t and sw_f and sw_t > 0 then swap_pct = math.floor((sw_t - sw_f) / sw_t * 100 + 0.5) end
      mod_mem.set_big("", tostring(pct), "%", pct)
      mod_mem.set_cells {
        fmt_gib(used * 1024),
        cached and fmt_gib(cached * 1024) or "--",
        string.format("%d%%", swap_pct),
        buffers and fmt_gib(buffers * 1024) or "--",
      }
      mod_mem.push(1, pct) -- série única: uso% real da memória (swap fica na célula)
    end)
  end

  -- ── COROLLÁRIO update_gpu ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que interroga a placa gráphica por meio
  -- de nvidia-smi (uma só chamada CSV). Faltando o apparato, tudo recahe em "--".
  local function update_gpu()
    awful.spawn.easy_async_with_shell(
      "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,clocks.current.graphics,memory.used,memory.total,fan.speed --format=csv,noheader,nounits 2>/dev/null",
      function(out)
        out = out or ""
        -- partição por vírgula (preserva a posição; o campo "[N/A]" torna-se nil sem deslocar os índices)
        local f, i = {}, 0
        for tok in out:gmatch("[^,]+") do
          i = i + 1
          f[i] = tonumber(tok:match("[%d%.]+"))
        end
        if not f[1] then
          mod_gpu.set_big("", "--", "%")
          mod_gpu.set_cells { "--", "--", "--", "--" }
          return
        end
        local util  = f[1] or 0
        local temp  = f[2]
        local clk   = f[3]
        local mused = f[4]
        local mtot  = f[5]
        if util < 0 then util = 0 elseif util > 100 then util = 100 end
        local r = math.floor(util + 0.5)
        last_gpu = r
        mod_gpu.set_big("", tostring(r), "%", r)
        mod_gpu.set_cells {
          string.format("%d%%", r),                                     -- USE
          temp and string.format("%d°", math.floor(temp + 0.5)) or "--", -- TEMP
          clk and string.format("%d", math.floor(clk + 0.5)) or "--",   -- CLK
          (mused and mtot and mtot > 0) and string.format("%.1fG", mused / 1024) or "--", -- VRAM
        }
        mod_gpu.push(1, r) -- série única: utilização% real da GPU (temp fica na célula)
      end
    )
  end

  -- ── COROLLÁRIO update_net ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que mede a rede por /proc/net/dev,
  -- sommando todas as interfaces excepto a de loopback (lo) e derivando a taxa do
  -- delta entre duas amostras. Alimenta a leitura (↓ com unidade /s), as células
  -- DOWN/UP e as séries A (down) e B (up).
  local function update_net()
    awful.spawn.easy_async_with_shell("cat /proc/net/dev 2>/dev/null", function(out)
      out = out or ""
      local rx_sum, tx_sum = 0, 0
      for line in out:gmatch("[^\r\n]+") do
        local ifn, rest = line:match("^%s*([%w%-%._]+):%s*(.+)$")
        if ifn and ifn ~= "lo" and rest then
          local fields = {}
          for tok in rest:gmatch("%S+") do fields[#fields + 1] = tonumber(tok) end
          if fields[1] then rx_sum = rx_sum + fields[1] end
          if fields[9] then tx_sum = tx_sum + fields[9] end
        end
      end
      local now = os.time()
      local up_rate, down_rate = 0, 0
      if prev_rx and prev_tx and prev_net_time then
        local dt = now - prev_net_time
        if dt <= 0 then dt = INTERVAL end
        local d_rx, d_tx = rx_sum - prev_rx, tx_sum - prev_tx
        if d_rx < 0 then d_rx = 0 end
        if d_tx < 0 then d_tx = 0 end
        down_rate = d_rx / dt
        up_rate   = d_tx / dt
      end
      prev_rx, prev_tx, prev_net_time = rx_sum, tx_sum, now
      mod_net.set_big("↓", format.rate(down_rate, "compact"), "/s")
      mod_net.set_cell(1, format.rate(down_rate, "compact")) -- DOWN
      mod_net.set_cell(2, format.rate(up_rate, "compact"))   -- UP
      mod_net.push(1, down_rate / 1024) -- série 1 (frente, laranja): download real em KiB/s
      mod_net.push(2, up_rate   / 1024) -- série 2 (trás, amarelo-neon): upload real em KiB/s (escala partilhada)
    end)
  end

  -- ── COROLLÁRIO update_net_extra ─────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que colhe a latência ao gateway (ping) e
  -- o número de conexões TCP estabelecidas (ss) — num único invólucro assíncrono.
  -- Povoa as células PING e CONN; á falta de dado, recahe em "--".
  local function update_net_extra()
    local script = [[
      GW=$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')
      P=
      if [ -n "$GW" ]; then
        P=$(ping -c1 -W1 "$GW" 2>/dev/null | awk -F'time=' '/time=/{split($2,a," ");print a[1];exit}')
      fi
      echo "PING:${P:-}"
      echo "CONN:$(ss -tn 2>/dev/null | grep -c ESTAB)"
    ]]
    awful.spawn.easy_async_with_shell(script, function(out)
      out = out or ""
      local ping = tonumber(out:match("PING:([%d%.]+)"))
      local conn = tonumber(out:match("CONN:(%d+)"))
      mod_net.set_cell(3, ping and string.format("%dms", math.floor(ping + 0.5)) or "--")
      mod_net.set_cell(4, conn and tostring(conn) or "--")
    end)
  end

  -- ── COROLLÁRIO update_vol ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que interroga o volume sonoro por pactl,
  -- e ajusta a barra do MonRail (valor e leitura textual).
  local function update_vol()
    awful.spawn.easy_async_with_shell("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null", function(out)
      out = out or ""
      local v = tonumber(out:match("(%d+)%%"))
      if v then rail.set_vol(v) end
    end)
  end

  -- ── COROLLÁRIO update_aggregate ─────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que compõe a carga aggregada, tomada por
  -- média arithmética das últimas percentagens de cpu, mem e gpu.
  local function update_aggregate()
    rail.set_load((last_cpu + last_mem + last_gpu) / 3)
  end

  gears.timer {
    timeout   = INTERVAL,
    call_now  = true,
    autostart = true,
    callback  = function()
      tick = tick + 1
      update_cpu()
      update_mem()
      update_net()
      if tick % 2 == 1 then -- os invólucros de shell mais custosos, a cada dois segundos
        update_gpu()
        update_cpu_extra()
        update_net_extra()
        update_vol()
      end
      update_aggregate()
    end,
  }

  return bar
end
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
