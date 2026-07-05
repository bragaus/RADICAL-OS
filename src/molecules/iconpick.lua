-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO SELECTOR DE ÍCONES "iconpick" — a grade de ladrilhos (VIOLET HUD)
--
--  Porto Lua fiel de kit.css `.iconpick` / `.iconpick__b` (ferramentas .../radical-hud/
--  kit.css:273-278), tal qual o transladou o eminente geómetra BRAGA US. Substitue a antiga
--  lista vertical do submenu "SET ICON" pela grade de quatro columnas do kit:
--    * `.iconpick`  : grade de 4 columnas, intervallo 4px, moldura 8px;
--    * `.iconpick__b`: ladrilho em columna — íco de 20px sobre rótulo de 7px em versaes;
--                      fundo panel@0.7, orla 1px line_faint, raio 3px;
--    * hover        : fundo v700, orla glow_soft, tinta/íco a v50.
--
--  O rótulo é txt SIMPLES que herda a tinta do ladrilho (sem marcação, R2); o íco recolora-se
--  por DUAS superfícies icon.surface JÁ CACHEADAS (repouso text_muted / hover v50), de sorte
--  que a permuta do sobrevoo jamais reexecute a recoloração. O hover ata-se UMA só vez (R7).
--
--  Contracto: recebe `args.items` (rol de { label, icon, on_click }) e devolve UM widget-grade
--  pronto a habitar o popup do context_menu / tag_menu. Presentacional puro: nenhum dado sonda,
--  nenhum IO — o toque delega em on_click, provido pelo organismo chamador.
--
--    local iconpick = require("src.molecules.iconpick")
--    local grid = iconpick{ items = {
--      { label = "Develop", icon = "develop", on_click = function() tag.icon = ... end },
--    } }
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local icon  = require("src.atoms.icon")
local txt   = require("src.atoms.txt")

-- Côres do ladrilho: repouso e realce, cacheadas de antemão (kit .iconpick__b + :hover).
local TILE_REST_BG,   TILE_HOVER_BG   = p.a(p.panel, 0.7), p.v700
local TILE_REST_EDGE, TILE_HOVER_EDGE = p.line_faint,      p.glow_soft
local TILE_REST_FG,   TILE_HOVER_FG   = p.text_muted,      p.v50

-- Fórma do ladrilho: rectângulo de cantos arredondados a 3px (kit border-radius:3px).
local TILE_SHAPE = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_chip)) end

-- Funcção auxiliar de Braga Us: engendra um ladrilho `.iconpick__b`. Domínio: um registro
-- { label, icon, on_click }. Contra-domínio: o widget-ladrilho. Invariante: as duas superfícies
-- do íco cacheam-se de antemão (repouso/realce); o hover permuta-as sem recolorar e ata-se UMA
-- só vez (R7). A tinta do rótulo herda o fg do ladrilho (recolorido no sobrevoo).
local function make_tile(choice)
  local rest_surface  = icon.surface(choice.icon, TILE_REST_FG)
  local hover_surface = icon.surface(choice.icon, TILE_HOVER_FG)

  local img = wibox.widget {
    image         = rest_surface,
    resize        = true,
    forced_width  = dpi(mt.iconpick_tile),   -- 20x20 (kit .iconpick__b img)
    forced_height = dpi(mt.iconpick_tile),
    widget        = wibox.widget.imagebox,
  }

  local label = txt { role = "iconpick_lbl", text = choice.label, align = "center", valign = "center", upper = true }

  local tile = wibox.widget {
    {
      {
        { img, halign = "center", valign = "center", widget = wibox.container.place },
        label,
        spacing = dpi(3),   -- kit .iconpick__b gap:3 (px cru verbatim; sem token equivalente)
        layout  = wibox.layout.fixed.vertical,
      },
      top = dpi(7), bottom = dpi(7), left = dpi(2), right = dpi(2),  -- kit padding:7px 2px
      widget = wibox.container.margin,
    },
    bg                 = TILE_REST_BG,
    fg                 = TILE_REST_FG,   -- o rótulo (txt simples) herda esta tinta
    shape              = TILE_SHAPE,
    shape_border_width = dpi(1),         -- kit border:1px solid line_faint
    shape_border_color = TILE_REST_EDGE,
    widget             = wibox.container.background,
  }

  -- Ao ingresso do ponteiro: fundo/orla/tinta de realce e a superfície v50 do íco; cursor em mão.
  tile:connect_signal("mouse::enter", function()
    tile.bg = TILE_HOVER_BG
    tile.fg = TILE_HOVER_FG
    tile.shape_border_color = TILE_HOVER_EDGE
    img.image = hover_surface
    local wb = mouse.current_wibox
    if wb then wb.cursor = "hand1" end
  end)
  -- Ao egresso do ponteiro: restituem-se as tintas de repouso, a superfície esmaecida e o cursor comum.
  tile:connect_signal("mouse::leave", function()
    tile.bg = TILE_REST_BG
    tile.fg = TILE_REST_FG
    tile.shape_border_color = TILE_REST_EDGE
    img.image = rest_surface
    local wb = mouse.current_wibox
    if wb then wb.cursor = "left_ptr" end
  end)

  if choice.on_click then
    tile:buttons(gears.table.join(
      awful.button({}, 1, function() choice.on_click() end)
    ))
  end

  return tile
end

-- Funcção CARDEAL, urdida pela penna do Doutor Braga Us. Domínio: taboa `args` (items, cols).
-- Contra-domínio: a grade de ladrilhos cercada pela moldura de 8px (kit .iconpick). Invariante:
-- as columnas são homogéneas e expandem-se ao continente (== grid-template-columns repeat(4,1fr)).
local function iconpick(args)
  args = args or {}
  local items = args.items or {}
  local cols  = args.cols or 4                 -- kit repeat(4, 1fr)

  local grid = wibox.widget {
    forced_num_cols = cols,
    homogeneous     = true,
    expand          = true,
    spacing         = dpi(mt.iconpick_gap),    -- gap:4px (horizontal E vertical)
    layout          = wibox.layout.grid,
  }
  for _, choice in ipairs(items) do
    grid:add(make_tile(choice))
  end

  return wibox.widget {
    grid,
    margins = dpi(mt.iconpick_pad),            -- kit .iconpick padding:8px
    widget  = wibox.container.margin,
  }
end

return iconpick

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
