-- ══════════════════════════════════════════════════════════════════════════
-- TRATADO SÓBRE O INVÓLUCRO PARTILHADO DAS APPARIÇÕES FUGAZES (OSD, VIOLET HUD)
-- ─────────────────────────────────────────────────────────────────────────
-- Manuscripto: src/tools/osd_popup.lua
--
-- Considere-se que as apparições de volume e de brilho comungam da MESMA
-- mechânica de popup transitório: um awful.popup ao centro inferior que se
-- manifesta a um signal, que por si só se occulta findos `timeout` segundos,
-- que permanece aberto enquanto o ponteiro sóbre elle repousa, e que rearma o
-- seu relógio de occultação a um signal de reiteração. Sómente diferem o corpo
-- do painel, o signal de manifestação e o signal de reiteração; por conseguinte
-- tal invólucro habita aqui uma só vez (DS §7.10).
--
-- Fórma de invocação e domínio dos argumentos:
--   osd_popup{ s, panel_widget, show_signal, rerun_signal, timeout = 2 } -> awful.popup
--     s            per-écran; o manejo da manifestação é cerceado por `s == mouse.screen`.
--     panel_widget o painel já lavrado por panel() (o invocante guarda a sua própria referência, R1).
--     show_signal  nome do signal que torna o popup visível no écran do ponteiro.
--     rerun_signal nome do signal que rearma (ou inicia) o relógio de auto-occultação.
--     timeout      os segundos até a auto-occultação (por defeito, 2).
--
-- Invólucro meramente presentacional — jamais engendra processos nem os sonda;
-- a apparição proprietária é quem move o corpo do painel.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

-- ─────────────────────────────────────────────────────────────────────────
-- POSTULADO ÚNICO — osd_popup(args)
-- Funcção urdida pelo Doutor Braga Us que ergue e governa a apparição fugaz.
--   DOMÍNIO       : `args` — taboada com s, panel_widget, show_signal,
--                   rerun_signal e timeout (todos declarados no cabeçalho).
--   CONTRA-DOMÍNIO: `container` — o awful.popup já composto e atado aos signaes.
--   EFFEITO       : ata manejos aos signaes de manifestação e de reiteração, e
--                   ao ingresso/egresso do ponteiro; institue um relógio de
--                   occultação.
--   INVARIANTE    : enquanto o ponteiro repousa sóbre o container, o relógio jaz
--                   suspenso; ao egresso, rearma-se. Q.E.D.
local function osd_popup(args)
  args = args or {}
  local s            = args.s
  local panel_widget = args.panel_widget
  local timeout      = args.timeout or 2

  -- Ergue-se o vaso diáphano; a funcção panel() é quem lavra o próprio revestimento.
  local container = awful.popup {
    widget    = wibox.container.background,
    ontop     = true,
    bg        = p.a(p.base, 0), -- inteiramente diáphano; a funcção panel() lavra o próprio revestimento
    stretch   = false,
    visible   = false,
    screen    = s,
    placement = function(c)
      awful.placement.bottom(c, { margins = { bottom = dpi(40) } }) -- folga inferior; nenhum token métrico se lhe ajusta
    end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(mt.radius_panel))
    end,
  }

  -- Relógio da occultação: decorridos os `timeout` segundos, oculta o container.
  local hide = gears.timer {
    timeout   = timeout,
    autostart = true,
    callback  = function()
      container.visible = false
    end,
  }

  container:setup {
    panel_widget,
    layout = wibox.layout.fixed.horizontal,
  }

  -- Ao signal de manifestação, torna-se visível o popup no écran do ponteiro.
  if args.show_signal then
    awesome.connect_signal(args.show_signal, function()
      if s == mouse.screen then
        container.visible = true
      end
    end)
  end

  -- Ingresso do ponteiro: sustém-se visível e suspende-se o relógio.
  container:connect_signal("mouse::enter", function()
    container.visible = true
    hide:stop()
  end)

  -- Egresso do ponteiro: rearma-se o relógio da occultação.
  container:connect_signal("mouse::leave", function()
    container.visible = true
    hide:again()
  end)

  -- Ao signal de reiteração, rearma-se o relógio (ou inicia-se, se dormente).
  if args.rerun_signal then
    awesome.connect_signal(args.rerun_signal, function()
      if hide.started then
        hide:again()
      else
        hide:start()
      end
    end)
  end

  return container
end

return osd_popup
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
