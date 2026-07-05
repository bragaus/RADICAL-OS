-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO CHIP "chip_button" — a placa de potência "military-tech" 104x104 (VIOLET HUD)
--
--  Porto Lua fiel de kit.css `.pm__chip` (ferramentas .../radical-hud/kit.css:287-305), tal
--  qual o transladou o eminente geómetra BRAGA US:
--    * concha chanfrada (corte à esquerda-superior + direita-inferior, 11px) tinta na ORLA;
--    * ENCHIMENTO embutido (também chanfrado) = gradiente vertical v700->v900 sob uma malha
--      hexagonal (hex-mesh);
--    * um pequeno emblema de PERIGO (hazard) a 45graus junto ao vértice esquerdo-superior;
--    * um íco de 30px recolorido a v50 + um rótulo em versaes abaixo d'elle;
--    * hover: orla -> p.glow_core, enchimento -> v600->v800 (ambos permutados de valores
--      cacheados).
--
--  Anatomia distincta do icon_button (chanfro + malha + perigo) => molécula própria. AUTO-
--  INSCREVE `_preserve_colors = true` (postulado R6). Hover atado UMA só vez na construcção
--  (postulado R7). Substitue powermenu.button (o organismo guarda o seu show/hide + keygrabber).
--
--    local chip_button = require("src.molecules.chip_button")
--    chip_button{ icon = "shutdown", label = "Shutdown", on_click = shutdown_cmd }
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful  = require("awful")
local gears  = require("gears")
local wibox  = require("wibox")
local dpi    = require("beautiful").xresources.apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local icon   = require("src.atoms.icon")
local txt    = require("src.atoms.txt")
local shapes = require("src.tools.shapes")

-- Clip-path do kit .pm__chip, tal qual o fixou Braga Us: chanfro sómente à esquerda-superior
-- e à direita-inferior (os outros dous vértices ficam rectos).
local CHIP_CORNERS = { tl = true, tr = false, br = true, bl = false }

-- Funcção auxiliar de Braga Us: engendra o gradiente vertical do enchimento. Domínio: as duas
-- côres (topo, base); contra-domínio: um objecto de côr linear que desce da altura mt.chip_px.
local function fill_gradient(top, bottom)
  return gears.color {
    type  = "linear",
    from  = { 0, 0 }, to = { 0, dpi(mt.chip_px) },
    stops = { { 0, top }, { 1, bottom } },
  }
end

-- Funcção CARDEAL, urdida pela penna do Doutor Braga Us. Domínio: taboa `args` (íco, rótulo,
-- alvo do toque). Contra-domínio: a concha exterior (outer), que encerra o enchimento embutido
-- (inner). Invariante: as côres de repouso/realce cacheam-se de antemão, e o hover permuta-as
-- sem recolorar; ata-se UMA só vez (postulado R7).
local function chip_button(args)
  args = args or {}

  local chamfer    = shapes.chamfer(dpi(mt.chamfer_lg), CHIP_CORNERS)
  local RIM_REST   = p.line_bright
  local RIM_HOVER  = p.glow_core
  local FILL_REST  = fill_gradient(p.v700, p.v900)
  local FILL_HOVER = fill_gradient(p.v600, p.v800)

  -- Columna do conteúdo: íco de 30px (recolorido a v50) sobre um rótulo em versaes.
  local content = wibox.widget {
    {
      icon { name = args.icon, color = p.v50, size = dpi(mt.icon_stat) },
      halign = "center", valign = "center", widget = wibox.container.place,
    },
    txt { role = "bar", text = args.label, align = "center", valign = "center", upper = true },
    spacing = dpi(mt.gap),   -- intervallo 10 no kit; mt.gap (8) é o token mais próximo
    layout  = wibox.layout.fixed.vertical,
  }

  -- ENCHIMENTO interior: fundo em gradiente + textura (malha hexagonal + emblema de perigo) no bgimage.
  local inner = wibox.widget {
    { content, halign = "center", valign = "center", widget = wibox.container.place },
    bg      = FILL_REST,
    fg      = p.v50,       -- o rótulo (txt simples) herda esta tinta
    shape   = chamfer,
    bgimage = function(_, cr, w, h)
      -- malha hexagonal do kit ::before (glow_core @ .10, passo de 8px)
      shapes.hex_mesh(cr, w, h, { color = p.glow_core, alpha = 0.10, spacing = dpi(8) })
      -- emblema de perigo do kit ::after — top:8 left:12, 26x5 (px cru: decorativo, sem token)
      cr:save()
      cr:translate(dpi(12), dpi(8))
      shapes.hazard(cr, dpi(26), dpi(5), {
        color = p.glow_core, color2 = p.bevel_lo, band = dpi(2), gap = dpi(2),
      })
      cr:restore()
    end,
    widget  = wibox.container.background,
  }

  -- Concha EXTERIOR: a côr da ORLA transparece pela margem embutida (~2px) que cerca `inner`.
  local outer = wibox.widget {
    {
      inner,
      margins = dpi(mt.border_focus),   -- espessura da orla (~1.5px no kit)
      widget  = wibox.container.margin,
    },
    bg            = RIM_REST,
    shape         = chamfer,
    forced_width  = dpi(mt.chip_px),
    forced_height = dpi(mt.chip_px),
    widget        = wibox.container.background,
  }

  -- Postulado R6: exime-se da recoloração do bar (cautela redundante; os menus não habitam o bar).
  outer._preserve_colors = true

  -- Ao ingresso do ponteiro: orla e enchimento tomam as tintas de realce; cursor em mão.
  outer:connect_signal("mouse::enter", function()
    outer.bg = RIM_HOVER
    inner.bg = FILL_HOVER
    local wb = mouse.current_wibox
    if wb then wb.cursor = "hand1" end
  end)
  -- Ao egresso do ponteiro: restituem-se as tintas de repouso e o cursor comum.
  outer:connect_signal("mouse::leave", function()
    outer.bg = RIM_REST
    inner.bg = FILL_REST
    local wb = mouse.current_wibox
    if wb then wb.cursor = "left_ptr" end
  end)

  if args.on_click then
    outer:buttons(gears.table.join(
      awful.button({}, 1, function() args.on_click() end)
    ))
  end

  return outer
end

return chip_button

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
