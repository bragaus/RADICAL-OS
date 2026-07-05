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
    user_vars.layouts[12]
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
    s.layoutlist = require("src.organisms.layout_list")(s)
    s.taglist = require("src.organisms.taglist")(s)
    -- ═════════════════════════════════════════════════════════════════════════════════
    -- DA BARRA SUPERIOR e dos DASHBOARDS AO-CLIQUE (vide DESIGN_SYSTEM §5).
    -- Não há colunas estáticas, nem carta monolítica, nem doca: os painéis se manifestam
    -- em popups (aos pares) ao acto de clicar-se nos lozangos do control_center. Assim o
    -- dispôz o Doutor Braga Us, por economia de espaço e por clareza de exposição.
    -- ═════════════════════════════════════════════════════════════════════════════════

    -- ----- BARRA SUPERIOR ----- (a coroa do écran: taglist, controlos de tag e centro de commando)
    s.tag_controls = require("src.organisms.tag_controls")(s)
    s.tag_controls._preserve_colors = true
    s.powerbutton  = require("src.molecules.power")()
    require("radical_wm.radical_bar")(s, { s.layoutlist, s.taglist, s.tag_controls })

    -- ----- PAINÉIS (aos pares — residem DENTRO dos dashboards ao-clique) -----
    local W = dpi(520)
    s.info_panel        = require("src.organisms.info_panel") { w = W }
    s.usage_panel       = require("src.organisms.usage_panel") { w = W }
    s.process_panel     = require("src.organisms.process_panel") { w = W }
    s.net_graph_panel   = require("src.organisms.net_graph_panel") { w = W }
    s.ip_panel          = require("src.organisms.ip_panel") { w = W }
    s.connections_panel = require("src.organisms.connections_panel") { w = W }
    s.protocols_donut   = require("src.organisms.protocols_donut") { w = W }
    s.apps_panel        = require("src.organisms.apps_panel") { w = W }
    s.calendar_panel    = require("src.organisms.calendar_panel") { w = W }
    s.clock_br = require("src.molecules.world_clock") { city = "BRASIL", timezone = "America/Sao_Paulo", country = "br", width = dpi(504) }
    s.clock_fr = require("src.molecules.world_clock") { city = "FRANCA", timezone = "Europe/Paris", country = "fr", width = dpi(504) }
    s.clock_jp = require("src.molecules.world_clock") { city = "JAPAO", timezone = "Asia/Tokyo", country = "jp", width = dpi(504) }
    s.clock_us = require("src.molecules.world_clock") { city = "EUA", timezone = "America/New_York", country = "us", width = dpi(504) }
    s.international_panel = panel({
      title = "INTERNATIONAL",
      w = W,
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

    -- ----- CENTRO DE COMMANDO: lozangos clicáveis (ao alto, ao centro) e dashboards ao-clique -----
    require("src.organisms.control_center")(s, {
      right_widget   = s.powerbutton, -- o botão de energia é levado à barra do canto superior-direito (ao pé do relógio)
      system_panels  = { s.info_panel, s.usage_panel, s.process_panel },
      network_panels = { s.net_graph_panel, s.ip_panel, s.connections_panel, s.protocols_donut, s.apps_panel },
      time_panels    = { s.calendar_panel, s.international_panel },
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
