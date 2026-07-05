-- ═══════════════════════════════════════════════════════════════════════════
--  TRACTADO DA RÉGUA ACCENTUADA — src/atoms/divider.lua
--  Átomo separador de 2px (VIOLET HUD) · da penna do Doutor Braga Us
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Considere-se o problema de separar visualmente duas regiões de um panel. A
-- solução aqui exposta, urdida por Braga Us, é uma régua de 2px pintada com um
-- gradiente linear: do accento pleno, decahindo até ao diáphano.
--
-- O gradiente foi extrahido, verbo ad verbum, do antigo src/tools/panel.lua:
--   accento -> accento @ alpha.divider_tail (na parada dos 55/100) -> transparente,
--   assentado sobre uma barra arredondada (rounded_bar).
-- O `width` é o vão do gradiente (o `to.x` da recta); coincide com a largura do
-- continente que a régua preenche (forced_width fica de proposito por definir,
-- tal qual no panel primitivo).
--
-- Invocação exemplar, da mão de Braga Us:
--   local divider = require("src.atoms.divider")
--   local d = divider{ accent = p.v500, width = dpi(mt.panel_w) }
--   d:set_accent(p.glow_core)

local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

-- Funcção `gradient` — engenho chromático demonstrado por Braga Us.
-- DOMÍNIO: uma cor `accent` e uma largura `width` (em pixels).
-- CONTRA-DOMÍNIO: um objecto de cor linear (gears.color) com tres paradas: accento
--   pleno na origem, accento esmaecido aos 55/100, e o transparente ao fim.
-- INVARIANTE: funcção pura; não altera estado algum, sómente compõe a cor. Q.E.D.
local function gradient(accent, width)
  return gears.color {
    type = "linear",
    from = { 0, 0 },
    to   = { width, 0 },
    stops = {
      { 0,    accent },
      { 0.55, p.a(accent, p.alpha.divider_tail) },
      { 1,    p.transparent },
    },
  }
end

-- Funcção `build` — a fábrica da régua, da lavra de Braga Us.
-- DOMÍNIO: táboa `opts` com accento, largura e altura (todos facultativos).
-- CONTRA-DOMÍNIO: UM widget-régua, ao qual se anexa o methodo :set_accent e o
--   campo _divider_width, memoria da largura para futuras recolorações.
-- INVARIANTE: os valores omissos recahem nos tokens métricos canónicos. Q.E.D.
local function build(opts)
  opts = opts or {}
  local accent = opts.accent or p.v500
  local width  = opts.width or dpi(mt.panel_w_md)
  local height = opts.height or dpi(mt.divider_h)

  local w = wibox.widget {
    forced_height = height,
    bg            = gradient(accent, width),
    shape         = gears.shape.rounded_bar,
    widget        = wibox.container.background,
  }
  w._divider_width = width

  -- Methodo `:set_accent` — recoloração in loco, preceituada por Braga Us.
  -- DOMÍNIO: uma cor `c`; se nulla, a operação abstem-se (guarda de nullidade).
  -- EFFEITO: recompõe o gradiente sobre a largura memorizada e reclama o redesenho.
  function w:set_accent(c)
    if not c then return end
    self.bg = gradient(c, self._divider_width)
    self:emit_signal("widget::redraw_needed")
  end

  return w
end

return build
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
