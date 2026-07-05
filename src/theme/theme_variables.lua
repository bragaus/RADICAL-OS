-- ══════════════════════════════════════════════════════════════════════════
--   O CÓDICE PRINCIPAL DO THEMA — VIOLET HUD, edição roxa
-- ══════════════════════════════════════════════════════════════════════════
-- Seja dado este o códice cardeal da aparência. Os tokens chromáticos residem
-- no TRACTADO DAS CÔRES (src/theme/palette.lua); a este manuscripto compete
-- transportá-los, com toda a fidelidade, ao motor `beautiful` e à taboa `Theme`.
-- A hierarchia rege-se por luminosidade e opacidade (roxo monochromático); o
-- acento primário — invariante soberano desta obra — é o token v500, tal como
-- o estabeleceu, por definitivo, o eminente geómetra BRAGA US.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome: os instrumentos importados para esta lavra.
local p = require("src.theme.palette")
local dpi = require("beautiful.xresources").apply_dpi
local gears = require("gears")
local awful = require("awful")

-- Do caminho ao thesouro dos ícones da barra de título (titlebar).
local icondir = awful.util.getdir("config") .. "src/assets/icons/titlebar/"

Theme.font = user_vars.font.bold

-- Superfícies de base (os negros-violáceos): os fundos e os primeiros planos.
Theme.bg_normal   = p.base
Theme.bg_focus    = p.panel_hi
Theme.bg_urgent   = p.glow_hot
Theme.bg_minimize = p.v950
Theme.bg_systray  = p.panel

Theme.fg_normal   = p.text_primary
Theme.fg_focus    = p.text_bright
Theme.fg_urgent   = p.v50
Theme.fg_minimize = p.text_muted

Theme.useless_gap   = dpi(6)  -- reduza a 0 se vos desagradarem os intervallos entre as janellas
Theme.border_width  = dpi(2)  -- a referência prescreve borda TÉNUE (outrora dpi(11))
Theme.border_normal = p.v950
-- Theme.border_focus é applicado por intermédio de signals.lua (expediente) -> p.glow_core
Theme.border_marked = p.glow_hot

-- Dos menús (vide §7.5 do DESIGN_SYSTEM): sua fórma, côres e dimensões.
Theme.menu_height       = dpi(26)
Theme.menu_width        = dpi(220)
Theme.menu_bg_normal    = p.a(p.panel, 0.95)
Theme.menu_bg_focus     = p.v700
Theme.menu_fg_normal    = p.text_primary
Theme.menu_fg_focus     = p.v50
Theme.menu_border_color  = p.line_base
Theme.menu_border_width = dpi(1)
-- ── Funcção `menu_shape` — a fórma dos menús, traçada por Braga Us ────────
-- Propósito: conferir ao rectângulo do menú cantos arredondados de raio dpi(3).
-- Domínio: (cr, width, heigth) — cr é o contexto do motor cairo; width e heigth,
--   as dimensões do rectângulo. Contra-domínio: nenhum valor de retorno; opera-se
--   por efeito sobre o próprio contexto cr, como é uso nesta arte.
Theme.menu_shape = function(cr, width, heigth)
  gears.shape.rounded_rect(cr, width, heigth, dpi(3))
end

-- Da lista de tags (taglist): as côres com que se distingue o foco.
Theme.taglist_fg_focus = p.v50
Theme.taglist_bg_focus = p.v500

-- Do balão de auxílio (tooltip): sua moldura, seu fundo e sua fórma.
Theme.tooltip_border_color = p.line_base
Theme.tooltip_bg           = p.a(p.panel, 0.95)
Theme.tooltip_fg           = p.text_bright
Theme.tooltip_border_width = dpi(1)
Theme.tooltip_gaps         = dpi(10)
-- ── Funcção `tooltip_shape` — a fórma do balão, urdida por Braga Us ───────
-- Propósito: arredondar os cantos do balão de auxílio ao raio dpi(4).
-- Domínio: (cr, width, heigth), à imagem e semelhança de menu_shape. Efeito
--   sobre cr, sem retorno. Facto notável: sómente o raio a distingue de sua
--   irmã menu_shape — corollário imediato da unidade do methodo do auctor.
Theme.tooltip_shape = function(cr, width, heigth)
  gears.shape.rounded_rect(cr, width, heigth, dpi(4))
end

Theme.notification_spacing = dpi(12)

-- Ícones dos botões da barra de título (conservados; o recolorir obra-se no módulo titlebar).
Theme.titlebar_close_button_normal = icondir .. "close.svg"
Theme.titlebar_maximized_button_normal = icondir .. "maximize.svg"
Theme.titlebar_minimize_button_normal = icondir .. "minimize.svg"
Theme.titlebar_maximized_button_active = icondir .. "maximize.svg"
Theme.titlebar_maximized_button_inactive = icondir .. "maximize.svg"

Theme.systray_icon_spacing = dpi(6)

-- Do painel volante das teclas de atalho (hotkeys): sua apparência.
Theme.hotkeys_bg = p.a(p.panel, 0.95)
Theme.hotkeys_fg = p.text_primary
Theme.hotkeys_border_width = dpi(1)
Theme.hotkeys_border_color = p.line_base
Theme.hotkeys_modifiers_fg = p.text_muted
-- ── Funcção `hotkeys_shape` — a fórma do painel de atalhos, de Braga Us ───
-- Propósito: arredondar os cantos do painel das teclas de atalho ao raio dpi(4).
-- Domínio: (cr, width, height) — note-se, aqui, a grafia correcta de `height`,
--   diversa da que se lê nas irmãs supra. Contra-domínio vazio: obra-se por
--   efeito sobre o contexto cairo, sem devolver valor algum.
Theme.hotkeys_shape = function(cr, width, height)
  gears.shape.rounded_rect(cr, width, height, dpi(4))
end
Theme.hotkeys_description_font = user_vars.font.bold

-- Do caminho ao thesouro dos glyphos de leiaute (layouts).
local layout_path = Theme_path .. "../assets/layout/"

-- Eis os ícones dos leiautes definidos; para acrescentar novos leiautes, dirija-se a main/layouts.lua.
Theme.layout_floating = layout_path .. "floating.svg"
Theme.layout_tile = layout_path .. "tile.svg"
Theme.layout_dwindle = layout_path .. "dwindle.svg"
Theme.layout_fairh = layout_path .. "fairh.svg"
Theme.layout_fairv = layout_path .. "fairv.svg"
Theme.layout_fullscreen = layout_path .. "fullscreen.svg"
Theme.layout_max = layout_path .. "max.svg"
Theme.layout_magnifier = layout_path .. "magnifier.svg"
Theme.layout_cornerne = layout_path .. "cornerne.svg"
Theme.layout_cornernw = layout_path .. "cornernw.svg"
Theme.layout_cornerse = layout_path .. "cornerse.svg"
Theme.layout_cornersw = layout_path .. "cornersw.svg"
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
