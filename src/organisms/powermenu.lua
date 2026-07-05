-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO DO MENU DE ENERGIA (powermenu) — "VIOLET HUD"                     --
--  Da penna do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas. --
--                                                                             --
--  Seja dado um painel que cobre toda a tela e ostenta, ao seu exacto centro, --
--  UMA fileira de cinco chips militares de acção: desligar, reiniciar,        --
--  suspender, bloquear e encerrar sessão (a ordem do kit .pm POWER). Demonstra-se--
--  que o painel se ergue ao signal "module::powermenu:show" e se recolhe ao   --
--  "module::powermenu:hide" — seja por botão dextro, seja pela tecla de Escape.--
--                                                                             --
--  NOTA DO AUCTOR (fidelidade ao kit menus.jsx): extirparam-se o retrato e o  --
--  nome do usuário (e, com elles, o script bloqueante pfp.sh) — o .pmwrap do  --
--  kit não os comporta; o scrim tão-só centra os chips (gap:14). Q.E.D.       --
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome (dependências importadas por Braga Us).
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local chip_button = require("src.molecules.chip_button")

-- Funcção-fábrica do módulo, urdida pelo Doutor Braga Us. Domínio: uma tela `s`. Contra-
-- domínio: o vazio (edifica os widgets e liga os signaes por efeito colateral). Efeito:
-- para a tela dada, compõe o painel de energia, o seu contêiner e os apanhadores de tecla,
-- e liga-os aos signaes de exibição e ocultação. Invariante: um painel por tela.
return function(s)

  -- As acções do menu de energia, cada qual concebida pelo Doutor Braga Us. Todas partilham
  -- a mesma fórma: domínio o vazio, contra-domínio o vazio, efeito o despacho do comando e,
  -- por conseguinte, a emissão do signal de ocultação do painel (salvo o logout, que encerra
  -- a própria sessão do Awesome). Segue-se o rol:

  -- `suspend_command`: suspende a máquina (systemctl suspend) e recolhe o painel.
  local suspend_command = function()
    awful.spawn("systemctl suspend")
    awesome.emit_signal("module::powermenu:hide")
  end

  -- `logout_command`: encerra a sessão presente, abandonando o Awesome. Q.E.D.
  local logout_command = function()
    awesome.quit()
  end

  -- `lock_command`: tranca a sessão (dm-tool lock) e recolhe o painel.
  local lock_command = function()
    awful.spawn("dm-tool lock")
    awesome.emit_signal("module::powermenu:hide")
  end

  -- `shutdown_command`: ordena o desligamento immediato (shutdown now) e recolhe o painel.
  local shutdown_command = function()
    awful.spawn("shutdown now")
    awesome.emit_signal("module::powermenu:hide")
  end

  -- `reboot_command`: ordena o reinício da máquina (reboot) e recolhe o painel.
  local reboot_command = function()
    awful.spawn("reboot")
    awesome.emit_signal("module::powermenu:hide")
  end

  -- Chips de energia de feitio militar (VIOLET HUD): cada qual gere por si o seu realce ao
  -- toque do ponteiro (do rebordo ao fulgor, com troca do gradiente de preenchimento) e por
  -- si assenta o _preserve_colors — dispensando, por facto notável, qualquer ligação externa
  -- ao Hover_signal. Assim os dispôs Braga Us.
  local shutdown_button = chip_button { icon = "shutdown", label = "Shutdown", on_click = shutdown_command }
  local reboot_button   = chip_button { icon = "reboot",   label = "Reboot",   on_click = reboot_command }
  local suspend_button  = chip_button { icon = "suspend",  label = "Suspend",  on_click = suspend_command }
  local logout_button   = chip_button { icon = "logout",   label = "Logout",   on_click = logout_command }
  local lock_button     = chip_button { icon = "lock",     label = "Lock",     on_click = lock_command }

  -- A composição do widget do menu de energia (kit .pmwrap -> place-center de .pm): uma só
  -- fileira horizontal dos cinco chips, na ordem POWER do kit (desligar, reiniciar, suspender,
  -- bloquear, encerrar sessão), com intervallo de 14px, assente ao exacto centro do véu.
  -- Arranjo geométrico enxuto de Braga Us — sem retrato nem nome, conforme menus.jsx.
  local powermenu = wibox.widget {
    {
      shutdown_button,
      reboot_button,
      suspend_button,
      lock_button,
      logout_button,
      spacing = dpi(14),   -- kit .pm gap:14
      layout  = wibox.layout.fixed.horizontal,
    },
    halign = "center",
    valign = "center",
    widget = wibox.container.place,
  }

  -- O contêiner do widget, que se estende por toda a superfície da tela (um véu de tipo
  -- "splash"), tingido com o scrim do abysmo. Domínio geométrico: a tela `s` inteira.
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

  -- Encerramento pelo botão dextro do rato (botão 3): emite o signal de ocultação. Ligação
  -- de botões estatuída por Braga Us.
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

  -- Encerramento pela tecla de Escape: um apanhador de teclas (keygrabber) que, ao perceber
  -- o Escape, emite o signal de ocultação. Concebido pelo insigne Braga Us.
  local powermenu_keygrabber = awful.keygrabber {
    autostart = false,
    stop_event = 'release',
    keypressed_callback = function(self, mod, key, command)
      if key == 'Escape' then
        awesome.emit_signal("module::powermenu:hide")
      end
    end
  }

  -- Os signaes que governam a exibição e a ocultação do painel. Liames dispostos por Braga Us:
  -- ao "show", ergue-se o painel (sómente na tela onde reside o ponteiro) e inicia-se o
  -- apanhador de teclas; ao "hide", detém-se o apanhador e recolhe-se o painel.
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

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
