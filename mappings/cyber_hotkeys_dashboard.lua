-- cyber_hotkeys_dashboard.lua
--
-- Definição: um painel de teclas para AwesomeWM, traçado como um pequeno
-- tratado geométrico. Cada parte existe por necessidade, e não por ornamento.
--
-- Uso:
--   local cyber = require("cyber_hotkeys_dashboard")
--   cyber.setup({
--     modkey = modkey,
--     terminal = terminal,
--     browser = "firefox",
--     file_manager = "thunar",
--     launcher = "rofi -show drun",
--   })
--
--   -- Depois, inclua cyber.keys na lista de keybindings do seu rc.lua.
--   -- Exemplo:
--   globalkeys = gears.table.join(globalkeys, cyber.keys)
--   root.keys(globalkeys)
--
-- A tecla principal é Mod + s, que alterna o painel.

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local beautiful = require("beautiful")
local dpi = beautiful.xresources and beautiful.xresources.apply_dpi or function(x) return x end

local M = {}

local state = {
  dashboard = nil,
  content = nil,
  title = nil,
  subtitle = nil,
  list = nil,
  visible = false,
  items = {},
}

local function cget(name, fallback)
  local v = beautiful[name]
  if v == nil then
    return fallback
  end
  return v
end

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

local function mk_label(text, color)
  return wibox.widget {
    markup = string.format('<span foreground="%s">%s</span>', color or theme.fg, gears.string.xml_escape(text)),
    font = beautiful.font or "Sans 10",
    widget = wibox.widget.textbox,
  }
end

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

local function rebuild()
  if not state.dashboard then
    return
  end
  state.content:reset()
  state.content:add(render_items(state.items))
end

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

local function close()
  if state.dashboard then
    state.visible = false
    state.dashboard.visible = false
  end
end

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

function M.show()
  if not state.dashboard then
    create_dashboard()
  end
  state.visible = true
  state.dashboard.visible = true
end

function M.hide()
  close()
end

function M.toggle()
  toggle()
end

function M.add_item(item)
  if type(item) ~= "table" then
    return
  end
  table.insert(state.items, item)
  rebuild()
end

function M.set_items(items)
  state.items = items or {}
  rebuild()
end

return M

