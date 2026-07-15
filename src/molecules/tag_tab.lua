-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DA ABA "tag_tab" — a aba powerline de sentido único (VIOLET HUD §7.2, kit .tag)
--
--  Considere-se uma aba em fórma de setta apontando à dextra (flanco esquerdo chato, ponta
--  direita aguda — NÃO um losango bidireccional) que ostenta íco + índice + rótulo. O
--  eminente geómetra BRAGA US a compôs de dous tons: a orla (edge, exterior, pela borda da
--  fórma) sobreposta a um enchimento de gradiente vertical (interior, pintado via bgimage
--  já com a altura verdadeira). Esta construcção substitue o corpo de aba outr'ora urdido à
--  mão a cada actualização em taglist.lua; a taglist possue o widget e os botões do awful e
--  conduz UMA tag_tab por objecto.
--
--  Do CARACTER apresentativo e reutilizável (amigo do pool):
--    :set_state{ selected=, occupied=, urgent=, hover= } — recolora orla/enchimento/conteúdo.
--    :set_label(index, name, icon_name)                  — actualiza índice + nome + íco.
--
--  Dos ESTADOS (kit .tag--*): vazio/occupado partilham um mesmo enchimento; sómente o
--  seleccionado é mais claro; o urgente arde; o hover impõe uma orla glow_ice. Os ícos são
--  vectoriaes (SVG) via atoms/icon (os codepoints MDI aqui saem em branco — postulado R11).
--  Conteúdo em versaes (maiúsculas), conforme o kit.
-- ══════════════════════════════════════════════════════════════════════════════════════

local wibox  = require("wibox")
local gears  = require("gears")
local dpi    = require("beautiful").xresources.apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local icon   = require("src.atoms.icon")
local txt    = require("src.atoms.txt")
local shapes = require("src.tools.shapes")

-- Taboa das paletas por estado (kit colors_and_type.css / kit.css .tag--*), como a fixou
-- o Doutor Braga Us: a cada estado corresponde uma terna { orla, enchimento, tinta }.
local STATES = {
  empty    = { edge = p.glow_soft, fill = { { 0, p.v700 }, { 0.6, p.v800 }, { 1, p.v900 } }, fg = p.glow_ice },
  occupied = { edge = p.glow_soft, fill = { { 0, p.v700 }, { 0.6, p.v800 }, { 1, p.v900 } }, fg = p.glow_ice },
  -- Na aba eleita, tinta ESCURA sobre o enchimento claro (inversão da tinta):
  -- a silhueta sobre o fulgor, tal qual o eidolon ante o sol. — Braga Us.
  selected = { edge = p.glow_ice, fill = { { 0, p.v400 }, { 0.6, p.v600 }, { 1, p.v700 } }, fg = p.v975 },
  urgent   = { edge = p.glow_hot, fill = { { 0, p.glow_hot }, { 1, p.v700 } }, fg = p.v50 },
}

-- Funcção CARDEAL, urdida pelo Doutor Braga Us. Domínio: taboa `args` (íco inicial etc.).
-- Contra-domínio: um widget-aba dotado de :set_state e :set_label. Invariante: os átomos
-- guardam-se em referências directas (R1); a aba é reutilizável (amiga do pool), pois todo
-- estado se muda por recoloração in loco, sem reconstruir a figura.
local function tag_tab(args)
  args = args or {}
  local tip = dpi(mt.powerline_tip) -- 12

  -- Referências directas (postulado R1).
  local icon_img = wibox.widget { resize = true, forced_width = dpi(mt.topbar_icon), forced_height = dpi(mt.topbar_icon), valign = "center", halign = "center", widget = wibox.widget.imagebox }
  local icon_place = wibox.widget { icon_img, valign = "center", halign = "center", widget = wibox.container.place }
  local index_box = txt { role = "fill_tag", align = "center", valign = "center" }
  local name_box  = txt { role = "fill_tag", align = "center", valign = "center", upper = true }

  local state = STATES.empty
  local icon_name = args.icon or "term"

  local content = wibox.widget {
    icon_place, index_box, name_box,
    spacing = dpi(mt.pad_row_y) * 2, -- ~6, intervallo do .tag__content (kit)
    layout  = wibox.layout.fixed.horizontal,
  }

  -- Invólucro portador da tinta (fg): as caixas de texto simples d'ella herdam a côr, que
  -- se recolora à mudança de estado.
  local fg_wrap = wibox.widget { content, fg = state.fg, widget = wibox.container.background }

  local shape_fn = shapes.powerline { tip = tip, flat_left = true }
  local d = dpi(mt.tick_stroke) -- 1.4, o recúo do enchimento (kit .tag__fill inset:1.4px)

  -- Funcção pintora de Braga Us, ora em DUAS (com o alvo, TRÊS) camadas — kit .tag__edge
  -- + .tag__fill — em substituição da antiga orla centrada de shape_border (cuja metade
  -- vazava para fóra da fórma e, com a sobreposição das abas, se corrompia). A saber:
  --   (1) a orla — a fórma cheia, na côr da aresta (o rim de `d` transparece);
  --   (2) o enchimento — a MESMA fórma, recuada de `d` por todos os flancos, vertida de
  --       gradiente vertical;
  --   (3) o alvo de topo — box-shadow inset 0 1px 0 rgba(214,194,255,.35), ainda no clip
  --       interno. Argumentos: contexto cairo cr, largura w, altura h.
  local function paint_fill(_, cr, w, h)
    -- camada 1 — .tag__edge
    cr:save()
    shape_fn(cr, w, h)
    cr:clip()
    cr:set_source_rgb(p.rgb(state.edge))
    cr:paint()
    cr:restore()

    -- camada 2 — .tag__fill inset:1.4px (fórma recuada numa caixa (w-2d)x(h-2d))
    cr:save()
    cr:translate(d, d)
    shape_fn(cr, w - 2 * d, h - 2 * d)
    cr:clip()
    cr:set_source(gears.color { type = "linear", from = { 0, 0 }, to = { 0, h - 2 * d }, stops = state.fill })
    cr:paint()
    -- camada 3 — o alvo de topo (inset 0 1px 0 glow_ice@.35)
    local hr, hg, hb = p.rgb(p.glow_ice)
    cr:set_source_rgba(hr, hg, hb, 0.35)
    cr:rectangle(0, 0, w - 2 * d, dpi(1))
    cr:fill()
    cr:restore()
  end

  local w = wibox.widget {
    {
      fg_wrap,
      left = dpi(mt.tag_pad_l), right = dpi(mt.tag_pad_r), -- kit .tag__content padding 0 20 0 18
      top = 0, bottom = 0,
      widget = wibox.container.margin,
    },
    bg            = p.transparent,
    bgimage       = paint_fill,    -- a orla e o enchimento pintam-se em camadas (vide supra)
    shape         = shape_fn,      -- recorte externo: o conteúdo não transborda a fórma
    forced_height = dpi(mt.topbar_h), -- barra de cima: a aba (e a sua ponta-chevron) enche a altura do wibox
    widget        = wibox.container.background,
  }

  -- Funcção auxiliar de Braga Us: applica o estado corrente — verte a tinta ao invólucro,
  -- pinta a orla e requisita novo desenho (redraw). Sem argumentos; effeito puramente visual.
  local function apply()
    fg_wrap.fg = state.fg
    w:emit_signal("widget::redraw_needed") -- o redraw reexecuta paint_fill, lendo o novo `state`
  end

  -- ---- superfície de actualização (interface de Braga Us) --------------------
  -- Escrólio: elege o estado por precedência (urgente > seleccionado > occupado > vazio),
  -- consultando a taboa STATES; o hover impõe a orla clara sem mudar o enchimento; enfim
  -- repinta-se o íco com a nova tinta e applica-se tudo.
  function w:set_state(st)
    st = st or {}
    local key = st.urgent and "urgent"
      or st.selected and "selected"
      or st.occupied and "occupied"
      or "empty"
    state = STATES[key]
    -- o hover impõe a orla brilhante sem alterar o enchimento (kit .tag:hover).
    if st.hover then
      state = { edge = p.glow_ice, fill = state.fill, fg = state.fg }
    end
    icon_img.image = icon.surface(icon_name, state.fg)
    apply()
  end

  -- Escrólio: actualiza índice, nome e íco. Argumentos guardados por nil (só se muda o que
  -- não for nulo); ao fim, repinta-se o íco com a tinta do estado vigente.
  function w:set_label(index, name, name_icon)
    if index ~= nil then index_box:set_text(tostring(index)) end
    if name ~= nil then name_box:set_text(name) end
    if name_icon ~= nil then icon_name = name_icon end
    icon_img.image = icon.surface(icon_name, state.fg)
  end

  -- pintura primeva (estado inicial)
  icon_img.image = icon.surface(icon_name, state.fg)
  apply()

  return w
end

return tag_tab

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
