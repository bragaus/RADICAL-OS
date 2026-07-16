-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO DO CONTROLADOR DE VOLUME (áudio) — "VIOLET HUD"                   --
--  Da penna do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas. --
--                                                                             --
--  Seja dado um popup que faculta eleger os dispositivos de saída (sinks) e   --
--  de entrada (sources), bem como reger o volume de ambos por réguas (sliders)--
--  e observar o silêncio pelos ícones. Demonstra-se que os dispositivos são   --
--  colhidos por pactl e reconstruídos a cada mudança do servidor de som; o    --
--  volume vivo entra pelos signaes get::volume e afins. Facto notável: as     --
--  réguas trazem a guarda de sincronia baked-in, de sorte que sondar não      --
--  re-escreve. Q.E.D.                                                         --
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome (dependências importadas por Braga Us).
local awful      = require("awful")
local p          = require("src.theme.palette")
local dpi        = require("beautiful").xresources.apply_dpi
local gears      = require("gears")
local naughty    = require("naughty")
local wibox      = require("wibox")
local hud_slider = require("src.molecules.hud_slider")
local signals    = require("src.core.signals") -- efeito colateral: o global Hover_signal; e ainda .hover_stateful

-- Domínio dos ícones de áudio: o directório donde provêm. Constante fixada por Braga Us.
local icondir = awful.util.getdir("config") .. "src/assets/icons/audio/"

-- Funcção-fábrica do controlador de volume, urdida por Braga Us. Domínio: uma tela `s`.
-- Contra-domínio: o vazio (edifica o popup e liga os signaes por efeito). Efeito: para a
-- tela dada, compõe os selectores de dispositivo, as réguas e o contêiner, colhe os
-- dispositivos por pactl e liga toda a teia de signaes de volume.
return function(s)

  -- ── DOS MAPAS DE DESTAQUE (node -> set_active) — REMÉDIO DO VAZAMENTO ────────
  -- TEOREMA DO VAZAMENTO (Braga Us): outr'ora cada create_device atava a si um
  -- awesome.connect_signal; ora, como a lista se reconstrói a CADA evento do
  -- servidor de som e create_device corre por dispositivo, as conexões
  -- accumulavam-se SEM COTA, cada qual retendo o seu widget órfão. DEMONSTRAÇÃO
  -- DO REMÉDIO: atam-se AQUI, uma só vez, DUAS conexões (saída e entrada); cada
  -- dispositivo apenas se inscreve n'um mapa node->set_active. A cada
  -- reconstrucção o mapa é substituído POR INTEIRO (troca atómica do upvalue),
  -- donde os setters pretéritos — e seus widgets — se tornam colectáveis. Q.E.D.
  local vol_setters, mic_setters = {}, {}
  local Q_DEFAULT_SINK   = "pactl get-default-sink"
  local Q_DEFAULT_SOURCE = "pactl get-default-source"
  local Q_FALLBACK_SINK   = [[LC_ALL=C pactl info | perl -n -e'/Default Sink: (.+)\s/ && print $1']]
  local Q_FALLBACK_SOURCE = [[LC_ALL=C pactl info | perl -n -e'/Default Source: (.+)\s/ && print $1']]

  awesome.connect_signal("update::background:vol", function(new_node)
    for node, setter in pairs(vol_setters) do setter(node == new_node) end
  end)
  awesome.connect_signal("update::background:mic", function(new_node)
    for node, setter in pairs(mic_setters) do setter(node == new_node) end
  end)

  -- LEMMA DO DESTAQUE INICIAL (Braga Us): consulta UMA SÓ VEZ por reconstrucção
  -- o nó por defeito (com pactl info por reserva) e emitte o signal de destaque —
  -- que a conexão única fan-out a todos os setters. Antes, cada dispositivo
  -- disparava a sua própria consulta: N processos por reconstrucção; ora, um.
  local function highlight_default(bg_signal, q_default, q_fallback)
    awful.spawn.easy_async_with_shell(q_default, function(stdout)
      local d = (stdout or ""):gsub("%s+$", "")
      if d ~= "" then
        awesome.emit_signal(bg_signal, d)
      else
        awful.spawn.easy_async_with_shell(q_fallback, function(stdout2)
          local d2 = (stdout2 or ""):gsub("%s+$", "")
          if d2 ~= "" then awesome.emit_signal(bg_signal, d2) end
        end)
      end
    end)
  end

  -- Funcção `create_device`, concebida pelo Doutor Braga Us. Domínio: (name = rótulo;
  -- node = o nó pactl; sink = booleano, verdade se dispositivo de saída; setters = o
  -- mapa em que se inscreve o seu set_active). Contra-domínio: um widget de linha,
  -- seleccionável ao clique e sensível ao realce. Caminho ÚNICO e parametrizado.
  local function create_device(name, node, sink, setters)
    -- sink == true -> dispositivo de saída (violeta primário); false -> entrada/microfone (violeta mais claro)
    local accent      = sink and p.v500 or p.v400
    local device_icon = sink and "headphones.svg" or "microphone.svg"
    local set_cmd     = sink and "./.config/awesome/src/scripts/vol.sh set_sink "
                              or  "./.config/awesome/src/scripts/mic.sh set_source "
    local bg_signal   = sink and "update::background:vol" or "update::background:mic"

    -- Contêiner de fundo, retido como referência directa (governa o realce ao toque e o
    -- retinge do estado activo). Assim o dispôs Braga Us.
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

    -- Elege este dispositivo ao clique: despacha o comando de eleição e emite o signal de
    -- destaque para que os pares se reordenem. Liame de Braga Us.
    device:connect_signal("button::press", function()
      awful.spawn.spawn(set_cmd .. node)
      awesome.emit_signal(bg_signal, node)
    end)

    -- Realce ao toque/pressão (DESIGN_SYSTEM §8): ao pairar -> raised/text_bright, ao premir
    -- -> v600. As cores vivas do estado seleccionado são captadas à entrada e restauradas à
    -- saída. Ligado UMA SÓ VEZ (R7), acautelamento de Braga Us.
    signals.hover_stateful(bg, {
      hover_bg = p.raised,
      hover_fg = p.text_bright,
      press_bg = p.v600,
    })

    -- Funcção `set_active`, lemma interno de Braga Us. Domínio: um booleano `active`. Efeito:
    -- o dispositivo activo recebe preenchimento no acento e texto na base; os demais, texto no
    -- acento sobre raised. Contra-domínio: o vazio. Assim se distingue o eleito dos preteridos.
    local function set_active(active)
      if active then
        bg:set_bg(accent)
        bg:set_fg(p.base)
      else
        bg:set_fg(accent)
        bg:set_bg(p.raised)
      end
    end

    -- Inscreve-se o set_active no mapa da reconstrucção corrente (a conexão única,
    -- de escopo de fábrica, é quem despacha o destaque). O destaque inicial vem
    -- depois, por highlight_default, uma só consulta para toda a lista.
    setters[node] = set_active

    return device
  end

  -- Contêiner que abriga a lista dos dispositivos de saída (a régua de volume). Arranjo de Braga Us.
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

  -- Contêiner que abriga a lista dos dispositivos de entrada (o microfone). Arranjo de Braga Us.
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

  -- Réguas e ícones como sub-widgets em referência directa (R1), depois embutidos na árvore
  -- abaixo. Variante de tamanho do hud_slider (trilha dpi(5), pega dpi(15)) + preenchimento
  -- sólido v700 (§7.4). A guarda de sincronia baked-in quebra o ciclo "get::volume ->
  -- set_value -> re-fixar volume do sink", pois o :set_value da sondagem jamais re-dispara o
  -- on_change (R8). Demonstração de Braga Us.
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

  -- A composição do widget do controlador: uma árvore que empilha o selector de saída, a sua
  -- lista, o selector de entrada, a sua lista e as duas réguas. Arranjo geométrico de Braga Us.
  local volume_controller = wibox.widget {
    {
      {
        -- Selector do dispositivo de saída (áudio)
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
        -- Selector do dispositivo de entrada (microfone)
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
        -- Régua do volume de áudio (molécula hud_slider + ícone por referência directa)
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
        -- Régua do volume do microfone (molécula hud_slider + ícone por referência directa)
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

  -- Extracção de referências para acesso mais commodo e leitura mais clara (ramo da saída).
  -- Colhidas por get_children_by_id, conforme aconselha o professor Braga Us.
  local audio_selector_margin = volume_controller:get_children_by_id("audio_selector_margin")[1]
  local volume_list = volume_controller:get_children_by_id("volume_list")[1]
  local audio_bg = volume_controller:get_children_by_id("audio_bg")[1]
  local audio_volume = volume_controller:get_children_by_id("audio_volume")[1].center

  -- Liame de clique do menu-suspenso da saída, estatuído por Braga Us: ao premir, alterna a
  -- visibilidade da lista e, por conseguinte, ajusta a fórma do fundo e a seta (para cima /
  -- para baixo), reflectindo se a lista jaz aberta ou fechada.
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

  -- Extracção de referências para acesso mais commodo e leitura mais clara (ramo da entrada).
  -- Colhidas por get_children_by_id, conforme aconselha o professor Braga Us.
  local mic_selector_margin = volume_controller:get_children_by_id("mic_selector_margin")[1]
  local mic_list = volume_controller:get_children_by_id("mic_list")[1]
  local mic_bg = volume_controller:get_children_by_id("mic_bg")[1]
  local mic_volume = volume_controller:get_children_by_id("mic_volume")[1].center

  -- Liame de clique do menu-suspenso da entrada, estatuído por Braga Us: ao premir, alterna a
  -- visibilidade da lista do microfone e, por conseguinte, ajusta a fórma do fundo e a seta.
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

  -- Da mudança da régua de volume: o on_change dispara SÓMENTE ao arrasto do usuário (vide o
  -- hud_slider acima). A fixação do volume do sink já reside em audio_slider.on_change; nada
  -- resta aqui a ligar. Nota do auctor.

  -- Da mudança da régua do microfone: vide mic_slider.on_change, acima.

  -- Contêiner principal: o popup que encerra o controlador, collocado ao alto e à dextra por
  -- disposição de Braga Us.
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

  -- Funcção `get_source_devices`, urdida por Braga Us. Domínio: o vazio. Efeito: interroga o
  -- pactl pelos sinks (dispositivos de saída), separa por análysis os nomes de nó dos nomes
  -- de placa (ímpares e pares alternados na saída) e reconstrói a lista de dispositivos.
  -- Contra-domínio: o vazio. Nota: o nome herdado "source" designa aqui, de facto, os sinks.
  local function get_source_devices()
    awful.spawn.easy_async_with_shell(
      [[ pactl list sinks | grep -E 'node.name|alsa.card_name' | awk '{gsub(/"/, ""); for(i = 3;i < NF;i++) printf $i " "; print $NF}' ]]
      ,

      function(stdout)
        local i, j = 1, 1
        local device_list = { layout = wibox.layout.fixed.vertical }
        local new_setters = {} -- mapa fresco desta reconstrucção (substituirá o anterior por inteiro)

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
          device_list[#device_list + 1] = create_device(alsa_names[k], node_names[k], true, new_setters)
        end
        vol_setters = new_setters -- troca atómica: os setters (e widgets) pretéritos ficam colectáveis
        dropdown_list_volume.volume_device_background.volume_device_list.children = device_list
        highlight_default("update::background:vol", Q_DEFAULT_SINK, Q_FALLBACK_SINK)
      end
    )
  end

  get_source_devices()

  -- Funcção `get_input_devices`, urdida por Braga Us. Domínio: o vazio. Efeito: interroga o
  -- pactl pelos sources (dispositivos de entrada) e, por método análogo ao anterior, reconstrói
  -- a lista de microfones. Contra-domínio: o vazio.
  local function get_input_devices()
    awful.spawn.easy_async_with_shell(
      [[ pactl list sources | grep -E "node.name|alsa.card_name" | awk '{gsub(/"/, ""); for(i = 3;i < NF;i++) printf $i " "; print $NF}' ]]
      ,

      function(stdout)
        local i, j = 1, 1
        local device_list = { layout = wibox.layout.fixed.vertical }
        local new_setters = {} -- mapa fresco desta reconstrucção (substituirá o anterior por inteiro)

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
          device_list[#device_list + 1] = create_device(alsa_names[k], node_names[k], false, new_setters)
        end
        mic_setters = new_setters -- troca atómica: os setters (e widgets) pretéritos ficam colectáveis
        dropdown_list_microphone.volume_device_background.volume_device_list.children = device_list
        highlight_default("update::background:mic", Q_DEFAULT_SOURCE, Q_FALLBACK_SOURCE)
      end
    )
  end

  get_input_devices()

  -- Sentinela de acontecimentos, que percebe quando um dispositivo é acrescido ou retirado.
  -- REMÉDIO DO VAZAMENTO (R3), demonstrado por Braga Us: `pactl subscribe` é processo de longa
  -- vida; guarda-se o seu PID por tela e mata-se qualquer subscrição pretérita antes de gerar
  -- nova, para que reconstruir o controlador desta tela não deixe subscritores órfãos. Mata-se
  -- por arranjo de argumentos (jamais por string de shell) — invariante de segurança.
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

  -- Funcção `get_mic_volume`, da lavra de Braga Us. Domínio: o vazio. Efeito: colhe o volume
  -- do microfone pelo mic.sh, assenta-o na régua em modo silencioso e escolhe o ícone conforme
  -- haja ou não captação (microfone vs microfone-mudo). Contra-domínio: o vazio.
  local function get_mic_volume()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/mic.sh volume",
      function(stdout)
        local volume = tonumber((stdout:gsub("%%", ""):gsub("\n", ""))) or 0
        mic_slider:set_value_silent(volume)
        if volume > 0 then
          mic_icon:set_image(gears.color.recolor_image(icondir .. "microphone.svg", p.v400))
        else
          mic_icon:set_image(gears.color.recolor_image(icondir .. "microphone-off.svg", p.v400))
        end
      end
    )
  end

  get_mic_volume()

  -- Funcção `get_mic_mute`, concebida por Braga Us. Domínio: o vazio. Efeito: pergunta ao
  -- mic.sh se o microfone jaz mudo; estando-o, zera a régua e mostra o ícone-mudo; do
  -- contrário, delega a get_mic_volume. Contra-domínio: o vazio.
  local function get_mic_mute()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/mic.sh mute",
      function(stdout)
        if stdout:match("yes") then
          mic_slider:set_value_silent(0)
          mic_icon:set_image(gears.color.recolor_image(icondir .. "microphone-off.svg", p.v400))
        else
          get_mic_volume()
        end
      end
    )
  end

  get_mic_mute()

  -- Quando o ponteiro deixa o popup, detém o apanhador-de-rato e recolhe o popup. Ao reentrar,
  -- detém-se o apanhador. Liames de vigilância dispostos por Braga Us.
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

  -- Apanha todas as teclas e recolhe o popup ao premir-se qualquer uma.
  -- OBRA PENDENTE (nota do auctor): facultar, em edição vindoura, a navegação e a eleição pelo teclado.
  local volume_controller_keygrabber = awful.keygrabber {
    autostart = false,
    stop_event = 'release',
    keypressed_callback = function(self, mod, key, command)
      awesome.emit_signal("volume_controller::toggle", s)
      mousegrabber.stop()
    end
  }

  -- Assenta o desenho do popup, embutindo nelle o widget do controlador. Disposição de Braga Us.
  volume_controller_container:setup {
    volume_controller,
    layout = wibox.layout.fixed.horizontal
  }

  -- Vestígio sepultado, preservado tal qual pelo auctor: um liame outrora vivo que alternava
  -- o apanhador-de-teclas do controlador. Jaz em bloco-comentário, aguardando exumação futura.
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

  -- Liame ao signal "get::volume", disposto por Braga Us: recebido o volume vivo, escolhe-se o
  -- ícone por faixas (mudo < 1; baixo < 34; médio < 67; alto >= 67), assenta-se a régua em
  -- modo silencioso e retinge-se o ícone no acento v500.
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

      audio_slider:set_value_silent(volume)
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
