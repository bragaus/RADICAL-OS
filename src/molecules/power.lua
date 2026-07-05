-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE A LOZANGA DO PODER (VIOLET HUD)
--   Da penna do professor Braga Us, geómetra desta Casa.
--
--   Reconstruída sobre a molécula partilhada `pill` (em modo de segmento). A
--   antiga cápsula de ícone-e-fundo, lavrada à mão, foi supprimida; pill{
--   segment=true } por si mesma iça a bandeira `_preserve_colors` e espelha os
--   indícios vestigiaes `_segment_*`, de sorte que este artefacto permaneça um
--   substituto fiel ao byte para o segmento do radical_bar (defeito R6). A
--   interface pública não se alterou — `function() -> widget`; ainda proclama
--   `module::powermenu:show` ao soltar-se, e ainda arde em p.crit sob o ponteiro,
--   pelo global legado Hover_signal. Assim o attesta Braga Us.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do systema Awesome, invocadas por necessidade da arte.
local pill = require("src.molecules.pill")
local p    = require("src.theme.palette")
local mt   = require("src.theme.metrics")
local dpi  = require("beautiful").xresources.apply_dpi
require("src.core.signals")

-- Funcção soberana, da penna de Braga Us. Domínio vazio; contra-domínio: a lozanga do
-- poder, que se devolve ao chamador. Effeito: ao soltar-se o botão, proclama-se o signal
-- «module::powermenu:show», e a lozanga realça-se em vermelho crítico sob o ponteiro.
return function()
  local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
  local segment_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.segment or 0.90)
  -- `p.a` é o porto endurecido de colors.with_alpha (idêntica saída «#RRGGBBAA»).
  local segment_bg = p.a(p.panel, segment_alpha)

  -- Lozanga de segmento, sómente com ícone. `icon_size` e `pad_x` fixados aos valores
  -- do antigo widget de poder (18 e 10), de sorte que o segmento renderizado seja fiel
  -- ao pixel; `segment=true` semeia os indícios _segment_* (44x46 preferido, bg==edge),
  -- exactamente como outrora fazia o widget — assim o certifica o Doutor Braga Us.
  local power_widget = pill {
    icon          = "power",
    icon_color    = p.text_primary,
    icon_size     = dpi(mt.icon_row),  -- 18, o constrangimento do ícone do antigo poder
    label_visible = false,
    segment       = true,
    bg            = segment_bg,
    fg            = p.text_primary,
    pad_x         = dpi(mt.seg_pad_x), -- 10, a margem esquerda/direita do antigo poder
  }

  -- Dos signaes (o global legado; p.crit -> «#fb5e8add» sob o ponteiro, tal qual o original).
  Hover_signal(power_widget, p.crit, p.text_primary)

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
