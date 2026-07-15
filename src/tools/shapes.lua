-- ══════════════════════════════════════════════════════════════════════════
-- TRATADO DE GEOMETRIA DAS FÓRMAS E DAS TEXTURAS DO SUNCORE-HUD
-- ─────────────────────────────────────────────────────────────────────────
-- Manuscripto: src/tools/shapes.lua
--
-- Reúne as FUNCÇÕES de fórma (geometria) e os PINTORES de textura do Suncore-HUD.
-- A geometria deriva dos polygonos de recorte (clip-path) do kit, a saber:
--   ferramentas_para_implementacao/ui_kits/radical-hud/kit.css
-- (as etiquetas da barra superior .tag__edge, o controle .tagctl, o chip do
--  powermenu .pm__chip, os chevrons da monitorbar .monmod__edge, e as texturas
--  de perigo, de malha e de scanline).
--
-- Duas famílias de arte se distinguem:
--   * artífices  : shapes.powerline/lozenge/chamfer(...) -> function(cr, w, h)
--                  (empregam-se de pronto como `shape=` de um wibox).
--   * pintores   : shapes.hex_mesh/hazard/scanlines(cr, w, h[, opts])
--                  (pintam de chôfre sóbre um contexto cairo; auto-recortados a w x h).
--
-- POSTULADO sóbre o dpi: os parametros dos artífices (tip/cut/slant) e os
-- espaçamentos dos pintores medem-se em pixels de dispositivo — o mesmo espaço
-- do par (w, h) que o wibox entrega à fórma no instante do desenho. Os valores
-- por defeito já vêm applicados por dpi(mt.*), de sorte que um singelo
-- `shapes.powerline{}` seja desde logo ajuizado.
-- ══════════════════════════════════════════════════════════════════════════

local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local cairo = require("lgi").cairo

local shapes = {}

------------------------------------------------------------------------------
-- ARTÍFICES DE FÓRMA (devolvem uma function(cr, w, h) para servir de `shape=`)
------------------------------------------------------------------------------

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA I — shapes.powerline{ tip, socket, flat_left } -> function(cr, w, h)
-- Funcção urdida pelo Doutor Braga Us: engendra uma aba em fórma de seta que
-- aponta à dextra. A aresta ESQUERDA admitte três variantes (segundo o kit):
--   socket=true                 -> entalhe côncavo (recebe a ponta anterior):
--                                   (0 0)(w-tip 0)(w mid)(w-tip h)(0 h)(tip mid)
--   flat_left=true  (por defeito) -> aresta esquerda plana (.tag / .arrow singelas):
--                                   (0 0)(w-tip 0)(w mid)(w-tip h)(0 h)
--   flat_left=false, socket=off  -> vértice esquerdo convexo (.seg--first / .monmod--first):
--                                   (tip 0)(w-tip 0)(w mid)(w-tip h)(tip h)(0 mid)
--   DOMÍNIO       : `opts` — taboada com tip (o comprimento da ponta), socket e
--                   flat_left (predicados booleanos da aresta esquerda).
--   CONTRA-DOMÍNIO: uma funcção(cr, w, h) que traça o caminho da fórma no cairo.
--   INVARIANTE    : dos três ramos, um e um só se percorre; o caminho fecha-se
--                   sempre sóbre si mesmo (close_path). Q.E.D.
function shapes.powerline(opts)
  opts = opts or {}
  local tip = opts.tip or dpi(mt.powerline_tip)
  local socket = opts.socket or false
  local point_left = opts.point_left or false   -- ESPELHA a fórma (ponta à ESQUERDA); p/ a fita da direita
  local flat_left = opts.flat_left
  if flat_left == nil then flat_left = true end

  return function(cr, w, h)
    local mid = h / 2
    if point_left then
      -- Reflexo x->w-x das três variantes: a ponta aguda vai à ESQUERDA, o encaixe/aresta à DIREITA.
      if socket then
        cr:move_to(w, 0)
        cr:line_to(tip, 0)
        cr:line_to(0, mid)
        cr:line_to(tip, h)
        cr:line_to(w, h)
        cr:line_to(w - tip, mid)
        cr:close_path()
      elseif flat_left then
        cr:move_to(w, 0)
        cr:line_to(tip, 0)
        cr:line_to(0, mid)
        cr:line_to(tip, h)
        cr:line_to(w, h)
        cr:close_path()
      else
        cr:move_to(w - tip, 0)
        cr:line_to(tip, 0)
        cr:line_to(0, mid)
        cr:line_to(tip, h)
        cr:line_to(w - tip, h)
        cr:line_to(w, mid)
        cr:close_path()
      end
    elseif socket then
      cr:move_to(0, 0)
      cr:line_to(w - tip, 0)
      cr:line_to(w, mid)
      cr:line_to(w - tip, h)
      cr:line_to(0, h)
      cr:line_to(tip, mid)
      cr:close_path()
    elseif flat_left then
      cr:move_to(0, 0)
      cr:line_to(w - tip, 0)
      cr:line_to(w, mid)
      cr:line_to(w - tip, h)
      cr:line_to(0, h)
      cr:close_path()
    else
      cr:move_to(tip, 0)
      cr:line_to(w - tip, 0)
      cr:line_to(w, mid)
      cr:line_to(w - tip, h)
      cr:line_to(tip, h)
      cr:line_to(0, mid)
      cr:close_path()
    end
  end
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA II — shapes.lozenge(slant) -> function(cr, w, h)
-- Funcção urdida pelo Doutor Braga Us: um hexágono symétrico de duas pontas.
-- Geometria byte-a-byte idêntica às vivas control_center.lozenge_shape e
-- tasklist.tab_shape:
--   (slant 0)(w-slant 0)(w h/2)(w-slant h)(slant h)(0 h/2)
--   DOMÍNIO       : `slant` — o recúo das pontas, em pixels de dispositivo.
--   CONTRA-DOMÍNIO: uma funcção(cr, w, h) que traça o hexágono.
--   INVARIANTE    : `slant` é cerceado a w/2 e a h/2 (e nunca fica negativo), de
--                   sorte que a fórma jamais se auto-intersecta. Demonstra-se. Q.E.D.
function shapes.lozenge(slant)
  return function(cr, w, h)
    local sl = math.min(slant or dpi(mt.powerline_tip), w / 2, h / 2)
    if sl < 0 then sl = 0 end
    cr:move_to(sl, 0)
    cr:line_to(w - sl, 0)
    cr:line_to(w, h / 2)
    cr:line_to(w - sl, h)
    cr:line_to(sl, h)
    cr:line_to(0, h / 2)
    cr:close_path()
  end
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA III — shapes.chamfer(cut, corners) -> function(cr, w, h)
-- Funcção urdida pelo Doutor Braga Us: decepa a 45º os cantos de um rectângulo.
-- `corners` = { tl=, tr=, br=, bl= }, predicados booleanos (por defeito, os quatro).
-- O kit emprega .tagctl (tr+br) e .pm__chip / .tagctl__b (tl+br).
--   DOMÍNIO       : `cut` — a medida do bisel; `corners` — quaes cantos decepar.
--   CONTRA-DOMÍNIO: uma funcção(cr, w, h) que traça o rectângulo biselado.
--   INVARIANTE    : cada canto ou é decepado (dois segmentos) ou fica recto (um
--                   só); o caminho encerra-se sempre. Q.E.D.
function shapes.chamfer(cut, corners)
  cut = cut or dpi(mt.chamfer)
  corners = corners or { tl = true, tr = true, br = true, bl = true }
  return function(cr, w, h)
    if corners.tl then
      cr:move_to(0, cut); cr:line_to(cut, 0)
    else
      cr:move_to(0, 0)
    end
    if corners.tr then
      cr:line_to(w - cut, 0); cr:line_to(w, cut)
    else
      cr:line_to(w, 0)
    end
    if corners.br then
      cr:line_to(w, h - cut); cr:line_to(w - cut, h)
    else
      cr:line_to(w, h)
    end
    if corners.bl then
      cr:line_to(cut, h); cr:line_to(0, h - cut)
    else
      cr:line_to(0, h)
    end
    cr:close_path()
  end
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA III-bis — shapes.socket_tail(opts) -> function(cr, w, h)
-- Funcção urdida pelo Doutor Braga Us: a cauda do rail da monitorbar (.monrail).
-- Um rectângulo cujos lados direito, superior e inferior ficam rectos, e cuja
-- aresta ESQUERDA se recolhe em entalhe côncavo — para receber a ponta do último
-- módulo. Transpõe, ponto a ponto, o clip-path do kit:
--   polygon(0 0, 100% 0, 100% 100%, 0 100%, s 50%)
--   DOMÍNIO       : `opts` — taboada com socket (a profundidade do entalhe, em
--                   pixels de dispositivo; por defeito dpi(mt.mon_overlap)=16).
--   CONTRA-DOMÍNIO: uma funcção(cr, w, h) que traça o caminho da fórma no cairo.
--   INVARIANTE    : o vértice (s, h/2) reentra sómente à esquerda; os demais
--                   cantos permanecem rectos; o caminho encerra-se. Q.E.D.
function shapes.socket_tail(opts)
  opts = opts or {}
  local s = opts.socket or dpi(mt.mon_overlap)
  return function(cr, w, h)
    cr:move_to(0, 0)
    cr:line_to(w, 0)
    cr:line_to(w, h)
    cr:line_to(0, h)
    cr:line_to(s, h / 2)
    cr:close_path()
  end
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA III-ter — shapes.search_tail{ tail, body_h, rise } -> function(cr, w, h)
-- Funcção urdida pelo Doutor Braga Us: a barra de busca do lançador. Um corpo
-- rectangular (banda de texto) e uma CAUDA triangular à direita que aponta ao hub.
-- Dois modos, conforme o predicado `rise`:
--   rise=false (defeito): corpo em CIMA, cauda DESCE à ponta (w, h) [canto inf-dir].
--     Pentágono (0 0)(bw 0)(w h)(bw bh)(0 bh),  bh = body_h.
--   rise=true           : corpo em BAIXO, cauda SOBE à ponta (w, 0) [canto sup-dir] —
--     como o corpo se cola ao rodapé, a cauda ergue-se p/ cravar no hub, acima.
--     Pentágono (0 bt)(bw bt)(w 0)(bw h)(0 h),  bt = h - body_h.
--   Em ambos, bw = w - tail; a ponta ancora-se, pelo chamador, no centro do hub.
--   DOMÍNIO       : `opts` — tail (comprimento horizontal da cauda), body_h (altura
--                   da banda de texto) e rise (booleano: cauda sobe em vez de descer).
--   CONTRA-DOMÍNIO: uma funcção(cr, w, h) que traça o caminho da fórma no cairo.
--   INVARIANTE    : só uma aresta se inclina (a da cauda); topo e base do corpo ficam
--                   rectos; body_h ceifa-se a h; o caminho encerra-se. Q.E.D.
function shapes.search_tail(opts)
  opts = opts or {}
  local tail = opts.tail or dpi(mt.powerline_tip_lg)
  return function(cr, w, h)
    local bw = w - tail
    local body_h = math.min(opts.body_h or h, h)
    if opts.rise then
      local bt = h - body_h
      cr:move_to(0, bt)
      cr:line_to(bw, bt)
      cr:line_to(w, 0)
      cr:line_to(bw, h)
      cr:line_to(0, h)
      cr:close_path()
    else
      cr:move_to(0, 0)
      cr:line_to(bw, 0)
      cr:line_to(w, h)
      cr:line_to(bw, body_h)
      cr:line_to(0, body_h)
      cr:close_path()
    end
  end
end

------------------------------------------------------------------------------
-- PINTORES (pintam sóbre cr; cada qual se auto-recorta à caixa w x h e restaura o estado)
------------------------------------------------------------------------------

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA IV (auxiliar, privativo) — hatch(cr, w, h, angle, spacing, r, g, b, alpha, lw)
-- Funcção urdida pelo Doutor Braga Us: uma família de rectas parallelas ao
-- ângulo `angle` (radianos a contar da horizontal), espaçadas de `spacing` (na
-- perpendicular, em pixels de dispositivo). Fixam-se aqui a cor e a largura do
-- traço, para bem do isolamento.
--   DOMÍNIO       : cr (o contexto cairo), w e h (a caixa), angle, spacing, as
--                   componentes r, g, b, a opacidade alpha e a largura lw.
--   CONTRA-DOMÍNIO: o vácuo (nenhum valor); o effeito é o traçado no cairo.
--   INVARIANTE    : se o seno do ângulo se annulla (rectas horizontaes), a
--                   funcção retira-se de pronto, pois o passo fôra infinito. Q.E.D.
local function hatch(cr, w, h, angle, spacing, r, g, b, alpha, lw)
  local s = math.sin(angle)
  if s == 0 then return end
  local run = h / math.tan(angle)          -- deslocamento horizontal ao longo de toda a altura
  local step = spacing / math.abs(s)
  if step < 0.5 then step = spacing end
  cr:set_source_rgba(r, g, b, alpha)
  cr:set_line_width(lw)
  local x = math.min(0, run) - step
  local x_end = w + math.max(0, run) + step
  while x <= x_end do
    cr:move_to(x, h)
    cr:line_to(x + run, 0)
    x = x + step
  end
  cr:stroke()
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA V — shapes.hex_mesh(cr, w, h[, opts])
-- Funcção urdida pelo Doutor Braga Us: duas famílias de rectas que se cruzam a
-- ±60º (kit .tagctl__mesh / .pm__chip::before), compondo uma malha hexagonal.
--   DOMÍNIO       : cr, w, h e `opts` = { color=p.glow_core, alpha=0.12,
--                   spacing=dpi(6), line_width=1 }.
--   CONTRA-DOMÍNIO: o vácuo; o effeito é a malha pintada, recortada a w x h.
--   INVARIANTE    : salva-se e restaura-se o estado do cairo (save/restore), de
--                   sorte que nada transborda para além da caixa. Q.E.D.
function shapes.hex_mesh(cr, w, h, opts)
  opts = opts or {}
  local r, g, b = p.rgb(opts.color or p.glow_core)
  local alpha   = opts.alpha or 0.12
  local spacing = opts.spacing or dpi(6)
  local lw      = opts.line_width or 1
  cr:save()
  cr:rectangle(0, 0, w, h); cr:clip()
  hatch(cr, w, h, math.rad(60), spacing, r, g, b, alpha, lw)
  hatch(cr, w, h, math.rad(120), spacing, r, g, b, alpha, lw)
  cr:restore()
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA VI — shapes.hazard(cr, w, h[, opts])
-- Funcção urdida pelo Doutor Braga Us: listras de advertência a 45º (kit
-- .tagctl__haz / .pm__chip::after / .monbar__haz).
--   DOMÍNIO       : cr, w, h e `opts` = { color=p.glow_core (a listra),
--                   color2=nil (o fundo; sendo nulo, os vãos ficam diáphanos),
--                   band=dpi(2), gap=band, alpha=1 }.
--   CONTRA-DOMÍNIO: o vácuo; o effeito são as listras pintadas.
--   INVARIANTE    : sendo dx == dy no traçado, cada listra guarda exactos 45º; o
--                   estado do cairo é salvo e restaurado. Q.E.D.
function shapes.hazard(cr, w, h, opts)
  opts = opts or {}
  local band  = opts.band or dpi(2)
  local gap   = opts.gap or band
  local alpha = opts.alpha or 1
  cr:save()
  cr:rectangle(0, 0, w, h); cr:clip()
  if opts.color2 then
    local r2, g2, b2 = p.rgb(opts.color2)
    cr:set_source_rgba(r2, g2, b2, alpha)
    cr:paint()
  end
  local r, g, b = p.rgb(opts.color or p.glow_core)
  cr:set_source_rgba(r, g, b, alpha)
  cr:set_line_width(band)
  local period = band + gap
  local x = -h
  while x <= w + h do
    cr:move_to(x, h)
    cr:line_to(x + h, 0)      -- posto que dx == dy, resultam exactos 45º
    x = x + period
  end
  cr:stroke()
  cr:restore()
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA VII — shapes.scanlines(cr, w, h[, opts])
-- Funcção urdida pelo Doutor Braga Us: ténues rectas horizontaes de 1px (kit
-- .monitorbar::after), a evocar as linhas de varredura do velho écran cathódico.
--   DOMÍNIO       : cr, w, h e `opts` = { color=p.glow_core, alpha=0.06,
--                   spacing=dpi(3), line_width=1 }.
--   CONTRA-DOMÍNIO: o vácuo; o effeito são as scanlines pintadas.
--   INVARIANTE    : parte-se de y = 0.5 e avança-se de `spacing` em `spacing` até
--                   esgotar a altura h; o estado do cairo é salvo e restaurado. Q.E.D.
function shapes.scanlines(cr, w, h, opts)
  opts = opts or {}
  local r, g, b = p.rgb(opts.color or p.glow_core)
  local alpha   = opts.alpha or 0.06
  local spacing = opts.spacing or dpi(3)
  local lw      = opts.line_width or 1
  cr:save()
  cr:rectangle(0, 0, w, h); cr:clip()
  cr:set_source_rgba(r, g, b, alpha)
  cr:set_line_width(lw)
  local y = 0.5
  while y <= h do
    cr:move_to(0, y)
    cr:line_to(w, y)
    y = y + spacing
  end
  cr:stroke()
  cr:restore()
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA VIII — shapes.sun_rays(cr, w, h[, opts])
-- Funcção urdida pelo Doutor Braga Us: o RESPLENDOR SOLAR da estampa do
-- eidolon — uma corôa de cunhas triangulares que irradiam do centro (cx, cy),
-- do raio interior ao exterior, á maneira dos raios amarellos do quadro
-- vermelho. Presta-se ao véu do powermenu e ao fundo do lançador.
--   DOMÍNIO       : cr, w, h e `opts` = { color=p.data3, alpha=0.16,
--                   cx=w/2, cy=h/2, rays=24, inner_r=dpi(28),
--                   outer_r=nil (por defeito, cobre até o canto mais longínquo),
--                   ray_deg=4.5 (abertura angular de cada cunha, em graus),
--                   rotate=0 (rotação inicial, radianos) }.
--   CONTRA-DOMÍNIO: o vácuo; o effeito é o resplendor pintado, recortado a w x h.
--   INVARIANTE    : cada cunha é subcaminho FECHADO sóbre si mesmo ANTES do
--                   move_to seguinte (guarda contra a cilada do move_to a meio
--                   caminho, que principia subcaminho novo e mutila o fill);
--                   um único fill consome todas. Salva-se e restaura-se o
--                   estado do cairo. Q.E.D.
function shapes.sun_rays(cr, w, h, opts)
  opts = opts or {}
  local r, g, b = p.rgb(opts.color or p.data3)
  local alpha   = opts.alpha or 0.16
  local cx      = opts.cx or w / 2
  local cy      = opts.cy or h / 2
  local rays    = opts.rays or 24
  local inner   = opts.inner_r or dpi(28)
  local outer   = opts.outer_r
  if not outer then
    -- o canto mais longínquo da caixa, para que o resplendor a cubra inteira
    local dx = math.max(cx, w - cx)
    local dy = math.max(cy, h - cy)
    outer = math.sqrt(dx * dx + dy * dy)
  end
  local half = math.rad(opts.ray_deg or 4.5) / 2
  local rot  = opts.rotate or 0
  cr:save()
  cr:rectangle(0, 0, w, h); cr:clip()
  cr:set_source_rgba(r, g, b, alpha)
  for i = 0, rays - 1 do
    local a0 = rot + i * (2 * math.pi / rays)
    cr:move_to(cx + inner * math.cos(a0 - half), cy + inner * math.sin(a0 - half))
    cr:line_to(cx + outer * math.cos(a0 - half), cy + outer * math.sin(a0 - half))
    cr:line_to(cx + outer * math.cos(a0 + half), cy + outer * math.sin(a0 + half))
    cr:line_to(cx + inner * math.cos(a0 + half), cy + inner * math.sin(a0 + half))
    cr:close_path()
  end
  cr:fill()
  cr:restore()
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA IX — shapes.halo(cr, w, h[, opts])
-- Funcção urdida pelo Doutor Braga Us: o HALO da estampa — annel tracejado
-- (ou, querendo-se, PONTILHADO) que cinge a cabeça do eidolon. Serve de guia
-- á órbita do lançador e de adôrno ao vazio central do donut.
--   DOMÍNIO       : cr, w, h e `opts` = { color=p.data2, alpha=0.5,
--                   cx=w/2, cy=h/2, r=min(w,h)/2 - line_width,
--                   line_width=dpi(2), dash={dpi(2), dpi(5)},
--                   dot=false (verdadeiro -> pontos redondos: dash {0, passo}
--                   com remate LINE_CAP.ROUND, o pontilhado verdadeiro),
--                   start_angle=0 (offset do tracejado, radianos) }.
--   CONTRA-DOMÍNIO: o vácuo; o effeito é o annel pintado.
--   INVARIANTE    : o par save/restore restitue TAMBÉM o padrão de traço e o
--                   remate (dash e line_cap pertencem ao estado gráphico do
--                   cairo), de sorte que nenhum pintor subsequente herde o
--                   pontilhado por descuido. Q.E.D.
function shapes.halo(cr, w, h, opts)
  opts = opts or {}
  local r, g, b = p.rgb(opts.color or p.data2)
  local alpha   = opts.alpha or 0.5
  local lw      = opts.line_width or dpi(2)
  local cx      = opts.cx or w / 2
  local cy      = opts.cy or h / 2
  local radius  = opts.r or (math.min(w, h) / 2 - lw)
  if radius <= 0 then return end
  cr:save()
  cr:rectangle(0, 0, w, h); cr:clip()
  cr:set_source_rgba(r, g, b, alpha)
  cr:set_line_width(lw)
  if opts.dot then
    local step = (opts.dash and opts.dash[2]) or dpi(5)
    cr:set_line_cap(cairo.LineCap.ROUND)
    cr:set_dash({ 0, lw + step }, 0)
  else
    cr:set_dash(opts.dash or { dpi(2), dpi(5) }, 0)
  end
  cr:arc(cx, cy, radius, opts.start_angle or 0, (opts.start_angle or 0) + 2 * math.pi)
  cr:stroke()
  cr:restore()
end

return shapes
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
