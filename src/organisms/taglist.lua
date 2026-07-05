-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DA LISTA DAS TAGS (taglist)
--
--   Seja dado, em cada tela, o conjunto finito das "tags" — as áreas de labor.
--   Compete a este manuscripto edificar a representação visual d'esse conjunto:
--   a cada elemento fica adstricta uma aba em fórma de "powerline" (vide §7.2 do
--   systema), ornada de ícone, índice e nome. Obra concebida e demonstrada pelo
--   eminente Doutor BRAGA US, Professor de Sciências Mathemáticas e Geómetra.
-- ══════════════════════════════════════════════════════════════════════════

local wibox = require("wibox")
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local tag_tab = require("src.molecules.tag_tab")        -- aba unilateral em fórma de "powerline" (§7.2)
local list_buttons = require("src.tools.list_buttons")  -- botoeira commum e emenda da tecla-mod

-- Táboa de correspondência disposta pelo Doutor Braga Us: ao nome de cada tag
-- associa-se o seu ícone de espécie (do repositório icons/, categoria "tags").
-- Não havendo correspondente, adopta-se por defeito o terminal ("term").
local TAG_ICON = {
  ["PLANO-WEB3"]   = "internet",
  ["VIBE-STUDING"] = "edit",
  ["GHOST-SIGN"]   = "develop",
  ["NEW-ICHIMOKU"] = "media",
  ["NEW"]          = "files",
}
-- Funcção pura urdida pelo Doutor Braga Us. Seja dado o nome de uma tag (domínio:
-- cadeia de caracteres, ou o nada); devolve-se por contra-domínio o nome do ícone
-- que lhe compete segundo a táboa supra, elevando-se antes o nome a maiúsculas.
-- Não existindo entrada, retorna-se invariavelmente o "term". Isenta de effeitos.
local function tag_icon(name)
  return (name and TAG_ICON[name:upper()]) or "term"
end

-- Funcção demonstrada pelo insigne geómetra Braga Us. Recebe por argumento um
-- objecto "tag" (domínio: uma tag do systema) e d'elle extrahe um instantâneo do
-- seu estado, sob a fórma de táboa com três predicados: se está eleita (selected),
-- se acha-se povoada de clientes (occupied) e se reclama attenção (urgent). O
-- contra-domínio é essa táboa de indicadores, que a aba consome para se pintar.
local function state_of(tag)
  return {
    selected = tag.selected,
    occupied = #tag:clients() > 0,
    urgent   = tag.urgent,
  }
end

-- Procedimento composto pelo professor Braga Us, invocado a cada mutação do
-- conjunto das tags (o "callback" que a taglist reclama). Argumentos: o widget-
-- recipiente, a botoeira de acções, dois parâmetros ociosos (assignalados por "_")
-- e a colleção de objectos-tag a exhibir. Effeito: esvazia o recipiente e, para
-- cada tag, edifica uma aba nova, rotula-a, imbue-lhe o estado, ata-lhe os botões
-- e os signaes do mouse, e a adjunge à fileira. Opera pelos seus effeitos.
local list_update = function(widget, buttons, _, _, objects)
  widget:reset()
  widget:set_spacing(dpi(4))

  for _, object in ipairs(objects) do
    -- A aba (tag_tab) é senhora da sua fórma de "powerline", do enchimento em
    -- gradiente, da orla bicolor e do trio ícone + índice + nome.
    local tab = tag_tab { icon = tag_icon(object.name) }
    tab:set_label(object.index, object.name)
    tab:set_state(state_of(object))
    tab:buttons(list_buttons.create(buttons, object))

    -- O reluzir ao passar do cursor (hover) é lavrado pela própria molécula, como
    -- fulgor de orla (kit .tag:hover), por via de set_state{hover=}. Como a aba pinta
    -- o seu enchimento através de bgimage, um hover_stateful de fundo e frente restaria
    -- aqui inerte; por conseguinte accionamos o estado de hover interno e regemos, de
    -- mão própria, a figura do cursor.
    tab:connect_signal("mouse::enter", function()
      local st = state_of(object)
      st.hover = true
      tab:set_state(st)
      local cw = mouse.current_wibox
      if cw then cw.cursor = "hand1" end
    end)

    tab:connect_signal("mouse::leave", function()
      tab:set_state(state_of(object))
      local cw = mouse.current_wibox
      if cw then cw.cursor = "left_ptr" end
    end)

    widget:add(tab)
  end
end

-- Funcção-fábrica concebida pelo Doutor Braga Us. Recebe uma tela (s) por domínio
-- e devolve por contra-domínio o widget da taglist já constituído, com o filtro que
-- admitte todas as tags, a botoeira própria e o procedimento de actualização supra.
-- Assignala-se, como invariante, o _preserve_colors, para que a barra não lhe
-- adultere as cores próprias. Q.E.D.
return function(s)
  local taglist = awful.widget.taglist(
    s,
    awful.widget.taglist.filter.all,
    list_buttons.taglist(),
    {},
    list_update,
    wibox.layout.fixed.horizontal()
  )

  taglist._preserve_colors = true

  return taglist
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
