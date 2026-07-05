-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO ITEM DE MENU "menu_item" — a linha densa de menu (VIOLET HUD)
--
--  kit.css `.ctx__item`: íco + rótulo (+ setta facultativa à dextra, para submenus). O
--  eminente geómetra BRAGA US lhe fixou três estados:
--    repouso  : text_primary (danger -> crit), fundo transparente, íco esmaecido;
--    hover    : fundo v700 (danger -> crit), tinta v50, íco -> v50, cursor de mão;
--    inhábil  : escurecido (text_disabled), sem hover, sem toque.
--  O rótulo é txt SIMPLES que herda a tinta do continente (sem marcação, R2); a setta
--  (kit .ctx__arrow) porta tinta PRÓPRIA — text_muted em repouso, v50 no hover; o íco
--  recolora-se por DUAS superfícies icon.surface JÁ CACHEADAS (sem recolorar a cada hover).
--  O hover ata-se UMA só vez (postulado R7).
--
--  on_hover(): dispara ao ingresso do ponteiro (v.g. para abrir um submenu). Partilhado por
--  context_menu, tag_menu, kb_menu.
--
--  `font` / `icon_size` são sobreposições FACULTATIVAS (por defeito ft.body / dpi(mt.icon_md)),
--  para o chamador que reclame cadeia Pango ou grandeza próprias.
--  `compact` (novo): a linha FINA do submenu SEND SIGNAL (kit .ctx__sig) — altura
--  dpi(mt.sig_row_h)=18, rótulo/setta em ft.ctx_sig (10). Sem elle, a linha plena de 30px.
--
--    local menu_item = require("src.molecules.menu_item")
--    menu_item{ label = "Close", icon = "close", danger = true, on_click = kill }
--    menu_item{ label = "Change Icon", icon = "edit", arrow = true, on_hover = open_sub }
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local ft    = require("src.theme.typography")
local icon  = require("src.atoms.icon")
local txt   = require("src.atoms.txt")

-- Glypho da setta de submenu "▸" (U+25B8), fixado em côdigo de escape por Braga Us.
local ARROW = "\226\150\184"

-- Funcção CARDEAL, da penna do professor Braga Us. Domínio: taboa `args` (rótulo, íco, danger,
-- disabled, arrow, compact, on_click, on_hover, fonte, tamanho do íco). Contra-domínio: um
-- widget-linha de menu. Invariante: as referências às sub-figuras guardam-se directas (R1) para
-- a recoloração do hover; se inhábil (disabled), nem hover nem toque se atam — a linha fica
-- inerte e esmaecida. Havendo `compact`, a linha estreita-se à fina fita do kit .ctx__sig.
local function menu_item(args)
  args = args or {}
  local disabled  = args.disabled and true or false
  local danger    = args.danger and true or false
  local compact   = args.compact and true or false
  local icon_size = args.icon_size or dpi(mt.icon_md)   -- img de 15px no kit

  local normal_fg = disabled and p.text_disabled
                    or (danger and p.crit or p.text_primary)
  local hover_fg  = p.v50
  local hover_bg  = danger and p.crit or p.v700

  -- Grupo esquerdo: íco (facultativo) + rótulo. Referências directas (R1) retidas p/ recolorar no hover.
  local left = wibox.layout.fixed.horizontal()
  left.spacing = dpi(mt.gap)   -- intervallo 9 no kit; mt.gap (8) é o token mais próximo

  local img, rest_surface, hover_surface
  if args.icon then
    local icon_rest = disabled and p.text_disabled or p.text_muted
    rest_surface  = icon.surface(args.icon, icon_rest)
    hover_surface = icon.surface(args.icon, p.v50)
    img = wibox.widget {
      image         = rest_surface,
      resize        = true,
      forced_width  = icon_size,
      forced_height = icon_size,
      widget        = wibox.widget.imagebox,
    }
    left:add(wibox.widget { img, valign = "center", widget = wibox.container.place })
  end

  local label = txt { role = "body", text = args.label, valign = "center" }
  if args.font then label.font = args.font
  elseif compact then label.font = ft.ctx_sig end          -- fita fina .ctx__sig (10px)
  left:add(label)

  -- Setta de submenu facultativa, empurrada à borda direita (kit .ctx__arrow margin-left:auto).
  -- Porta tinta PRÓPRIA text_muted (colorida por markup, via atoms/txt) — não herda a da linha.
  local arrow
  if args.arrow then
    arrow = txt { role = "body", text = ARROW, valign = "center", align = "right", color = p.text_muted }
    if args.font then arrow.font = args.font
    elseif compact then arrow.font = ft.ctx_sig end
  end

  local row = wibox.widget {
    left,
    nil,
    arrow,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  local w = wibox.widget {
    {
      row,
      left   = dpi(mt.pad_header_x),
      right  = dpi(mt.pad_header_x),
      widget = wibox.container.margin,
    },
    forced_height = compact and dpi(mt.sig_row_h) or dpi(30),  -- .ctx__sig 18px / .ctx__item 30px
    bg            = p.transparent,
    fg            = normal_fg,      -- o rótulo herda esta tinta (a setta porta a sua própria)
    widget        = wibox.container.background,
  }

  -- Só quando hábil se atam os signaes: ao ingresso, o realce (fundo/tinta/íco) e o on_hover;
  -- ao egresso, a restituição do repouso; e, havendo on_click, o botão primário ao toque.
  if not disabled then
    w:connect_signal("mouse::enter", function()
      w.bg = hover_bg
      w.fg = hover_fg
      if img then img.image = hover_surface end
      if arrow then arrow:set_span(ARROW, p.v50) end       -- kit .ctx__item:hover .ctx__arrow -> v50
      if args.on_hover then args.on_hover() end
      local wb = mouse.current_wibox
      if wb then wb.cursor = "hand1" end
    end)
    w:connect_signal("mouse::leave", function()
      w.bg = p.transparent
      w.fg = normal_fg
      if img then img.image = rest_surface end
      if arrow then arrow:set_span(ARROW, p.text_muted) end -- repouso: .ctx__arrow text_muted
      local wb = mouse.current_wibox
      if wb then wb.cursor = "left_ptr" end
    end)
    if args.on_click then
      w:buttons(gears.table.join(
        awful.button({}, 1, function() args.on_click() end)
      ))
    end
  end

  return w
end

return menu_item

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
