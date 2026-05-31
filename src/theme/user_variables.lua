-------------------------------------------
-- Uservariables are stored in this file --
-------------------------------------------
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local home = os.getenv("HOME")

-- If you want different default programs, wallpaper path or modkey; edit this file.
user_vars = {

  -- Autotiling layouts
  layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.floating,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.corner.nw,
    awful.layout.suit.corner.ne,
    awful.layout.suit.corner.sw,
    awful.layout.suit.corner.se,
    awful.layout.suit.magnifier,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.spiral.dwindle,
  },

  -- Icon theme from /usr/share/icons
  icon_theme = "Papirus-Dark",

  -- Write the terminal command to start anything here
  autostart = {
    "sh " .. home .. "/.config/awesome/src/scripts/display_setup.sh",
    "picom --config " .. home .. "/.config/picom.conf"
  },

  -- Type 'ip a' and check your wlan and ethernet name.
  -- This machine has no WiFi adapter, only wired 'eno1'. Empty wlan = skip wireless checks.
  network = {
    wlan = "",
    ethernet = "eno1"
  },

  -- Set your font with this format:
  font = {
    regular = "JetBrainsMono Nerd Font, 14",
    bold = "JetBrainsMono Nerd Font, bold 14",
    extrabold = "JetBrainsMono Nerd Font, ExtraBold 14",
    specify = "JetBrainsMono Nerd Font"
  },

  -- This is your default Terminal
  terminal = "alacritty",

  -- This is the modkey 'mod4' = Super/Mod/WindowsKey, 'mod3' = alt...
  modkey = "Mod4",

  -- place your wallpaper at this path with this name, you could also try to change the path
  wallpaper = home .. "/Imagens/lain.jpg",

  -- Naming scheme for the powermenu, userhost = "user@hostname", fullname = "Firstname Surname", something else ...
  namestyle = "userhost",

  -- List every Keyboard layout you use here comma seperated. (run localectl list-keymaps to list all averiable keymaps)
  kblayout = { "br", "us" },

  -- Your filemanager that opens with super+e
  file_manager = "nautilus",

  -- Screenshot program to make a screenshot when print is hit
  screenshot_program = "flameshot gui",

  -- If you use the dock here is how you control its size
  dock_icon_size = dpi(100),

  -- Transparency and blur settings.
  transparency = {
    panels = {
      enabled = true,
      segment = 0.90,
      segment_edge = 0.96,
      segment_border = 0.96,
      dock = 0.86,
      dock_button = 0.92,
      tab = 0.88,
      overlay = 0.55,
      chart = 0.80,
    },
    clients = {
      enabled = true,
      default_opacity = 1,
      toggle_opacity = 0.86,
      class_defaults = {
        -- Alacritty = 0.90,
      },
    },
    blur = {
      enabled = true,
      strength = 7,
    },
  },

  -- Add your programs exactly like in this example.
  -- First entry has to be how you would start the program in the terminal (just try it if you dont know yahoo it)
  -- Second can be what ever the fuck you want it to be (will be the displayed name if you hover over it)
  -- For steam games please use this format (look in .local/share/applications for the .desktop file, that will contain the number you need)
  -- {"394360", "Name", true} true will tell the func that it's a steam game
  -- Use xprop | grep WM_CLASS and use the *SECOND* string
  -- { WM_CLASS, program, name, user_icon, isSteam }
  dock_programs = {
    { "Alacritty", "alacritty", "Alacritty" },
    { "firefox", "firefox", "Firefox" },
    { "discord", "discord", "Discord" },
    { "nautilus", "nautilus", "Nautilus" },
    { "rustdesk", "rustdesk", "RustDesk" } 
  }
}
