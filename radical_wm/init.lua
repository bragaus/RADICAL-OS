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
    s.cyber_chart = require("src.widgets.system_monitor_chart") {
      width = dpi(1180),
      height = dpi(720),
      interval = 1,
      samples = 42,
      radius = dpi(18),
      palette = {
        accent = "#ff7a00",
        cpu = "#ff9a1f",
        mem = "#9c63ff",
        gpu = "#62b9ff",
        net = "#55ffd7",
        grid = "#ff7a00",
        text = "#fff4e8",
        overlay = "#120d22",
        glow = "#8d72ff"
      }
    }

    s.tasklist = require("src.widgets.tasklist")(s)
    s.kblayout = require("src.widgets.kblayout")(s)
    s.powerbutton = require("src.widgets.power")()
    s.layoutlist = require("src.widgets.layout_list")(s)
    s.clock_br = require("src.widgets.world_clock") { city = "BRASIL", timezone = "America/Sao_Paulo", country = "br", width = dpi(84), segment_bg = "#1f8f52" }
    s.clock_fr = require("src.widgets.world_clock") { city = "FRANCA", timezone = "Europe/Paris", country = "fr", width = dpi(84), segment_bg = "#191338" }
    s.clock_jp = require("src.widgets.world_clock") { city = "JAPAO", timezone = "Asia/Tokyo", country = "jp", width = dpi(84), segment_bg = "#C24347" }
    s.clock_us = require("src.widgets.world_clock") { city = "EUA", timezone = "America/New_York", country = "us", width = dpi(84), segment_bg = "#1E588D" }
    require("radical_wm.radical_bar")(s, { s.layoutlist, s.taglist, s.tasklist })
    require("radical_wm.center_bar")(s, { s.cyber_chart })
    require("radical_wm.right_bar")(s, { s.clock_br, s.clock_fr, s.clock_jp, s.clock_us, s.powerbutton })
    require("radical_wm.dock")(s, user_vars.dock_programs)
  end
end
)
