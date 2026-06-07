-----------------------------------
-- This is the volume_old module --
-----------------------------------

-- Awesome Libs
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local panel = require("src.tools.panel")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/audio/"
-- VIOLET HUD icon set (icons/svg/): vol / volume_mute (§3.13.1), recolorido p/ text_heading.
local hud_svg = awful.util.getdir("config") .. "icons/svg/"
local function vol_image(muted)
  return gears.color.recolor_image(hud_svg .. (muted and "volume_mute" or "vol") .. ".svg", p.text_heading)
end

-- Returns the volume_osd
return function(s)

  -- Compact icon (~dpi(24)), recolored text_heading; held as a direct ref
  -- (panel's bg-wrapper breaks dotted id chains — see MEMORY violet-hud note).
  local icon = wibox.widget {
    forced_height = dpi(24),
    forced_width  = dpi(24),
    image  = vol_image(false),
    widget = wibox.widget.imagebox,
  }

  local value_label = wibox.widget {
    text   = "0%",
    align  = "right",
    valign = "center",
    widget = wibox.widget.textbox,
  }

  -- Trilha inset, height dpi(8) (§7.4.2), fill gradient v700 -> v500
  local volume_slider = wibox.widget {
    bar_shape        = gears.shape.rounded_bar,
    bar_height       = dpi(8),
    bar_color        = p.inset,
    bar_active_color = {
      type  = "linear",
      from  = { 0, 0 },
      to    = { dpi(232), 0 },
      stops = { { 0, p.v700 }, { 1, p.v500 } }
    },
    handle_color        = p.v500,
    handle_shape        = gears.shape.circle,
    handle_width        = dpi(10),
    handle_border_color = p.line_bright,
    maximum             = 100,
    widget              = wibox.widget.slider,
  }

  -- Body: icon + horizontal bar (value % on the right); slider is the
  -- expanding middle element so it fills the panel width.
  local osd_body = wibox.widget {
    icon,
    {
      volume_slider,
      forced_height = dpi(24),
      widget        = wibox.container.place,
    },
    value_label,
    spacing = dpi(10),
    expand  = "inside",
    layout  = wibox.layout.align.horizontal,
  }

  local volume_osd_widget = panel({
    title = "VOLUME",
    body  = osd_body,
    w     = dpi(280),
  })

  local function is_not_a_number(value)
    return value == nil or tonumber(value) == nil
  end

  local function update_osd()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/vol.sh volume",
      function(stdout)
      local volume_level = stdout:gsub("\n", ""):gsub("%%", "")
      if is_not_a_number(volume_level) then
        return
      end
      awesome.emit_signal("widget::volume")
      value_label:set_text(volume_level .. "%")

      awesome.emit_signal(
        "widget::volume:update",
        volume_level
      )

      if awful.screen.focused().show_volume_osd then
        awesome.emit_signal(
          "module::volume_osd:show",
          true
        )
      end
      volume_level = tonumber(volume_level)
      icon:set_image(vol_image(volume_level < 1))
    end
    )
  end

  volume_slider:connect_signal(
    "property::value",
    function()
    update_osd()
  end
  )

  local update_slider = function()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/vol.sh mute",
      function(stdout)
      if stdout:match("yes") then
        value_label:set_text("0%")
        icon:set_image(vol_image(true))
      else
        awful.spawn.easy_async_with_shell(
          "./.config/awesome/src/scripts/vol.sh volume",
          function(stdout2)
          local volume_level = stdout2:gsub("%%", ""):gsub("\n", "")
          if is_not_a_number(volume_level) then
            return
          end
          volume_slider:set_value(tonumber(volume_level))
          update_osd()
        end
        )
      end
    end
    )
  end

  -- Signals
  awesome.connect_signal(
    "module::slider:update",
    function()
    update_slider()
  end
  )

  awesome.connect_signal(
    "widget::volume:update",
    function(value)
    volume_slider:set_value(tonumber(value))
  end
  )

  update_slider()

  local volume_container = awful.popup {
    widget = wibox.container.background,
    ontop = true,
    bg = p.base .. "00",
    stretch = false,
    visible = false,
    screen = s,
    placement = function(c) awful.placement.bottom(c, { margins = { bottom = dpi(40) } }) end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(4))
    end
  }

  local hide_volume_osd = gears.timer {
    timeout = 2,
    autostart = true,
    callback = function()
      volume_container.visible = false
    end
  }

  volume_container:setup {
    volume_osd_widget,
    layout = wibox.layout.fixed.horizontal
  }

  awesome.connect_signal(
    "module::volume_osd:show",
    function()
    if s == mouse.screen then
      volume_container.visible = true
    end
  end
  )

  volume_container:connect_signal(
    "mouse::enter",
    function()
    volume_container.visible = true
    hide_volume_osd:stop()
  end
  )

  volume_container:connect_signal(
    "mouse::leave",
    function()
    volume_container.visible = true
    hide_volume_osd:again()
  end
  )

  awesome.connect_signal(
    "widget::volume_osd:rerun",
    function()
    if hide_volume_osd.started then
      hide_volume_osd:again()
    else
      hide_volume_osd:start()
    end
  end
  )
end
