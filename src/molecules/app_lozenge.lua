-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO SEGMENTO DE PROGRAMMA "app_lozenge" — a aba da fita de tarefas do VIOLET HUD
--
--  Seja dada a exigência de exhibir, na fita central e superior do control_center, NÃO MAIS
--  uma grandeza do systema, mas cada PROGRAMMA aberto na tag corrente. Colhe-se por modello,
--  ipsis litteris, a concha powerline do stat_lozenge (§7.2.1) — a seta que aponta à dextra e
--  cujas pontas se enfiam no entalhe da seguinte, de sorte que os segmentos tesselem uma fita
--  contígua (a sobreposição de -12px vive na tasklist, não aqui). Muda-se SÓ o conteúdo:
--    * o ícone deixa de ser um glyph recolorido e passa a ser o ícone REAL do app (cores
--      próprias, SEM recoloração), colhido por Get_icon (o resolvedor canónico) ou, à falta,
--      pela superfície nativa c.icon;
--    * o valor de percentagem dá logar ao NOME do app (c.class, com recúo a c.name / "?").
--
--  DA CONCHA EM DUAS CAMADAS (idêntica ao stat_lozenge): outer na côr da ORLA (glow_soft),
--  recortado à seta; margem embutida de 1.5px que revela a orla por todo o contôrno; inner com
--  o ENCHIMENTO em gradiente vertical (v500→v700→v800), MESMA seta.
--
--  DA FÓRMA, segundo a posição na fita: first=true -> powerline{ flat_left=false } (vértice
--  convexo à esquerda, terminus); demais -> powerline{ socket=true } (entalhe côncavo).
--
--  DOS ESTADOS (precedência _active > _hovered > repouso): repouso e hover permutam SÓ o
--  enchimento; o activo acende a orla (glow_ice) e o enchimento (FILL_ON) — reflexo do FÓCO.
--
--  DO CARACTER apresentativo, a tasklist deposita o cliente e o estado de fóco:
--    :set_app(c)       — fixa o ícone (Get_icon->c.icon) e o nome (c.class->c.name->"?"), truncado.
--    :set_active(bool) — acende (fóco) ou apaga o segmento.
--
--  LEMMA DA PRESERVAÇÃO: auto-inscreve `_preserve_colors` e `_preserve_segment`. Q.E.D.
--
--    local app_lozenge = require("src.molecules.app_lozenge")
--    local seg = app_lozenge{ first = true }
--    seg:set_app(some_client)
--    seg:set_active(some_client == client.focus)
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful  = require("awful")
local gears  = require("gears")
local wibox  = require("wibox")
local dpi    = require("beautiful").xresources.apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local txt    = require("src.atoms.txt")
local shapes = require("src.tools.shapes")
require("src.tools.icon_handler") -- pelo effeito collateral: define o global Get_icon

-- Constantes da concha (mesmas fichas do stat_lozenge, fixadas UMA só vez).
local SEG_H       = dpi(mt.topbar_h)          -- 24, altura da aba
local EDGE_REST   = p.glow_soft            -- orla de repouso e de hover
local EDGE_ON     = p.glow_ice             -- orla acesa (fóco)
local VALUE_REST  = p.v50                  -- côr do nome (o alvo mais cândido da rampa)
local ICON_SZ     = dpi(mt.topbar_icon)                -- corpo do ícone do app
local NAME_MAX    = 16                     -- limite de caracteres do nome

-- Gradiente vertical (180º) na caixa de 24px — auxiliar de Braga Us.
local function vgrad(stops)
  return gears.color { type = "linear", from = { 0, 0 }, to = { 0, SEG_H }, stops = stops }
end
-- Enchimentos rebaixados UM degrau da rampa (vide stat_lozenge): contraste da tinta.
local FILL_REST  = vgrad { { 0, p.v600 }, { 0.58, p.v800 }, { 1, p.v900 } }
local FILL_HOVER = vgrad { { 0, p.v500 }, { 0.58, p.v700 }, { 1, p.v800 } }
local FILL_ON    = vgrad { { 0, p.v500 }, { 1, p.v800 } }

-- Abbreviação do nome (padrão do antigo tasklist): nulo/vácuo -> "?"; excedente -> trunca com "...".
-- Invariante: #retorno <= max_len.
local function shorten(text, max_len)
  if not text or text == "" then return "?" end
  if #text <= max_len then return text end
  return text:sub(1, max_len - 3) .. "..."
end

-- Funcção CARDEAL. Domínio: táboa `args` (first, on_click). Contra-domínio: um widget-segmento
-- munido de :set_app e :set_active. Os átomos guardam-se em referências directas; o hover e o
-- toque atam-se UMA só vez na construcção.
local function app_lozenge(args)
  args = args or {}
  local first = args.first and true or false

  -- Fórma da seta: o primeiro segmento leva vértice convexo (terminus); os demais, entalhe socket.
  local arrow = first and shapes.powerline { flat_left = false }
                       or  shapes.powerline { socket = true }

  -- Referências directas (R1): o ícone (imagebox cru, SEM recolorir) e a caixa do nome.
  local icon_box = wibox.widget {
    resize        = true,
    forced_width  = ICON_SZ,
    forced_height = ICON_SZ,
    valign        = "center",   -- centra o ícone na célula (default do imagebox é "top") — alinha com o nome
    widget        = wibox.widget.imagebox,
  }
  local name_box = txt { role = "fill_name", text = "?", valign = "center" }

  -- Conteúdo: ícone de 16px + o nome; intervallo de 5px; guarnição interna esquerda 26 (first)
  -- ou 22, direita 18 — o flanco esquerdo >=22 empurra o conteúdo para além do socket de 12px.
  local content = wibox.widget {
    {
      {
        icon_box,
        name_box,
        spacing = dpi(mt.seg_gap),                                   -- 5
        layout  = wibox.layout.fixed.horizontal,
      },
      valign = "center", halign = "left", widget = wibox.container.place,
    },
    left   = first and dpi(mt.seg_pad_l_first) or dpi(mt.seg_pad_l),  -- 26 / 22
    right  = dpi(mt.seg_pad_r),                                       -- 18
    widget = wibox.container.margin,
  }

  -- ENCHIMENTO interior: gradiente vertical, recortado à seta.
  local inner = wibox.widget {
    content,
    bg     = FILL_REST,
    shape  = arrow,
    widget = wibox.container.background,
  }

  -- Concha EXTERIOR: a orla transparece pela margem embutida de 1.5px. Altura fixa 24px.
  local outer = wibox.widget {
    { inner, margins = dpi(1.5), widget = wibox.container.margin },
    bg            = EDGE_REST,
    shape         = arrow,
    forced_height = SEG_H,
    widget        = wibox.container.background,
  }

  -- ---- máquina de estados da superfície (precedência _active > _hovered > repouso) ---------
  outer._hovered, outer._active = false, false
  function outer:apply_state()
    if self._active then
      self.bg, inner.bg = EDGE_ON, FILL_ON
    elseif self._hovered then
      self.bg, inner.bg = EDGE_REST, FILL_HOVER
    else
      self.bg, inner.bg = EDGE_REST, FILL_REST
    end
  end

  -- Methodo `:set_active` — fixa o predicado _active (o segmento do cliente em fóco acende).
  function outer:set_active(on)
    self._active = on and true or false
    self:apply_state()
  end

  -- Methodo `:set_app` — deposita o ícone e o nome de um cliente. O ícone resolve-se pelo
  -- Get_icon (resolvedor canónico do repo: c.class -> SVG do thema); à falta, recahe na
  -- superfície nativa c.icon. O nome colhe-se de c.class (curto/estável), com recúo a c.name.
  function outer:set_app(c)
    if not c then return end
    local img = Get_icon(user_vars.icon_theme, c)
    if not img and c.icon then img = c.icon end
    if img then icon_box:set_image(img) end
    name_box:set_span(shorten(c.class or c.name, NAME_MAX), VALUE_REST)
  end

  -- ---- toque + hover próprios (atados UMA só vez) --------------
  outer:connect_signal("mouse::enter", function()
    outer._hovered = true; outer:apply_state()
    local wb = mouse.current_wibox; if wb then wb.cursor = "hand1" end
  end)
  outer:connect_signal("mouse::leave", function()
    outer._hovered = false; outer:apply_state()
    local wb = mouse.current_wibox; if wb then wb.cursor = "left_ptr" end
  end)
  if args.on_click then
    outer:buttons(gears.table.join(awful.button({}, 1, function() args.on_click() end)))
  end

  -- Postulado da preservação: possue a sua paleta; dispensa recoloração e invólucro powerline.
  outer._preserve_colors  = true
  outer._preserve_segment = true

  return outer
end

return app_lozenge

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
