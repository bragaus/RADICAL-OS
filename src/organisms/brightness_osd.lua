---------------------------------------
-- This is the brightness_osd module --
---------------------------------------

-- Awesome Libs
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local p = require("src.theme.palette")
local panel = require("src.tools.panel")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/brightness/"
-- VIOLET HUD icon set (icons/svg/): brightness (§3.13.1), recolorido p/ text_heading.
local hud_svg = awful.util.getdir("config") .. "icons/svg/"
local function brightness_image()
  return gears.color.recolor_image(hud_svg .. "brightness.svg", p.text_heading)
end

-- This is a desktop with an NVIDIA RTX 3060 and an external DP monitor: there is no
-- hardware backlight (/sys/class/backlight is empty), so brightness is done in software
-- via xrandr on the primary output. The helper script owns the get/set logic.
BRIGHTNESS_SCRIPT = awful.util.getdir("config") .. "src/scripts/brightness.sh"
-- Step (in %) per keyboard brightness key press. Kept global for mappings/global_keys.lua.
BACKLIGHT_SEPS = 10

return function(s)

  -- Sub-widgets como locais diretos: panel() aninha um `body` pré-construído, então os
  -- ids declarativos NÃO entram no by_id do painel — get_children_by_id devolveria nil
  -- (era o bug de construção). Referência direta é robusta (mesmo padrão do volume_osd).
  local icon_image = wibox.widget {
    forced_height = dpi(24),
    forced_width  = dpi(24),
    image         = brightness_image(),
    widget        = wibox.widget.imagebox,
  }

  local value_label = wibox.widget {
    text   = "0%",
    align  = "left",
    valign = "center",
    widget = wibox.widget.textbox,
  }

  local brightness_slider = wibox.widget {
    bar_shape           = gears.shape.rounded_rect,
    bar_height          = dpi(8),
    bar_color           = p.inset,
    bar_active_color    = {
      type = "linear",
      from = { 0, 0 },
      to   = { dpi(232), 0 },
      stops = { { 0, p.v700 }, { 1, p.v500 } },
    },
    handle_color        = p.v500,
    handle_shape        = gears.shape.circle,
    handle_width        = dpi(10),
    handle_border_color = p.line_bright,
    maximum             = 100,
    widget              = wibox.widget.slider,
  }

  local osd_body = wibox.widget {
    {
      icon_image,
      fg     = p.text_heading,
      widget = wibox.container.background,
    },
    {
      {
        value_label,
        fg     = p.text_bright,
        widget = wibox.container.background,
      },
      {
        brightness_slider,
        widget = wibox.container.place,
      },
      spacing = dpi(6),
      layout  = wibox.layout.fixed.vertical,
    },
    spacing = dpi(10),
    layout  = wibox.layout.fixed.horizontal,
  }

  local brightness_osd_widget = panel({
    title = "BRIGHTNESS",
    body  = osd_body,
    w     = dpi(280),
  })

  local refresh_label = function(brightness_value)
    value_label:set_text(tostring(brightness_value) .. "%")
    icon_image:set_image(brightness_image())
  end

  -- Guard so programmatic set_value() (from update_slider) does not re-trigger an xrandr write.
  local syncing_slider = false

  brightness_slider:connect_signal(
    "property::value",
    function()
    if syncing_slider then return end
    local brightness_value = brightness_slider.value
    awful.spawn.easy_async_with_shell(
      BRIGHTNESS_SCRIPT .. " set " .. tostring(brightness_value),
      function(stdout)
      local applied = tonumber(stdout) or brightness_value
      refresh_label(applied)

      if awful.screen.focused().show_brightness_osd then
        awesome.emit_signal(
          "module::brightness_osd:show",
          true
        )
      end
    end
    )
  end
  )

  local update_slider = function()
    awful.spawn.easy_async_with_shell(
      BRIGHTNESS_SCRIPT .. " get ",
      function(stdout)
      local value = tonumber(stdout)
      if not value then return end
      syncing_slider = true
      brightness_slider:set_value(value)
      syncing_slider = false
      refresh_label(value)
    end
    )
  end

  awesome.connect_signal(
    "module::brightness_slider:update",
    function()
    update_slider()
  end
  )

  awesome.connect_signal(
    "widget::brightness:update",
    function(value)
    brightness_slider:set_value(tonumber(value))
  end
  )

  update_slider()

  local brightness_container = awful.popup {
    widget = wibox.container.background,
    ontop = true,
    bg = p.a(p.base, 0),
    stretch = false,
    visible = false,
    screen = s,
    placement = function(c) awful.placement.bottom(c, { margins = { bottom = dpi(40) } }) end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(4))
    end
  }

  local hide_brightness_osd = gears.timer {
    timeout = 2,
    autostart = true,
    callback = function()
      brightness_container.visible = false
    end
  }

  brightness_container:setup {
    brightness_osd_widget,
    layout = wibox.layout.fixed.horizontal
  }

  awesome.connect_signal(
    "widget::brightness_osd:rerun",
    function()
    if hide_brightness_osd.started then
      hide_brightness_osd:again()
    else
      hide_brightness_osd:start()
    end
  end
  )

  awesome.connect_signal(
    "module::brightness_osd:show",
    function()
    if s == mouse.screen then
      brightness_container.visible = true
    end
  end
  )

  brightness_container:connect_signal(
    "mouse::enter",
    function()
    brightness_container.visible = true
    hide_brightness_osd:stop()
  end
  )

  brightness_container:connect_signal(
    "mouse::leave",
    function()
    brightness_container.visible = true
    hide_brightness_osd:again()
  end
  )
end
