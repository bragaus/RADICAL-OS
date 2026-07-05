---------------------------------------
-- This is the brightness_osd module --
---------------------------------------

-- Awesome Libs
local awful      = require("awful")
local dpi        = require("beautiful").xresources.apply_dpi
local gears      = require("gears")
local wibox      = require("wibox")
local p          = require("src.theme.palette")
local mt         = require("src.theme.metrics")
local panel      = require("src.tools.panel")
local hud_slider = require("src.molecules.hud_slider")
local osd_popup  = require("src.tools.osd_popup")

-- VIOLET HUD icon set (icons/svg/): brightness (§3.13.1), recolorido p/ text_heading.
local hud_svg = awful.util.getdir("config") .. "icons/svg/"
local function brightness_image()
  return gears.color.recolor_image(hud_svg .. "brightness.svg", p.text_heading)
end

-- This is a desktop with an NVIDIA RTX 3060 and an external DP monitor: there is no
-- hardware backlight (/sys/class/backlight is empty), so brightness is done in software
-- via xrandr on the primary output. The helper script owns the get/set logic.
--   * script : the get/set helper (was global BRIGHTNESS_SCRIPT).
--   * steps  : % per keyboard brightness key press (was global BACKLIGHT_SEPS).
-- Read from user_vars defensively; the global_keys.lua consumer reads the same fallback.
local brightness = user_vars.brightness or {
  script = awful.util.getdir("config") .. "src/scripts/brightness.sh",
  steps  = 10,
}

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

  -- hud_slider molecule: same HUD look as before + baked-in syncing guard, which replaces
  -- the old manual `syncing_slider` flag (a poller :set_value never re-fires on_change, so
  -- polling brightness no longer triggers an xrandr write — R8/R4).
  local brightness_slider = hud_slider {
    span_w = dpi(232), -- gradient reach: preserves the pre-refactor `to = { dpi(232), 0 }`
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
    w     = dpi(mt.osd_w),
  })

  local refresh_label = function(brightness_value)
    value_label:set_text(tostring(brightness_value) .. "%")
    icon_image:set_image(brightness_image())
  end

  -- User drag writes the new brightness (on_change fires ONLY on drag, never on the
  -- programmatic :set_value from update_slider — so no xrandr write-back loop).
  brightness_slider:set_on_change(function(brightness_value)
    awful.spawn.easy_async_with_shell(
      brightness.script .. " set " .. tostring(brightness_value),
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
  end)

  local update_slider = function()
    awful.spawn.easy_async_with_shell(
      brightness.script .. " get ",
      function(stdout)
      local value = tonumber(stdout)
      if not value then return end
      brightness_slider:set_value(value) -- silent (hud_slider guard replaces syncing_slider)
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

  -- Transient bottom-centre popup (shared shell): show + auto-hide + hover-hold + rerun.
  osd_popup {
    s            = s,
    panel_widget = brightness_osd_widget,
    show_signal  = "module::brightness_osd:show",
    rerun_signal = "widget::brightness_osd:rerun",
    timeout      = 2,
  }
end
