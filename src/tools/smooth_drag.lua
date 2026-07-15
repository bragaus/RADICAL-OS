-- ══════════════════════════════════════════════════════════════════════════
-- TRACTADO DO ARRASTO COMPASSADO (smooth_drag) — src/tools/smooth_drag.lua
--
-- Seja dado o arrasto d'uma janella fluctuante. O caminho clássico
-- (awful.mouse.client.move) escreve a geometria A CADA evento de motion do
-- rato — d'onde um rato de 500/1000Hz commanda outras tantas repinturas de
-- écran INTEIRO no compositor (use-damage há-de ficar false nesta GPU), e
-- mesmo a 125Hz o compasso dos quadros segue o compasso IRREGULAR dos eventos,
-- não o do monitor → judder. Demonstra-se aqui o remédio: o caçador-de-rato
-- apenas ANOTA a última posição (custo ínfimo por evento), e UM timer de
-- quadro (1/user_vars.performance.refresh_rate, 165 no DP-0) applica a
-- geometria QUANDO MUITO uma vez por quadro — compasso parelho, cravado na
-- taxa do monitor, indifferente ao Hz do rato. Ao largar, applica-se a
-- posição final EXACTA, com íman de borda (snap) á área de trabalho.
--
-- As janellas LADRILHADAS seguem delegadas ao awful (a troca de posições no
-- leiaute é semântica d'elle, não geometria livre). — Braga Us.
--
--   local smooth_drag = require("src.tools.smooth_drag")
--   smooth_drag.move(c)     -- modkey + botão 1 (client_buttons)
--   smooth_drag.resize(c)   -- modkey + botão 3 (client_buttons)
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")
local dpi   = require("beautiful").xresources.apply_dpi

local M = {}

local RATE = (user_vars and user_vars.performance and user_vars.performance.refresh_rate) or 60
local DT   = 1 / RATE
local SNAP = dpi(10)   -- íman de borda ao largar (o awful usa 8; 10 é mais dócil no ultrawide)
local MIN  = dpi(30)   -- grandeza mínima a que um redimensionar pode reduzir a janella

-- Predicado: a janella rege-se por geometria LIVRE (fluctuante de facto)?
local function is_floating(c)
  return c.floating or awful.layout.get(c.screen) == awful.layout.suit.floating
end

-- Predicado: admitte-se sequer arrastá-la?
local function draggable(c)
  return c and c.valid and not c.fullscreen
    and c.type ~= "desktop" and c.type ~= "splash" and c.type ~= "dock"
end

-- Íman de borda, applicado UMA vez ao largar: estando a orla externa (com a
-- bordadura) a menos de SNAP px d'um limite da área de trabalho, crava-se rente.
local function snap_edges(x, y, w, h, c)
  local wa = c.screen.workarea
  local bw = c.border_width or 0
  local ow, oh = w + 2 * bw, h + 2 * bw
  if math.abs(x - wa.x) <= SNAP then x = wa.x end
  if math.abs((x + ow) - (wa.x + wa.width)) <= SNAP then x = wa.x + wa.width - ow end
  if math.abs(y - wa.y) <= SNAP then y = wa.y end
  if math.abs((y + oh) - (wa.y + wa.height)) <= SNAP then y = wa.y + wa.height - oh end
  return x, y
end

-- ── O MOVER COMPASSADO ──────────────────────────────────────────────────────
function M.move(c)
  c = c or client.focus
  if not draggable(c) or mousegrabber.isrunning() then return end
  if not is_floating(c) then
    return awful.mouse.client.move(c)   -- ladrilhada: a troca de posições fica com o awful
  end
  if c.maximized then c.maximized = false end

  local g  = c:geometry()
  local m0 = mouse.coords()
  local dx, dy = m0.x - g.x, m0.y - g.y          -- offset do ponto de agarre
  local last_x, last_y, dirty = m0.x, m0.y, false

  local tick = gears.timer {
    timeout   = DT,
    autostart = true,
    callback  = function()
      if dirty and c.valid then
        dirty = false
        c:geometry { x = last_x - dx, y = last_y - dy }
      end
    end,
  }

  mousegrabber.run(function(m)
    if not c.valid then tick:stop(); return false end
    if not m.buttons[1] then
      tick:stop()
      local x, y = snap_edges(m.x - dx, m.y - dy, g.width, g.height, c)
      c:geometry { x = x, y = y }               -- posição final EXACTA (+ íman)
      return false
    end
    last_x, last_y = m.x, m.y                    -- só anota; quem escreve é o tick
    dirty = true
    return true
  end, "fleur")
end

-- ── O REDIMENSIONAR COMPASSADO ──────────────────────────────────────────────
-- A quina mais próxima do ponteiro no agarre decide quaes orlas seguem o rato
-- (mesma eleição do awful). As demais ficam pregadas.
function M.resize(c)
  c = c or client.focus
  if not draggable(c) or mousegrabber.isrunning() then return end
  if not is_floating(c) then
    return awful.mouse.client.resize(c)
  end
  if c.maximized then c.maximized = false end

  local g  = c:geometry()
  local m0 = mouse.coords()
  local right  = m0.x >= g.x + g.width / 2
  local bottom = m0.y >= g.y + g.height / 2
  local cursor = (bottom and "bottom" or "top") .. (right and "_right_corner" or "_left_corner")
  local hints  = c.size_hints or {}
  local min_w  = math.max(hints.min_width or 0, MIN)
  local min_h  = math.max(hints.min_height or 0, MIN)
  local last_x, last_y, dirty = m0.x, m0.y, false

  local function target()
    local x, y, w, h = g.x, g.y, g.width, g.height
    if right then
      w = last_x - g.x
    else
      x = math.min(last_x, g.x + g.width - min_w)
      w = g.x + g.width - x
    end
    if bottom then
      h = last_y - g.y
    else
      y = math.min(last_y, g.y + g.height - min_h)
      h = g.y + g.height - y
    end
    return { x = x, y = y, width = math.max(w, min_w), height = math.max(h, min_h) }
  end

  local tick = gears.timer {
    timeout   = DT,
    autostart = true,
    callback  = function()
      if dirty and c.valid then
        dirty = false
        c:geometry(target())
      end
    end,
  }

  mousegrabber.run(function(m)
    if not c.valid then tick:stop(); return false end
    if not (m.buttons[1] or m.buttons[3]) then
      tick:stop()
      c:geometry(target())                      -- grandeza final EXACTA
      return false
    end
    last_x, last_y = m.x, m.y
    dirty = true
    return true
  end, cursor)
end

return M

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
