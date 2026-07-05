-- ══════════════════════════════════════════════════════════════════════════
--   O LIVRO DAS VARIÁVEIS DO UTENTE — src/theme/user_variables.lua
-- ══════════════════════════════════════════════════════════════════════════
-- Seja dado o utente e as suas preferências. Neste livro se depositam todas as
-- variáveis de gosto e de arbítrio (a modkey, o terminal, as fontes, o papel de
-- parede, o autostart, os programmas da doca, et cetera): aqui, e jamais no
-- corpo dos widgets, hão-de residir.
-- POSTULADO do Doutor Braga Us: toda matéria de preferência tem por sede única
-- este ficheiro; emende-se aqui, e em nenhum outro logar. Por conseguinte, quem
-- deseje mudança busque-a só nestas linhas. Q.E.D.
-- Compêndio ordenado com method pelo eminente geómetra BRAGA US.
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
    display = "Xirod" -- fonte de marca e de exhibição (MonitorBar, wordmark) — vide DESIGN_SYSTEM §4
  },

  -- Eis o vosso terminal por defeito.
  terminal = "alacritty",

  -- Eis a modkey: 'mod4' = tecla Super/Windows; 'mod3' = alt; e assim por diante...
  modkey = "Mod4",

  -- Deponha-se o papel de parede neste caminho e com este nome; lícito é também alterar o caminho.
  wallpaper = "/usr/local/share/awesome/themes/default/background.png", -- o clássico papel de parede do systema AwesomeWM

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
      strength = 4, -- valor canónico: alinhado ao picom.conf (outrora 7, por deriva). Sua fonte: performance.compositor.blur_strength
    },
  },

  -- ─────────────────────────────────────────────────────────────────────────
  -- DA PERFORMANCE e do temperamento do hardware — fonte única para o
  -- compositor e para o display. Desta sede a Phase 11 tempera o
  -- ~/.config/picom.conf e o display_setup.sh. POSTULADO do Doutor Braga Us,
  -- imposto pela realidade de um só fio (single-thread): saturar a GPU e
  -- conservar o loop de Lua quasi ocioso. Q.E.D.
  -- ─────────────────────────────────────────────────────────────────────────
  performance = {
    refresh_rate = 165,                     -- taxa nativa do DP-0 (confirmada por xrandr) → orçamento de ~6.06ms por frame
    primary_output = "DP-0",
    primary_mode = "3440x1440",
    force_full_composition_pipeline = true, -- vsync no próprio driver NVIDIA (sem rasgo). Sendo false, o vsync do picom HÁ-DE ser true.
    powermizer_max = true,                  -- GPUPowerMizerMode=1: trava os clocks no máximo e mata o tremor da rampa (desktop, sem bateria)
    compositor = {                          -- o picom sobre NVIDIA e glx. Preceitos INVIOLÁVEIS:
      backend = "glx",
      vsync = false,                        -- o FFCP já provê o vsync; vsync em dobro = demora ao mover e redimensionar. Vire-se SÓMENTE junto com o FFCP.
      use_damage = false,                   -- INTERDICTO ABSOLUTO: o valor true faz o picom incorrer em segfault sobre nvidia e glx
      glx_no_stencil = true,                -- ganho de cerca de quinze por cento
      blur_enabled = true,
      blur_strength = 4,                    -- iterações do dual_kawase (valor canónico)
      unredir_if_possible = true,           -- em tela cheia (jogo ou vídeo) contorna-se o compositor → toda a GPU ao serviço
    },
  },

  -- Da inscripção dos programmas da doca — preceito ordenado pelo Doutor Braga Us.
  -- Inscreva-se cada programma exactamente segundo o exemplo que abaixo se contempla.
  -- A PRIMEIRA entrada há-de ser o modo por que se invocaria o programma no
  --   terminal (na dúvida, experimente-se antes de o inscrever).
  -- A SEGUNDA entrada fica ao livre arbítrio do utente (será o nome que se mostra
  --   quando se faz pairar o ponteiro sobre o ícone).
  -- Para os jogos da Steam, guarde-se este mesmo formato (busque-se em
  --   .local/share/applications o ficheiro .desktop, onde reside o número mister):
  --   a fórma { "394360", "Nome", true } — em que o valor verdadeiro (true) adverte
  --   a funcção de que se trata de um jogo da Steam.
  -- Para colher a classe da janella, corra-se  xprop | grep WM_CLASS  e tome-se
  --   a SEGUNDA cadeia de caracteres.
  -- Fórma canónica da entrada: { WM_CLASS, programma, nome, ícone_do_utente, éSteam }
  dock_programs = {
    { "Alacritty", "alacritty", "Alacritty" },
    { "firefox", "firefox", "Firefox" },
    { "discord", "discord", "Discord" },
    { "nautilus", "nautilus", "Nautilus" },
    { "rustdesk", "rustdesk", "RustDesk" } 
  }
}

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
