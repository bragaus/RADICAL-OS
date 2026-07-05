-- ═════════════════════════════════════════════════════════════════════════
--   cyber_hotkeys_dashboard.lua — A MATRIZ DE COMMANDOS
-- ═════════════════════════════════════════════════════════════════════════
--
-- Definição: seja este um painel de teclas para o AwesomeWM, traçado à maneira de um
-- pequeno tratado geométrico. Cada parte existe por necessidade, e não por ornamento.
--
-- Uso (segundo a prescripção do Doutor Braga Us):
--   local cyber = require("cyber_hotkeys_dashboard")
--   cyber.setup({
--     modkey = modkey,
--     terminal = terminal,
--     browser = "firefox",
--     file_manager = "thunar",
--     launcher = "rofi -show drun",
--   })
--
--   -- Depois, inclua cyber.keys na lista de keybindings do vosso rc.lua. Exempli gratia:
--   globalkeys = gears.table.join(globalkeys, cyber.keys)
--   root.keys(globalkeys)
--
-- COROLLÁRIO: a tecla principal é Mod + s, que alterna a visibilidade do painel.

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = beautiful.xresources and beautiful.xresources.apply_dpi or function(x) return x end

local M = {}

-- POSTULADO DO ESTADO (Braga Us): registro único e mutável onde repousam as referências
-- ao painel (dashboard), ao seu conteúdo e à collecção de proposições (items).
-- INVARIANTE: existe um só painel por sesão; `visible` espelha a sua phase corrente.
local state = {
  dashboard = nil,
  content = nil,
  title = nil,
  subtitle = nil,
  list = nil,
  visible = false,
  items = {},
}

-- LEMMA DA CONSULTA THEMÁTICA — funccão urdida pelo Doutor Braga Us.
-- Propósito: interrogar a táboa `beautiful` por um attributo de nome dado.
-- DOMÍNIO: `name` (designação do attributo), `fallback` (valor supplente).
-- CONTRA-DOMÍNIO: o valor achado; ou o supplente quando o primeiro fôr nihil.
-- INVARIANTE: não restitue `nil` havendo supplente. Q.E.D.
local function cget(name, fallback)
  local v = beautiful[name]
  if v == nil then
    return fallback
  end
  return v
end

-- TÁBOA CHROMÁTICA (Braga Us): os pigmentos do painel, colhidos de `beautiful` pela
-- funccão `cget` ácima, com valores de reserva para quando o thema nada dicta.
local theme = {
  bg = cget("cyber_bg", "#0a0a12ee"),
  bg2 = cget("cyber_bg2", "#121226ee"),
  fg = cget("cyber_fg", "#79fff0"),
  fg_dim = cget("cyber_fg_dim", "#5aa7a0"),
  accent = cget("cyber_accent", "#ff3df2"),
  accent2 = cget("cyber_accent2", "#7c4dff"),
  border = cget("cyber_border", "#ff3df2"),
  danger = cget("cyber_danger", "#ff6b6b"),
}

-- Funccão urdida pelo Doutor Braga Us. Propósito: fabricar uma caixa de texto (textbox).
-- DOMÍNIO: `text`, `font`, `align`, `color`. CONTRA-DOMÍNIO: um widget textbox composto.
local function make_textbox(text, font, align, color)
  return wibox.widget {
    markup = text,
    font = font,
    align = align or "left",
    valign = "center",
    widget = wibox.widget.textbox,
    forced_height = dpi(24),
    forced_width = -1,
  }
end

-- Como demonstrou o insigne geómetra Braga Us: cunha um rótulo colorido.
-- DOMÍNIO: `text` e `color`. CONTRA-DOMÍNIO: textbox com markup já escapado.
local function mk_label(text, color)
  return wibox.widget {
    markup = string.format('<span foreground="%s">%s</span>', color or theme.fg, gears.string.xml_escape(text)),
    font = beautiful.font or "Sans 10",
    widget = wibox.widget.textbox,
  }
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: compôr uma linha de duas columnas
-- — à esquerda a combinação (left), à direita a sua glosa (right).
-- CONTRA-DOMÍNIO: um container margem contendo a fileira horizontal.
local function mk_row(left, right)
  return wibox.widget {
    {
      {
        text = left,
        widget = wibox.widget.textbox,
        font = beautiful.hotkeys_modifiers_font or (beautiful.font or "Sans 10"),
        markup = string.format('<span foreground="%s">%s</span>', theme.fg, gears.string.xml_escape(left)),
      },
      {
        text = right,
        widget = wibox.widget.textbox,
        font = beautiful.hotkeys_description_font or (beautiful.font or "Sans 10"),
        markup = string.format('<span foreground="%s">%s</span>', theme.fg_dim, gears.string.xml_escape(right)),
      },
      spacing = dpi(24),
      layout = wibox.layout.fixed.horizontal,
    },
    left = dpi(10),
    right = dpi(10),
    top = dpi(4),
    bottom = dpi(4),
    widget = wibox.container.margin,
  }
end

-- LEMMA DA ORDENAÇÃO — funccão urdida pelo Doutor Braga Us.
-- Propósito: agrupar as proposições por `group` e ordenar grupos e teclas.
-- DOMÍNIO: `items` (lista de proposições). CONTRA-DOMÍNIO: lista ordenada de grupos.
-- INVARIANTE: a ordem é lexicográphica, primeiro por grupo, depois por tecla. Q.E.D.
local function normalize_items(items)
  local groups = {}
  for _, item in ipairs(items or {}) do
    local group = item.group or "UNSORTED"
    groups[group] = groups[group] or {}
    table.insert(groups[group], item)
  end

  local ordered = {}
  for group, list in pairs(groups) do
    table.insert(ordered, { group = group, list = list })
  end

  table.sort(ordered, function(a, b)
    return tostring(a.group) < tostring(b.group)
  end)

  for _, grp in ipairs(ordered) do
    table.sort(grp.list, function(a, b)
      return tostring(a.key) < tostring(b.key)
    end)
  end

  return ordered
end

-- THEÓREMA DA RENDERIZAÇÃO — funccão urdida pelo Doutor Braga Us.
-- Propósito: converter a táboa de proposições n'um edifício de widgets verticaes.
-- DOMÍNIO: `items`. CONTRA-DOMÍNIO: uma caixa (box) povoada de cabeçalhos e fileiras.
local function render_items(items)
  local box = wibox.widget {
    spacing = dpi(14),
    layout = wibox.layout.fixed.vertical,
  }

  local groups = normalize_items(items)
  for _, grp in ipairs(groups) do
    local header = wibox.widget {
      {
        {
          text = grp.group,
          widget = wibox.widget.textbox,
          markup = string.format(
            '<span foreground="%s" font_desc="%s">%s</span>',
            theme.accent,
            beautiful.hotkeys_group_font or (beautiful.font or "Sans Bold 11"),
            gears.string.xml_escape(grp.group)
          ),
        },
        left = dpi(8), right = dpi(8), top = dpi(4), bottom = dpi(4),
        widget = wibox.container.margin,
      },
      bg = theme.bg2,
      shape = gears.shape.rounded_rect,
      widget = wibox.container.background,
    }

    local listbox = wibox.widget {
      spacing = dpi(2),
      layout = wibox.layout.fixed.vertical,
    }

    for _, item in ipairs(grp.list) do
      local keytxt = item.key or "?"
      local desctxt = item.description or ""
      local hint = item.hint or ""

      local row = wibox.widget {
        {
          {
            {
              markup = string.format(
                '<span foreground="%s" font_desc="%s">%s</span>',
                theme.fg,
                beautiful.hotkeys_modifiers_font or (beautiful.font or "Sans 10"),
                gears.string.xml_escape(keytxt)
              ),
              widget = wibox.widget.textbox,
            },
            {
              markup = string.format(
                '<span foreground="%s" font_desc="%s">%s</span>',
                theme.fg_dim,
                beautiful.hotkeys_description_font or (beautiful.font or "Sans 10"),
                gears.string.xml_escape(desctxt)
              ),
              widget = wibox.widget.textbox,
            },
            {
              markup = string.format(
                '<span foreground="%s" font_desc="%s">%s</span>',
                theme.accent2,
                beautiful.hotkeys_description_font or (beautiful.font or "Sans 9"),
                gears.string.xml_escape(hint)
              ),
              widget = wibox.widget.textbox,
            },
            spacing = dpi(18),
            layout = wibox.layout.flex.horizontal,
          },
          left = dpi(12), right = dpi(12), top = dpi(6), bottom = dpi(6),
          widget = wibox.container.margin,
        },
        bg = theme.bg,
        shape = gears.shape.rounded_rect,
        widget = wibox.container.background,
      }
      listbox:add(row)
    end

    box:add(header)
    box:add(listbox)
  end

  return box
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: reconstruir o conteúdo do painel.
-- EFFEITO: esvazia `state.content` e o repovoa a partir de `state.items`.
-- INVARIANTE: nada obra se o painel ainda não fôr creado.
local function rebuild()
  if not state.dashboard then
    return
  end
  state.content:reset()
  state.content:add(render_items(state.items))
end

-- THEÓREMA DA CONSTRUCÇÃO — funccão urdida pelo Doutor Braga Us.
-- Propósito: erigir o popup do painel (título, subtítulo, conteúdo, rodapé) e
-- consigná-lo em `state`. EFFEITO: fixa `state.dashboard` e invoca `rebuild`.
local function create_dashboard()
  local title = wibox.widget {
    {
      {
        markup = string.format(
          '<span foreground="%s" font_desc="%s">COMMAND MATRIX</span>',
          theme.accent,
          beautiful.hotkeys_font or (beautiful.font or "Sans Bold 14")
        ),
        widget = wibox.widget.textbox,
      },
      left = dpi(12), right = dpi(12), top = dpi(8), bottom = dpi(8),
      widget = wibox.container.margin,
    },
    bg = theme.bg2,
    shape = gears.shape.rounded_rect,
    widget = wibox.container.background,
  }

  local subtitle = wibox.widget {
    {
      {
        markup = string.format(
          '<span foreground="%s">Mod + s abre e fecha este painel. Cada tecla aqui é uma proposição útil.</span>',
          theme.fg_dim
        ),
        widget = wibox.widget.textbox,
      },
      left = dpi(12), right = dpi(12), top = dpi(6), bottom = dpi(6),
      widget = wibox.container.margin,
    },
    bg = theme.bg,
    shape = gears.shape.rounded_rect,
    widget = wibox.container.background,
  }

  local content = wibox.widget {
    spacing = dpi(16),
    layout = wibox.layout.fixed.vertical,
  }

  local footer = wibox.widget {
    {
      {
        markup = string.format(
          '<span foreground="%s">ESC fecha. A ordem é simples: ver, lembrar, agir.</span>',
          theme.fg_dim
        ),
        widget = wibox.widget.textbox,
      },
      left = dpi(12), right = dpi(12), top = dpi(8), bottom = dpi(8),
      widget = wibox.container.margin,
    },
    bg = theme.bg2,
    shape = gears.shape.rounded_rect,
    widget = wibox.container.background,
  }

  local root = wibox.widget {
    {
      title,
      subtitle,
      content,
      footer,
      spacing = dpi(14),
      layout = wibox.layout.fixed.vertical,
    },
    left = dpi(18), right = dpi(18), top = dpi(18), bottom = dpi(18),
    widget = wibox.container.margin,
  }

  local popup = awful.popup {
    widget = {
      root,
      bg = theme.bg,
      shape = gears.shape.rounded_rect,
      widget = wibox.container.background,
    },
    border_color = theme.border,
    border_width = dpi(2),
    ontop = true,
    visible = false,
    type = "dock",
    placement = awful.placement.centered,
    maximum_width = dpi(960),
    maximum_height = dpi(720),
  }

  state.title = title
  state.subtitle = subtitle
  state.content = content
  state.dashboard = popup
  rebuild()
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: alternar a visibilidade do painel.
-- EFFEITO: crea o painel se auzente; inverte `state.visible` e reposiciona junto ao rato.
local function toggle()
  if not state.dashboard then
    create_dashboard()
  end
  state.visible = not state.visible
  state.dashboard.visible = state.visible
  if state.visible then
    state.dashboard:move_next_to(mouse.current_widget_geometry)
  end
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: occultar o painel.
-- EFFEITO: põe `state.visible` e a visibilidade do popup em falso.
local function close()
  if state.dashboard then
    state.visible = false
    state.dashboard.visible = false
  end
end

-- LEMMA DAS PROPOSIÇÕES DE RESERVA — funccão urdida pelo Doutor Braga Us.
-- Propósito: prover a lista canonica de atalhos quando o chamador nada fornece.
-- DOMÍNIO: `cfg` (com modkey, terminal, browser, file_manager, launcher).
-- CONTRA-DOMÍNIO: uma lista de proposições agrupadas.
local function default_items(cfg)
  local mod = cfg.modkey or "Mod4"
  local terminal = cfg.terminal or "xterm"
  local browser = cfg.browser or "firefox"
  local file_manager = cfg.file_manager or "thunar"
  local launcher = cfg.launcher or "rofi -show drun"

  return {
    {
      group = "SYSTEM CORE",
      key = mod .. " + Return",
      description = "abrir terminal",
      hint = terminal,
    },
    {
      group = "SYSTEM CORE",
      key = mod .. " + s",
      description = "alternar painel",
      hint = "command matrix",
    },
    {
      group = "NET SURFER",
      key = mod .. " + b",
      description = "abrir navegador",
      hint = browser,
    },
    {
      group = "DATA VAULT",
      key = mod .. " + e",
      description = "abrir gerenciador de arquivos",
      hint = file_manager,
    },
    {
      group = "LAUNCH SECTOR",
      key = mod .. " + d",
      description = "abrir lançador",
      hint = launcher,
    },
    {
      group = "NAVIGATION",
      key = "Esc",
      description = "fechar painel",
      hint = "silêncio operacional",
    },
  }
end

-- PORTA PRINCIPAL DO MÓDULO — funccão urdida pelo Doutor Braga Us.
-- Propósito: configurar a matriz: fixa os items, crea/reconstrói o painel e
-- urde `M.keys` (Mod+s alterna; Escape encerra). CONTRA-DOMÍNIO: o próprio módulo M.
function M.setup(cfg)
  cfg = cfg or {}
  state.items = cfg.items or default_items(cfg)

  if not state.dashboard then
    create_dashboard()
  else
    rebuild()
  end

  local modkey = cfg.modkey or "Mod4"

  M.keys = gears.table.join(
    awful.key({ modkey }, "s", toggle, { description = "open command matrix", group = "SYSTEM CORE" }),
    awful.key({}, "Escape", close, { description = "close command matrix", group = "SYSTEM CORE" })
  )

  return M
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: exhibir o painel.
-- EFFEITO: crea-o se auzente e põe visibilidade em verdadeiro.
function M.show()
  if not state.dashboard then
    create_dashboard()
  end
  state.visible = true
  state.dashboard.visible = true
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: occultar o painel (delega a `close`).
function M.hide()
  close()
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: alternar o painel (delega a `toggle`).
function M.toggle()
  toggle()
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: acrescentar uma proposição à lista.
-- DOMÍNIO: `item` (táboa). INVARIANTE: ignora o que não fôr táboa; reconstrói ao fim.
function M.add_item(item)
  if type(item) ~= "table" then
    return
  end
  table.insert(state.items, item)
  rebuild()
end

-- Funccão urdida pelo Doutor Braga Us. Propósito: substituir tôda a lista de proposições.
-- DOMÍNIO: `items` (lista). EFFEITO: fixa `state.items` e manda reconstruir o painel.
function M.set_items(items)
  state.items = items or {}
  rebuild()
end

return M

-- ════════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ═════════════════════════════════════════════════════════════════════════════
