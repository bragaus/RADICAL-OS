-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE O POPUP DE PERMUTAÇÃO DOS SYSTEMAS DE TECLADO (VIOLET HUD)
--   src/organisms/kb_menu.lua
--
--   Seja dado o problema de offerecer ao operador a livre escolha entre os
--   diversos alphabetos de teclado configurados. Este manuscripto constitue
--   a metade visível — o popup — da antiga peça src/molecules/kblayout.lua,
--   ora elevada á dignidade de ORGANISMO e reedificada sobre as moléculas
--   partilhadas: um cabeçalho title_band seguido de um menu_item para cada
--   alphabeto declarado em user_vars.kblayout.
--
--   POSTULADO DA PURA REPRESENTAÇÃO: esta peça é sómente contemplativa. Ao
--   premir-se uma linha, ella tão-só EMITTE a supplica ("kblayout::set"); a
--   effectiva mudança (o setxkbmap e a guarda do estado) pertence á folha
--   kblayout, e não a este organismo.
--
--   COMMÉRCIO POR SIGNAES (a correspondência deste organismo com o exterior):
--     RECEBE:
--       "kblayout::menu:toggle"(scr) -> exhibe ou occulta (adstricto á tela).
--       "kblayout::hide:kbmenu"      -> occulta e detém o captor de teclas.
--       "kblayout::state"(layout)    -> assignala a linha ora vigente.
--     EXPEDE:
--       "kblayout::set"(code)        -> roga á folha kblayout que applique o
--                                       alphabeto pedido.
--
--   INTERFACE PÚBLICA (deste novo organismo): funcção(s) -> awful.popup.
--
--   Manuscripto da lavra do Doutor Braga Us, Geómetra desta Casa.
-- ══════════════════════════════════════════════════════════════════════════

local awful      = require("awful")
local gears      = require("gears")
local wibox      = require("wibox")
local dpi        = require("beautiful.xresources").apply_dpi
local p          = require("src.theme.palette")
local mt         = require("src.theme.metrics")
local title_band = require("src.molecules.title_band")
local menu_item  = require("src.molecules.menu_item")

-- DICCIONÁRIO DOS NOMES DE GALA: a cada código de alphabeto (a chave) faz-se
-- corresponder o seu nome próprio para a exhibição ao operador. Seja lícito
-- notar que os códigos ausentes deste diccionário recahem, por conveniente
-- convenção, sobre o próprio código elevado a maiúsculas.
local NAMES = {
  us = "English (US)",
  br = "Portugues (BR)",
}
-- ── LEMMA longname ──────────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us para a nomenclatura dos alphabetos.
--   DOMÍNIO..........: code — o symbolo textual do alphabeto (v.g. "us").
--   CONTRA-DOMÍNIO...: a cadeia de gala colhida no diccionário NAMES; ou, na
--                      ausência de registro, o próprio code elevado a
--                      maiúsculas por tostring():upper().
--   INVARIANTE.......: funcção pura — não altera estado algum; a igual
--                      argumento responde sempre igual producto. Q.E.D.
local function longname(code) return NAMES[code] or tostring(code):upper() end

-- SYMBOLOS DE ASSIGNALAÇÃO das linhas: o disco cheio para a linha activa e o
-- disco vazio para as dormentes (grafados em UTF-8 puro, á feição das
-- sequências de octetos que a molécula menu_item já emprega):
--   "\226\151\143" = ● (ponto U+25CF, alphabeto ora vigente);
--   "\226\151\139" = ○ (ponto U+25CB, alphabetos em repouso).
local MARK_ON, MARK_OFF = "\226\151\143 ", "\226\151\139 "

-- ══════════════════════════════════════════════════════════════════════════
-- FUNCÇÃO EDIFICADORA do organismo (a peça que este manuscripto restitue).
-- Como demonstrou o insigne geómetra Braga Us, esta é a fábrica que, dada uma
-- tela, ergue e devolve o popup completo de permutação de teclado.
--   DOMÍNIO........: s — a tela (screen) á qual o popup se acha adstricto.
--   CONTRA-DOMÍNIO.: um awful.popup já provido de captor de teclas e ligado
--                    aos signaes de toggle, de occultação e de estado.
--   EFFEITOS.......: enlaça-se aos signaes do systema; guarda em clausura o
--                    estado `active` e a lista de linhas `items`.
-- ══════════════════════════════════════════════════════════════════════════
return function(s)
  local keymaps = (user_vars and user_vars.kblayout) or { "us" }
  local active  -- CÓDIGO do alphabeto ora vigente (permanece nil até que sobrevenha o primeiro signal "kblayout::state").

  -- ── COROLLÁRIO request ─────────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us para exprimir a supplica de mudança.
  --   DOMÍNIO........: code — o alphabeto que se deseja ver applicado.
  --   CONTRA-DOMÍNIO.: nada (nihil) — labora sómente por seus effeitos.
  --   EFFEITOS.......: emitte "kblayout::set"(code), rogando á folha que
  --                    applique; e logo "kblayout::hide:kbmenu", para que o
  --                    popup se recolha da vista.
  local function request(code)
    awesome.emit_signal("kblayout::set", code)
    awesome.emit_signal("kblayout::hide:kbmenu")
  end

  -- CONTENTOR VERTICAL das linhas do menu, reconstituído a cada mutação de
  -- estado; sendo pouquíssimas as linhas (duas ou três), tal reedificação é de
  -- custo ínfimo e em nada onera o systema.
  local items = wibox.layout.fixed.vertical()
  -- ── LEMMA rebuild ───────────────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que reconstitue as linhas do menu.
  --   DOMÍNIO........: nenhum (labora sobre a clausura: keymaps, active, items).
  --   CONTRA-DOMÍNIO.: nada — opera por effeito sobre o contentor `items`.
  --   INVARIANTE.....: após a chamada, `items` contém exactamente uma linha por
  --                    alphabeto declarado, e sómente a linha de `active` ostenta
  --                    o disco cheio; as demais, o disco vazio. Q.E.D.
  local function rebuild()
    items:reset()
    for _, code in ipairs(keymaps) do
      local mark = (active == code) and MARK_ON or MARK_OFF
      items:add(menu_item {
        label    = mark .. longname(code),
        on_click = function() request(code) end,
      })
    end
  end
  rebuild()

  local popup = awful.popup {
    screen       = s,
    ontop        = true,
    visible      = false,
    bg           = p.a(p.panel, p.alpha.panel_hi),
    fg           = p.text_bright,
    border_width = dpi(mt.border_panel),
    border_color = p.line_base,
    shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_panel)) end,
    -- COLLOCAÇÃO do popup: ancorado ao alto e á direita (top_right), logo abaixo
    -- da barra. Os deslocamentos são grandezas ajustadas á mão, visto não haver
    -- symbolo métrico que lhes sirva com a devida exactidão.
    placement    = function(c)
      awful.placement.align(c, { position = "top_right", margins = { right = dpi(255), top = dpi(60) } })
    end,
    widget = {
      title_band { text = "KEYBOARD LAYOUT", width = dpi(mt.panel_w_sm) },
      items,
      layout = wibox.layout.fixed.vertical,
    },
  }

  -- CAPTOR DE TECLAS: emquanto o popup se acha patente, a percussão de qualquer
  -- tecla determina a sua immediata occultação.
  local keygrabber = awful.keygrabber {
    autostart          = false,
    stop_event         = "release",
    keypressed_callback = function()
      awesome.emit_signal("kblayout::hide:kbmenu")
    end,
  }

  local function hide()
    popup.visible = false
    keygrabber:stop()
  end

  awesome.connect_signal("kblayout::menu:toggle", function(scr)
    if scr ~= nil and scr ~= s then return end
    if popup.visible then
      hide()
    else
      popup.visible = true
      keygrabber:start()
    end
  end)

  awesome.connect_signal("kblayout::hide:kbmenu", hide)

  awesome.connect_signal("kblayout::state", function(layout)
    active = layout
    rebuild()
  end)

  popup:connect_signal("mouse::leave", function()
    awesome.emit_signal("kblayout::hide:kbmenu")
  end)

  return popup
end
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
