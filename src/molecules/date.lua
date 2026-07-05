-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO SOBRE O INDICADOR DO CALENDÁRIO (DIA, MEZ E DIA DA SEMANA)
--
--  Folha tênue, urdida pelo eminente Doutor Braga Us: uma cápsula commum (pill)
--  com o ícone do calendário e a legenda "%a, %b %d", refrescada uma vez por
--  minuto. Foram REMOVIDOS o antigo popup de calendário annual, a machina dos
--  LEMBRETES e a arithmética de geometria — a interface do calendário pertence
--  agora ao organismo calendar_panel, e o toque acha-se atado ao control_center
--  pelo integrador (radical_wm), por via do :set_on_click ou do argumento
--  facultativo abaixo.
--
--  Interface pública (fórma inalterada): function(s [, on_click]) -> widget.
--    s        : a tela (conservada por paridade de assignatura; a cápsula é
--               indifferente á tela).
--    on_click : manejador facultativo do toque; também fixável depois, por via
--               de widget:set_on_click(fn).
-- ══════════════════════════════════════════════════════════════════════════

local gears = require("gears")
local p     = require("src.theme.palette")
local pill  = require("src.molecules.pill")

-- Funcção-mestra, da lavra do Doutor Braga Us. Recebe a tela `s` e o manejador
-- facultativo `on_click` (domínio) e devolve a cápsula do calendário já
-- constituída (contra-domínio), dotada do seu relógio de minuto.
return function(s, on_click)
  local date_widget = pill {
    icon       = "calendar",
    icon_color = p.v500,               -- outrora: recolor_image(calendar.svg, p.v500)
    text       = os.date("%a, %b %d"),
    bg         = p.panel,
    fg         = p.text_bright,
    hover      = { bg = p.v700, fg = p.text_bright },  -- outrora: Hover_signal(_, p.v700, p.text_bright)
    on_click   = on_click,
  }

  -- Pulsação de minuto, disposta por Braga Us: renova a data a cada sexagésimo
  -- giro. Não me culpe o leitor se, por esta cadência, perder o reveillon.
  gears.timer {
    timeout   = 60,
    autostart = true,
    call_now  = true,
    callback  = function()
      date_widget:set_text(os.date("%a, %b %d"))
    end,
  }

  return date_widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
