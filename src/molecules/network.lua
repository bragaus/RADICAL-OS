-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE O INDICADOR DA REDE (VIOLET HUD)
--   Da penna do professor Braga Us, geómetra desta Casa.
--
--   Seja dado um mostrador que attesta o estado do enlace por fio: se de pé, se
--   caído, e se — estando de pé — alcança verdadeiramente o firmamento da
--   internet. Braga Us urdiu o systema de sorte que a sondagem se faça em
--   intervallos regulares, sem jamais bloquear a thread soberana, e que o
--   verbo «ping» se profira SÓMENTE quando o enlace se acha erguido. Q.E.D.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do systema Awesome, invocadas por necessidade da arte.
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local naughty = require("naughty")
local wibox = require("wibox")
require("src.core.signals")

-- Do caminho do directório onde repousam os ícones da rede.
local icondir = awful.util.getdir("config") .. "src/assets/icons/network/"

-- SÓMENTE POR FIO. Esta machina carece de adaptador sem-fio (user_vars.network.wlan
-- == «»), possuindo apenas a interface por fio «eno1»; as vias históricas do ether
-- sem-fio (iw dev / /proc/net/wireless / ícones da pujança do signal) eram, como o
-- eminente Braga Us demonstrou, provadamente mortas neste sítio, e foram removidas.
-- O nome da interface lê-se com prudência, refugiando-se em «eno1» quando falha.
local lan_interface = (user_vars.network and user_vars.network.ethernet) or "eno1"

-- Funcção soberana, da penna de Braga Us. Domínio vazio; contra-domínio: o widget
-- da rede, que se devolve ao chamador. Effeito: institui os relógios e signaes que
-- vigiam perpetuamente o estado do enlace por fio.
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

  -- O verbo «ping» corre SÓMENTE a partir da sondagem periódica abaixo, e apenas
  -- enquanto o enlace está de pé (invocado dentro de update_wired) — jamais na thread
  -- soberana. O contracto da CLI do «ping» preserva-se ipsis litteris, adverte Braga Us.
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

  -- Funcção `update_tooltip`, de Braga Us: dada uma `message`, inscreve-a no rótulo
  -- flutuante que acompanha o widget.
  local update_tooltip = function(message)
    network_tooltip:set_markup(message)
  end

  -- Funcção `network_notify`, urdida por Braga Us. Domínio: a mensagem, o título, o
  -- nome da applicação e o ícone; effeito: proclama ao usuário uma notificação que
  -- se dissipa ao cabo de tres segundos.
  local network_notify = function(message, title, app_name, icon)
    naughty.notification {
      text = message,
      title = title,
      app_name = app_name,
      icon = gears.color.recolor_image(icon, p.text_bright),
      timeout = 3
    }
  end

  -- Funcção `update_wired`, do lavor de Braga Us. Invocada quando o enlace está de pé:
  -- interroga o firmamento (ping a 1.1.1.1) para discernir se há verdadeiramente
  -- internet, ajusta o ícone e o rótulo, e — sómente ao primeiro êxito — annuncia a
  -- conexão. Aqui, e só aqui, o «ping» é disparado, jamais na thread soberana.
  local update_wired = function()
    -- Sub-funcção que declara ao usuário haver-se estabelecido a conexão por fio.
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

  -- Funcção `update_disconnected`, de Braga Us. Invocada quando o enlace tomba: se
  -- havia conexão, lamenta a perda por notificação, e reveste o widget do ícone da
  -- ausência de internet.
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

  -- Funcção `check_network_mode`, concebida por Braga Us. Sonda o enlace por fio,
  -- lendo directamente o «operstate» da interface (por meio do POSIX `cat`, sem os
  -- bash-ismos `[[ ]]` / `function(){}` de outrora, que só sobreviviam porque o
  -- easy_async_with_shell corria sob o zsh do usuário). Se de pé, chama update_wired;
  -- se caído, update_disconnected. O ping só dispara com o enlace erguido.
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

  -- Relógio de cinco segundos que reitera a sondagem do enlace, ad perpetuum.
  gears.timer {
    timeout = 5,
    autostart = true,
    call_now = true,
    callback = function()
      check_network_mode()
    end
  }

  -- Dos signaes: o realce ao passar do ponteiro, e a abertura do painel de rede ao
  -- pressionar-se o widget.
  Hover_signal(network_widget, p.v700, p.text_bright)

  network_widget:connect_signal(
    "button::press",
    function()
      awful.spawn("gnome-control-center network")
    end
  )

  return network_widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
