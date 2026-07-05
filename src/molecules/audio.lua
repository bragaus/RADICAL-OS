------------------------------
-- This is the audio widget --
------------------------------
-- VIOLET HUD wiring pass:
--   * PATH FIX (R3): the vol.sh / bt.sh invocations were CWD-relative
--     ("./.config/awesome/..."), which only resolved when awesome's cwd was $HOME.
--     Now anchored via gears.filesystem.get_configuration_dir().
--   * GATED SAMPLING (R8): the two always-on autostart gears.timer pollers (0.5s
--     pactl mute + 5s bt.sh) are replaced by the canonical :start_sampling() /
--     :stop_sampling() shape (self._sampling guard -> immediate sample -> timer
--     :start()/:stop()) so the widget never runs an always-on poller.
--   * get::volume / get::volume_mute / volume_controller emissions kept VERBATIM.
--
-- NOTE (pill): a full pill{} swap was NOT applied here — this widget's dynamic
-- multi-state icon set (volume-low/-medium/-high/-mute) lives in
-- src/assets/icons/audio (NOT icons/svg/, which the pill icon atom resolves), and
-- it carries an inline bluetooth sub-row (bt_icon + bt_label). Neither fits pill's
-- single-icon + single-label API without regressing behavior or copying assets.
-- See the returned findings / BLUEPRINT §4 audio row.

-- Awesome Libs
local awful = require("awful")
local p     = require("src.theme.palette")
local dpi   = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local gfs   = require("gears.filesystem")
local wibox = require("wibox")
require("src.core.signals")

-- Icon directory path
local icondir    = awful.util.getdir("config") .. "src/assets/icons/audio/"
local bt_icondir = awful.util.getdir("config") .. "src/assets/icons/bluetooth/"
-- Shell helpers, anchored to the config dir (was CWD-relative "./.config/awesome/...").
local scripts    = gfs.get_configuration_dir() .. "src/scripts/"

-- Returns the audio widget
return function(s)

  local audio_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              resize = false
            },
            id = "icon_layout",
            widget = wibox.container.place
          },
          top = dpi(2),
          widget = wibox.container.margin,
          id = "icon_margin"
        },
        spacing = dpi(10),
        {
          id = "label",
          align = "center",
          valign = "center",
          widget = wibox.widget.textbox
        },
        {
          id = "bt_status",
          visible = false,
          spacing = dpi(4),
          layout = wibox.layout.fixed.horizontal,
          {
            id = "bt_icon",
            image = gears.color.recolor_image(bt_icondir .. "bluetooth-on.svg", p.v500),
            widget = wibox.widget.imagebox,
            resize = false
          },
          {
            id = "bt_label",
            align = "center",
            valign = "center",
            widget = wibox.widget.textbox
          }
        },
        id = "audio_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.panel,
    fg = p.text_bright,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  local get_volume = function()
    awful.spawn.easy_async_with_shell(
      scripts .. "vol.sh volume",
      function(stdout)
        local icon = icondir .. "volume"
        stdout = stdout:gsub("%%", "")
        local volume = tonumber(stdout) or 0
        audio_widget.container.audio_layout.spacing = dpi(5)
        audio_widget.container.audio_layout.label.visible = true
        if volume < 1 then
          icon = icon .. "-mute"
          audio_widget.container.audio_layout.spacing = dpi(0)
          audio_widget.container.audio_layout.label.visible = false
        elseif volume >= 1 and volume < 34 then
          icon = icon .. "-low"
        elseif volume >= 34 and volume < 67 then
          icon = icon .. "-medium"
        elseif volume >= 67 then
          icon = icon .. "-high"
        end
        audio_widget.container.audio_layout.label:set_text(volume .. "%")
        audio_widget.container.audio_layout.icon_margin.icon_layout.icon:set_image(
          gears.color.recolor_image(icon .. ".svg", p.text_bright ))
        awesome.emit_signal("get::volume", volume)
      end
    )
  end

  local check_muted = function()
    awful.spawn.easy_async_with_shell(
      scripts .. "vol.sh mute",
      function(stdout)
        if stdout:match("yes") then
          audio_widget.container.audio_layout.label.visible = false
          audio_widget.container:set_right(0)
          audio_widget.container.audio_layout.icon_margin.icon_layout.icon:set_image(
            gears.color.recolor_image(icondir .. "volume-mute" .. ".svg", p.text_bright ))
          awesome.emit_signal("get::volume_mute", true)
        else
          audio_widget.container:set_right(10)
          awesome.emit_signal("get::volume_mute", false)
          get_volume()
        end
      end
    )
  end

  local update_bluetooth = function()
    awful.spawn.easy_async_with_shell(
      scripts .. "bt.sh",
      function(stdout)
        local compact = (stdout or ""):gsub("\n", " "):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        local bt_status = audio_widget.container.audio_layout.bt_status

        if compact == "" then
          bt_status.visible = false
          return
        end

        bt_status.visible = true
        bt_status.bt_label:set_text(compact:sub(1, 16):upper())
      end
    )
  end

  -- Signals
  Hover_signal(audio_widget, p.v700, p.v500 )

  audio_widget:connect_signal(
    "button::press",
    function()
      awesome.emit_signal("module::slider:update")
      awesome.emit_signal("widget::volume_osd:rerun")
      awesome.emit_signal("volume_controller::toggle", s)
      awesome.emit_signal("volume_controller::toggle:keygrabber")
    end
  )

  -- Gated sampling (R8): no always-on pollers. Mounting code opts in via
  -- :start_sampling() (mirrors the 8 dashboard organisms' shape).
  local muted_timer = gears.timer {
    timeout   = 0.5,
    autostart = false,
    call_now  = false,
    callback  = check_muted,
  }
  local bt_timer = gears.timer {
    timeout   = 5,
    autostart = false,
    call_now  = false,
    callback  = update_bluetooth,
  }

  function audio_widget:start_sampling()
    if self._sampling then return end
    self._sampling = true
    check_muted()
    update_bluetooth()
    muted_timer:start()
    bt_timer:start()
  end

  function audio_widget:stop_sampling()
    self._sampling = false
    muted_timer:stop()
    bt_timer:stop()
  end

  return audio_widget
end
