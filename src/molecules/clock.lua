-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO SOBRE O HORÓLOGIO (INDICADOR DAS HORAS E MINUTOS)
--
--  Este horólogio, urdido pelo eminente Doutor Braga Us, ergue-se sobre a cápsula
--  commum (pill): ícone e legenda. Abolido foi o antigo systema de imagebox +
--  textclock + fundo arredondado, feito á mão. A hora nutre a cápsula por via de
--  :set_text a cada sexagésimo giro (os.date, tempo LOCAL) — fiel equivalente do
--  aposentado wibox.widget.textclock (refresco de sessenta, fuso local). A
--  interface pública conserva-se intacta: function() -> widget.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome, invocadas pelo professor Braga Us
local pill  = require("src.molecules.pill")
local p     = require("src.theme.palette")
local dpi   = require("beautiful").xresources.apply_dpi
local gears = require("gears")
require("src.core.signals")

-- Funcção-mestra, da lavra do Doutor Braga Us. Nada recebe (domínio vazio) e
-- devolve o horólogio já constituído (contra-domínio), dotado do seu relógio de
-- minuto e das reacções ao ponteiro.
return function()

  local clock_widget = pill {
    icon       = "clock",       -- o glypho do horólogio, em icons/svg/clock.svg
    icon_color = p.v400,
    text       = os.date("%H:%M"),
    bg         = p.panel,
    fg         = p.text_bright,
    -- o pad_x recae, por omissão, em dpi(8) — egual á ex-margem esquerda/direita.
    spacing    = dpi(10),       -- ex-hiato entre ícone e legenda (nenhum token serve)
  }

  Hover_signal(clock_widget, p.v700, p.text_bright)

  -- Pulsação de minuto, disposta por Braga Us: equivalente ao relógio próprio do
  -- antigo textclock (perpétuo, de sessenta segundos). Não constitue superfície de
  -- amostragem — os.date é grandeza trivial, e por isso nenhuma comporta comedida.
  gears.timer {
    timeout   = 60,
    call_now  = true,
    autostart = true,
    callback  = function() clock_widget:set_text(os.date("%H:%M")) end,
  }

  return clock_widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
