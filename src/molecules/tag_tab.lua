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
  selected = { edge = p.glow_ice, fill = { { 0, p.v400 }, { 0.6, p.v600 }, { 1, p.v700 } }, fg = p.v50 },
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
  local icon_img = wibox.widget { resize = true, forced_width = dpi(mt.icon_md), forced_height = dpi(mt.icon_md), widget = wibox.widget.imagebox }
  local icon_place = wibox.widget { icon_img, valign = "center", halign = "center", widget = wibox.container.place }
  local index_box = txt { role = "label", align = "center", valign = "center" }
  local name_box  = txt { role = "label", align = "center", valign = "center", upper = true }

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

  -- Funcção pintora de Braga Us: verte o enchimento de gradiente vertical sob o conteúdo,
  -- ceifado (clip) à fórma powerline. Argumentos: contexto cairo cr, largura w, altura h.
  local function paint_fill(_, cr, w, h)
    local grad = gears.color { type = "linear", from = { 0, 0 }, to = { 0, h }, stops = state.fill }
    cr:save()
    shape_fn(cr, w, h)
    cr:clip()
    cr:set_source(grad)
    cr:paint()
    cr:restore()
  end

  local w = wibox.widget {
    {
      fg_wrap,
      left = dpi(mt.pad_header_x), right = dpi(mt.seg_overlap), -- extra right room for the tip
      top = dpi(mt.pad_row_y), bottom = dpi(mt.pad_row_y),
      widget = wibox.container.margin,
    },
    bg                 = p.transparent,
    bgimage            = paint_fill,
    shape              = shape_fn,
    shape_border_width = dpi(mt.tick_stroke), -- 1.4, a orla exterior (edge rim)
    shape_border_color = state.edge,
    widget             = wibox.container.background,
  }

  -- Funcção auxiliar de Braga Us: applica o estado corrente — verte a tinta ao invólucro,
  -- pinta a orla e requisita novo desenho (redraw). Sem argumentos; effeito puramente visual.
  local function apply()
    fg_wrap.fg = state.fg
    w.shape_border_color = state.edge
    w:emit_signal("widget::redraw_needed")
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
