--------------------------------
-- This is the network widget --
--------------------------------

-- Awesome Libs
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local chip_button = require("src.molecules.chip_button")

-- Icon directory path (profile-picture assets live under the legacy set).
local icondir = awful.util.getdir("config") .. "src/assets/icons/powermenu/"

return function(s)

  -- Profile picture imagebox
  local profile_picture = wibox.widget {
    image = icondir .. "defaultpfp.svg",
    resize = true,
    forced_height = dpi(200),
    clip_shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 30)
    end,
    widget = wibox.widget.imagebox
  }

  -- Username textbox
  local profile_name = wibox.widget {
    align = 'center',
    valign = 'center',
    text = " ",
    font = "JetBrains Mono Bold 30",
    widget = wibox.widget.textbox
  }

  -- Get the profile script from /var/lib/AccountsService/icons/${USER}
  -- and copy it to the assets folder
  -- TODO: If the user doesnt have AccountsService look into $HOME/.faces
  local update_profile_picture = function()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/pfp.sh 'userPfp'",
      function(stdout)
        local pfp = stdout and stdout:gsub("\n", "") or ""
        if pfp ~= "" then
          profile_picture:set_image(pfp)
        else
          profile_picture:set_image(icondir .. "defaultpfp.svg")
        end
      end
    )
  end
  update_profile_picture()

  -- Get the full username(if set) and the username + hostname
  local update_user_name = function()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/pfp.sh 'userName' '" .. user_vars.namestyle .. "'",
      function(stdout)
        if stdout:gsub("\n", "") == "Rick Astley" then
          profile_picture:set_image(awful.util.getdir("config") .. "src/assets/userpfp/" .. "rickastley.jpg")
        end
        profile_name:set_text(stdout)
      end
    )
  end
  update_user_name()

  -- Create the power menu actions
  local suspend_command = function()
    awful.spawn("systemctl suspend")
    awesome.emit_signal("module::powermenu:hide")
  end

  local logout_command = function()
    awesome.quit()
  end

  local lock_command = function()
    awful.spawn("dm-tool lock")
    awesome.emit_signal("module::powermenu:hide")
  end

  local shutdown_command = function()
    awful.spawn("shutdown now")
    awesome.emit_signal("module::powermenu:hide")
  end

  local reboot_command = function()
    awful.spawn("reboot")
    awesome.emit_signal("module::powermenu:hide")
  end

  -- Military-tech power chips (VIOLET HUD): each self-manages its hover (rim -> glow,
  -- fill gradient swap) and self-sets _preserve_colors — no external Hover_signal wiring.
  local shutdown_button = chip_button { icon = "shutdown", label = "Shutdown", on_click = shutdown_command }
  local reboot_button   = chip_button { icon = "reboot",   label = "Reboot",   on_click = reboot_command }
  local suspend_button  = chip_button { icon = "suspend",  label = "Suspend",  on_click = suspend_command }
  local logout_button   = chip_button { icon = "logout",   label = "Logout",   on_click = logout_command }
  local lock_button     = chip_button { icon = "lock",     label = "Lock",     on_click = lock_command }

  -- The powermenu widget
  local powermenu = wibox.widget {
    layout = wibox.layout.align.vertical,
    expand = "none",
    nil,
    {
      {
        nil,
        {
          {
            nil,
            {
              nil,
              {
                profile_picture,
                margins = dpi(0),
                widget = wibox.container.margin
              },
              nil,
              expand = "none",
              layout = wibox.layout.align.horizontal
            },
            nil,
            layout = wibox.layout.align.vertical,
            expand = "none"
          },
          spacing = dpi(50),
          {
            profile_name,
            margins = dpi(0),
            widget = wibox.container.margin
          },
          layout = wibox.layout.fixed.vertical
        },
        nil,
        expand = "none",
        layout = wibox.layout.align.horizontal
      },
      {
        nil,
        {
          {
            shutdown_button,
            reboot_button,
            logout_button,
            lock_button,
            suspend_button,
            spacing = dpi(30),
            layout = wibox.layout.fixed.horizontal
          },
          margins = dpi(0),
          widget = wibox.container.margin
        },
        nil,
        expand = "none",
        layout = wibox.layout.align.horizontal
      },
      layout = wibox.layout.align.vertical
    },
    nil
  }

  -- Container for the widget, covers the entire screen
  local powermenu_container = wibox {
    widget = powermenu,
    screen = s,
    type = "splash",
    visible = false,
    ontop = true,
    bg = p.a(p.abyss, p.alpha.scrim),
    height = s.geometry.height,
    width = s.geometry.width,
    x = s.geometry.x,
    y = s.geometry.y
  }

  -- Close on rightclick
  powermenu_container:buttons(
    gears.table.join(
      awful.button(
        {},
        3,
        function()
          awesome.emit_signal("module::powermenu:hide")
        end
      )
    )
  )

  -- Close on Escape
  local powermenu_keygrabber = awful.keygrabber {
    autostart = false,
    stop_event = 'release',
    keypressed_callback = function(self, mod, key, command)
      if key == 'Escape' then
        awesome.emit_signal("module::powermenu:hide")
      end
    end
  }

  -- Signals
  awesome.connect_signal(
    "module::powermenu:show",
    function()
      if s == mouse.screen then
        powermenu_container.visible = true
        powermenu_keygrabber:start()
      end
    end
  )

  awesome.connect_signal(
    "module::powermenu:hide",
    function()
      powermenu_keygrabber:stop()
      powermenu_container.visible = false
    end
  )
end
