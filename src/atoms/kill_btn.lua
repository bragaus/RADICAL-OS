-- ═══════════════════════════════════════════════════════════════════════════
--  TRACTADO DO BOTÃO OCCISOR — src/atoms/kill_btn.lua
--  Átomo alvo de SIGTERM · da penna do Doutor Braga Us
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Alvo de 28px portando, ao centro, o glypho "kill" de 14px. Ao sobrevoo, o ícone
-- permuta de esmaecido para p.crit por meio de DOIS estados de superfície PRÉ-
-- GUARDADOS (icon.surface) — SEM recoloração a cada sobrevoo (a qual sangrava e
-- reparseava o SVG a cada ingresso). Esta parcimónia é demonstração de Braga Us.
--
-- A SEMÂNTICA da occisão permanece no callback on_kill do chamador (c:kill() /
-- awful.spawn({"kill", pid}) — JAMAIS os.execute). Este átomo sómente a dispara.
--
-- Invocação exemplar:
--   local kill_btn = require("src.atoms.kill_btn")
--   local w = kill_btn{ on_kill = function() awful.spawn({"kill", pid}) end }
--   w:set_on_kill(fn)   -- reata o alvo quando uma linha de pool é reaproveitada
--
-- Requer o átomo icon (mesma camada, sanccionado pelo §2, que aqui impõe
-- icon.surface); e mais src.theme + awful/gears/wibox.

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local icon  = require("src.atoms.icon")

-- Funcção `kill_btn` — a fábrica do botão occisor, da lavra de Braga Us.
-- DOMÍNIO: táboa `args` com o callback `on_kill`. CONTRA-DOMÍNIO: um widget-alvo
--   que reage ao sobrevoo e ao click, e aceita o methodo :set_on_kill.
local function kill_btn(args)
  args = args or {}
  local kill_cb = args.on_kill

  -- Dois estados guardados UMA vez na construcção (jamais recoloridos por sobrevoo).
  local rest_surface = icon.surface("kill", p.text_muted)
  local hot_surface  = icon.surface("kill", p.crit)

  local img = wibox.widget {
    image         = rest_surface,
    resize        = true,
    forced_width  = dpi(mt.kill_icon),
    forced_height = dpi(mt.kill_icon),
    widget        = wibox.widget.imagebox,
  }

  -- Alvo de 28px; ícone ao centro. A altura decorre da linha que o encerra.
  local w = wibox.widget {
    img,
    halign       = "center",
    valign       = "center",
    forced_width = dpi(mt.kill_w),
    widget       = wibox.container.place,
  }

  w:connect_signal("mouse::enter", function()
    img.image = hot_surface
    local wb = mouse.current_wibox
    if wb then wb.cursor = "hand2" end
  end)
  w:connect_signal("mouse::leave", function()
    img.image = rest_surface
    local wb = mouse.current_wibox
    if wb then wb.cursor = "left_ptr" end
  end)

  w:buttons(gears.table.join(
    awful.button({}, 1, function()
      if kill_cb then kill_cb() end
    end)
  ))

  -- Methodo `:set_on_kill` — amigo do pool de linhas, preceito de Braga Us.
  -- DOMÍNIO: uma funcção `fn`. EFFEITO: reata o alvo da occisão sem reconstruir o widget.
  function w:set_on_kill(fn)
    kill_cb = fn
  end

  return w
end

return kill_btn
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
