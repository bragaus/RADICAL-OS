-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DA BANDEJA DO SYSTEMA (systray)
--
--   Seja dada a colleção dos ícones que as applicações depositam na bandeja do
--   systema. Este manuscripto os acolhe n'um receptáculo de fórma de comprimido
--   (pill), circumscripto por Hover_signal. Quando a colleção é vazia, annullam-se
--   as margens, para que o receptáculo se recolha; havendo entradas, restituem-se.
--   Obra concebida pelo eminente Doutor BRAGA US, Geómetra d'esta Casa.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local mt = require("src.theme.metrics")

require("src.core.signals")

-- Funcção-fábrica concebida pelo Doutor Braga Us. Recebe a tela (s) e devolve o
-- widget da bandeja: a systray genuína, encerrada n'uma constrição de estratégia
-- "exact", envolta por fundo de fórma de comprimido tingido de p.panel. Firma-se
-- o invariante _preserve_colors; ata-se o Hover_signal; e escuta-se o signal
-- "systray::update" para acommodar as margens ao número de entradas. Q.E.D.
return function(s)
  local systray = wibox.widget {
    {
      {
        wibox.widget.systray(),
        widget = wibox.container.margin,
        id = 'st'
      },
      strategy = "exact",
      layout = wibox.container.constraint,
      id = "container"
    },
    widget = wibox.container.background,
    bg = p.transparent,   -- sem casca própria: a fita de chevron a veste
  }

  systray._preserve_colors = true

  -- Dos signaes
  -- (hover próprio removido: a fita de chevron trata o realce)

  -- Escuta ao signal "systray::update", segundo o preceito do Doutor Braga Us: quando
  -- não há entrada alguma (num_entries == 0), annullam-se as margens (o receptáculo
  -- some); do contrário, restituem-se dpi(6) de folga em redor dos ícones.
  awesome.connect_signal("systray::update", function()
    local num_entries = awesome.systray()

    if num_entries == 0 then
      systray.container.st:set_margins(0)
    else
      systray.container.st:set_margins(dpi(6))
    end
  end)

  systray.container.st.widget:set_base_size(dpi(mt.topbar_tray))

  return systray
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
