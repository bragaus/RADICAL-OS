-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO SEGMENTO-CHEVRON GENÉRICO — src/molecules/chevron_seg.lua
--
--  Casca powerline REUTILIZÁVEL (a mesma arte das tags/tasklist): uma seta de dous tons —
--  orla (edge) por baixo, enchimento (fill) recuado 1.5px por cima — que ENVOLVE um conteúdo
--  qualquer (texto/ícone/systray). Ao contrário de tag_tab/app_lozenge (presos a tag/cliente),
--  este aceita `content` arbitrário, direção (`point_left`) e posição na fita (`terminus`), de
--  sorte que a fita da DIREITA da barra superior se erga espelhada (apontando à esquerda) com
--  o mesmo chevron roxo do resto. — na tradição do Doutor Braga Us.
--
--    local chevron_seg = require("src.molecules.chevron_seg")
--    local seg = chevron_seg { content = w, terminus = true, on_click = fn }
--    seg:set_active(true)   -- acende (fill claro + orla glow_ice), p.ex. dashboard aberto
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful  = require("awful")
local gears  = require("gears")
local wibox  = require("wibox")
local dpi    = require("beautiful").xresources.apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local shapes = require("src.tools.shapes")

-- Gradiente vertical (180º) na altura `h` — auxiliar de Braga Us.
local function vgrad(h, stops)
  return gears.color { type = "linear", from = { 0, 0 }, to = { 0, h }, stops = stops }
end

-- Funcção CARDEAL. Domínio: táboa `args`. Contra-domínio: um widget-segmento powerline
-- munido de :set_active. Os invólucros guardam-se em referências directas (R1); hover e
-- toque atam-se UMA só vez (R7).
local function chevron_seg(args)
  args = args or {}
  local height     = args.height or dpi(mt.topbar_h)
  local point_left = args.point_left ~= false        -- por defeito aponta à ESQUERDA (fita da direita)
  local terminus   = args.terminus and true or false
  local do_hover   = args.hover ~= false
  local tip        = dpi(mt.powerline_tip)
  local pad_l      = args.pad_l or (tip + dpi(4))     -- simétrico: centra o conteúdo entre os divisores diagonais
  local pad_r      = args.pad_r or (tip + dpi(4))

  -- paletas (kit .tag): repouso vs aceso (== tag seleccionada).
  local EDGE_REST, EDGE_ON = p.glow_soft, p.glow_ice
  local FILL_REST = vgrad(height, { { 0, p.v700 }, { 0.6, p.v800 }, { 1, p.v900 } })
  local FILL_ON   = vgrad(height, { { 0, p.v400 }, { 0.6, p.v600 }, { 1, p.v700 } })

  -- fórma: intermediários = socket (encaixe); terminus = vértice convexo. Espelhada se point_left.
  local arrow = terminus
    and shapes.powerline { point_left = point_left, flat_left = false }
    or  shapes.powerline { point_left = point_left, socket = true }

  local content_wrap = wibox.widget {
    { args.content, valign = "center", halign = "center", widget = wibox.container.place },
    left = pad_l, right = pad_r, widget = wibox.container.margin,
  }

  local inner = wibox.widget {
    content_wrap, bg = FILL_REST, shape = arrow, widget = wibox.container.background,
  }
  local outer = wibox.widget {
    { inner, margins = dpi(1.5), widget = wibox.container.margin },
    bg            = EDGE_REST,
    shape         = arrow,
    forced_height = height,
    widget        = wibox.container.background,
  }
  outer._preserve_colors = true

  -- ---- estado (aceso) + hover -------------------------------------------------
  outer._active, outer._hovered = false, false
  function outer:apply_state()
    if self._active then
      inner.bg, self.bg = FILL_ON, EDGE_ON
    elseif self._hovered then
      inner.bg, self.bg = FILL_REST, EDGE_ON
    else
      inner.bg, self.bg = FILL_REST, EDGE_REST
    end
  end
  function outer:set_active(on)
    self._active = on and true or false
    self:apply_state()
  end

  if do_hover then
    outer:connect_signal("mouse::enter", function()
      outer._hovered = true; outer:apply_state()
      local wb = mouse.current_wibox; if wb then wb.cursor = "hand1" end
    end)
    outer:connect_signal("mouse::leave", function()
      outer._hovered = false; outer:apply_state()
      local wb = mouse.current_wibox; if wb then wb.cursor = "left_ptr" end
    end)
  end

  if args.on_click then
    outer:buttons(gears.table.join(awful.button({}, 1, function() args.on_click() end)))
  end

  return outer
end

return chevron_seg

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
