-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/line_graph.lua — Da penna do professor BRAGA US.
--
-- TRACTADO SOBRE O ÚNICO RENDERIZADOR DE LINHA/ÁREA (VIOLET HUD §7.4.3 + §7.3.1),
-- demonstrado pelo insigne geómetra Braga Us. Um só renderizador cairo, puro,
-- que serve a AMBOS os graphos do kit:
--   * charts.jsx  LineGraph  — grelha + enchimento de área + halo + traço de 2px
--                              (em três passagens), "poço" (well) reintrante com
--                              borda de accent, escala dynâmica com um `floor`.
--   * monitorbar.jsx MonGraph — `gradient_fill` vertical, mescla additiva
--                               `blend="screen"` ao redor de cada grupo de séries,
--                               escala `fixed100` (0..100 %).
-- Ambos partilham o mesmo cerne de três passagens (área -> halo -> traço) e a
-- polilinha RECTA do kit (segmentos "L"); a flag aditiva smooth=true retoma, quando
-- desejado, o antigo alisamento de Bézier pelo ponto-médio. Por conseguinte, esta
-- obra substitue net_graph_panel.make_graph E monitor_bar.make_area_graph.
--
-- POSTULADO APRESENTATIVO / PURO — nada gera e nada amostra. O DONO empurra os
-- valores (já em %, KB/s, o que seja) por :push(i,v) / :set_data(i,vals); cada
-- valor é ainda assim guardado por tonumber() aqui, por defesa (nil -> 0, concorde
-- às duas implementações vivas). Ambos os mutadores emittem "widget::redraw_needed".
-- Retorna um widget-base com aquelles métodos + referências de clausura directas
-- aos seus vectores de séries (jamais consulta ids — LEMMA R1).
--
-- DA ESCALA (não normalizada a 0..1 — assim como no código vivo que substitue):
--   fixed100=true  -> peak = 100 (as séries são percentagens).
--   fixed100=false -> peak = max(floor, max(valores)) (dynâmica; o `floor` guarda o ruído baixo).
--
-- As côres são SEMPRE tokens da palette (series[i].color, p.grid, p.inset). Os
-- multiplicadores de alpha/largura abaixo são parâmetros intrínsecos do traçado
-- de graphos (não há token de DS para elles; o crivo de aceitação por pixel-diff
-- exclue as regiões de grapho).
--
-- Uso:
--   local line_graph = require("src.molecules.line_graph")
--   -- estylo net_graph (escala dynâmica, poço, grelha, halo):
--   local g = line_graph{ series = {{ color = p.data4, data = zeros(30) }}, floor = 64 }
--   g:push(1, kbps)
--   -- estylo monitor_bar (preenche a caixa, área em gradiente, mescla screen, %):
--   local mg = line_graph{ series = {{color=p.data1},{color=p.data4}},
--                          fill = true, gradient_fill = true, blend = "screen",
--                          fixed100 = true, grid = false, halo = false, well = false }
-- ══════════════════════════════════════════════════════════════════════════

local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

-- Operadores cairo para a mescla additiva "screen" (MonGraph). lgi é o mesmo
-- substrato de renderização de baixo nível sobre o qual assentam gears/wibox;
-- guardado, de sorte que a mescla se torne funcção nulla, com graça, se ausente.
local OP_SCREEN, OP_OVER
do
  local ok, lgi = pcall(require, "lgi")
  if ok and lgi and lgi.cairo and lgi.cairo.Operator then
    OP_SCREEN = lgi.cairo.Operator.SCREEN
    OP_OVER   = lgi.cairo.Operator.OVER
  end
end

-- Geometria/alpha intrínsecos do grapho (NÃO tokens do design-system — vide o cabeçalho). --
local PAD    = 4    -- reintrância do plot quando `well` (o pad do LineGraph do kit); dpi() no ponto de uso
local WELL_R = 4    -- raio do canto do poço (kit LineGraph borderRadius:4)
local HALO_W = 5    -- largura do traço translúcido do halo (kit strokeWidth:5)
local MAIN_W = 2    -- largura do traço da linha principal
local MAIN_A = 1.0  -- alpha da linha principal (kit: opacidade plena)
-- alpha da grelha horizontal (kit: 0.22 / 0.12 / 0.22 nas 3 linhas de 25/50/75%)
local GRID_A_STRONG, GRID_A_FAINT = 0.22, 0.12
-- alpha (fixa) da grelha vertical, traçada sobre p.v400 (kit: opacity 0.06)
local VGRID_A = 0.06
-- fracções das 3 linhas de grelha (horizontaes E verticaes), a 25/50/75% (kit)
local GRID_FRACS = { 0.25, 0.5, 0.75 }
-- paradas verticaes do gradient_fill (MonGraph): topo opaco -> meio -> fundo quasi-diáphano
local GRAD_TOP, GRAD_MID, GRAD_BOT, GRAD_MID_STOP = 0.6, 0.16, 0.02, 0.62

-- côres da palette decompostas uma só vez (tokens estáticos)
local GRID_R, GRID_G, GRID_B    = p.rgb(p.grid)
local INSET_R, INSET_G, INSET_B = p.rgb(p.inset)
local V400_R, V400_G, V400_B    = p.rgb(p.v400)

-- ──────────────────────────────────────────────────────────────────────────
-- Funcção line_graph — concebida pelo Doutor Braga Us como renderizador único.
--   DOMÍNIO (`args`, taboa facultativa): grid, halo, well, gradient_fill, blend,
--     fixed100, floor, fill, width, height e series ({{color, data}, ...}).
--   CONTRA-DOMÍNIO: retorna o widget-base `w`, dotado de :fit, :draw, :push e
--     :set_data. INVARIANTE: cada valor de série é guardado por tonumber (nil -> 0).
local function line_graph(args)
  args = args or {}

  local grid          = args.grid ~= false
  local halo          = args.halo ~= false
  local well          = args.well ~= false
  local gradient_fill = args.gradient_fill and true or false
  local blend         = args.blend
  local fixed100      = args.fixed100 and true or false
  local floor         = args.floor or mt.net_floor_kbps
  local fill          = args.fill and true or false
  -- Alisamento: por defeito RECTO (segmentos "L", como o kit LineGraph/MonGraph);
  -- smooth=true reactiva o antigo alisamento de Bézier pelo ponto-médio (aditivo).
  local smooth        = args.smooth and true or false

  -- dimensionamento do fit: largura do chamador ou disponível; altura = explícita
  -- / graph_h / (fill -> disponível)
  local fw = args.width
  local fh = args.height
  if fh == nil and not fill then fh = dpi(mt.graph_h) end

  -- Séries: {{ color, data = {..} }, ...}. data facultativa (o dono semeia/empurra).
  local series = {}
  for i, sdef in ipairs(args.series or {}) do
    local d = {}
    if type(sdef.data) == "table" then
      for k = 1, #sdef.data do d[k] = tonumber(sdef.data[k]) or 0 end
    end
    series[i] = { color = sdef.color or p.v500, data = d }
  end

  local w = wibox.widget.base.make_widget()

  -- Método w:fit — de Braga Us. DOMÍNIO: (_, avail_w, avail_h). CONTRA-DOMÍNIO:
  --   (rw, rh) — a largura pedida (fw ou disponível) e a altura (disponível se
  --   fill, senão fh ou disponível).
  function w:fit(_, avail_w, avail_h)
    local rw = fw or avail_w
    local rh = fill and avail_h or (fh or avail_h)
    return rw, rh
  end

  -- Método w:draw — o pincel geométrico de Braga Us. DOMÍNIO: (_, cr, width,
  --   height). EFEITO: traça, sobre o contexto cairo, o poço (opcional), a grelha
  --   (opcional) e cada série em três passagens (área -> halo -> traço), com a
  --   polilinha recta do kit (ou de Bézier, sob smooth=true). Nada retorna.
  function w:draw(_, cr, width, height)
    local pad = dpi(PAD)
    local x, y, pw, ph
    if well then
      x, y = pad, pad
      pw = math.max(1, width - pad * 2)
      ph = math.max(1, height - pad * 2)
      -- poço reintrante: SÓ bg p.inset, raio 4, SEM borda de accent (kit LineGraph)
      gears.shape.rounded_rect(cr, width, height, dpi(WELL_R))
      cr:set_source_rgba(INSET_R, INSET_G, INSET_B, p.alpha.well)
      cr:fill()
    else
      x  = 0
      pw = math.max(1, width)
      y  = dpi(2)
      ph = math.max(1, height - dpi(4))
    end

    -- grelha (kit LineGraph): 3 horizontaes em 25/50/75% sobre p.grid (alpha
    -- 0.22/0.12/0.22) + 3 verticaes nas mesmas fracções sobre p.v400 @0.06.
    if grid then
      cr:set_line_width(dpi(1))
      -- horizontaes: alpha alterna forte/tênue/forte (índice 0/1/2 => 0.22/0.12/0.22)
      for i = 1, 3 do
        local gy = y + ph * GRID_FRACS[i]
        cr:set_source_rgba(GRID_R, GRID_G, GRID_B, ((i - 1) % 2 == 0) and GRID_A_STRONG or GRID_A_FAINT)
        cr:move_to(x, gy); cr:line_to(x + pw, gy); cr:stroke()
      end
      -- verticaes: mesma alpha ténue (0.06) para as três, sobre p.v400
      cr:set_source_rgba(V400_R, V400_G, V400_B, VGRID_A)
      for i = 1, 3 do
        local gx = x + pw * GRID_FRACS[i]
        cr:move_to(gx, y); cr:line_to(gx, y + ph); cr:stroke()
      end
    end

    -- séries (na ordem da frente para trás, tal como passadas) -----------------------------
    for si = 1, #series do
      local s     = series[si]
      local vals  = s.data
      local count = #vals
      if count >= 2 then
        local sr, sg, sb = p.rgb(s.color)

        -- escala
        local peak
        if fixed100 then
          peak = 100
        else
          peak = floor
          for _, v in ipairs(vals) do
            local n = tonumber(v) or 0
            if n > peak then peak = n end
          end
        end
        if peak <= 0 then peak = 1 end

        local step = pw / math.max(count - 1, 1)
        local pts = {}
        for i = 1, count do
          local n = tonumber(vals[i]) or 0
          local frac = n / peak
          if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
          pts[i] = { x = x + (i - 1) * step, y = y + ph - (ph * frac) }
        end

        -- Funcção trace — traça a polilinha da série. Por defeito RECTA (segmentos
        -- "L", tal como o kit LineGraph/MonGraph); sob smooth=true retoma o antigo
        -- alisamento de Bézier pelo ponto-médio (controlos no meio-caminho horizontal
        -- entre vizinhos). Da penna de Braga Us.
        local function trace()
          cr:move_to(pts[1].x, pts[1].y)
          for i = 2, count do
            if smooth then
              local prev, cur = pts[i - 1], pts[i]
              local mx = (prev.x + cur.x) / 2
              cr:curve_to(mx, prev.y, mx, cur.y, cur.x, cur.y)
            else
              cr:line_to(pts[i].x, pts[i].y)
            end
          end
        end

        if blend == "screen" and OP_SCREEN then cr:set_operator(OP_SCREEN) end

        -- passagem 1: enchimento de área (plano, ou gradiente vertical para o MonGraph)
        cr:new_path()
        cr:move_to(pts[1].x, y + ph)
        cr:line_to(pts[1].x, pts[1].y)
        trace()
        cr:line_to(pts[count].x, y + ph)
        cr:close_path()
        if gradient_fill then
          cr:set_source(gears.color({
            type = "linear",
            from = { pts[1].x, y },
            to   = { pts[1].x, y + ph },
            stops = {
              { 0,             p.a(s.color, GRAD_TOP) },
              { GRAD_MID_STOP, p.a(s.color, GRAD_MID) },
              { 1,             p.a(s.color, GRAD_BOT) },
            },
          }))
          cr:fill()
        else
          cr:set_source_rgba(sr, sg, sb, p.alpha.graph_area)
          cr:fill()
        end

        -- passagem 2: halo (traço grosso e translúcido, por baixo da linha)
        if halo then
          cr:new_path(); trace()
          cr:set_source_rgba(sr, sg, sb, p.alpha.graph_halo)
          cr:set_line_width(dpi(HALO_W))
          cr:stroke()
        end

        -- passagem 3: a linha principal
        cr:new_path(); trace()
        cr:set_source_rgba(sr, sg, sb, MAIN_A)
        cr:set_line_width(dpi(MAIN_W))
        cr:stroke()

        if blend == "screen" and OP_OVER then cr:set_operator(OP_OVER) end
      end
    end
  end

  -- Método w:push — de Braga Us. DOMÍNIO: (i, v) — índice da série e o novo valor.
  --   EFEITO: anexa em anel (depõe o mais antigo, anexa o mais recente) à série i;
  --   o dono semeia a profundidade desejada; nil coage-se a 0 (concorde ao push
  --   vivo). Emitte um redesenho.
  function w:push(i, v)
    local s = series[i]
    if not s then return end
    local d = s.data
    table.remove(d, 1)
    d[#d + 1] = tonumber(v) or 0
    self:emit_signal("widget::redraw_needed")
  end

  -- Método w:set_data — de Braga Us. DOMÍNIO: (i, vals) — índice da série e o novo
  --   histórico. EFEITO: substitue a história da série i (cada valor guardado por
  --   tonumber). Emitte um redesenho.
  function w:set_data(i, vals)
    local s = series[i]
    if not s then return end
    local d = {}
    if type(vals) == "table" then
      for k = 1, #vals do d[k] = tonumber(vals[k]) or 0 end
    end
    s.data = d
    self:emit_signal("widget::redraw_needed")
  end

  return w
end

return line_graph

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
