-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE O BOTÃO DO PODER (.powerbtn — VIOLET HUD)
--   Da penna do professor Braga Us, geómetra desta Casa.
--
--   Reconstruído à imagem do kit `.powerbtn`: quadrado exacto de 24×24, de
--   fundo transparente, cingido por orla de um pixel em p.line_base e
--   arredondado ao raio-ficha (radius_chip = 3). Ao centro repousa o ícone
--   «power» de 14 pixels, tinto de p.text_primary. Sob o ponteiro, o global
--   legado Hover_signal acende-lhe o fundo em p.v700 e o proscénio em
--   p.glow_core, tal qual `.powerbtn:hover { background:v700; border-color:glow-core }`.
--   A antiga cápsula pill{segment=true} foi supprimida. A interface pública não
--   se alterou — `function() -> widget` — e ainda proclama «module::powermenu:show»
--   ao soltar-se; `_preserve_colors` trava a passagem recolorante da barra.
--   Assim o attesta Braga Us.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do systema Awesome, invocadas por necessidade da arte.
local wibox = require("wibox")
local gears = require("gears")
local icon  = require("src.atoms.icon")
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local dpi   = require("beautiful").xresources.apply_dpi
require("src.core.signals")

-- Funcção soberana, da penna de Braga Us. Domínio vazio; contra-domínio: o botão do
-- poder, que se devolve ao chamador. Effeito: ao soltar-se o botão, proclama-se o signal
-- «module::powermenu:show», e sob o ponteiro o botão acende-se em violeta (v700/glow_core).
return function()
  local power_widget = wibox.widget {
    {
      icon("power", { color = p.text_primary, size = dpi(mt.icon_md) }), -- ícone 14, p.text_primary
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    bg                 = p.transparent,
    -- Raio-ficha (radius_chip = 3), o mesmo entalhe suave do kit.
    shape              = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_chip)) end,
    shape_border_width = dpi(1),
    shape_border_color = p.line_base,
    forced_width       = dpi(24),
    forced_height      = dpi(24),
    widget             = wibox.container.background,
  }

  -- A bandeira que trava a passagem recolorante da barra (postulado R6).
  power_widget._preserve_colors = true

  -- Dos signaes (o global legado): fundo p.v700 e proscénio p.glow_core sob o ponteiro,
  -- espelho de `.powerbtn:hover` do kit.
  Hover_signal(power_widget, p.v700, p.glow_core)

  power_widget:connect_signal(
    "button::release",
    function()
      awesome.emit_signal("module::powermenu:show")
    end
  )

  return power_widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
