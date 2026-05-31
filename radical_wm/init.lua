--------------------------------------------------------------------------------------------------------------
-- This is the statusbar, every widget, module and so on is combined to all the stuff you see on the screen --
--------------------------------------------------------------------------------------------------------------
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi

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
  require("src.modules.powermenu")(s)
  -- TODO: rewrite calendar osd, maybe write an own inplementation
  -- require("src.modules.calendar_osd")(s)
  require("src.modules.volume_osd")(s)
  require("src.modules.brightness_osd")(s)
  require("src.modules.titlebar")
  require("src.modules.volume_controller")(s)

  -- Widgets
  s.layoutlist = require("src.widgets.layout_list")(s)
  s.taglist = require("src.widgets.taglist")(s)
  if s == resolve_primary() then
    -- =====================================================================================
    -- HUD DE 3 COLUNAS — estrutura da Image #6 (DESIGN_SYSTEM §5.1).
    -- O system_monitor_chart monolítico foi APOSENTADO do centro; o dock inferior também.
    -- =====================================================================================

    -- ----- BARRA SUPERIOR -----
    s.tag_controls = require("src.widgets.tag_controls")(s)
    s.tag_controls._preserve_colors = true
    s.powerbutton  = require("src.widgets.power")()
    s.status_dock  = require("src.widgets.status_dock")()

    -- tags + controle de tags (canto superior-ESQUERDO)
    require("radical_wm.radical_bar")(s, { s.layoutlist, s.taglist, s.tag_controls })
    -- power (canto superior-DIREITO)
    require("radical_wm.right_bar")(s, { s.powerbutton })
    -- STATUS DO MEIO (lozenges Image #7) — topo-CENTRO, entre tags e power
    if s._status_popup then s._status_popup.visible = false end
    s._status_popup = awful.popup {
      screen      = s,
      widget      = s.status_dock,
      ontop       = false,
      bg          = "#0c0617cc", -- base@cc
      visible     = true,
      placement   = function(c) awful.placement.top(c, { margins = { top = dpi(8) } }) end,
    }

    -- ----- PAINÉIS (reusam coletores; todos com chrome de painel) -----
    s.info_panel        = require("src.widgets.info_panel")()
    s.usage_panel       = require("src.widgets.usage_panel")()
    s.process_panel     = require("src.widgets.process_panel")()
    s.net_graph_panel   = require("src.widgets.net_graph_panel")()
    s.ip_panel          = require("src.widgets.ip_panel")()
    s.connections_panel = require("src.widgets.connections_panel")()
    s.protocols_donut   = require("src.widgets.protocols_donut")()
    s.apps_panel        = require("src.widgets.apps_panel")()
    s.calendar_panel    = require("src.widgets.calendar_panel")()
    s.clock_br = require("src.widgets.world_clock") { city = "BRASIL", timezone = "America/Sao_Paulo", country = "br", width = dpi(84), segment_bg = "#130a24" }
    s.clock_fr = require("src.widgets.world_clock") { city = "FRANCA", timezone = "Europe/Paris", country = "fr", width = dpi(84), segment_bg = "#1b1030" }
    s.clock_jp = require("src.widgets.world_clock") { city = "JAPAO", timezone = "Asia/Tokyo", country = "jp", width = dpi(84), segment_bg = "#241640" }
    s.clock_us = require("src.widgets.world_clock") { city = "EUA", timezone = "America/New_York", country = "us", width = dpi(84), segment_bg = "#2e1065" }

    -- COLUNA ESQUERDA: INFO · USAGE · PROCESS
    require("radical_wm.side_panels")(s, { s.info_panel, s.usage_panel, s.process_panel },
      { side = "left", top = dpi(70) })
    -- COLUNA DO MEIO: GRAPH · IP · CONNECTIONS · PROTOCOLS · APPLICATIONS
    require("radical_wm.side_panels")(s, { s.net_graph_panel, s.ip_panel, s.connections_panel, s.protocols_donut, s.apps_panel },
      { side = "center", top = dpi(70) })
    -- COLUNA DIREITA: CALENDAR · INTERNATIONAL (relógios)
    require("radical_wm.side_panels")(s, { s.calendar_panel, s.clock_br, s.clock_fr, s.clock_jp, s.clock_us },
      { side = "right", top = dpi(70) })
  end
end
)
