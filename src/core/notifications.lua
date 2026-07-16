-------------------------------
--   TRACTADO DOS AVISOS E NOTIFICAÇÕES DO SYSTEMA — pela mão de Braga Us
--   Estabelecem-se aqui os predicados padrão e a apparência dos avisos que o
--   systema dirige ao operador, segundo a doutrina do HUD violáceo.
-------------------------------
-- Das bibliothecas primeiras do gerenciador, da palette violácea, da medida em
-- pontos densos (dpi), e do naughty, arauto official de todas as notificações.
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local menubar = require('menubar')
local naughty = require("naughty")
local wibox = require("wibox")

local icondir = awful.util.getdir("config") .. "src/assets/icons/notifications/"
-- Do conjunto de ícones do HUD violáceo (o repositório icons/svg/), donde se
-- extrahem as figuras da notificação e do não-perturbar, conforme o §3.13.1.
local hud_svg = awful.util.getdir("config") .. "icons/svg/"

-- QUAESTIO EM ABERTO (por resolver): investigar como applicar os effeitos de
-- passagem do cursor sem corromper as acções do aviso. Problema ainda não demonstrado.
--
-- POSTULADO DOS PREDICADOS PADRÃO — fixados pelo Doutor Braga Us. Estabelece o
-- geómetra as qualidades primeiras de todo aviso: sua sobreposição, a magnitude
-- de sua figura, o tempo de sua permanência (tres segundos), o título, as
-- margens, a posição ao canto inferior direito, a fórma de seus cantos
-- arredondados, a espessura e a côr de sua bordadura, e o espaçamento entre
-- elles. São estes os axiomas de que derivam todos os avisos, salvo declaração
-- em contrário.
naughty.config.defaults.ontop = true
naughty.config.defaults.icon_size = dpi(80)
naughty.config.defaults.timeout = 3
naughty.config.defaults.title = "System Notification"
naughty.config.defaults.margin = dpi(10)
naughty.config.defaults.position = "bottom_right"
naughty.config.defaults.shape = function(cr, width, height)
  gears.shape.rounded_rect(cr, width, height, dpi(4))
end
naughty.config.defaults.border_width = dpi(1)
naughty.config.defaults.border_color = p.line_base
naughty.config.defaults.spacing = dpi(10)

-- LEMMA DO ÍCONE — Funcção urdida pelo Doutor Braga Us.
-- Seja dado um aviso n, seu contexto e suas indicações (hints). Quando, e sómente
-- quando, o contexto seja o de um ícone de applicação, busca-se no menubar a
-- figura correspondente ao nome da applicação (tentada outrossim em minúsculas).
-- DOMÍNIO: (n, contexto, hints). EFFEITO: attribue-se a n o ícone achado, se
-- algum houver; do contrário, nada se altera.
naughty.connect_signal(
  'request::icon',
  function(n, context, hints)
    if context ~= 'app_icon' then
      return
    end
    local path = menubar.utils.lookup_icon(hints.app_icon) or menubar.utils.lookup_icon(hints.app_icon:lower())
    if path then
      n.icon = path
    end
  end
)

-- THEÓREMA DA APRESENTAÇÃO — grande funcção urdida pelo Doutor Braga Us.
-- Seja dado um aviso n a exhibir-se. Demonstra-se aqui, por longa construcção, a
-- fórma visível do aviso: a tarja de accento (violácea, ou crítica quando
-- urgente), o cabeçalho com o nome da applicação e a hora, o botão de fecho
-- guarnecido de arco decrescente, a figura, o título, a mensagem e as acções.
-- DOMÍNIO: o aviso n. EFFEITO: compõe-se e mostra-se a caixa do aviso ao écran.
-- INVARIANTE: os identificadores buscam-se por get_children_by_id, robustos á
-- interposição do invólucro de accento; e o arco esvahece-se com o tempo, salvo
-- quando o cursor sobre elle repousa. Q.E.D.
naughty.connect_signal(
  "request::display",
  function(n)
    -- Da côr da tarja de accento (tres pontos á esquerda): violácea na regra
    -- geral, e da côr crítica quando o aviso fôr de urgência.
    local accent_color = p.v500
    if n.urgency == "critical" then
      accent_color = p.crit
      n.title = string.format("<span foreground='%s' font='JetBrainsMono Nerd Font, ExtraBold 16'>%s</span>",
        p.crit, string.upper(tostring(n.title or ""))) or ""
      n.message = string.format("<span foreground='%s'>%s</span>", p.text_primary, n.message) or ""
      n.app_name = string.format("<span foreground='%s'>%s</span>", p.text_muted, n.app_name) or ""
      n.bg = p.panel .. "f2"
    else
      n.title = string.format("<span foreground='%s' font='JetBrainsMono Nerd Font, ExtraBold 16'>%s</span>",
        p.text_heading, string.upper(tostring(n.title or ""))) or ""
      n.message = string.format("<span foreground='%s'>%s</span>", p.text_primary, n.message) or ""
      n.app_name = string.format("<span foreground='%s'>%s</span>", p.text_muted, n.app_name) or ""
      n.bg = p.panel .. "f2"
      n.timeout = n.timeout or 3
    end

    local use_image = false

    if n.app_name == "Spotify" then
      n.actions = { naughty.action {
        program = "Spotify",
        id = "skip-prev",
        icon = gears.color.recolor_image(icondir .. "skip-prev.svg", p.text_bright)
      }, naughty.action {
        program = "Spotify",
        id = "play-pause",
        icon = gears.color.recolor_image(icondir .. "play-pause.svg", p.text_bright)
      }, naughty.action {
        program = "Spotify",
        id = "skip-next",
        icon = gears.color.recolor_image(icondir .. "skip-next.svg", p.text_bright)
      } }
      use_image = true
    end

    local action_template_widget = {}

    if use_image then
      action_template_widget = {
        {
          {
            {
              {
                id = "icon_role",
                widget = wibox.widget.imagebox
              },
              id = "centered",
              valign = "center",
              halign = "center",
              widget = wibox.container.place
            },
            margins = dpi(5),
            widget = wibox.container.margin
          },
          forced_height = dpi(35),
          forced_width = dpi(35),
          fg = p.text_bright,
          bg = p.v700,
          shape = function(cr, width, height)
            gears.shape.rounded_rect(cr, width, height, dpi(6))
          end,
          widget = wibox.container.background,
          id = "bgrnd"
        },
        id = "mrgn",
        top = dpi(10),
        bottom = dpi(10),
        widget = wibox.container.margin
      }
    else
      action_template_widget = {
        {
          {
            {
              {
                id = "text_role",
                font = "JetBrainsMono Nerd Font, Regular 12",
                widget = wibox.widget.textbox
              },
              id = "centered",
              widget = wibox.container.place
            },
            margins = dpi(5),
            widget = wibox.container.margin
          },
          fg = p.text_bright,
          bg = p.v700,
          shape = function(cr, width, height)
            gears.shape.rounded_rect(cr, width, height, dpi(6))
          end,
          widget = wibox.container.background,
          id = "bgrnd"
        },
        id = "mrgn",
        top = dpi(10),
        bottom = dpi(10),
        widget = wibox.container.margin
      }
    end

    local actions_template = wibox.widget {
      notification = n,
      base_layout = wibox.widget {
        spacing = dpi(40),
        layout = wibox.layout.fixed.horizontal
      },
      widget_template = action_template_widget,
      style = {
        underline_normal = false,
        underline_selected = true,
        bg_normal = p.v700,
        bg_selected = p.v600
      },
      widget = naughty.list.actions
    }

    local w_template = wibox.widget {
      {
        -- A tarja de accento de tres pontos á esquerda (violácea, ou crítica
        -- quando urgente), primeiro elemento da composição.
        {
          forced_width = dpi(3),
          bg = accent_color,
          widget = wibox.container.background,
          id = "accent_strip"
        },
        {
          {
            {
              {
                {
                  {
                    {
                      {
                        {
                          {
                            image = gears.color.recolor_image(hud_svg .. "notification.svg", p.text_muted),
                            resize = false,
                            widget = wibox.widget.imagebox
                          },
                          right = dpi(5),
                          widget = wibox.container.margin
                        },
                        {
                          markup = n.app_name or 'System Notification',
                          align = "center",
                          valign = "center",
                          widget = wibox.widget.textbox
                        },
                        layout = wibox.layout.fixed.horizontal
                      },
                      fg = p.text_muted,
                      widget = wibox.container.background
                    },
                    margins = dpi(10),
                    widget = wibox.container.margin
                  },
                  nil,
                  {
                    {
                      {
                        text = os.date("%H:%M"),
                        widget = wibox.widget.textbox
                      },
                      id = "background",
                      fg = p.text_muted,
                      widget = wibox.container.background
                    },
                    {
                      {
                        {
                          {
                            {
                              font = user_vars.font.specify .. ", 10",
                              text = "✕",
                              align = "center",
                              valign = "center",
                              widget = wibox.widget.textbox
                            },
                            start_angle = 4.71239,
                            thickness = dpi(2),
                            min_value = 0,
                            max_value = 360,
                            value = 360,
                            widget = wibox.container.arcchart,
                            id = "arc_chart"
                          },
                          id = "close_button",
                          fg = p.text_muted,
                          bg = p.panel,
                          widget = wibox.container.background
                        },
                        strategy = "exact",
                        width = dpi(20),
                        height = dpi(20),
                        widget = wibox.container.constraint,
                        id = "const"
                      },
                      margins = dpi(10),
                      widget = wibox.container.margin,
                      id = "arc_margin"
                    },
                    layout = wibox.layout.fixed.horizontal,
                    id = "arc_app_layout_2"
                  },
                  id = "arc_app_layout",
                  layout = wibox.layout.align.horizontal
                },
                id = "arc_app_bg",
                border_color = p.line_base,
                border_width = dpi(1),
                widget = wibox.container.background
              },
              {
                {
                  {
                    {
                      {
                        image = n.icon,
                        resize = true,
                        widget = wibox.widget.imagebox,
                        clip_shape = function(cr, width, height)
                          gears.shape.rounded_rect(cr, width, height, 10)
                        end
                      },
                      width = naughty.config.defaults.icon_size,
                      height = naughty.config.defaults.icon_size,
                      strategy = "exact",
                      widget = wibox.container.constraint
                    },
                    halign = "center",
                    valign = "top",
                    widget = wibox.container.place
                  },
                  left = dpi(20),
                  bottom = dpi(15),
                  top = dpi(15),
                  right = dpi(10),
                  widget = wibox.container.margin
                },
                {
                  {
                    {
                      widget = naughty.widget.title,
                      align = "left"
                    },
                    {
                      widget = naughty.widget.message,
                      align = "left"
                    },
                    {
                      actions_template,
                      widget = wibox.container.place
                    },
                    layout = wibox.layout.fixed.vertical
                  },
                  left = dpi(10),
                  bottom = dpi(10),
                  top = dpi(10),
                  right = dpi(20),
                  widget = wibox.container.margin
                },
                layout = wibox.layout.fixed.horizontal
              },
              id = "widget_layout",
              layout = wibox.layout.fixed.vertical
            },
            id = "min_size",
            strategy = "min",
            width = dpi(100),
            widget = wibox.container.constraint
          },
          id = "max_size",
          strategy = "max",
          width = Theme.notification_max_width or dpi(500),
          widget = wibox.container.constraint
        },
        nil,
        layout = wibox.layout.align.horizontal
      },
      id = "background",
      bg = p.panel .. "f2",
      border_color = p.line_base,
      border_width = dpi(1),
      shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(4))
      end,
      widget = wibox.container.background
    }

    -- COROLLÁRIO DA BUSCA ROBUSTA DOS IDENTIFICADORES. Adverte o Doutor Braga Us:
    -- como o re-vestimento violáceo interpôs um invólucro de accento que desloca a
    -- cadeia pontuada dos identificadores, resolve-se cada um por get_children_by_id,
    -- methodo que prevalece independentemente do aninhamento.
    local close = w_template:get_children_by_id("close_button")[1]
    local arc = w_template:get_children_by_id("arc_chart")[1]

    local timeout = n.timeout
    local remove_time = timeout

    if timeout ~= 0 then
      arc.value = 360
      local arc_timer = gears.timer {
        timeout = 0.1,
        call_now = true,
        autostart = true,
        callback = function()
          arc.value = (remove_time - 0) / (timeout - 0) * 360
          remove_time = remove_time - 0.1
        end
      }
      -- COROLLÁRIO DA GUARDA (Braga Us): confia-se o relógio ao próprio aviso,
      -- para que o lemma da destruição o encontre e o detenha. Sem esta
      -- referência, o relógio de 10 Hz sobreviveria à morte do aviso — retendo
      -- consigo toda a árvore de widgets — e nada haveria por onde alcançá-lo.
      n._arc_timer = arc_timer

      w_template:connect_signal(
        "mouse::enter",
        function()
          -- Nota do geómetra: attribuir-lhe o valor zero de nada aproveita; por
          -- isso se detém o relógio e se dilata o tempo a numero avultado.
          arc_timer:stop()
          n.timeout = 99999
        end
      )

      w_template:connect_signal(
        "mouse::leave",
        function()
          arc_timer:start()
          n.timeout = remove_time
        end
      )
    end

    Hover_signal(close, p.panel, p.text_bright)

    close:connect_signal(
      "button::press",
      function()
        n:destroy()
      end
    )

    w_template:connect_signal(
      "button::press",
      function(c, d, e, key)
        if key == 3 then
          n:destroy()
        end
        -- QUAESTIO EM ABERTO: descobrir como alcançar o cliente associado ao
        -- aviso. Logo abaixo jaz, preservado intacto e ainda por demonstrar, o
        -- specimen de código lavrado para tal fim, que se não ousa tocar.
        --[[ if key == 1 then
          if n.clients then
            n.clients[1]:activate {
              switch_to_tag = true,
              raise         = true
            }
          end
        end ]]
      end
    )

    local box = naughty.layout.box {
      notification = n,
      timeout = 3,
      type = "notification",
      screen = awful.screen.focused(),
      shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(4))
      end,
      widget_template = w_template
    }

    box.buttons = {}
    n.buttons = {}
  end
)

-- LEMMA DA DESTRUIÇÃO — Funcção urdida pelo Doutor Braga Us.
-- Ao aniquilar-se um aviso, invoca-se esta funcção. DOMÍNIO: o aviso `n`;
-- CONTRA-DOMÍNIO: vazio (acção por efeito). DEMONSTRAÇÃO, ora suprida: cada aviso
-- de timeout finito trazia um relógio de 10 Hz (o arco decrescente); ao expirar
-- por si — e não sob o ponteiro do rato, único caso que o detinha — o relógio
-- ficava a bater PARA SEMPRE, retendo em seu encerro a árvore inteira do aviso.
-- N avisos legavam N relógios e N árvores. Detém-se aqui o relógio confiado ao
-- aviso (n._arc_timer), donde o aviso morto se torna, enfim, colectável. Q.E.D.
naughty.connect_signal(
  "destroyed",
  function(n)
    if n and n._arc_timer then
      n._arc_timer:stop()
      n._arc_timer = nil
    end
  end
)

-- SPECIMEN DE PROVA (aviso de ensaio). Guarda-se logo abaixo, preservado e
-- intacto, um aviso de demonstração outrora lavrado, cuja construcção se conserva
-- para futura verificação, sem que se lhe altere um só traço.
--[[naughty.notification {
  app_name = "System Notification",
  title    = "A notification 3",
  message  = "This is very informative and overflowing",
  icon     = "/home/crylia/.config/awesome/src/assets/userpfp/crylia.png",
  urgency  = "normal",
  timeout  = 1,
  actions  = {
    naughty.action {
      name = "Accept",
    },
    naughty.action {
      name = "Refuse",
    },
    naughty.action {
      name = "Ignore",
    },
  }
}--]]

-- COROLLÁRIO DA ACÇÃO INVOCADA — Funcção urdida pelo Doutor Braga Us.
-- Quando o operador aperta uma das acções do aviso, considera-se aqui o seu
-- programa e sua identidade. DOMÍNIO: (_, acção). EFFEITO: sendo o programa o
-- Spotify, despacha-se ao playerctl a ordem correspondente — recuar, alternar
-- entre tocar e pausar, ou avançar á peça seguinte.
naughty.connect_signal(
  "invoked",
  function(_, action)
    if action.program == "Spotify" then
      if action.id == "skip-prev" then
        awful.spawn("playerctl previous")
      end
      if action.id == "play-pause" then
        awful.spawn("playerctl play-pause")
      end
      if action.id == "skip-next" then
        awful.spawn("playerctl next")
      end
    end
  end
)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
