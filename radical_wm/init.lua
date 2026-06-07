--------------------------------------------------------------------------------------------------------------
-- This is the statusbar, every widget, module and so on is combined to all the stuff you see on the screen --
--------------------------------------------------------------------------------------------------------------
local awful = require("awful")
local wibox = require("wibox")
local dpi = require("beautiful").xresources.apply_dpi
local p = require("src.theme.palette")
local panel = require("src.tools.panel")
local Icon = require("src.tools.icons")

-- Pick a primary that is actually usable: prefer screen.primary, but if its
-- geometry is zero (e.g. xrandr left a disconnected output marked primary),
-- fall back to the first available screen.
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

tag.connect_signal("request::default_layouts", function()
  awful.layout.append_default_layouts(user_vars.layouts)
end)

awful.screen.connect_for_each_screen(

  function(s)
  awful.tag(
    { "PLANO-WEB3", "VIBE-STUDING", "GHOST-SIGN", "NEW-ICHIMOKU" },
    s,
    user_vars.layouts[12]
  )
--[[ uma das coisas mais tristes na vida e chegar ao fim e olhar oara traz com remorso, sabendo que voce poderia teer sido feito e tido muito mais --]]
  -- Tela secundária (vertical) fica limpa: só tags, sem barras/widgets/menus/OSDs.
  if s == resolve_primary() then
    require("src.modules.powermenu")(s)
    -- TODO: rewrite calendar osd, maybe write an own inplementation
    -- require("src.modules.calendar_osd")(s)
    require("src.modules.volume_osd")(s)
    require("src.modules.brightness_osd")(s)
    require("src.modules.titlebar")
    require("src.modules.volume_controller")(s)

    -- Widgets
    s.layoutlist = require("src.organisms.layout_list")(s)
    s.taglist = require("src.organisms.taglist")(s)
    -- =====================================================================================
    -- BARRA SUPERIOR + DASHBOARDS ON-CLICK (DESIGN_SYSTEM §5).
    -- Sem colunas estáticas, sem chart monolítico, sem dock: os painéis aparecem em popups
    -- (2×) ao CLICAR nos lozenges do control_center.
    -- =====================================================================================

    -- ----- BARRA SUPERIOR -----
    s.tag_controls = require("src.organisms.tag_controls")(s)
    s.tag_controls._preserve_colors = true
    s.powerbutton  = require("src.molecules.power")()
    require("radical_wm.radical_bar")(s, { s.layoutlist, s.taglist, s.tag_controls })

    -- ----- PAINÉIS (2× — vivem DENTRO dos dashboards on-click) -----
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

    -- ----- CONTROL CENTER: lozenges clicáveis (topo-centro) + dashboards on-click -----
    require("src.organisms.control_center")(s, {
      right_widget   = s.powerbutton, -- power vai p/ a barra do canto superior-direito (junto do relógio)
      system_panels  = { s.info_panel, s.usage_panel, s.process_panel },
      network_panels = { s.net_graph_panel, s.ip_panel, s.connections_panel, s.protocols_donut, s.apps_panel },
      time_panels    = { s.calendar_panel, s.international_panel },
    })

    -- ----- LAUNCHER: botão GIF circular no canto inferior-direito + menu de apps -----
    s.app_launcher = require("src.organisms.app_launcher")(s)

    -- ----- MONITORBAR: dock de telemetria persistente no rodapé (DESIGN_SYSTEM §7.3.1) -----
    s.monitor_bar = require("src.organisms.monitor_bar")(s)
  end
end
)
