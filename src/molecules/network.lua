--------------------------------
-- This is the network widget --
--------------------------------

-- Awesome Libs
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")
require("src.core.signals")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/network/"

-- WIRED-ONLY. This machine has no WiFi adapter (user_vars.network.wlan == ""),
-- only wired 'eno1'; the historic wireless code paths (iw dev / /proc/net/wireless
-- / wifi-strength icons) were provably dead here and have been removed. The
-- interface name is read defensively with an eno1 fallback.
local lan_interface = (user_vars.network and user_vars.network.ethernet) or "eno1"

-- Returns the network widget
return function()
  local startup = true
  local reconnect_startup = true

  local network_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = 'icon',
              image = gears.color.recolor_image(icondir .. "no-internet" .. ".svg", p.data4),
              widget = wibox.widget.imagebox,
              resize = false
            },
            id = "icon_layout",
            widget = wibox.container.place
          },
          id = "icon_margin",
          top = dpi(2),
          widget = wibox.container.margin
        },
        spacing = dpi(10),
        {
          id = "label",
          visible = false,
          valign = "center",
          align = "center",
          widget = wibox.widget.textbox
        },
        id = "network_layout",
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

  local network_tooltip = awful.tooltip {
    text = "Loading",
    objects = { network_widget },
    mode = "inside",
    preferred_alignments = "middle",
    margins = dpi(10)
  }

  -- `ping` runs ONLY from the periodic check below, and only while the link is up
  -- (invoked inside update_wired) — never on the main thread. The ping CLI contract
  -- is preserved verbatim.
  local check_for_internet = [=[
        status_ping=0
        packets="$(ping -q -w2 -c2 1.1.1.1 | grep -o "100% packet loss")"
        if [ ! -z "${packets}" ];
        then
            status_ping=0
        else
            status_ping=1
        fi
        if [ $status_ping -eq 0 ];
        then
            echo "Connected but no internet"
        fi
    ]=]

  local update_tooltip = function(message)
    network_tooltip:set_markup(message)
  end

  local network_notify = function(message, title, app_name, icon)
    naughty.notification {
      text = message,
      title = title,
      app_name = app_name,
      icon = gears.color.recolor_image(icon, p.text_bright),
      timeout = 3
    }
  end

  local update_wired = function()
    local notify_connected = function()
      network_notify(
        "You are now connected to " .. lan_interface,
        "Connection successfull",
        "System Notification",
        icondir .. "ethernet.svg"
      )
    end

    awful.spawn.easy_async_with_shell(
      check_for_internet,
      function(stdout)
        local icon = "ethernet"

        if stdout:match("Connected but no internet") then
          icon = "no-internet"
          update_tooltip("No internet")
        else
          update_tooltip("You are connected to:\nEthernet Interface <b>" .. lan_interface .. "</b>")
          if startup or reconnect_startup then
            awesome.emit_signal("system::network_connected")
            notify_connected()
            startup = false
          end
          reconnect_startup = false
        end
        network_widget.container.network_layout.label.visible = false
        network_widget.container.network_layout.spacing = dpi(0)
        network_widget.container.network_layout.icon_margin.icon_layout.icon:set_image(icondir .. icon .. ".svg")
      end
    )
  end

  local update_disconnected = function()
    if not reconnect_startup then
      reconnect_startup = true
      network_notify(
        "Ethernet has been unplugged",
        "Connection lost",
        "System Notification",
        icondir .. "no-internet.svg"
      )
    end
    network_widget.container.network_layout.label.visible = false
    network_widget.container.network_layout.spacing = dpi(0)
    update_tooltip("Network unreachable")
    network_widget.container.network_layout.icon_margin.icon_layout.icon:set_image(gears.color.recolor_image(icondir .. "no-internet.svg", p.data4))
  end

  -- Wired-only link check. Reads the interface operstate directly (POSIX `cat`,
  -- no bash `[[ ]]` / `function(){}` — the historic bash-ism that only survived
  -- because easy_async_with_shell runs under the user's zsh). ping fires only when
  -- the link is up (inside update_wired).
  local check_network_mode = function()
    awful.spawn.easy_async_with_shell(
      "cat /sys/class/net/" .. lan_interface .. "/operstate 2>/dev/null",
      function(stdout)
        if stdout:match("up") then
          update_wired()
        else
          update_disconnected()
        end
      end
    )
  end

  gears.timer {
    timeout = 5,
    autostart = true,
    call_now = true,
    callback = function()
      check_network_mode()
    end
  }

  -- Signals
  Hover_signal(network_widget, p.v700, p.text_bright)

  network_widget:connect_signal(
    "button::press",
    function()
      awful.spawn("gnome-control-center network")
    end
  )

  return network_widget
end
