-- ══════════════════════════════════════════════════════════════════════════
--   TRATADO DA COMPOSIÇÃO DA BARRA DE ESTADO — radical_wm/init.lua
-- ══════════════════════════════════════════════════════════════════════════
-- Seja dado o systema de janellas AwesomeWM. Neste manuscripto se demonstra a
-- composição da barra de estado (statusbar): a congregação, por cada écran, de
-- todos os widgets, módulos e organismos que ao olho se apresentam. Considere-se
-- este ficheiro o ponto de reunião onde as partes discretas se ajuntam em um só
-- todo continuo e visível.
-- POSTULADO: cada écran recebe as suas tags; sómente o écran primário recebe a
-- composição integral do violeta-HUD (barras, painéis, docas). Q.E.D. na
-- leitura que segue.
-- Compêndio urdido com method pelo insigne geómetra Braga Us.
-- ══════════════════════════════════════════════════════════════════════════
local awful = require("awful")
local wibox = require("wibox")
local dpi = require("beautiful").xresources.apply_dpi
local mt = require("src.theme.metrics")
local p = require("src.theme.palette")
local panel = require("src.tools.panel")
local Icon = require("src.tools.icons")

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA I — Da eleição do écran primário legítimo.
-- Funcção urdida pelo Doutor Braga Us para eleger, dentre os écrans do systema,
-- aquelle que verdadeiramente serve de sede à composição.
--   DOMÍNIO       : nenhum argumento (colhe-se o estado global dos écrans).
--   CONTRA-DOMÍNIO: um écran de geometria não-degenerada (largura e altura > 0).
--   INVARIANTE    : preferir screen.primary; mas se a sua geometria fôr nulla
--                   (v.g. o xrandr deixou por primário um output desligado, de
--                   medida zero), recorra-se ao primeiro écran de área positiva.
--                   Não se achando nenhum, devolve-se o primário tal e qual.
-- Demonstra-se por conseguinte que o valor devolvido é sempre utilizável. Q.E.D.
-- ─────────────────────────────────────────────────────────────────────────
local function resolve_primary()
  local p = screen.primary
  if p and p.geometry and p.geometry.width > 0 and p.geometry.height > 0 then
    return p
  end
  for s in screen do
    if s.geometry and s.geometry.width > 0 and s.geometry.height > 0 then
      return s
    end
  end
  return p
end

-- ─────────────────────────────────────────────────────────────────────────
-- COROLLÁRIO — Da provisão dos leiautes por defeito.
-- Ouvinte (signal) que o Doutor Braga Us ata ao pedido "request::default_layouts":
-- sempre que o systema reclama os arranjos padrão, anexam-se os leiautes que no
-- Livro das Variáveis do Utente (user_vars.layouts) se acham inscriptos.
--   DOMÍNIO : o evento emittido pelo systema de tags.
--   EFFEITO : os leiautes de user_vars.layouts passam a estar disponíveis.
-- ─────────────────────────────────────────────────────────────────────────
tag.connect_signal("request::default_layouts", function()
  awful.layout.append_default_layouts(user_vars.layouts)
end)

-- ─────────────────────────────────────────────────────────────────────────
-- THEÓREMA CENTRAL — Da composição por cada écran.
-- Funcção mestra, da lavra do eminente geómetra Braga Us, applicada a cada
-- écran do systema. A ella se confia dotar todo écran das suas quatro tags e,
-- provando-se ser elle o écran primário, erguer sobre elle a composição
-- integral do violeta-HUD.
--   DOMÍNIO    : s — o écran em processamento.
--   EFFEITO    : sobre s se instituem tags, menus, OSDs, painéis e docas.
--   INVARIANTE : sómente o écran primário (vide LEMMA I) recebe barras,
--                widgets e dashboards; os demais permanecem limpos, com tags só.
-- ─────────────────────────────────────────────────────────────────────────
awful.screen.connect_for_each_screen(

  function(s)
  awful.tag(
    { "PLANO-WEB3", "VIBE-STUDING", "GHOST-SIGN", "NEW-ICHIMOKU" },
    s,
    user_vars.layouts[1] -- suit.tile (was [12] = suit.magnifier)
  )
--[[ Máxima moral, colhida pelo Doutor Braga Us: das mais tristes cousas desta vida é chegar-se ao termo e olhar-se para traz com remorso, sabedor de que muito mais se poderia ter obrado e alcançado. --]]
  -- Observe-se: o écran secundário (disposto na vertical) permanece limpo — só tags, sem barras, sem widgets, sem menus, sem OSDs.
  if s == resolve_primary() then
    require("src.organisms.powermenu")(s)
    -- PENDÊNCIA (por resolver): refazer o OSD do calendário; talvez lavrar-se implementação própria.
    -- require("src.organisms.calendar_osd")(s)
    require("src.organisms.volume_osd")(s)
    require("src.organisms.brightness_osd")(s)
    require("src.organisms.titlebar")
    require("src.organisms.volume_controller")(s)

    -- Widgets — os órgãos visíveis que abaixo se instituem sobre o écran primário.
    s.taglist = require("src.organisms.taglist")(s)
    -- A FITA DE PROGRAMMAS: os segmentos powerline dos apps abertos na tag corrente. Toma o
    -- centro da barra superior (opts.center_widget), no logar da antiga fita de estatística.
    s.tasklist = require("src.organisms.tasklist")(s)
    -- ═════════════════════════════════════════════════════════════════════════════════
    -- DA BARRA SUPERIOR e dos DASHBOARDS AO-CLIQUE (vide DESIGN_SYSTEM §5).
    -- Não há colunas estáticas, nem carta monolítica, nem doca: os painéis se manifestam
    -- em popups (por columnas) ao acto de clicar-se nos lozangos do control_center. Assim o
    -- dispôz o Doutor Braga Us, por economia de espaço e por clareza de exposição.
    -- ═════════════════════════════════════════════════════════════════════════════════

    -- ----- BARRA SUPERIOR ----- (a coroa do écran: taglist, controlos de tag, bandeja, teclado, poder)
    -- A antiga radical_bar (ilha-esquerda de segmentos powerline) foi retirada do boot: a barra
    -- unifica-se agora n'UMA só wibar rasa, cuja senhoria compete ao control_center. A tagctl já
    -- inscreve por si o invariante _preserve_colors; a systray e o kblayout tomam a secção direita.
    s.tag_controls = require("src.organisms.tag_controls")(s)
    s.powerbutton  = require("src.molecules.power")()
    s.systray      = require("src.organisms.systray")(s)
    s.kblayout     = require("src.molecules.kblayout")(s)

    -- ----- PAINÉIS (por columnas — residem DENTRO dos dashboards ao-clique) -----
    -- Larguras verba a verba do kit dashboards.jsx (DESIGN_SYSTEM §5), em logar do antigo W=520
    -- uniforme: INFO/USAGE/IP/PROTOCOLS/net-GRAPH/INTERNATIONAL 236; PROCESS/system-GRAPH 264;
    -- CONNECTIONS/APPLICATIONS 300; CALENDAR 252.
    local W236 = dpi(mt.panel_w_236)
    local W264 = dpi(mt.panel_w_264)
    local W300 = dpi(mt.panel_w_300)
    local W252 = dpi(mt.panel_w_252)
    s.info_panel         = require("src.organisms.info_panel") { w = W236 }
    s.usage_panel        = require("src.organisms.usage_panel") { w = W236 }
    s.system_graph_panel = require("src.organisms.system_graph_panel") { w = W264 }
    s.process_panel      = require("src.organisms.process_panel") { w = W264 }
    s.net_graph_panel    = require("src.organisms.net_graph_panel") { w = W236 }
    s.ip_panel           = require("src.organisms.ip_panel") { w = W236 }
    s.protocols_donut    = require("src.organisms.protocols_donut") { w = W236 }
    s.connections_panel  = require("src.organisms.connections_panel") { w = W300 }
    s.apps_panel         = require("src.organisms.apps_panel") { w = W300 }
    s.calendar_panel     = require("src.organisms.calendar_panel") { w = W252 }

    -- O painel INTERNATIONAL conserva-se montado como hoje (os quatro relógios do mundo); só a
    -- sua largura passa a 236 (§5), donde a largura interior de cada relógio se ajusta ao vão.
    local WC_W = W236 - dpi(2 * mt.pad_panel) -- largura interior (236 menos os 8+8 de guarnição do corpo)
    s.clock_br = require("src.molecules.world_clock") { city = "BRASIL", timezone = "America/Sao_Paulo", country = "br", width = WC_W }
    s.clock_fr = require("src.molecules.world_clock") { city = "FRANCA", timezone = "Europe/Paris", country = "fr", width = WC_W }
    s.clock_jp = require("src.molecules.world_clock") { city = "JAPAO", timezone = "Asia/Tokyo", country = "jp", width = WC_W }
    s.clock_us = require("src.molecules.world_clock") { city = "EUA", timezone = "America/New_York", country = "us", width = WC_W }
    s.international_panel = panel({
      title = "INTERNATIONAL",
      w = W236,
      right_icon = Icon("clock", { size = dpi(14), color = p.text_muted }),
      body = wibox.widget {
        s.clock_br,
        s.clock_fr,
        s.clock_jp,
        s.clock_us,
        spacing = dpi(6),
        layout = wibox.layout.fixed.vertical,
      },
    })

    -- ----- CENTRO DE COMMANDO: a wibar superior (tags | lozangos | relógio) e os dashboards -----
    -- As colunas seguem verba a verba o kit dashboards.jsx (DESIGN_SYSTEM §5), compostas SÓ de
    -- painéis reaes existentes (satellite_panel NÃO se referencia — não há tal painel em Lua).
    require("src.organisms.control_center")(s, {
      left_widgets  = { s.taglist, s.tag_controls },   -- secção esquerda da wibar (a tagctl encaixa -22)
      center_widget = s.tasklist,                      -- CENTRO: a fita de programmas abertos (tasklist)
      right_extra   = { s.systray, s.kblayout },       -- bandeja + teclado, entre o relógio e o poder
      right_widget  = s.powerbutton,                   -- o botão do poder, ao extremo direito
      system_cols  = { { s.info_panel, s.usage_panel }, { s.system_graph_panel, s.process_panel } },
      network_cols = { { s.net_graph_panel, s.ip_panel, s.protocols_donut }, { s.connections_panel, s.apps_panel } },
      time_cols    = { { s.calendar_panel }, { s.international_panel } },
    })

    -- ----- LANÇADOR: botão GIF circular ao canto inferior-direito e menu de programmas -----
    s.app_launcher = require("src.organisms.app_launcher")(s)

    -- ----- MONITORBAR: doca de telemetria perenne ao rodapé (vide DESIGN_SYSTEM §7.3.1) -----
    s.monitor_bar = require("src.organisms.monitor_bar")(s)
  end
end
)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
