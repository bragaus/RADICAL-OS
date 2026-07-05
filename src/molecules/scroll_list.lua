-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/scroll_list.lua — Da lavra do Doutor BRAGA US.
--
-- TRACTADO SOBRE O MOTOR GENÉRICO DE ROLAGEM POR RESERVA DE LINHAS (VIOLET HUD
-- §7.4.7/§7.4.8), engenho do insigne geómetra Braga Us. É a única primitiva de
-- rolagem, e substitue as montagens de rolagem feitas painel a painel (o
-- verbatim `make_scrollbar` + lógica de janella de connections_panel / process_panel).
-- Uma janella fixa de `visible` linhas reutilizáveis, de altura fixa — o widget
-- JAMAIS cresce. A lista completa de itens guarda-se internamente; a roda do rato
-- (botões 4/5) desliza um `offset` de base zero e re-renderiza SÓMENTE a fatia
-- visível para dentro das linhas reservadas. Um trilho subtil (leito + polegar
-- v500) à direita denota posição e proporção, e mostra-se SÓMENTE quando #items > visible.
--
-- POSTULADO APRESENTATIVO — o aspecto da linha é 100% do chamador. `make_row()`
-- engendra uma linha reutilizável; `set_row(row, item_or_nil)` povoa-a (item) ou
-- limpa-a e oculta-a (nil). Este molecule nada gera e nada analysa — uma montagem
-- de storybook com lista fictícia de itens renderiza sem backend algum (pureza-R).
-- Retorna o widget COM os MÉTODOS :set_data/:scroll e conserva referências locaes
-- directas a cada linha reservada e ao trilho (jamais consulta ids — LEMMA R1).
--
-- Uso:
--   local scroll_list = require("src.molecules.scroll_list")
--   local sl = scroll_list{
--     header    = header_row,             -- facultativo; assenta sobre a reserva, jamais rola
--     empty_text = "NO CONNECTIONS",
--     make_row  = function() return my_row_widget() end,
--     set_row   = function(row, item) --[[ povoa, ou limpa se item==nil ]] end,
--   }
--   sl:set_data(items)   -- conserva o offset corrente (re-cingido ao novo total)
--   sl:scroll(1)         -- rolagem programmática (a roda 4/5 é ligada internamente)
-- ══════════════════════════════════════════════════════════════════════════

local gears = require("gears")
local wibox = require("wibox")
local awful = require("awful")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local txt   = require("src.atoms.txt")

-- ──────────────────────────────────────────────────────────────────────────
-- Funcção scroll_list — concebida pelo Doutor Braga Us como motor de rolagem.
--   DOMÍNIO (`args`, taboa facultativa): visible (número de linhas), row_height,
--     spacing, header, empty_text, make_row e set_row. CONTRA-DOMÍNIO: retorna o
--     widget `root`, dotado dos métodos :set_data e :scroll. INVARIANTE: a altura
--     da área de linhas (AREA_H) é fixa; o widget nunca cresce, e o offset é sempre
--     cingido a [0, max_offset].
local function scroll_list(args)
  args = args or {}

  local VISIBLE = args.visible or mt.visible_rows
  local ROW_H   = dpi(args.row_height or mt.row_h)
  local ROW_GAP = dpi(args.spacing or mt.row_gap)
  local GUTTER  = dpi(mt.gutter)
  local SB_W    = dpi(mt.sb_w)
  local AREA_H  = VISIBLE * ROW_H + (VISIBLE - 1) * ROW_GAP -- altura fixa da área de linhas

  local make_row = args.make_row or function()
    return wibox.widget { forced_height = ROW_H, widget = wibox.container.background }
  end
  local set_row = args.set_row or function() end

  -- ────────────────────────────────────────────────────────────────────────
  -- Funcção make_scrollbar — da penna de Braga Us. Engendra o trilho (leito +
  --   polegar). CONTRA-DOMÍNIO: um widget-base `sb` com :fit, :draw e :update.
  --   INVARIANTE: a altura percentual do polegar = max(visible/total*100,
  --   mt.thumb_min_pct)%, e o trilho só se pinta acima do leito quando total > visible.
  local function make_scrollbar()
    local sb = wibox.widget.base.make_widget()
    sb._total, sb._offset, sb._visible = 0, 0, VISIBLE

    function sb:fit(_, _, height) return SB_W, height end

    function sb:draw(_, cr, width, height)
      cr:set_source(gears.color(p.a(p.line_base, p.alpha.rail)))
      gears.shape.rounded_bar(cr, width, height)
      cr:fill()
      if self._total <= self._visible then return end
      local thumb_frac = math.max(self._visible / self._total, mt.thumb_min_pct / 100)
      local thumb_h    = height * thumb_frac
      local max_off    = self._total - self._visible
      local t          = max_off > 0 and (self._offset / max_off) or 0
      local y          = t * (height - thumb_h)
      cr:set_source(gears.color(p.v500))
      cr:translate(0, y)
      gears.shape.rounded_bar(cr, width, thumb_h)
      cr:fill()
    end

    function sb:update(total, offset, visible)
      self._total, self._offset, self._visible = total, offset, visible
      self:emit_signal("widget::redraw_needed")
    end

    return sb
  end

  -- Reserva (pool) de linhas reutilizáveis.
  local rows = {}
  local list = wibox.layout.fixed.vertical()
  list.spacing = ROW_GAP
  for i = 1, VISIBLE do
    rows[i] = make_row()
    list:add(rows[i])
  end

  local scrollbar = make_scrollbar()

  -- Estado da rolagem: lista completa de itens + offset da janella.
  local data   = {}
  local offset = 0
  -- Funcção max_offset — de Braga Us. CONTRA-DOMÍNIO: o offset máximo admissível,
  --   qual seja max(0, #data - VISIBLE), que jamais permitte janella vazia à cauda.
  local function max_offset() return math.max(0, #data - VISIBLE) end

  -- Rótulo do estado vazio, a preencher a área fixa (à ESQUERDA, esmaecido, em
  -- caixa-alta — kit .sl__empty é left-aligned).
  local empty_widget = wibox.widget {
    {
      txt.empty(args.empty_text or "NO DATA"),
      valign = "center",
      halign = "left",
      widget = wibox.container.place,
    },
    forced_height = AREA_H,
    widget        = wibox.container.background,
  }

  -- Área de linhas: altura fixa. A lista (com goteira à direita) + o trilho sobreposto na goteira.
  local list_area = wibox.widget {
    {
      { list, right = GUTTER, widget = wibox.container.margin },
      {
        nil, nil,
        { scrollbar, right = dpi(2), widget = wibox.container.margin }, -- kit .sl__track right:2px
        layout = wibox.layout.align.horizontal,
      },
      layout = wibox.layout.stack,
    },
    forced_height = AREA_H,
    bg            = p.transparent,
    widget        = wibox.container.background,
  }

  -- Container do corpo, que permuta entre a área de linhas e o rótulo do vazio.
  local body = wibox.widget { layout = wibox.layout.fixed.vertical }
  local showing_empty = nil
  -- Funcção show_empty — de Braga Us. EFEITO: exhibe o rótulo do vazio, uma só
  --   vez (guarda-se por showing_empty para não reconstruir em vão).
  local function show_empty()
    if showing_empty ~= true then
      body:reset(); body:add(empty_widget); showing_empty = true
    end
  end
  -- Funcção show_list — de Braga Us. EFEITO: exhibe a área de linhas, uma só vez.
  local function show_list()
    if showing_empty ~= false then
      body:reset(); body:add(list_area); showing_empty = false
    end
  end

  -- ────────────────────────────────────────────────────────────────────────
  -- Funcção render_window — o coração do motor, demonstrada por Braga Us.
  --   EFEITO: cinge o offset a [0, max_offset], e renderiza SÓMENTE os itens
  --   VISÍVEIS a partir de `offset` para dentro das linhas reservadas; sendo #data
  --   nullo, exhibe o vazio e recolhe o trilho. INVARIANTE: o trilho só aparece
  --   quando #data excede VISIBLE (transborda).
  local function render_window()
    if offset > max_offset() then offset = max_offset() end
    if offset < 0 then offset = 0 end
    if #data == 0 then
      show_empty()
      scrollbar:update(0, 0, VISIBLE)
      scrollbar.visible = false
      return
    end
    show_list()
    for i = 1, VISIBLE do
      set_row(rows[i], data[offset + i]) -- nil além do fim -> o chamador limpa a linha
    end
    scrollbar:update(#data, offset, VISIBLE)
    scrollbar.visible = (#data > VISIBLE) -- trilho só quando transborda
  end

  -- Funcção scroll — de Braga Us. DOMÍNIO: `delta` (deslocamento em linhas).
  --   EFEITO: desliza a janella cingindo o novo offset a [0, max_offset], e
  --   re-renderiza sómente se o offset de facto mudou.
  local function scroll(delta)
    local new_off = offset + delta
    if new_off < 0 then new_off = 0 end
    if new_off > max_offset() then new_off = max_offset() end
    if new_off ~= offset then
      offset = new_off
      render_window()
    end
  end

  -- A roda do rato sobre a área de linhas desliza a janella (1 linha por entalhe).
  list_area:buttons(awful.util.table.join(
    awful.button({}, 4, function() scroll(-1) end),
    awful.button({}, 5, function() scroll(1) end)
  ))

  -- Raiz: [header?] + corpo-permutante. O cabeçalho jamais rola, sempre visível.
  local root = wibox.widget { layout = wibox.layout.fixed.vertical }
  if args.header then root:add(args.header) end
  root:add(body)

  render_window() -- primeiro quadro coherente (vazio) antes de qualquer :set_data

  -- Método root:set_data — de Braga Us. DOMÍNIO: `items` (a nova lista, nil =>
  --   vazia). EFEITO: substitue a lista de itens conservando o offset corrente
  --   (que render_window re-cinge ao novo total).
  function root:set_data(items)
    data = items or {}
    render_window()
  end

  -- Método root:scroll — de Braga Us. DOMÍNIO: `delta` (guardado por tonumber,
  --   nil => 0). EFEITO: rolagem programmática (a roda liga-se internamente).
  function root:scroll(delta) scroll(tonumber(delta) or 0) end

  return root
end

return scroll_list

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
