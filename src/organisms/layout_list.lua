----------------------------------
-- This is the layoutbox widget --
----------------------------------

-- Awesome Libs
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local gfs = require("gears.filesystem")
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
require("src.core.signals")

local glyph_color = p.text_primary
local glyph_active = p.v400

-- Returns the layoutbox widget
return function(s)
  local layout_icon = wibox.widget {
    resize = true,
    widget = wibox.widget.imagebox
  }

  local layout = wibox.widget {
    {
      {
        layout_icon,
        id = "icon_layout",
        widget = wibox.container.place
      },
      id = "icon_margin",
      left = dpi(5),
      right = dpi(5),
      forced_width = dpi(40),
      widget = wibox.container.margin
    },
    bg = p.v900,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(mt.radius_pill))
    end,
    widget = wibox.container.background,
    screen = s
  }

  layout._preserve_colors = true

  local layout_icon_map = {
    floating = "floating.svg",
    tile = "tile.svg",
    fairh = "fairh.svg",
    fairv = "fairv.svg",
    fullscreen = "fullscreen.svg",
    max = "max.svg",
    magnifier = "magnifier.svg",
    cornerne = "cornerne.svg",
    cornernw = "cornernw.svg",
    cornerse = "cornerse.svg",
    cornersw = "cornersw.svg",
    dwindle = "dwindle.svg"
  }

  local function update_layout_icon()

    local current_layout = awful.layout.get(s)
    local layout_name = awful.layout.getname(current_layout)
    local icon_file = layout_icon_map[layout_name]

    if icon_file then
      local icon_path = gfs.get_configuration_dir() .. "src/assets/layout/" .. icon_file
      layout_icon:set_image(gears.color.recolor_image(icon_path, glyph_color))
    end
  end

  -- Signals
  Hover_signal(layout, p.raised, glyph_active)

  -- Botões por-botão (antes: button::press em QUALQUER botão fazia sempre inc(-1), então
  -- clique-esquerdo voltava o layout e scroll/direito também — rearranjava as janelas ao
  -- contrário do esperado). Agora: esquerdo = próximo, direito = anterior, scroll = cicla.
  layout:buttons(gears.table.join(
    awful.button({}, 1, function() awful.layout.inc( 1, s); update_layout_icon() end),
    awful.button({}, 3, function() awful.layout.inc(-1, s); update_layout_icon() end),
    awful.button({}, 4, function() awful.layout.inc( 1, s); update_layout_icon() end),
    awful.button({}, 5, function() awful.layout.inc(-1, s); update_layout_icon() end)
  ))

  tag.connect_signal(
    "property::layout",
    function(t)
      if t.screen == s and t.selected then
        update_layout_icon()
      end
    end
  )

  update_layout_icon()

  return layout
end
