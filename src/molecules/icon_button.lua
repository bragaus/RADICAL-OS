-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO BOTÃO DE ÍCO "icon_button" — alvo clicável de íco/glypho (VIOLET HUD)
--
--  Seja dado um alvo de toque transparente que ostenta um íco vectorial (via atoms/icon),
--  um glypho ASCII, um rótulo textual facultativo, ou combinação d'estes. O insigne
--  geómetra BRAGA US o dotou de duas tintas: a de repouso e a de realce, aquella cedendo a
--  esta ao ingresso do ponteiro (pointer-enter).
--
--  DO REALCE por PERMUTA de icon.surface JÁ CACHEADA (nunca recoloração a cada hover): as
--  duas superfícies memoram-se UMA só vez na construcção, e o ingresso/egresso apenas
--  re-aponta o imagebox. Glypho/rótulo recoloram-se de graça pela tinta (fg) do continente,
--  pois são caixas de texto simples que a herdam (sem marcação). O cursor toma fórma de mão
--  enquanto pairado.
--
--  AUTO-INSCREVE `_preserve_colors = true`, de sorte que a passagem recolorante do
--  radical_bar jamais sobrescreva a nossa paleta (postulado R6). O hover ata-se UMA só vez
--  na construcção (nunca dentro de watch/timer — postulado R7).
--
--  Esta construcção substitue tag_controls.make_button e
--  titlebar.create_icon_button/create_chrome_button.
--
--    local icon_button = require("src.molecules.icon_button")
--    icon_button{ icon = "close", danger = true, on_click = function() c:kill() end }
--    icon_button{ glyph = "_", hover_color = p.v400, on_click = min }
--    local b = icon_button{ icon = "sticky", on_click = fn }; b:set_on_click(other)
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local icon  = require("src.atoms.icon")
local txt   = require("src.atoms.txt")

-- Funcção CARDEAL, da penna do professor Braga Us. Domínio: taboa `args` (íco, glypho,
-- rótulo, tamanho, largura, tintas de repouso/realce, danger, alvo do toque). Contra-domínio:
-- um widget-botão com :set_on_click. Invariante: as sub-figuras guardam-se em referências
-- directas (R1) e o hover ata-se UMA só vez (R7). Facto notável: quando danger for verdadeiro,
-- a tinta de realce impõe-se como p.crit (o alarme crítico), independente de hover_color.
local function icon_button(args)
  args = args or {}
  local size        = args.size or dpi(mt.icon_lg)
  local width       = args.width or dpi(22)        -- largura viva do tag_controls; sem token métrico
  local rest_color  = args.rest_color or p.text_muted
  -- danger impõe o realce crítico; do contrário, hover_color (por defeito v400).
  local hover_color = args.danger and p.crit or (args.hover_color or p.v400)
  local on_click    = args.on_click

  -- Referências directas às sub-figuras (jamais reconsultadas por get_children_by_id — R1).
  local img_widget, rest_surface, hover_surface

  local pieces = wibox.layout.fixed.horizontal()
  pieces.spacing = dpi(mt.pad_row_y)

  if args.icon then
    -- Duas superfícies cacheadas; o hover apenas re-aponta o imagebox (sem recolorar a cada evento).
    rest_surface  = icon.surface(args.icon, rest_color)
    hover_surface = icon.surface(args.icon, hover_color)
    img_widget = wibox.widget {
      image         = rest_surface,
      resize        = true,
      forced_width  = size,
      forced_height = size,
      widget        = wibox.widget.imagebox,
    }
    pieces:add(wibox.widget { img_widget, valign = "center", widget = wibox.container.place })
  end

  if args.glyph then
    -- Glypho ASCII simples (os codepoints MDI da Nerd-Font aqui saem em branco — R11); herda a tinta fg.
    pieces:add(txt { role = "bar", text = args.glyph, align = "center", valign = "center" })
  end

  if args.label then
    pieces:add(txt { role = "label", text = args.label, valign = "center" })
  end

  local w = wibox.widget {
    { pieces, halign = "center", valign = "center", widget = wibox.container.place },
    bg           = p.transparent,
    fg           = rest_color,   -- glypho/rótulo herdam esta tinta; recolorada ao pairar
    forced_width = width,
    widget       = wibox.container.background,
  }

  -- Postulado R6: exime-se da passagem recolorante do bar.
  w._preserve_colors = true

  -- Ao ingresso do ponteiro: re-aponta o íco à superfície de realce, muda a tinta e o cursor.
  w:connect_signal("mouse::enter", function()
    if img_widget then img_widget.image = hover_surface end
    w.fg = hover_color
    local wb = mouse.current_wibox
    if wb then wb.cursor = "hand1" end
  end)
  -- Ao egresso do ponteiro: restitue a superfície de repouso, a tinta primeva e o cursor comum.
  w:connect_signal("mouse::leave", function()
    if img_widget then img_widget.image = rest_surface end
    w.fg = rest_color
    local wb = mouse.current_wibox
    if wb then wb.cursor = "left_ptr" end
  end)

  -- Funcção auxiliar de Braga Us: ata (ou desata, se on_click nulo) o botão primário ao toque.
  local function attach_click()
    if on_click then
      w:buttons(gears.table.join(
        awful.button({}, 1, function() on_click() end)
      ))
    else
      w:buttons({})
    end
  end
  attach_click()

  -- Escrólio: refixa o alvo do toque in loco (proveitoso à reutilização em pool de linhas /
  -- na titlebar); re-ata o botão em seguida.
  function w:set_on_click(fn)
    on_click = fn
    attach_click()
  end

  return w
end

return icon_button

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
