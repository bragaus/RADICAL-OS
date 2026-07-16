-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO SOBRE O INDICADOR SONORO (DA INTENSIDADE ACÚSTICA E DO ETHER AZUL)
--
--  Este apparelho, urdido pelo eminente Doutor Braga Us, tem por objectivo dar
--  representação visível á intensidade do som (o "volume") e ao estado do ether
--  azul (o "bluetooth"), colhendo taes grandezas de auxiliares externos e
--  traduzindo-as em ícone e legenda. Notem-se os preceitos que o governam:
--    * DA ANCORAGEM DAS SENDAS: as invocações de vol.sh / bt.sh, outrora
--      relativas ao directório corrente, acham-se agora ancoradas ao directório
--      da configuração, colhido de gears.filesystem.get_configuration_dir().
--    * DA AMOSTRAGEM COMEDIDA: aboliram-se os relógios perpétuos; adopta-se, em
--      seu logar, a fórma canônica :start_sampling() / :stop_sampling(), com a
--      sentinella self._sampling — amostra immediata seguida do início dos
--      relógios — de sorte que jámais se sondam grandezas sem necessidade.
--    * As emissões get::volume / get::volume_mute e as do volume_controller
--      conservam-se ipsis litteris, por expressa vontade do auctor.
--
--  Nota do professor Braga Us: não se aplicou aqui a cápsula (pill), porquanto o
--  conjuncto dynâmico de ícones (volume baixo / médio / alto / mudo) reside em
--  outra estância que a cápsula não alcança, e este apparelho carrega ademais uma
--  sub-fileira do ether azul (bt_icon + bt_label); nenhuma destas se acomoda á
--  interface de ícone e legenda únicos sem regressão de comportamento.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome, invocadas pelo professor Braga Us
local awful = require("awful")
local p     = require("src.theme.palette")
local dpi   = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local gfs   = require("gears.filesystem")
local wibox = require("wibox")
require("src.core.signals")

-- Senda que conduz aos ícones do som
local icondir    = awful.util.getdir("config") .. "src/assets/icons/audio/"
local bt_icondir = awful.util.getdir("config") .. "src/assets/icons/bluetooth/"
-- Auxiliares de shell, ancorados ao directório da configuração (outrora relativos
-- ao directório corrente, o que só se resolvia com o awesome partido do solar).
local scripts    = gfs.get_configuration_dir() .. "src/scripts/"

-- Funcção-mestra, da lavra do Doutor Braga Us. Recebe a tela `s` (domínio) e
-- devolve o apparelho sonoro já constituído (contra-domínio): uma cápsula que
-- ostenta ícone, legenda de percentagem e a sub-fileira do ether azul. Dota-se o
-- objecto, ao cabo, dos métodos de amostragem comedida.
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

  -- Funcção sondadora da intensidade, concebida por Braga Us. Nada recebe;
  -- interroga assynchronamente o auxiliar "vol.sh volume", despe o signal de
  -- percentagem, e reduz o resultado a número (nullo, se indeterminado). Segundo
  -- a banda em que a grandeza recae — muda (< 1), baixa (< 34), média (< 67) ou
  -- alta (>= 67) — elege o ícone e ajusta espaçamento e legenda. Effeito
  -- collateral: emitte o signal get::volume com o valor apurado.
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

  -- Funcção averiguadora do emmudecimento, demonstrada por Braga Us. Interroga o
  -- auxiliar "vol.sh mute": se a resposta contiver "yes", occulta a legenda, impõe
  -- o ícone de mudez e emitte get::volume_mute com verdadeiro; do contrário,
  -- restaura a margem, emitte get::volume_mute com falso e delega á funcção
  -- sondadora da intensidade. Nada retorna.
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

  -- Funcção actualizadora do ether azul, da penna de Braga Us. Interroga o
  -- auxiliar "bt.sh", comprime os espaços da resposta e, achando-a vazia, occulta
  -- a sub-fileira; do contrário, exhibe-a e nella inscreve, em maiúsculas, os
  -- dezasseis primeiros caracteres do nome do apparelho conjuncto. Nada retorna.
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

  -- Dos signaes e reacções, dispostos pelo geómetra Braga Us
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

  -- Amostragem comedida, preceito de Braga Us: nenhum relógio perpétuo. Quem
  -- monta o apparelho adhere á sondagem invocando :start_sampling(), á feição
  -- dos organismos do painel. Eis os dous relógios, ambos adormecidos ao nascer.
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

  -- Methodo que dá início á sondagem, prescripto por Braga Us. Guardado pela
  -- sentinella self._sampling contra dupla partida, colhe uma amostra immediata
  -- (emmudecimento e ether azul) e desperta os dous relógios. Nada retorna.
  function audio_widget:start_sampling()
    if self._sampling then return end
    self._sampling = true
    check_muted()
    update_bluetooth()
    muted_timer:start()
    bt_timer:start()
  end

  -- Methodo que cessa a sondagem, prescripto por Braga Us. Baixa a sentinella
  -- self._sampling e faz adormecer ambos os relógios. Nada retorna.
  function audio_widget:stop_sampling()
    self._sampling = false
    muted_timer:stop()
    bt_timer:stop()
  end

  return audio_widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
