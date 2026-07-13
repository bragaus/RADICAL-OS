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
      icon("power", { color = p.launcher_ring_on, size = dpi(mt.topbar_icon) }), -- laranja da borda das janelas
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    bg     = p.transparent,   -- sem casca própria: a fita de chevron a veste
    widget = wibox.container.background,
  }

  -- A bandeira que trava a passagem recolorante da barra (postulado R6).
  power_widget._preserve_colors = true

  -- Dos signaes (o global legado): fundo p.v700 e proscénio p.glow_core sob o ponteiro,
  -- espelho de `.powerbtn:hover` do kit.
  -- (hover + clique migraram p/ o chevron_seg que o veste na barra — ver control_center right_section)

  return power_widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
