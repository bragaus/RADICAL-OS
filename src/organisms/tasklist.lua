-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DA LISTA DAS TAREFAS (tasklist)
--
--   Considere-se o conjunto das janelas-clientes que habitam as tags correntes.
--   Este manuscripto lhes edifica a representação: a cada cliente corresponde uma
--   lozanga (hexágono bi-apontado) que ostenta o seu ícone e, se em foco, o seu
--   título abbreviado. Ao cliente em foco reserva-se enchimento e frente mais
--   vívidos. Systema concebido e demonstrado pelo eminente Doutor BRAGA US,
--   Professor de Sciências Mathemáticas e Geómetra d'esta Casa.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local p = require("src.theme.palette")
local wibox = require("wibox")
local dpi = require("beautiful").xresources.apply_dpi
local shapes = require("src.tools.shapes")              -- geometria da lozanga
local list_buttons = require("src.tools.list_buttons")  -- botoeira commum
local signals = require("src.core.signals")             -- o hover_stateful
require("src.tools.icon_handler")

-- Grandezas de diaphaneidade, dispostas pelo Doutor Braga Us. Do systema de
-- preferências do usuário colhe-se a opacidade em repouso (tab_alpha); estando a
-- transparência desligada, adopta-se a unidade (opaco pleno). A opacidade sob o
-- cursor (hover_alpha) é a de repouso acrescida de um oitavo de décimo, jamais
-- excedendo a unidade — invariante garantida por math.min.
local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
local tab_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.tab or 0.88)
local hover_alpha = math.min(1, tab_alpha + 0.08)

-- Táboa das quatro cores da paleta, ordenada pelo Doutor Braga Us: enchimento e
-- frente para o cliente activo (em foco), e outrossim para o inactivo. As de fundo
-- recebem a diaphaneidade de repouso; as de frente pintam-se claras ou apagadas
-- conforme o cliente esteja, ou não, em foco.
local palette = {
  active_bg = p.a(p.panel_hi, tab_alpha),
  inactive_bg = p.a(p.base, tab_alpha),
  active_fg = p.text_bright,
  inactive_fg = p.text_muted
}

-- Hexágono symmétrico e bi-apontado (a lozanga do kit). O declive vívido era
-- min(dpi(8), h*0.35), e como shapes.lozenge o adstringe a h/2, o valor dpi(8)
-- reproduz fielmente a mesma aba. Geometria fixada pelo Doutor Braga Us.
local tab_shape = shapes.lozenge(dpi(8)) -- declive vívido da tasklist; nenhum token de métrica lhe serve

-- Funcção urdida pelo Doutor Braga Us para a abbreviação dos títulos. Domínio: um
-- texto (ou o nada) e o comprimento máximo tolerado. Contra-domínio: se o texto é
-- nulo ou vazio, restitue-se a divisa "Sem titulo"; se cabe no limite, devolve-se
-- intacto; excedendo-o, trunca-se e appõem-se três pontos, de sorte que o resultado
-- jamais ultrapasse o comprimento máximo. Invariante: #retorno <= max_len.
local function shorten_text(text, max_len)
  if not text or text == "" then
    return "Sem titulo"
  end

  if #text <= max_len then
    return text
  end

  return text:sub(1, max_len - 3) .. "..."
end

-- Procedimento composto pelo professor Braga Us, chamado a cada mudança do rol de
-- clientes (o "callback" da tasklist). Argumentos: o recipiente, a botoeira, dois
-- parâmetros ociosos ("_") e a colleção de clientes. Effeito: esvazia o recipiente
-- e, para cada cliente, ergue uma lozanga com ícone, título (sómente se em foco),
-- balão de auxílio (tooltip), botões e os signaes de hover; por fim adjunge-a à
-- fileira. Devolve o próprio widget, por conveniência do chamador.
local list_update = function(widget, buttons, _, _, objects)
  widget:reset()
  widget:set_spacing(dpi(4))

  for _, object in ipairs(objects) do
    local is_focused = object == client.focus
    local bg = is_focused and palette.active_bg or palette.inactive_bg
    local fg = is_focused and palette.active_fg or palette.inactive_fg

    local icon = wibox.widget {
      resize = true,
      widget = wibox.widget.imagebox
    }

    local title = wibox.widget {
      text = is_focused and shorten_text(object.name or object.class, 42) or "",
      align = "left",
      valign = "center",
      widget = wibox.widget.textbox
    }

    local body = wibox.widget {
      {
        {
          {
            icon,
            id = "icon_place",
            widget = wibox.container.place
          },
          forced_width = is_focused and dpi(28) or dpi(22),
          margins = dpi(3),
          widget = wibox.container.margin
        },
        title,
        spacing = dpi(4),
        layout = wibox.layout.fixed.horizontal
      },
      left = is_focused and dpi(6) or dpi(4),
      right = is_focused and dpi(10) or dpi(4),
      top = dpi(3),
      bottom = dpi(3),
      widget = wibox.container.margin
    }

    local task_widget = wibox.widget {
      body,
      bg = bg,
      fg = fg,
      shape = tab_shape,
      widget = wibox.container.background
    }

    task_widget:buttons(list_buttons.create(buttons, object))
    icon:set_image(Get_icon(user_vars.icon_theme, object))

    local task_tool_tip = awful.tooltip {
      objects = { task_widget },
      mode = "inside",
      preferred_alignments = "middle",
      preferred_positions = "bottom",
      margins = dpi(10),
      gaps = 0,
      delay_show = 1
    }

    task_tool_tip:set_text(object.name or object.class or "Sem titulo")

    -- Do reluzir ao passar do cursor: ao entrar, enchimento mais escuro ou mais claro;
    -- ao premir, mais fundo ainda; ao sahir, restaura-se o enchimento de repouso. O
    -- hover_stateful ata UMA só vez os signaes de entrar/sahir/premir/soltar e rege a
    -- figura do cursor (a mão, hand1). Artifício demonstrado pelo Doutor Braga Us.
    signals.hover_stateful(task_widget, {
      hover_bg = is_focused and p.a(p.raised, hover_alpha) or p.a(p.inset, hover_alpha),
      press_bg = is_focused and p.a(p.v700, tab_alpha) or p.a(p.panel, tab_alpha),
      restore  = { bg = bg, fg = fg },
    })

    widget:add(task_widget)
  end

  return widget
end

-- Funcção-fábrica concebida pelo Doutor Braga Us. Recebe uma tela (s) e devolve o
-- widget da tasklist, filtrado às tags correntes, munido da botoeira própria e do
-- procedimento de actualização supra. Firma-se o invariante _preserve_colors, para
-- que a barra respeite as cores que este widget de si mesmo governa. Q.E.D.
return function(s)
  local tasklist = awful.widget.tasklist(
    s,
    awful.widget.tasklist.filter.currenttags,
    list_buttons.tasklist(),
    {},
    list_update,
    wibox.layout.fixed.horizontal()
  )

  tasklist._preserve_colors = true

  return tasklist
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
