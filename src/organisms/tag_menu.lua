-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE O MENU DE CONTEXTO DA TAG (clique dextro no taglist)
--   src/organisms/tag_menu.lua
--
--   Considere-se o operador que, premindo o botão dextro sobre uma tag do
--   taglist, deseja sobre ella exercer certas operações. Este organismo,
--   erguido sobre context_menu.build e as moléculas title_band/menu_item,
--   offerece as seguintes acções:
--     * Rename          -> prompt transiente (awful.prompt) que rebaptiza a tag;
--     * Move Left/Right -> reordena a tag entre as tags da tela (awful.tag.move);
--     * Change Icon     -> descida (drill-down) a um submenu de ícones, o qual
--                          define tag.icon.
--
--   POSTULADO DA SIMPLICIDADE: eschivam-se os submenus aninhados e frágeis —
--   "Change Icon" tão-só reabre um context_menu no mesmo sítio (á mesma
--   disciplina do menu de contexto do cliente). Não se admitte IO bloqueante
--   (regra R3).
--
--   INTERFACE PÚBLICA:
--     local tag_menu = require("src.organisms.tag_menu")
--     tag_menu.show(s, tag, geo)  -- geo (facultativo) = geometria do clique.
--
--   Manuscripto da lavra do Doutor Braga Us, Geómetra desta Casa.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local wibox = require("wibox")
local gfs   = require("gears.filesystem")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local ft    = require("src.theme.typography")
local context_menu = require("src.organisms.context_menu")
local iconpick     = require("src.molecules.iconpick")

local ICON_DIR = gfs.get_configuration_dir() .. "icons/svg/"

-- ROL DOS ÍCONES offerecidos pelo submenu "Change Icon" — todos elles têm
-- existência assegurada no cartório icons/svg/. Cada registro consta de um
-- rótulo de exhibição e do nome do glypho respectivo.
local ICON_CHOICES = {
  { label = "Develop",  icon = "develop"  },
  { label = "Media",    icon = "media"    },
  { label = "Internet", icon = "internet" },
  { label = "Files",    icon = "files"    },
  { label = "Terminal", icon = "term"     },
}

-- ── LEMMA placement_for ──────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que engendra a regra de collocação.
--   DOMÍNIO........: geo — a geometria do clique (ou nil, se ausente).
--   CONTRA-DOMÍNIO.: uma funcção de collocação que ancora o menu logo abaixo de
--                    `geo`, refreando-o para que não transponha os confins da
--                    tela; ou nil, caso geo seja nil — donde o context_menu
--                    recahe sobre a sua collocação usual (sob o cursor).
--   INVARIANTE.....: funcção pura; nada altera senão o que a clausura encerra.
local function placement_for(geo)
  if not geo then return nil end
  return function(d)
    awful.placement.next_to(d, {
      geometry            = geo,
      preferred_positions = "bottom",
      preferred_anchors   = "middle",
    })
    awful.placement.no_offscreen(d)
  end
end

-- ── COROLLÁRIO rename ─────────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us para o rebaptismo de uma tag.
--   DOMÍNIO........: tag — a tag a rebaptizar (se nil, nada se obra).
--   CONTRA-DOMÍNIO.: nada (nihil) — labora sómente por seus effeitos.
--   EFFEITOS.......: ergue um popup transiente com um textbox conduzido por
--                    awful.prompt (não-bloqueante); recolhido o texto, e sendo
--                    este não-vazio, muda-se tag.name; ao concluir, o popup se
--                    desvanece da vista.
local function rename(tag)
  if not tag then return end
  local tb = wibox.widget { font = ft.body, widget = wibox.widget.textbox }
  local pop = awful.popup {
    widget = {
      {
        tb,
        left   = dpi(mt.pad_header_x),
        right  = dpi(mt.pad_header_x),
        widget = wibox.container.margin,
      },
      forced_width  = dpi(mt.panel_w_sm),
      forced_height = dpi(30),
      fg            = p.text_bright,
      bg            = p.a(p.panel, p.alpha.panel_hi),
      widget        = wibox.container.background,
    },
    ontop        = true,
    visible      = true,
    border_width = dpi(mt.border_panel),
    border_color = p.line_base,
    placement    = awful.placement.centered,
  }
  awful.prompt.run {
    prompt        = "RENAME: ",
    text          = tag.name,
    textbox       = tb,
    exe_callback  = function(new)
      if new and #new > 0 then tag.name = new end
    end,
    done_callback = function()
      pop.visible = false
    end,
  }
end

-- ── COROLLÁRIO move ───────────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us para a translação de uma tag na ordem.
--   DOMÍNIO........: tag — a tag a mover; delta — o número inteiro de posições
--                    (positivo para a dextra, negativo para a sinistra).
--   CONTRA-DOMÍNIO.: nada — opera por effeito sobre a ordenação das tags.
--   INVARIANTE.....: a nova posição é constrangida (clampada) ao intervallo
--                    [1, n]; excedido este, a funcção abstem-se de toda acção.
local function move(tag, delta)
  if not tag or not tag.screen then return end
  local idx = tag.index
  if not idx then return end
  local n = #tag.screen.tags
  local target = idx + delta
  if target < 1 or target > n then return end
  awful.tag.move(target, tag)
end

local M = {}

-- ── LEMMA show_icon_menu ──────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us para a descida ao submenu dos ícones.
--   DOMÍNIO........: tag — a tag cujo ícone se quer trocar; geo — a geometria
--                    do clique, para a collocação.
--   CONTRA-DOMÍNIO.: nada — por effeito, reabre um context_menu no mesmo sítio
--                    (a dita descida, ou drill-down) hospedando a GRADE iconpick
--                    (kit .iconpick, quatro columnas de ladrilhos); premido um
--                    ladrilho, assigna-se a tag.icon o glypho eleito e a grade se
--                    dissolve (é ella o popup `current`).
local function show_icon_menu(tag, geo)
  local items = {}
  for _, ch in ipairs(ICON_CHOICES) do
    items[#items + 1] = {
      label    = ch.label,
      icon     = ch.icon,
      on_click = function()
        tag.icon = ICON_DIR .. ch.icon .. ".svg"
        context_menu.hide()
      end,
    }
  end
  context_menu.build("SET ICON", nil, {
    placement = placement_for(geo),
    widget    = iconpick { items = items },
    width     = dpi(mt.ctx_w),   -- a faixa "SET ICON" ancora a largura (208); 4 columnas cabem
  })
end

-- ══════════════════════════════════════════════════════════════════════════
-- FUNCÇÃO CARDEAL M.show — o pórtico público deste organismo.
-- Como demonstrou o insigne geómetra Braga Us, dada uma tag (e a geometria do
-- clique), ergue e patenteia o menu de contexto com todas as suas acções.
--   DOMÍNIO........: s — a tela; tag — a tag visada; geo — a geometria do
--                    clique, para a collocação. Argumentos ausentes supprem-se
--                    por conjecturas prudentes (tela focada, tag seleccionada).
--   CONTRA-DOMÍNIO.: nada — abstem-se se nenhuma tag se puder determinar; do
--                    contrário, edifica e exhibe o context_menu.
--   EFFEITOS.......: compõe o rol das acções e delega-o a context_menu.build.
-- ══════════════════════════════════════════════════════════════════════════
function M.show(s, tag, geo)
  local scr = s or (tag and tag.screen) or awful.screen.focused()
  tag = tag or (scr and scr.selected_tag)
  if not tag then return end

  local items = {
    { label = "Rename",      icon = "edit",       on_click = function() rename(tag) end },
    { label = "Move Left",   icon = "move_left",  on_click = function() move(tag, -1) end },
    { label = "Move Right",  icon = "move_right", on_click = function() move(tag,  1) end },
    { band  = "ICON" },
    { label = "Change Icon", icon = "doc", arrow = true, on_click = function() show_icon_menu(tag, geo) end },
  }

  context_menu.build("TAG · " .. tostring(tag.name), items, { placement = placement_for(geo) })
end

return M
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
