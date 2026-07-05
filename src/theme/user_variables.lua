-- ══════════════════════════════════════════════════════════════════════════
--   O LIVRO DAS VARIÁVEIS DO UTENTE — src/theme/user_variables.lua
-- ══════════════════════════════════════════════════════════════════════════
-- Neste livro se depositam as variáveis do utente. Tudo quanto é matéria de
-- gosto e de preferência (a modkey, o terminal, as fontes, o papel de parede,
-- o autostart, os programmas do dock, et cetera) aqui reside, e jamais no corpo
-- dos widgets. Compêndio ordenado com method pelo eminente Doutor BRAGA US.
-- ══════════════════════════════════════════════════════════════════════════
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local home = os.getenv("HOME")

-- Desejando-se outros programmas por defeito, outro papel de parede ou outra modkey, emende-se este ficheiro.
user_vars = {

  -- Os leiautes de auto-arranjo (autotiling): a ordem por que se dispõem as janellas.
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

  -- O thema de ícones, colhido de /usr/share/icons.
  icon_theme = "Papirus-Dark",

  -- Aqui se inscreve o commando de terminal que dá início a qualquer cousa.
  autostart = {
    "sh " .. home .. "/.config/awesome/src/scripts/display_setup.sh",
    "picom --config " .. home .. "/.config/picom.conf"
  },

  -- Digite-se 'ip a' e verifiquem-se os nomes da wlan e da ethernet.
  -- Esta máchina carece de adaptador WiFi: sómente a via cabeada 'eno1'. Wlan vazia = omittem-se as verificações sem fio.
  network = {
    wlan = "",
    ethernet = "eno1"
  },

  -- Estabeleça-se a fonte segundo este formato:
  font = {
    regular = "JetBrainsMono Nerd Font, 14",
    bold = "JetBrainsMono Nerd Font, bold 14",
    extrabold = "JetBrainsMono Nerd Font, ExtraBold 14",
    specify = "JetBrainsMono Nerd Font",
    display = "Xirod" -- fonte de marca/display (MonitorBar, wordmark) — vide DESIGN_SYSTEM §4
  },

  -- Eis o vosso terminal por defeito.
  terminal = "alacritty",

  -- Eis a modkey: 'mod4' = tecla Super/Windows; 'mod3' = alt; e assim por diante...
  modkey = "Mod4",

  -- Deponha-se o papel de parede neste caminho e com este nome; lícito é também alterar o caminho.
  wallpaper = "/usr/local/share/awesome/themes/default/background.png", -- o clássico papel de parede do AwesomeWM

  -- O esquema de nomes do powermenu: userhost = "user@hostname"; fullname = "Nome Sobrenome"; ou qualquer outro...
  namestyle = "userhost",

  -- Enumere-se aqui, separado por vírgulas, cada leiaute de teclado que se use. (rode-se localectl list-keymaps para listar os disponíveis)
  kblayout = { "br", "us" },

  -- O vosso gerenciador de ficheiros, que se abre com super+e.
  file_manager = "nautilus",

  -- O programma de captura de tela, accionado ao premir-se a tecla print.
  screenshot_program = "flameshot gui",

  -- Usando-se o dock, eis como se governa o seu tamanho.
  dock_icon_size = dpi(100),

  -- Ajustes de transparência e de desfoque (blur).
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
      strength = 4, -- canónico: alinhado ao picom.conf (outrora 7, por deriva). Fonte: performance.compositor.blur_strength
    },
  },

  -- ─────────────────────────────────────────────────────────────────────────
  -- PERFORMANCE / hardware tuning — fonte única para compositor + display.
  -- Phase 11 templa ~/.config/picom.conf e display_setup.sh a partir daqui.
  -- Realidade single-thread: saturar a GPU, manter o loop Lua quase ocioso.
  -- ─────────────────────────────────────────────────────────────────────────
  performance = {
    refresh_rate = 165,                     -- DP-0 nativo (xrandr-confirmado) → orçamento ~6.06ms/frame
    primary_output = "DP-0",
    primary_mode = "3440x1440",
    force_full_composition_pipeline = true, -- vsync no driver NVIDIA (tear-free). Se false, picom vsync TEM de ser true.
    powermizer_max = true,                  -- GPUPowerMizerMode=1: trava clocks no máx, mata ramp-stutter (desktop, sem bateria)
    compositor = {                          -- picom em NVIDIA + glx. Regras DURAS:
      backend = "glx",
      vsync = false,                        -- FFCP já faz vsync; vsync duplo = lag de move/resize. Flipar SÓ junto com FFCP.
      use_damage = false,                   -- HARD DO-NOT: true SEGFAULTA o picom em nvidia+glx
      glx_no_stencil = true,                -- ~15% de ganho
      blur_enabled = true,
      blur_strength = 4,                    -- iterações dual_kawase (valor canônico)
      unredir_if_possible = true,           -- fullscreen (jogo/vídeo) bypassa o compositor → GPU inteira
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
