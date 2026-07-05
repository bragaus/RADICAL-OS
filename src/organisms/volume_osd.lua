-----------------------------------
-- This is the volume_old module --
-----------------------------------

-- Awesome Libs
local awful      = require("awful")
local p          = require("src.theme.palette")
local dpi        = require("beautiful").xresources.apply_dpi
local gears      = require("gears")
local wibox      = require("wibox")
local mt         = require("src.theme.metrics")
local panel      = require("src.tools.panel")
local hud_slider = require("src.molecules.hud_slider")
local osd_popup  = require("src.tools.osd_popup")

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

  -- Trilha inset dpi(8) + fill gradiente v700 -> v500 (§7.4.2) via molecule. hud_slider's
  -- baked-in syncing guard means the poller's :set_value_silent() never re-fires on_change, so the
  -- classic set_value -> re-poll feedback loop is gone (R8/R4).
  local volume_slider = hud_slider {
    span_w = dpi(232), -- gradient reach: preserves the pre-refactor `to = { dpi(232), 0 }`
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
    w     = dpi(mt.osd_w),
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

  -- User drag re-reads the live volume (preserves the pre-refactor property::value wiring).
  volume_slider:set_on_change(function() update_osd() end)

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
          volume_slider:set_value_silent(tonumber(volume_level)) -- silent (hud_slider guard)
          update_osd()                                    -- explicit label/icon refresh
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
    volume_slider:set_value_silent(tonumber(value))
  end
  )

  update_slider()

  -- Transient bottom-centre popup (shared shell): show + auto-hide + hover-hold + rerun.
  osd_popup {
    s            = s,
    panel_widget = volume_osd_widget,
    show_signal  = "module::volume_osd:show",
    rerun_signal = "widget::volume_osd:rerun",
    timeout      = 2,
  }
end
