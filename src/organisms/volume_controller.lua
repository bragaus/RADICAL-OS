-----------------------------------
-- This is the volume controller --
-----------------------------------

-- Awesome Libs
local awful      = require("awful")
local color      = require("src.theme.colors")
local p          = require("src.theme.palette")
local dpi        = require("beautiful").xresources.apply_dpi
local gears      = require("gears")
local naughty    = require("naughty")
local wibox      = require("wibox")
local hud_slider = require("src.molecules.hud_slider")
local signals    = require("src.core.signals") -- side effect: Hover_signal global; also .hover_stateful

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/audio/"

-- Returns the volume controller
return function(s)

  -- Create a source/sink device row (single parametrized path — output vs input differ only
  -- in the accent, icon, select command, highlight signal and default-node queries).
  local function create_device(name, node, sink)
    -- sink == true -> output device (primary violet); false -> input/mic (lighter violet)
    local accent      = sink and p.v500 or p.v400
    local device_icon = sink and "headphones.svg" or "microphone.svg"
    local set_cmd     = sink and "./.config/awesome/src/scripts/vol.sh set_sink "
                              or  "./.config/awesome/src/scripts/mic.sh set_source "
    local bg_signal   = sink and "update::background:vol" or "update::background:mic"
    local q_default   = sink and "pactl get-default-sink" or "pactl get-default-source"
    local q_fallback  = sink
      and [[LC_ALL=C pactl info | perl -n -e'/Default Sink: (.+)\s/ && print $1']]
      or  [[LC_ALL=C pactl info | perl -n -e'/Default Source: (.+)\s/ && print $1']]

    -- Background container held as a direct ref (drives hover + active-state recolour).
    local bg = wibox.widget {
      {
        {
          {
            image  = gears.color.recolor_image(icondir .. device_icon, accent),
            resize = false,
            widget = wibox.widget.imagebox,
          },
          {
            text   = name,
            widget = wibox.widget.textbox,
          },
          layout = wibox.layout.align.horizontal,
        },
        margins = dpi(5),
        widget  = wibox.container.margin,
      },
      shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, 4)
      end,
      widget = wibox.container.background,
    }

    local device = wibox.widget {
      bg,
      margins = dpi(5),
      widget  = wibox.container.margin,
    }

    -- Select this device on click.
    device:connect_signal("button::press", function()
      awful.spawn.spawn(set_cmd .. node)
      awesome.emit_signal(bg_signal, node)
    end)

    -- Hover/press (DESIGN_SYSTEM §8): hover -> raised/text_bright, press -> v600. The live
    -- selected-state colours are captured at enter and restored on leave. Wired ONCE (R7).
    signals.hover_stateful(bg, {
      hover_bg = p.raised,
      hover_fg = p.text_bright,
      press_bg = p.v600,
    })

    -- Active (selected) device: accent fill + base text; others accent text on raised.
    local function set_active(active)
      if active then
        bg:set_bg(accent)
        bg:set_fg(p.base)
      else
        bg:set_fg(accent)
        bg:set_bg(p.raised)
      end
    end

    awesome.connect_signal(bg_signal, function(new_node)
      set_active(node == new_node)
    end)

    -- Initial highlight from the current default node (pactl info fallback).
    awful.spawn.easy_async_with_shell(q_default, function(stdout)
      local active = stdout:gsub("\n", "")
      if active ~= "" then
        set_active(node == active)
      else
        awful.spawn.easy_async_with_shell(q_fallback, function(stdout2)
          local active2 = stdout2:gsub("\n", "")
          if active2 ~= "" then
            set_active(node == active2)
          end
        end)
      end
    end)

    return device
  end

  -- Container for the source devices
  local dropdown_list_volume = wibox.widget {
    {
      {
        layout = wibox.layout.fixed.vertical,
        id = "volume_device_list"
      },
      id = "volume_device_background",
      bg = p.inset,
      shape = function(cr, width, height)
        gears.shape.partially_rounded_rect(cr, width, height, false, false, true, true, 4)
      end,
      widget = wibox.container.background
    },
    left = dpi(10),
    right = dpi(10),
    widget = wibox.container.margin
  }

  -- Container for the sink devices
  local dropdown_list_microphone = wibox.widget {
    {
      {
        layout = wibox.layout.fixed.vertical,
        id = "volume_device_list"
      },
      id = "volume_device_background",
      bg = p.inset,
      shape = function(cr, width, height)
        gears.shape.partially_rounded_rect(cr, width, height, false, false, true, true, 4)
      end,
      widget = wibox.container.background
    },
    left = dpi(10),
    right = dpi(10),
    widget = wibox.container.margin
  }

  -- Slider + icon sub-widgets built as direct refs (R1) and embedded into the tree below.
  -- hud_slider size variant (track dpi(5), handle dpi(15)) + solid v700 fill (§7.4). The
  -- baked-in syncing guard breaks the "get::volume -> set_value -> re-set sink volume" loop
  -- because the poller's :set_value never re-fires on_change (R8).
  local audio_slider = hud_slider {
    track_h   = dpi(5),
    handle_w  = dpi(15),
    fill      = p.v700,
    on_change = function(volume)
      awful.spawn("pactl set-sink-volume @DEFAULT_SINK@ " .. tonumber(volume) .. "%")
    end,
  }
  audio_slider.forced_height = dpi(26)

  local mic_slider = hud_slider {
    track_h   = dpi(5),
    handle_w  = dpi(15),
    fill      = p.v700,
    on_change = function(volume)
      awful.spawn("pactl set-source-volume @DEFAULT_SOURCE@ " .. tonumber(volume) .. "%")
      awesome.emit_signal("get::mic_volume", volume)
    end,
  }
  mic_slider.forced_height = dpi(26)

  local audio_icon = wibox.widget {
    resize = false,
    image  = gears.color.recolor_image(icondir .. "volume-high.svg", p.v500),
    widget = wibox.widget.imagebox,
  }

  local mic_icon = wibox.widget {
    resize = false,
    image  = gears.color.recolor_image(icondir .. "microphone.svg", p.v400),
    widget = wibox.widget.imagebox,
  }

  local volume_controller = wibox.widget {
    {
      {
        -- Audio Device selector
        {
          {
            {
              {
                {
                  resize = false,
                  image = gears.color.recolor_image(icondir .. "menu-down.svg", p.v400),
                  widget = wibox.widget.imagebox,
                  id = "icon"
                },
                id = "center",
                halign = "center",
                valign = "center",
                widget = wibox.container.place,
              },
              {
                {
                  text = "Output Device",
                  widget = wibox.widget.textbox,
                  id = "device_name"
                },
                margins = dpi(5),
                widget = wibox.container.margin
              },
              id = "audio_volume",
              layout = wibox.layout.fixed.horizontal
            },
            id = "audio_bg",
            bg = p.panel_hi,
            fg = p.text_heading,
            shape = function(cr, width, height)
              gears.shape.rounded_rect(cr, width, height, 4)
            end,
            widget = wibox.container.background
          },
          id = "audio_selector_margin",
          left = dpi(10),
          right = dpi(10),
          top = dpi(10),
          widget = wibox.container.margin
        },
        {
          id = "volume_list",
          widget = dropdown_list_volume,
          visible = false
        },
        -- Microphone selector
        {
          {
            {
              {
                {
                  resize = false,
                  image = gears.color.recolor_image(icondir .. "menu-down.svg", p.v400),
                  widget = wibox.widget.imagebox,
                  id = "icon",
                },
                id = "center",
                halign = "center",
                valign = "center",
                widget = wibox.container.place,
              },
              {
                {
                  text = "Input Device",
                  widget = wibox.widget.textbox,
                  id = "device_name"
                },
                margins = dpi(5),
                widget = wibox.container.margin
              },
              id = "mic_volume",
              layout = wibox.layout.fixed.horizontal
            },
            id = "mic_bg",
            bg = p.panel_hi,
            fg = p.text_heading,
            shape = function(cr, width, height)
              gears.shape.rounded_rect(cr, width, height, 4)
            end,
            widget = wibox.container.background
          },
          id = "mic_selector_margin",
          left = dpi(10),
          right = dpi(10),
          top = dpi(10),
          widget = wibox.container.margin
        },
        {
          id = "mic_list",
          widget = dropdown_list_microphone,
          visible = false
        },
        -- Audio volume slider (hud_slider molecule + direct-ref icon)
        {
          {
            audio_icon,
            {
              audio_slider,
              bottom = dpi(12),
              left   = dpi(5),
              widget = wibox.container.margin
            },
            layout = wibox.layout.align.horizontal
          },
          id = "audio_volume_margin",
          top = dpi(10),
          left = dpi(10),
          right = dpi(10),
          widget = wibox.container.margin
        },
        -- Microphone volume slider (hud_slider molecule + direct-ref icon)
        {
          {
            mic_icon,
            {
              mic_slider,
              left   = dpi(5),
              widget = wibox.container.margin
            },
            layout = wibox.layout.align.horizontal
          },
          id = "mic_volume_margin",
          left = dpi(10),
          right = dpi(10),
          widget = wibox.container.margin
        },
        id = "controller_layout",
        layout = wibox.layout.fixed.vertical
      },
      id = "controller_margin",
      margins = dpi(10),
      widget = wibox.container.margin
    },
    bg = p.panel .. "f2",
    border_color = p.line_base,
    border_width = dpi(4),
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 12)
    end,
    forced_width = dpi(400),
    widget = wibox.container.background
  }

  -- Variables for easier access and better readability
  local audio_selector_margin = volume_controller:get_children_by_id("audio_selector_margin")[1]
  local volume_list = volume_controller:get_children_by_id("volume_list")[1]
  local audio_bg = volume_controller:get_children_by_id("audio_bg")[1]
  local audio_volume = volume_controller:get_children_by_id("audio_volume")[1].center

  -- Click event for the audio dropdown
  audio_selector_margin:connect_signal(
    "button::press",
    function()
      volume_list.visible = not volume_list.visible
      if volume_list.visible then
        audio_bg.shape = function(cr, width, height)
          gears.shape.partially_rounded_rect(cr, width, height, true, true, false, false, 4)
        end
        audio_volume.icon:set_image(gears.color.recolor_image(icondir .. "menu-up.svg", p.v400))
      else
        audio_bg.shape = function(cr, width, height)
          gears.shape.rounded_rect(cr, width, height, 4)
        end
        audio_volume.icon:set_image(gears.color.recolor_image(icondir .. "menu-down.svg", p.v400))
      end
    end
  )

  -- Variables for easier access and better readability
  local mic_selector_margin = volume_controller:get_children_by_id("mic_selector_margin")[1]
  local mic_list = volume_controller:get_children_by_id("mic_list")[1]
  local mic_bg = volume_controller:get_children_by_id("mic_bg")[1]
  local mic_volume = volume_controller:get_children_by_id("mic_volume")[1].center

  -- Click event for the microphone dropdown
  mic_selector_margin:connect_signal(
    "button::press",
    function()
      mic_list.visible = not mic_list.visible
      if mic_list.visible then
        mic_selector_margin.mic_bg.shape = function(cr, width, height)
          gears.shape.partially_rounded_rect(cr, width, height, true, true, false, false, 4)
        end
        mic_volume.icon:set_image(gears.color.recolor_image(icondir .. "menu-up.svg", p.v400))
      else
        mic_bg.shape = function(cr, width, height)
          gears.shape.rounded_rect(cr, width, height, 4)
        end
        mic_volume.icon:set_image(gears.color.recolor_image(icondir .. "menu-down.svg", p.v400))
      end
    end
  )

  -- Volume slider change event: on_change fires ONLY on user drag (see hud_slider above).
  -- Setting the sink volume lives in audio_slider.on_change; nothing to wire here.

  -- Microphone slider change event: see mic_slider.on_change above.

  -- Main container
  local volume_controller_container = awful.popup {
    widget = wibox.container.background,
    ontop = true,
    bg = p.panel .. "f2",
    stretch = false,
    visible = false,
    screen = s,
    placement = function(c) awful.placement.align(c,
        { position = "top_right", margins = { right = dpi(305), top = dpi(60) } })
    end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 12)
    end
  }

  -- Get all source devices
  local function get_source_devices()
    awful.spawn.easy_async_with_shell(
      [[ pactl list sinks | grep -E 'node.name|alsa.card_name' | awk '{gsub(/"/, ""); for(i = 3;i < NF;i++) printf $i " "; print $NF}' ]]
      ,

      function(stdout)
        local i, j = 1, 1
        local device_list = { layout = wibox.layout.fixed.vertical }

        local node_names, alsa_names = {}, {}
        for node_name in stdout:gmatch("[^\n]+") do
          if (i % 2) == 0 then
            table.insert(node_names, node_name)
          end
          i = i + 1
        end

        for alsa_name in stdout:gmatch("[^\n]+") do
          if (j % 2) == 1 then
            table.insert(alsa_names, alsa_name)
          end
          j = j + 1
        end

        for k = 1, #alsa_names, 1 do
          device_list[#device_list + 1] = create_device(alsa_names[k], node_names[k], true)
        end
        dropdown_list_volume.volume_device_background.volume_device_list.children = device_list
      end
    )
  end

  get_source_devices()

  -- Get all input devices
  local function get_input_devices()
    awful.spawn.easy_async_with_shell(
      [[ pactl list sources | grep -E "node.name|alsa.card_name" | awk '{gsub(/"/, ""); for(i = 3;i < NF;i++) printf $i " "; print $NF}' ]]
      ,

      function(stdout)
        local i, j = 1, 1
        local device_list = { layout = wibox.layout.fixed.vertical }

        local node_names, alsa_names = {}, {}
        for node_name in stdout:gmatch("[^\n]+") do
          if (i % 2) == 0 then
            table.insert(node_names, node_name)
          end
          i = i + 1
        end

        for alsa_name in stdout:gmatch("[^\n]+") do
          if (j % 2) == 1 then
            table.insert(alsa_names, alsa_name)
          end
          j = j + 1
        end

        for k = 1, #alsa_names, 1 do
          device_list[#device_list + 1] = create_device(alsa_names[k], node_names[k], false)
        end
        dropdown_list_microphone.volume_device_background.volume_device_list.children = device_list
      end
    )
  end

  get_input_devices()

  -- Event watcher, detects when a device is added/removed.
  -- LEAK FIX (R3): `pactl subscribe` is a long-lived process; store its PID per-screen and
  -- kill any prior subscription before spawning a new one so reconstructing this screen's
  -- controller does not orphan subscribers. Kill via an argv array (never a shell string).
  if type(s._volume_pactl_subscribe_pid) == "number" then
    awful.spawn({ "kill", tostring(s._volume_pactl_subscribe_pid) })
  end
  local subscribe_pid = awful.spawn.with_line_callback(
    [[bash -c "LC_ALL=C pactl subscribe | grep --line-buffered 'on server'"]],
    {
      stdout = function(line)
        get_input_devices()
        get_source_devices()
      end
    }
  )
  if type(subscribe_pid) == "number" then
    s._volume_pactl_subscribe_pid = subscribe_pid
  end

  -- Get microphone volume
  local function get_mic_volume()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/mic.sh volume",
      function(stdout)
        local volume = tonumber((stdout:gsub("%%", ""):gsub("\n", ""))) or 0
        mic_slider:set_value(volume)
        if volume > 0 then
          mic_icon:set_image(gears.color.recolor_image(icondir .. "microphone.svg", p.v400))
        else
          mic_icon:set_image(gears.color.recolor_image(icondir .. "microphone-off.svg", p.v400))
        end
      end
    )
  end

  get_mic_volume()

  -- Check if microphone is muted
  local function get_mic_mute()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/mic.sh mute",
      function(stdout)
        if stdout:match("yes") then
          mic_slider:set_value(0)
          mic_icon:set_image(gears.color.recolor_image(icondir .. "microphone-off.svg", p.v400))
        else
          get_mic_volume()
        end
      end
    )
  end

  get_mic_mute()

  -- When the mouse leaves the popup it stops the mousegrabber and hides the popup.
  volume_controller_container:connect_signal(
    "mouse::leave",
    function()
      mousegrabber.run(
        function()
          awesome.emit_signal("volume_controller::toggle", s)
          mousegrabber.stop()
          return true
        end,
        "arrow"
      )
    end
  )

  volume_controller_container:connect_signal(
    "mouse::enter",
    function()
      mousegrabber.stop()
    end
  )

  -- Grabs all keys and hides popup when anything is pressed
  -- TODO: Make it possible to navigate and select using the kb
  local volume_controller_keygrabber = awful.keygrabber {
    autostart = false,
    stop_event = 'release',
    keypressed_callback = function(self, mod, key, command)
      awesome.emit_signal("volume_controller::toggle", s)
      mousegrabber.stop()
    end
  }

  -- Draw the popup
  volume_controller_container:setup {
    volume_controller,
    layout = wibox.layout.fixed.horizontal
  }

  --[[ awesome.connect_signal(
    "volume_controller::toggle:keygrabber",
    function()
      if awful.keygrabber.is_running then
        volume_controller_keygrabber:stop()
      else
        volume_controller_keygrabber:start()
      end

    end
  ) ]]

  -- Set the volume and icon
  awesome.connect_signal(
    "get::volume",
    function(volume)
      volume = tonumber(volume)
      local icon = icondir .. "volume"
      if volume < 1 then
        icon = icon .. "-mute"

      elseif volume >= 1 and volume < 34 then
        icon = icon .. "-low"
      elseif volume >= 34 and volume < 67 then
        icon = icon .. "-medium"
      elseif volume >= 67 then
        icon = icon .. "-high"
      end

      audio_slider:set_value(volume)
      audio_icon:set_image(gears.color.recolor_image(icon .. ".svg", p.v500))
    end
  )

  -- Check if the volume is muted
  awesome.connect_signal(
    "get::volume_mute",
    function(mute)
      if mute then
        audio_icon:set_image(gears.color.recolor_image(icondir .. "volume-mute.svg", p.v500))
      end
    end
  )

  -- Set the microphone volume
  awesome.connect_signal(
    "get::mic_volume",
    function(volume)
      if volume > 0 then
        mic_icon:set_image(gears.color.recolor_image(icondir .. "microphone.svg", p.v400))
      else
        mic_icon:set_image(gears.color.recolor_image(icondir .. "microphone-off.svg", p.v400))
      end
    end
  )

  -- Toggle container visibility
  awesome.connect_signal(
    "volume_controller::toggle",
    function(scr)
      if scr == s then
        volume_controller_container.visible = not volume_controller_container.visible
        if volume_controller_container.visible then
          local geo = mouse.current_widget_geometry
          if geo then
            awful.placement.next_to(volume_controller_container, {
              geometry = geo,
              preferred_positions = "bottom",
              preferred_anchors = "back",
            })
          else
            awful.placement.align(volume_controller_container,
              { position = "top_right", margins = { right = dpi(305), top = dpi(60) } })
          end
          awful.placement.no_offscreen(volume_controller_container)
        end
      end

    end
  )

end
