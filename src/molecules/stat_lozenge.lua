-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO SEGMENTO ESTATÍSTICO "stat_lozenge" — a aba da fita central do VIOLET HUD (§7.2.1)
--
--  Seja dada a exigência de exhibir, na fita central e superior do control_center, uma
--  grandeza colhida do systema (cpu, memória, gpu, rede, volume). Abandonado o antigo
--  hexágono de dupla ponta, o eminente geómetra BRAGA US concebeu — por fidelidade ao kit
--  `.seg` — um SEGMENTO de fita powerline: uma seta que aponta à dextra e cujas pontas se
--  enfiam no entalhe da aba seguinte, de sorte que os cinco segmentos tesselem uma fita
--  contígua (a sobreposição de -12px vive no control_center, não aqui).
--
--  DA CONCHA EM DUAS CAMADAS (padrão orla-por-margem, idêntico ao chip_button):
--    * outer — background na côr da ORLA (glow_soft), recortado à seta;
--    * uma margem embutida de 1.5px revela essa orla por todo o contôrno (kit .seg__fill inset:1.5);
--    * inner — background com o ENCHIMENTO em gradiente vertical (v500→v700→v800), MESMA seta.
--  Ambas as camadas partilham a MESMA funcção de fórma, donde a inner cabe na outer com o
--  inset uniforme que dá o efeito de aresta.
--
--  DA FÓRMA, segundo a posição na fita:
--    * first=true  -> powerline{ flat_left=false } — vértice convexo à esquerda (o terminus);
--    * demais      -> powerline{ socket=true }     — entalhe côncavo que recebe a ponta anterior.
--
--  DOS ESTADOS (precedência _active > _hovered > repouso):
--    * repouso  -> orla glow_soft, enchimento FILL_REST;
--    * hover    -> orla glow_soft, enchimento FILL_HOVER (o kit muda SÓ o fill ao pairar);
--    * activo   -> orla glow_ice,  enchimento FILL_ON  (o kit acende o seg do grupo aberto).
--
--  DO CARACTER apresentativo, o proprietário colhe as amostras e n'ellas as deposita:
--    :set_value(text, pct) — fixa o texto do valor; pct guarda-se por tonumber e, salvo
--                            never_hot, o valor arde em glow_hot quando pct >= mt.pct_hot
--                            (o postulado do >=90). VOL passa never_hot=true (sem alarme rubro).
--    :set_active(bool)     — NOVO: acende (activo) ou apaga o segmento; reflecte o dashboard aberto.
--
--  LEMMA DA PRESERVAÇÃO: auto-inscreve `_preserve_colors` (nada recolore o gradiente) e
--  `_preserve_segment` (inócuo; a fita vive no seu próprio popup). Q.E.D.
--
--    local stat_lozenge = require("src.molecules.stat_lozenge")
--    local cpu = stat_lozenge{ icon = "cpu", first = true, on_click = function() toggle("system") end }
--    cpu:set_value("42%", 42)
--    cpu:set_active(true)
--    local vol = stat_lozenge{ icon = "vol", never_hot = true }
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

-- Constantes da concha (kit .seg / .seg__edge / .seg__fill), fixadas UMA só vez por Braga Us.
local SEG_H       = dpi(mt.seg_h)          -- 24, .seg/.lozstrip height
local EDGE_REST   = p.glow_soft            -- .seg__edge bg (a orla de repouso e de hover)
local EDGE_ON     = p.glow_ice             -- .seg--on .seg__edge (a orla acesa)
local VALUE_REST  = p.v50                  -- .seg__v color (o alvo mais cândido da rampa)

-- Funcção auxiliar de Braga Us: engendra um gradiente vertical (180º) na caixa de 24px.
-- Domínio: os stops do gradiente; contra-domínio: um objecto de côr linear.
local function vgrad(stops)
  return gears.color { type = "linear", from = { 0, 0 }, to = { 0, SEG_H }, stops = stops }
end
-- Enchimentos rebaixados UM degrau da rampa: a tinta v50 ganha contraste
-- (5.0 no topo v600 contra 4.0 no antigo topo v500) sem perder o fulgor.
local FILL_REST  = vgrad { { 0, p.v600 }, { 0.58, p.v800 }, { 1, p.v900 } }  -- .seg__fill
local FILL_HOVER = vgrad { { 0, p.v500 }, { 0.58, p.v700 }, { 1, p.v800 } }  -- .seg:hover .seg__fill
local FILL_ON    = vgrad { { 0, p.v500 }, { 1, p.v800 } }                    -- .seg--on .seg__fill

-- Funcção CARDEAL, da penna do professor Braga Us. Domínio: taboa `args` (íco, first,
-- never_hot, on_click). Contra-domínio: um widget-segmento munido de :set_value e :set_active.
-- Como demonstrou o auctor, os átomos guardam-se em referências directas (R1) e o hover e o
-- toque atam-se UMA só vez na construcção (R7), d'onde a economia de operações em tempo de execução.
local function stat_lozenge(args)
  args = args or {}
  local never_hot = args.never_hot and true or false
  local first     = args.first and true or false

  -- Fórma da seta: o primeiro segmento leva vértice convexo à esquerda (terminus da fita);
  -- os demais levam entalhe côncavo (socket) que recebe a ponta do segmento anterior. Ambas
  -- as camadas (orla + enchimento) hão-de partilhar esta MESMA funcção — tip por defeito = 12.
  local arrow = first and shapes.powerline { flat_left = false }
                       or  shapes.powerline { socket = true }

  -- Referência directa (R1). O valor usa :set_span para côr própria (txt = único senhor da
  -- marcação); papel 'value' => ft.value = mono ExtraBold 12 (kit .seg__v 12/800).
  local value_box = txt { role = "value", text = "--", valign = "center" }

  -- Conteúdo: íco de 15px recolorido a glow_ice + o valor; intervallo de 5px; guarnição
  -- interna esquerda 26 (first) ou 22, direita 18 (kit .seg__content padding 0 18 0 22/26). O
  -- flanco esquerdo >=22 empurra o conteúdo para além da zona de sobreposição/socket de 12px.
  local content = wibox.widget {
    {
      {
        args.icon and icon { name = args.icon, color = p.glow_ice, size = dpi(15) }
                   or wibox.widget.base.make_widget(),
        value_box,
        spacing = dpi(mt.seg_gap),                                   -- 5, .seg__content gap
        layout  = wibox.layout.fixed.horizontal,
      },
      valign = "center", halign = "left", widget = wibox.container.place,
    },
    left   = first and dpi(mt.seg_pad_l_first) or dpi(mt.seg_pad_l),  -- 26 / 22
    right  = dpi(mt.seg_pad_r),                                       -- 18
    widget = wibox.container.margin,
  }

  -- ENCHIMENTO interior (.seg__fill): gradiente vertical, recortado à seta.
  local inner = wibox.widget {
    content,
    bg     = FILL_REST,
    shape  = arrow,
    widget = wibox.container.background,
  }

  -- Concha EXTERIOR (.seg__edge): a côr da ORLA transparece pela margem embutida de 1.5px
  -- que cerca o enchimento (= .seg__fill inset:1.5px). Altura fixa 24px.
  local outer = wibox.widget {
    { inner, margins = dpi(1.5), widget = wibox.container.margin },
    bg            = EDGE_REST,
    shape         = arrow,
    forced_height = SEG_H,
    widget        = wibox.container.background,
  }

  -- ---- máquina de estados da superfície (precedência _active > _hovered > repouso) ---------
  -- Escrólio: repinta orla e enchimento conforme os predicados _active/_hovered. O hover, à
  -- semelhança do kit, permuta SÓMENTE o enchimento; a orla só acende no estado activo.
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

  -- Methodo `:set_active` — NOVO. Fixa o predicado _active e reflecte-o na superfície. O
  -- control_center acende, por elle, o segmento do grupo cujo dashboard esteja aberto.
  function outer:set_active(on)
    self._active = on and true or false
    self:apply_state()
  end

  -- ---- superfície de actualização (interface de Braga Us) --------------------
  -- Escrólio: deposita o texto do valor. Argumentos text e pct; sem retorno. Demonstra-se:
  -- pct converte-se por tonumber; se não for never_hot e pct >= mt.pct_hot, o valor arde em
  -- glow_hot (o postulado do >=90); do contrário exhibe-se em VALUE_REST (#f5efff).
  function outer:set_value(text, pct)
    pct = tonumber(pct)
    local hot = (not never_hot) and pct ~= nil and pct >= mt.pct_hot
    value_box:set_span(text or "--", hot and p.glow_hot or VALUE_REST)
  end
  outer:set_value("--", nil)

  -- ---- toque + hover próprios (atados UMA só vez — postulado R7) --------------
  -- O Hover_signal antigo só mexia no fg (sem effeito numa superfície de côr própria); em seu
  -- lugar, o hover fixa _hovered e repinta o enchimento via apply_state, além do cursor de mão.
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

  -- Postulado R6: possue a sua paleta; dispensa recoloração do bar e invólucro powerline.
  outer._preserve_colors  = true
  outer._preserve_segment = true

  return outer
end

return stat_lozenge

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
