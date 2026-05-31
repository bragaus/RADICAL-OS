--------------------------------------------------------------------------------------------------------------
-- This is the statusbar, every widget, module and so on is combined to all the stuff you see on the screen --
--------------------------------------------------------------------------------------------------------------
local awful = require("awful")
local color = require("src.theme.colors")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local menubar = require("menubar")
local wibox = require("wibox")
local plano_gif = require("src.widgets.plano_gif")

return function(screen, programs)
  local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
  local dock_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.dock or 0.86)
  local dock_button_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.dock_button or 0.92)
  local dock_border_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.segment_border or 0.96)
  local button_size = math.min(user_vars.dock_icon_size, dpi(54))
  local icon_size = math.max(dpi(24), button_size - dpi(18))
  local launcher_size = math.max(button_size + dpi(42), dpi(96))
  local launcher_edge_margin = dpi(32)
  local launcher_default_icon = "/usr/share/icons/Papirus-Dark/128x128/apps/application-default-icon.svg"
  local launcher_slots = {
    { angle = 62, radius = launcher_size + dpi(18), size = dpi(104), icon_scale = 0.62, focused = true, anchor = "launcher" },
    { angle = 182, radius = dpi(76), size = dpi(34), icon_scale = 0.42, anchor = "focus" },
    { angle = 132, radius = dpi(86), size = dpi(38), icon_scale = 0.44, anchor = "focus" },
    { angle = 82, radius = dpi(90), size = dpi(44), icon_scale = 0.46, anchor = "focus" },
    { angle = 28, radius = dpi(84), size = dpi(38), icon_scale = 0.44, anchor = "focus" },
    { angle = -24, radius = dpi(74), size = dpi(34), icon_scale = 0.42, anchor = "focus" },
  }
  local dock_margin = dpi(10)
  local dock_spacing = dpi(4)
  local panel_bg = color.with_alpha("#08111f", dock_alpha)
  local panel_edge = color.with_alpha("#3b82f6", dock_border_alpha)
  local button_bg = color.with_alpha("#0d1728", dock_button_alpha)
  local button_hover_bg = "#16233a"
  local button_active_bg = color.with_alpha("#173969", math.min(1, dock_button_alpha + 0.04))
  local button_inactive_edge = color.with_alpha("#1e3556", dock_border_alpha)
  local dock_items = {}
  local launcher_apps = {}
  local launcher_apps_loading = false
  local launcher_menu_open = false
  local launcher_offset = 1
  local launcher_x = 0
  local launcher_y = 0
  local launcher_gif = plano_gif.new {
    fallback_bg = "#00000000",
    preload_size = launcher_size,
    anim_interval = 0.045,
    content_scale = 0.92,
    shape = gears.shape.circle,
  }

  for _, program in ipairs(programs or {}) do
    dock_items[#dock_items + 1] = program
  end

  local dock = awful.popup {
    widget = wibox.container.background,
    ontop = true,
    bg = "#00000000",
    visible = true,
    screen = screen,
    type = "dock",
  }

  local launcher_dock = awful.popup {
    widget = wibox.container.background,
    ontop = true,
    bg = "#00000000",
    visible = true,
    screen = screen,
    shape = gears.shape.circle,
    type = "dock",
  }

  local launcher_menu_popups = {}

  for index = 1, #launcher_slots do
    launcher_menu_popups[index] = awful.popup {
      widget = wibox.container.background,
      ontop = true,
      bg = "#00000000",
      visible = false,
      screen = screen,
      shape = gears.shape.circle,
      type = "dock",
    }
  end

  if screen._radical_dock_popup and screen._radical_dock_popup ~= dock then
    screen._radical_dock_popup.visible = false
  end

  if screen._radical_launcher_popup and screen._radical_launcher_popup ~= launcher_dock then
    screen._radical_launcher_popup.visible = false
  end

  if screen._radical_launcher_menu_popups then
    for _, popup in ipairs(screen._radical_launcher_menu_popups) do
      if popup then
        popup.visible = false
      end
    end
  end

  screen._radical_dock_popup = dock
  screen._radical_launcher_popup = launcher_dock
  screen._radical_launcher_menu_popups = launcher_menu_popups

  local items_layout = wibox.layout.fixed.vertical()
  items_layout.spacing = dock_spacing

  local launcher_button = wibox.widget {
    {
      {
        launcher_gif,
        margins = dpi(0),
        widget = wibox.container.margin,
      },
      forced_width = launcher_size,
      forced_height = launcher_size,
      bg = "#00000000",
      border_width = dpi(2),
      border_color = panel_edge,
      shape = gears.shape.circle,
      widget = wibox.container.background,
    },
    widget = wibox.container.background,
  }

  awful.tooltip {
    objects = { launcher_button },
    text = "Todos os aplicativos",
    mode = "outside",
    preferred_positions = { "right", "top" },
    preferred_alignments = { "middle" },
    margins = dpi(10),
  }

  local panel_widget = wibox.widget {
    {
      items_layout,
      left = dock_margin,
      right = dock_margin,
      top = dock_margin,
      bottom = dock_margin,
      widget = wibox.container.margin,
    },
    bg = panel_bg,
    border_width = dpi(1),
    border_color = panel_edge,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(14))
    end,
    widget = wibox.container.background,
  }

  dock:setup {
    panel_widget,
    widget = wibox.container.background,
  }

  launcher_dock:setup {
    {
      launcher_button,
      forced_width = launcher_size,
      forced_height = launcher_size,
      widget = wibox.container.constraint,
    },
    widget = wibox.container.background,
  }

  local function desktop_entry_command(app_id, exec_line)
    if app_id and app_id ~= "" then
      return "gtk-launch " .. string.format("%q", app_id)
    end

    local command = exec_line or ""
    command = command:gsub("%%[fFuUdDnNickvm]", "")
    command = command:gsub("%%[cCkK]", "")
    command = command:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

    if command == "" then
      return nil
    end

    return command
  end

  local function lookup_app_icon(icon_name)
    if not icon_name or icon_name == "" then
      return launcher_default_icon
    end

    return menubar.utils.lookup_icon(icon_name)
      or menubar.utils.lookup_icon(icon_name:lower())
      or launcher_default_icon
  end

  local function wrap_index(index, total)
    if total == 0 then
      return nil
    end

    return ((index - 1) % total) + 1
  end

  local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(value, maximum))
  end

  local function set_launcher_menu_visibility(visible)
    for _, popup in ipairs(launcher_menu_popups) do
      popup.visible = visible
    end
  end

  local function launcher_app_at(slot_index)
    local total = #launcher_apps

    if total == 0 then
      return nil
    end

    local app_index = wrap_index(launcher_offset + slot_index - 1, total)
    return launcher_apps[app_index], app_index
  end

  local function refresh_launcher_menu()
    local should_show = launcher_menu_open and launcher_dock.visible and #launcher_apps > 0

    if not should_show then
      set_launcher_menu_visibility(false)
      return
    end

    local launcher_center_x = launcher_x + (launcher_size / 2)
    local launcher_center_y = launcher_y + (launcher_size / 2)
    local area = screen.workarea
    local focus_slot = launcher_slots[1]
    local focus_angle = math.rad(focus_slot.angle)
    local focus_center_x = launcher_center_x + math.cos(focus_angle) * focus_slot.radius
    local focus_center_y = launcher_center_y - math.sin(focus_angle) * focus_slot.radius

    for slot_index, spec in ipairs(launcher_slots) do
      local app = launcher_app_at(slot_index)
      local popup = launcher_menu_popups[slot_index]

      if app and popup then
        local icon_size_for_slot = math.floor(spec.size * (spec.icon_scale or 0.46))
        local is_focused = spec.focused == true
        local angle = math.rad(spec.angle)
        local anchor_x = spec.anchor == "focus" and focus_center_x or launcher_center_x
        local anchor_y = spec.anchor == "focus" and focus_center_y or launcher_center_y
        local x = math.floor(anchor_x + math.cos(angle) * spec.radius - (spec.size / 2))
        local y = math.floor(anchor_y - math.sin(angle) * spec.radius - (spec.size / 2))

        x = clamp(x, area.x, area.x + area.width - spec.size)
        y = clamp(y, area.y, area.y + area.height - spec.size)

        local orbit_button = wibox.widget {
          {
            {
              resize = true,
              forced_width = icon_size_for_slot,
              forced_height = icon_size_for_slot,
              image = app.icon,
              widget = wibox.widget.imagebox,
            },
            halign = "center",
            valign = "center",
            widget = wibox.container.place,
          },
          forced_width = spec.size,
          forced_height = spec.size,
          bg = is_focused and button_active_bg or button_bg,
          border_width = dpi(is_focused and 2 or 1),
          border_color = panel_edge,
          shape = gears.shape.circle,
          widget = wibox.container.background,
        }

        Hover_signal(orbit_button, button_hover_bg, color["White"])

        orbit_button:buttons(gears.table.join(
          awful.button({}, 1, function()
            launcher_menu_open = false
            refresh_launcher_menu()
            awful.spawn.with_shell(app.command)
          end),
          awful.button({}, 4, function()
            launcher_offset = wrap_index(launcher_offset - 1, #launcher_apps)
            refresh_launcher_menu()
          end),
          awful.button({}, 5, function()
            launcher_offset = wrap_index(launcher_offset + 1, #launcher_apps)
            refresh_launcher_menu()
          end)
        ))

        awful.tooltip {
          objects = { orbit_button },
          text = app.name,
          mode = "outside",
          preferred_positions = { "top", "right" },
          preferred_alignments = { "middle" },
          margins = dpi(10),
        }

        popup:setup {
          orbit_button,
          widget = wibox.container.background,
        }

        popup:geometry {
          x = x,
          y = y,
          width = spec.size,
          height = spec.size,
        }

        popup.visible = true
      elseif popup then
        popup.visible = false
      end
    end
  end

  local function load_launcher_apps()
    if launcher_apps_loading or #launcher_apps > 0 then
      return
    end

    launcher_apps_loading = true

    awful.spawn.easy_async_with_shell([[python3 - <<'PY'
from pathlib import Path
import configparser

paths = [Path('/usr/share/applications'), Path.home() / '.local/share/applications']
entries = []
seen = set()

for root in paths:
    if not root.exists():
        continue
    for desktop_file in sorted(root.glob('*.desktop')):
        app_id = desktop_file.name
        if app_id in seen:
            continue
        seen.add(app_id)
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            parser.read(desktop_file, encoding='utf-8')
        except Exception:
            continue
        if 'Desktop Entry' not in parser:
            continue
        entry = parser['Desktop Entry']
        if entry.get('Type') != 'Application':
            continue
        if entry.get('NoDisplay', 'false').lower() == 'true':
            continue
        if entry.get('Hidden', 'false').lower() == 'true':
            continue
        name = entry.get('Name', '').strip()
        exec_line = entry.get('Exec', '').strip()
        icon_name = entry.get('Icon', '').strip()
        if not name or not exec_line:
            continue
        entries.append((name.lower(), name, app_id, exec_line, icon_name))

for _, name, app_id, exec_line, icon_name in sorted(entries):
    safe_name = name.replace('\t', ' ').replace('\n', ' ')
    safe_exec = exec_line.replace('\t', ' ').replace('\n', ' ')
    safe_icon = icon_name.replace('\t', ' ').replace('\n', ' ')
    print(f"{safe_name}\t{app_id}\t{safe_exec}\t{safe_icon}")
PY]], function(stdout)
      local entries = {}

      launcher_apps_loading = false

      for line in stdout:gmatch("[^\r\n]+") do
        local app_name, app_id, exec_line, icon_name = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
        if app_name and app_id and exec_line then
          local command = desktop_entry_command(app_id, exec_line)

          if command then
            entries[#entries + 1] = {
              name = app_name,
              command = command,
              icon = lookup_app_icon(icon_name),
            }
          end
        end
      end

      launcher_apps = entries

      if #launcher_apps > 0 then
        launcher_offset = wrap_index(launcher_offset, #launcher_apps)
      else
        launcher_offset = 1
      end

      refresh_launcher_menu()
    end)
  end

  launcher_button:buttons(gears.table.join(
    awful.button({}, 1, function()
      launcher_menu_open = not launcher_menu_open
      load_launcher_apps()
      refresh_launcher_menu()
    end),
    awful.button({}, 3, function()
      launcher_menu_open = false
      refresh_launcher_menu()
    end),
    awful.button({}, 4, function()
      launcher_menu_open = true
      load_launcher_apps()
      if #launcher_apps > 0 then
        launcher_offset = wrap_index(launcher_offset - 1, #launcher_apps)
      end
      refresh_launcher_menu()
    end),
    awful.button({}, 5, function()
      launcher_menu_open = true
      load_launcher_apps()
      if #launcher_apps > 0 then
        launcher_offset = wrap_index(launcher_offset + 1, #launcher_apps)
      end
      refresh_launcher_menu()
    end)
  ))

  local function normalize(value)
    if type(value) ~= "string" then
      return nil
    end

    value = value:lower():gsub("^%s+", ""):gsub("%s+$", "")

    if value == "" then
      return nil
    end

    return value
  end

  local function get_match_targets(item)
    local targets = {}
    local class = normalize(item[1])
    local command = normalize(item[2])

    if class then
      targets[#targets + 1] = class
    end

    if command then
      local binary = command:match("^[^%s]+")
      if binary and binary ~= class then
        targets[#targets + 1] = binary
      end
    end

    return targets
  end

  local function matching_clients(item)
    local targets = get_match_targets(item)
    local matches = {}

    for _, c in ipairs(client.get()) do
      local class = normalize(c.class)
      local name = normalize(c.name)

      for _, target in ipairs(targets) do
        if (class and class:find(target, 1, true)) or (name and name:find(target, 1, true)) then
          matches[#matches + 1] = c
          break
        end
      end
    end

    return matches
  end

  local function indicator_color(c)
    if c == client.focus then
      return color["BlueA200"]
    end
    if c.urgent then
      return color["RedA200"]
    end
    if c.maximized then
      return color["GreenA200"]
    end
    if c.minimized then
      return color["BlueGrey400"] or color["Grey600"]
    end
    if c.fullscreen then
      return color["PinkA200"]
    end

    return color["Grey600"]
  end

  local function build_indicator_strip(item)
    local matches = matching_clients(item)

    if #matches == 0 then
      return wibox.widget {
        forced_height = dpi(5),
        widget = wibox.container.background,
      }
    end

    local indicators = wibox.layout.fixed.horizontal()
    indicators.spacing = dpi(3)

    for index, c in ipairs(matches) do
      if index > 4 then
        indicators:add(wibox.widget {
          forced_width = dpi(10),
          forced_height = dpi(3),
          bg = indicator_color(c),
          shape = gears.shape.rounded_rect,
          widget = wibox.container.background,
        })
        break
      end

      indicators:add(wibox.widget {
        forced_width = dpi(4),
        forced_height = dpi(3),
        bg = indicator_color(c),
        shape = gears.shape.rounded_rect,
        widget = wibox.container.background,
      })
    end

    return wibox.widget {
      {
        indicators,
        halign = "center",
        widget = wibox.container.place,
      },
      top = dpi(2),
      widget = wibox.container.margin,
    }
  end

  local function create_dock_element(item)
    local class = item[1]
    local program = item[2]
    local name = item[3]
    local user_icon = item[4]
    local is_steam = item[5] or false

    if not class or not program then
      return nil
    end

    local matched_clients = matching_clients(item)
    local is_active = false

    for _, c in ipairs(matched_clients) do
      if c == client.focus then
        is_active = true
        break
      end
    end

    local background = wibox.widget {
      {
        {
          {
            resize = true,
            forced_width = icon_size,
            forced_height = icon_size,
            image = user_icon or Get_icon(user_vars.icon_theme, nil, program, class, is_steam),
            widget = wibox.widget.imagebox,
          },
          halign = "center",
          valign = "center",
          widget = wibox.container.place,
        },
        forced_width = button_size,
        forced_height = button_size,
        strategy = "exact",
        widget = wibox.container.constraint,
      },
      bg = is_active and button_active_bg or button_bg,
      border_width = dpi(1),
      border_color = is_active and panel_edge or button_inactive_edge,
      shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(10))
      end,
      widget = wibox.container.background,
    }

    Hover_signal(background, button_hover_bg, color["White"])

    local dock_element = wibox.widget {
      {
        background,
        widget = wibox.container.margin,
      },
      build_indicator_strip(item),
      layout = wibox.layout.fixed.vertical,
    }

    dock_element:connect_signal("button::press", function()
      if is_steam then
        awful.spawn("steam steam://rungameid/" .. program)
      else
        awful.spawn(program)
      end
    end)

    awful.tooltip {
      objects = { dock_element },
      text = name,
      mode = "outside",
      preferred_positions = { "left" },
      preferred_alignments = { "middle" },
      margins = dpi(10),
    }

    return dock_element
  end

  local function place_dock()
    local area = screen.workarea
    local geo = dock:geometry()

    dock:geometry {
      x = area.x + area.width - geo.width - dpi(4),
      y = area.y + math.floor((area.height - geo.height) / 2),
    }

    launcher_x = area.x + launcher_edge_margin
    launcher_y = area.y + area.height - launcher_size - launcher_edge_margin

    launcher_dock:geometry {
      x = launcher_x,
      y = launcher_y,
      width = launcher_size,
      height = launcher_size,
    }

    refresh_launcher_menu()
  end

  local function update_visibility()
    local selected_tag = screen.selected_tag

    if not selected_tag then
      dock.visible = true
      launcher_dock.visible = true
      refresh_launcher_menu()
      return
    end

    for _, c in ipairs(selected_tag:clients()) do
      if c.fullscreen then
        dock.visible = false
        launcher_dock.visible = false
        set_launcher_menu_visibility(false)
        return
      end
    end

    dock.visible = true
    launcher_dock.visible = true
    refresh_launcher_menu()
  end

  local function refresh_dock()
    items_layout:reset()

    for _, item in ipairs(dock_items) do
      local widget = create_dock_element(item)
      if widget then
        items_layout:add(widget)
      end
    end

    update_visibility()
    gears.timer.delayed_call(place_dock)
  end

  client.connect_signal("manage", refresh_dock)
  client.connect_signal("unmanage", refresh_dock)
  client.connect_signal("focus", refresh_dock)
  client.connect_signal("unfocus", refresh_dock)
  client.connect_signal("property::minimized", refresh_dock)
  client.connect_signal("property::urgent", refresh_dock)
  client.connect_signal("property::fullscreen", refresh_dock)
  client.connect_signal("property::maximized", refresh_dock)
  tag.connect_signal("property::selected", function(t)
    if t.screen == screen then
      refresh_dock()
    end
  end)

  load_launcher_apps()
  refresh_dock()
end
