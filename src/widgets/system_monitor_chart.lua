
-- tema/cores default
local beautiful = require("beautiful")

-- converte valores para pixels com suporte a DPI
local dpi = beautiful.xresources.apply_dpi

-- funcoes utilitarias (arquivos, superficie, timers)
local gears = require("gears")

-- acesso ao sistema de arquivos.
local gfs = require("gears.filesystem")

-- construcao de widget
local wibox = require("wibox")

-- paleta VIOLET HUD (tokens monocromaticos roxos)
local p = require("src.theme.palette")

-- converte cor hexadecimal (6 ou 8 digitos) para componentes RGBA (0.1)
local function hex_to_rgba(hex, alpha_override)
  hex = (hex or "#ffffff"):gsub("#", "")

  if #hex == 6 then
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    return r, g, b, alpha_override or 1
  end

  if #hex == 8 then
    local r = tonumber(hex:sub(1, 2), 16) / 255
    local g = tonumber(hex:sub(3, 4), 16) / 255
    local b = tonumber(hex:sub(5, 6), 16) / 255
    local a = tonumber(hex:sub(7, 8), 16) / 255
    return r, g, b, alpha_override or a
  end

  return 1, 1, 1, alpha_override or 1
end

-- clamp restringe o valor minimo ou maximo
local function clamp(value, minimum, maximum)
  if value < minimum then
    return minimum
  end

  if value > maximum then
    return maximum
  end

  return value
end

-- remove espaços extras e normaliza.
local function trim(value)
  local normalized = tostring(value or "")
  normalized = normalized:gsub("%s+", " ")
  normalized = normalized:gsub("^%s+", "")
  normalized = normalized:gsub("%s+$", "")
  return normalized
end

-- encurta string com "..."
local function shorten(value, max_len)
  value = trim(value)
  if #value <= max_len then
    return value
  end

  return value:sub(1, max_len - 3) .. "..."
end

-- Leitura de arquivos
local function read_first_line(path)

  -- abrir o arquivo em modo de leitura
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  -- leitura de uma linha inteira, sem incluir o \n
  local line = file:read("*l")
  file:close()
  return line
end

-- igual a funcao de cima so que agora ele vai ler o arquivo inteiro
local function read_all(path)

  -- abre o arquivo em modo leitura 
  local file = io.open(path, "r")
  if not file then
    return nil
  end

  -- vai ler o arquivo inteiro de um vez, incluindo quebras de linhas espacos e etc
  local content = file:read("*a")
  file:close()
  return content
end

-- rodar comandos do terminal
local function run_command(command)
  -- Bound every synchronous shell call: this runs inside the main-loop timer
  -- (call_now = true), so a hung helper (bluetoothctl with no controller,
  -- nvidia-smi, sensors) would freeze the whole WM -> black screen, dead D-Bus.
  -- `timeout` caps wall time; `</dev/null` stops interactive REPLs (bluetoothctl)
  -- from blocking forever waiting on stdin.
  local process = io.popen("timeout -k 1 2 " .. command .. " </dev/null") -- abre um processo que executa comandos no shell
  if not process then -- verifica se a variavel esta vazia
    return nil
  end

  local output = process:read("*a") -- lê toda (*a) a saída do processo como string
  process:close()
  return output
end

local function detect_default_iface()
  local iface = "eno1"
  return iface
end

-- add temperature of cpu and gpu
local function detect_battery_path()
  local path = "/sys/class/power_supply/BAT0" --trim(run_command([[sh -c "ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1"]]))
  --if path == "" then
   -- return nil
  --end

  return path
end

-- adiciona transparencia a cor
local function with_alpha(hex, alpha)
  return gears.color(string.format("%s%02x", hex, math.floor(alpha * 255 + 0.5)))
end

-- mesma logica do with_alpha mas retorna uma strign hex em vez de gears
local function hex_with_alpha_string(hex, alpha)
  return string.format("%s%02x", hex, math.floor(alpha * 255 + 0.5))
end

-- verifica se um arquivo existe no caminho informado
local function file_exists(path)
  local file = io.open(path, "rb") -- abre o arquivo em modo binario de leitura
  if not file then
    return false
  end

  file:close()
  return true
end

local function first_existing_path(paths)
  for _, path in ipairs(paths or {}) do
    if file_exists(path) then
      return path
    end
  end

  return nil
end

local function collect_existing_paths(paths)
  local collected = {}

  for _, path in ipairs(paths or {}) do
    if file_exists(path) then
      table.insert(collected, path)
    end
  end

  return collected
end

local function load_surface_safe(path)
  if not path then
    return nil
  end

  local ok, surface = pcall(gears.surface.load_uncached, path)
  if ok then
    return surface
  end

  return nil
end

local function draw_surface_cover(cr, surface, width, height, alpha)
  if not surface then
    return
  end

  local image_width = surface:get_width()
  local image_height = surface:get_height()

  if image_width <= 0 or image_height <= 0 then
    return
  end

  local scale = math.max(width / image_width, height / image_height)
  local offset_x = (width - image_width * scale) / 2
  local offset_y = (height - image_height * scale) / 2

  cr:save()
  cr:translate(offset_x, offset_y)
  cr:scale(scale, scale)
  cr:set_source_surface(surface, 0, 0)

  if alpha and alpha < 1 then
    cr:paint_with_alpha(alpha)
  else
    cr:paint()
  end

  cr:restore()
end

local function draw_surface_contain(cr, surface, width, height, alpha, padding)
  if not surface then
    return
  end

  local image_width = surface:get_width()
  local image_height = surface:get_height()

  if image_width <= 0 or image_height <= 0 then
    return
  end

  local inset = padding or 0
  local available_width = math.max(1, width - inset * 2)
  local available_height = math.max(1, height - inset * 2)
  local scale = math.min(available_width / image_width, available_height / image_height)
  local draw_width = image_width * scale
  local draw_height = image_height * scale
  local offset_x = (width - draw_width) / 2
  local offset_y = (height - draw_height) / 2

  cr:save()
  cr:translate(offset_x, offset_y)
  cr:scale(scale, scale)
  cr:set_source_surface(surface, 0, 0)

  if alpha and alpha < 1 then
    cr:paint_with_alpha(alpha)
  else
    cr:paint()
  end

  cr:restore()
end

return function(args)
  args = args or {}

  local width = args.width or dpi(980)
  local height = args.height or dpi(278)
  local interval = args.interval or 1
  local samples = args.samples or 42
  local radius = args.radius or dpi(18)

  local palette = args.palette or {
    accent = "#8b5cf6",
    cpu = "#a855f7",
    mem = "#c084fc",
    gpu = "#7c3aed",
    net = "#d946ef",
    grid = "#3a1f63",
    text = "#cbb6ff",
    overlay = "#0c0617",
    glow = "#b794ff",
  }

  palette.accent = palette.accent or "#8b5cf6"
  palette.cpu = palette.cpu or palette.accent
  palette.mem = palette.mem or "#c084fc"
  palette.gpu = palette.gpu or "#7c3aed"
  palette.net = palette.net or "#d946ef"
  palette.grid = palette.grid or "#3a1f63"
  palette.text = palette.text or "#cbb6ff"
  palette.overlay = palette.overlay or "#0c0617"
  palette.glow = palette.glow or "#b794ff"

  local script_dir = gfs.get_configuration_dir() .. "src/scripts/"
  local config_dir = gfs.get_configuration_dir()
  local bt_script = script_dir .. "bt.sh"
  local vol_script = script_dir .. "vol.sh"
  local glow_path = first_existing_path({ config_dir .. "brilho.jpg" })
  local main_image_path = first_existing_path({ config_dir .. "lain.jpg" })
  local archive_images = collect_existing_paths({
    config_dir .. "1.jpg",
    config_dir .. "2.jpg",
    config_dir .. "3.jpg",
    config_dir .. "4.jpg",
  })
  local glow_surface = load_surface_safe(glow_path)

  local history = {
    cpu = {},
    mem = {},
    gpu = {},
    net = {},
    wifi = {},
    audio = {},
  }

  for i = 1, samples do
    history.cpu[i] = 0
    history.mem[i] = 0
    history.gpu[i] = 0
    history.net[i] = 0
    history.wifi[i] = 0
    history.audio[i] = 0
  end

  local state = {
    cpu = 0,
    cpu_temp = nil,
    mem = 0,
    gpu = 0,
    gpu_temp = nil,
    net = 0,
    net_rate = 0,
    wifi = nil,
    audio = 0,
    muted = false,
    bt_name = "OFFLINE",
    keyboard = "US",
  }

  local prev_total = nil
  local prev_idle = nil
  local iface = detect_default_iface()
  local prev_rx = nil
  local prev_tx = nil
  local dynamic_net_peak = 128 * 1024
  local gpu_mode = nil
  local battery_path = detect_battery_path()
  local tick = 0
  local redraw_targets = {}

  local function push(target, value)
    table.remove(target, 1)
    table.insert(target, clamp(value, 0, 100))
  end

  local function sample_cpu()
    local line = read_first_line("/proc/stat")
    if not line then
      return 0
    end

    local user, nice, system, idle, iowait, irq, softirq, steal =
      line:match("^cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)")

    user = tonumber(user) or 0
    nice = tonumber(nice) or 0
    system = tonumber(system) or 0
    idle = tonumber(idle) or 0
    iowait = tonumber(iowait) or 0
    irq = tonumber(irq) or 0
    softirq = tonumber(softirq) or 0
    steal = tonumber(steal) or 0

    local idle_all = idle + iowait
    local non_idle = user + nice + system + irq + softirq + steal
    local total = idle_all + non_idle

    if not prev_total then
      prev_total = total
      prev_idle = idle_all
      return 0
    end

    local total_delta = total - prev_total
    local idle_delta = idle_all - prev_idle
    prev_total = total
    prev_idle = idle_all

    if total_delta <= 0 then
      return 0
    end

    return ((total_delta - idle_delta) / total_delta) * 100
  end

  local function sample_mem()
    local meminfo = read_all("/proc/meminfo")
    if not meminfo then
      return 0
    end

    local total = tonumber(meminfo:match("MemTotal:%s+(%d+)"))
    local available = tonumber(meminfo:match("MemAvailable:%s+(%d+)"))

    if not total or not available or total == 0 then
      return 0
    end

    return ((total - available) / total) * 100
  end

  local function detect_gpu_mode_once()
    if gpu_mode ~= nil then
      return gpu_mode
    end

    if read_first_line("/sys/class/drm/card0/device/gpu_busy_percent") then
      gpu_mode = "sysfs"
      return gpu_mode
    end

    local has_nvidia = trim(run_command([[sh -c "command -v nvidia-smi >/dev/null 2>&1 && echo yes || echo no"]]))
    gpu_mode = has_nvidia == "yes" and "nvidia" or "none"
    return gpu_mode
  end

  local function sample_gpu()
    local mode = detect_gpu_mode_once()

    if mode == "sysfs" then
      return tonumber(read_first_line("/sys/class/drm/card0/device/gpu_busy_percent")) or 0
    end

    if mode == "nvidia" then
      local raw_value = trim(run_command([[sh -c "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1"]]))
      return tonumber(raw_value) or 0
    end

    return 0
  end

  local function sample_net()
    if not iface or iface == "" then
      iface = detect_default_iface()
      if not iface or iface == "" then
        return 0
      end
    end

    local rx = tonumber(read_first_line("/sys/class/net/" .. iface .. "/statistics/rx_bytes")) or 0
    local tx = tonumber(read_first_line("/sys/class/net/" .. iface .. "/statistics/tx_bytes")) or 0

    if not prev_rx or not prev_tx then
      prev_rx = rx
      prev_tx = tx
      return 0, 0
    end

    local rate = (math.max(0, rx - prev_rx) + math.max(0, tx - prev_tx)) / interval
    prev_rx = rx
    prev_tx = tx

    dynamic_net_peak = math.max(rate, dynamic_net_peak * 0.92, 128 * 1024)
    return (rate / dynamic_net_peak) * 100, rate
  end

  local function sample_wifi()
    local raw_value = trim(run_command([[sh -c "awk 'NR==3 {printf \"%3.0f\", ($3/70)*100}' /proc/net/wireless 2>/dev/null"]]))
    local value = tonumber(raw_value)
    if not value then
      return nil
    end

    return clamp(value, 0, 100)
  end

  local function sample_battery()
    if not battery_path then
      battery_path = detect_battery_path()
      if not battery_path then
        return nil
      end
    end

    return tonumber(read_first_line(battery_path .. "/capacity"))
  end

  local function sample_cpu_temp()
    local raw_value = trim(run_command([[sh -c "sensors 2>/dev/null | awk '/Package id 0:|Tctl:|Tdie:/ { print; exit }'"]]))
    local value = tonumber((raw_value or ""):match("([%+%-]?%d+%.?%d*)"))

    if value then
      return value
    end

    raw_value = trim(run_command([[sh -c 'for f in /sys/class/thermal/thermal_zone*/temp; do [ -r "$f" ] && cat "$f" && break; done']]))
    value = tonumber(raw_value)

    if value and value > 1000 then
      value = value / 1000
    end

    return value
  end

  local function sample_gpu_temp()
    local raw_value = trim(run_command([[sh -c "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1"]]))
    local value = tonumber(raw_value)

    if value then
      return value
    end

    raw_value = trim(run_command([[sh -c 'for f in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do [ -r "$f" ] && cat "$f" && break; done']]))
    value = tonumber(raw_value)

    if value and value > 1000 then
      value = value / 1000
    end

    return value
  end

  local function sample_audio()
    local volume = trim(run_command(vol_script .. " volume 2>/dev/null"))
    local mute = trim(run_command(vol_script .. " mute 2>/dev/null"))
    local volume_number = tonumber((volume:gsub("%%", ""))) or 0
    return volume_number, mute:match("yes") ~= nil
  end

  local function sample_bt_name()
    local output = (run_command(bt_script .. " 2>/dev/null") or ""):gsub("\n", " ")
    output = trim(output)
    if output == "" then
      return "OFFLINE"
    end

    return shorten(output, 20):upper()
  end

  local function sample_keyboard()
    local layout = trim(run_command([[sh -c "setxkbmap -query 2>/dev/null | awk '/layout/ {print $2}'"]]))
    layout = layout:match("([^,]+)") or layout
    if layout == "" then
      return "US"
    end

    return layout:upper()
  end

  local function clamp_dimension(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
  end

  local function constrain(widget, forced_width, forced_height)
    if not forced_width and not forced_height then
      return widget
    end

    local constraint = wibox.widget {
      widget,
      forced_width = forced_width,
      forced_height = forced_height,
      strategy = "exact",
      widget = wibox.container.constraint,
    }

    return constraint
  end

  local function register_redraw_target(widget)
    table.insert(redraw_targets, widget)
    return widget
  end

  local function format_percent(value)
    return string.format("%02d%%", math.floor(clamp(tonumber(value) or 0, 0, 100) + 0.5))
  end

  local function format_temperature(value)
    if not value then
      return "N/D"
    end

    return string.format("%d°C", math.floor(value + 0.5))
  end

  local function create_info_row(label_text, initial_value, accent)
    local label = wibox.widget {
      text = label_text,
      font = "JetBrainsMono Nerd Font, bold 10",
      widget = wibox.widget.textbox,
    }

    local value = wibox.widget {
      text = initial_value or "--",
      font = "JetBrainsMono Nerd Font, ExtraBold 11",
      align = "right",
      widget = wibox.widget.textbox,
    }

    local row = wibox.widget {
      {
        {
          {
            label,
            fg = accent,
            widget = wibox.container.background,
          },
          nil,
          value,
          expand = "inside",
          layout = wibox.layout.align.horizontal,
        },
        left = dpi(8),
        right = dpi(8),
        top = dpi(3),
        bottom = dpi(3),
        widget = wibox.container.margin,
      },
      bg = with_alpha(accent, 0.09),
      border_width = dpi(1),
      border_color = with_alpha(accent, 0.32),
      shape = function(cr, w, h)
        gears.shape.rounded_rect(cr, w, h, dpi(6))
      end,
      widget = wibox.container.background,
    }

    return row, value
  end

  local function create_section_frame(title_text, body, accent, options)
    options = options or {}

    local section_title = wibox.widget {
      text = title_text,
      font = "JetBrainsMono Nerd Font, ExtraBold 11",
      widget = wibox.widget.textbox,
    }

    local section_line = wibox.widget {
      forced_height = dpi(2),
      bg = gears.color {
        type = "linear",
        from = { 0, 0 },
        to = { width, 0 },
        stops = {
          { 0, accent },
          { 0.55, hex_with_alpha_string(accent, 0.22) },
          { 1, "#00000000" },
        },
      },
      shape = gears.shape.rounded_bar,
      widget = wibox.container.background,
    }

    return wibox.widget {
      {
        {
          {
            section_title,
            fg = accent,
            widget = wibox.container.background,
          },
          section_line,
          body,
          spacing = dpi(8),
          layout = wibox.layout.fixed.vertical,
        },
        margins = options.margins or dpi(10),
        widget = wibox.container.margin,
      },
      bg = with_alpha(options.bg or palette.overlay, options.bg_alpha or 0.76),
      border_width = dpi(1),
      border_color = with_alpha(accent, 0.82),
      shape = function(cr, w, h)
        gears.shape.rounded_rect(cr, w, h, options.radius or dpi(10))
      end,
      widget = wibox.container.background,
    }
  end

  local function create_monitor_canvas(image_path, options)
    options = options or {}

    local image_surface = load_surface_safe(image_path)
    local accent = options.accent or palette.accent
    local tint = options.tint or palette.glow
    local glow_alpha = options.glow_alpha or 0.14
    local tint_alpha = options.tint_alpha or 0.12
    local band_alpha = options.band_alpha
    local corner = options.radius or dpi(8)
    local image_mode = options.image_mode or "cover"
    local image_padding = options.image_padding or dpi(8)
    local widget = wibox.widget.base.make_widget()

    if band_alpha == nil then
      band_alpha = image_mode == "contain" and 0.03 or 0.10
    end

    function widget:fit(_, available_width, available_height)
      return available_width, available_height
    end

    function widget:draw(_, cr, w, h)
      local accent_r, accent_g, accent_b = hex_to_rgba(accent)
      local tint_r, tint_g, tint_b = hex_to_rgba(tint)
      local corner_len = dpi(16)

      cr:save()
      gears.shape.rounded_rect(cr, w, h, corner)
      cr:clip()

      cr:set_source_rgba(0.02, 0.02, 0.05, 0.98)
      cr:paint()

      if image_surface then
        if image_mode == "contain" then
          draw_surface_contain(cr, image_surface, w, h, 0.95, image_padding)
        else
          draw_surface_cover(cr, image_surface, w, h, 0.95)
        end
      end

      cr:rectangle(0, 0, w, h)
      cr:set_source_rgba(tint_r, tint_g, tint_b, tint_alpha)
      cr:fill()

      cr:rectangle(0, h * 0.7, w, h * 0.3)
      cr:set_source_rgba(accent_r, accent_g, accent_b, band_alpha)
      cr:fill()

      if glow_surface then
        draw_surface_cover(cr, glow_surface, w, h, glow_alpha)
      end

      for line = 2, h, 4 do
        cr:set_source_rgba(1, 1, 1, 0.025)
        cr:rectangle(0, line, w, 1)
        cr:fill()
      end

      cr:restore()

      gears.shape.rounded_rect(cr, w, h, corner)
      cr:set_source_rgba(accent_r, accent_g, accent_b, 0.88)
      cr:set_line_width(dpi(1.2))
      cr:stroke()

      cr:set_source_rgba(accent_r, accent_g, accent_b, 0.92)
      cr:set_line_width(dpi(1.4))
      cr:move_to(0, corner_len)
      cr:line_to(0, 0)
      cr:line_to(corner_len, 0)
      cr:move_to(w - corner_len, 0)
      cr:line_to(w, 0)
      cr:line_to(w, corner_len)
      cr:move_to(0, h - corner_len)
      cr:line_to(0, h)
      cr:line_to(corner_len, h)
      cr:move_to(w - corner_len, h)
      cr:line_to(w, h)
      cr:line_to(w, h - corner_len)
      cr:stroke()
    end

    return widget
  end

  local function create_monitor_section(title_text, image_path, options)
    options = options or {}

    local image_widget = options.image_widget or create_monitor_canvas(image_path, {
      accent = options.accent,
      tint = options.tint,
      glow_alpha = options.glow_alpha,
      tint_alpha = options.tint_alpha,
      band_alpha = options.band_alpha,
      radius = dpi(8),
      image_mode = options.image_mode,
      image_padding = options.image_padding,
    })

    local content = {
      spacing = options.content_spacing or dpi(8),
      layout = wibox.layout.fixed.vertical,
    }

    if options.top_widget then
      table.insert(content, options.top_widget)
    end

    local image_box = constrain(
      image_widget,
      nil,
      options.image_height or dpi(180)
    )

    table.insert(content, image_box)

    if options.bottom_widget then
      table.insert(content, options.bottom_widget)
    end

    local footer = nil
    if options.footer then
      footer = wibox.widget {
        text = options.footer,
        font = "JetBrainsMono Nerd Font, bold 10",
        widget = wibox.widget.textbox,
      }
    end

    if footer then
      table.insert(content, footer)
    end

    local section = create_section_frame(title_text, content, options.accent or palette.accent, {
      bg_alpha = options.bg_alpha or 0.72,
      margins = options.margins or dpi(10),
    })

    return section, {
      image_box = image_box,
    }
  end

  local function create_history_trace_graph(values, accent, options)
    options = options or {}

    local widget = wibox.widget.base.make_widget()
    local graph_height = options.height or dpi(34)
    local max_points = options.max_points or 24
    local corner = options.radius or dpi(8)
    local bg_alpha = options.bg_alpha or 0.96
    local border_alpha = options.border_alpha or 0.18
    local fill_alpha = options.fill_alpha or 0.24
    local glow_alpha = options.glow_alpha or 0.18
    local line_alpha = options.line_alpha or 0.95
    local line_width = options.line_width or dpi(1.6)
    local glow_width = options.glow_width or dpi(4)
    local grid_alpha = options.grid_alpha or 0.16
    local vertical_grid_alpha = options.vertical_grid_alpha or 0.05

    function widget:fit(_, available_width, _)
      return available_width, graph_height
    end

    function widget:set_graph_height(new_height)
      graph_height = clamp_dimension(new_height or graph_height, dpi(16), dpi(240))
      self:emit_signal("widget::layout_changed")
      self:emit_signal("widget::redraw_needed")
    end

    function widget:draw(_, cr, w, h)
      local r, g, b = hex_to_rgba(accent)
      local grid_r, grid_g, grid_b = hex_to_rgba(palette.grid)
      local inset = dpi(5)
      local plot_x = inset
      local plot_y = inset
      local plot_w = math.max(1, w - inset * 2)
      local plot_h = math.max(1, h - inset * 2)
      local count = math.min(#values, max_points)
      local start_index = math.max(1, #values - count + 1)
      local compact_values = {}

      for index = start_index, #values do
        table.insert(compact_values, values[index])
      end

      local function compact_points_for(series)
        local points = {}
        local step = plot_w / math.max(#series - 1, 1)

        for index, value in ipairs(series) do
          points[index] = {
            x = plot_x + (index - 1) * step,
            y = plot_y + plot_h - (plot_h * (clamp(value, 0, 100) / 100)),
          }
        end

        return points
      end

      local function trace_compact_line(points)
        if #points == 0 then
          return
        end

        cr:move_to(points[1].x, points[1].y)

        for index = 2, #points do
          local previous = points[index - 1]
          local current = points[index]
          local mid_x = (previous.x + current.x) / 2
          cr:curve_to(mid_x, previous.y, mid_x, current.y, current.x, current.y)
        end
      end

      gears.shape.rounded_rect(cr, w, h, corner)
      cr:set_source_rgba(0.03, 0.03, 0.08, bg_alpha)
      cr:fill()

      gears.shape.rounded_rect(cr, w, h, corner)
      cr:set_source_rgba(r, g, b, border_alpha)
      cr:set_line_width(dpi(1))
      cr:stroke()

      for line = 0, 2 do
        local y = plot_y + (plot_h / 2) * line
        cr:set_source_rgba(grid_r, grid_g, grid_b, line == 2 and grid_alpha * 0.65 or grid_alpha)
        cr:set_line_width(1)
        cr:move_to(plot_x, y)
        cr:line_to(plot_x + plot_w, y)
        cr:stroke()
      end

      for line = 0, 4 do
        local x = plot_x + (plot_w / 4) * line
        cr:set_source_rgba(r, g, b, line % 2 == 0 and vertical_grid_alpha or vertical_grid_alpha * 0.6)
        cr:set_line_width(1)
        cr:move_to(x, plot_y)
        cr:line_to(x, plot_y + plot_h)
        cr:stroke()
      end

      if #compact_values >= 2 then
        local points = compact_points_for(compact_values)
        local first = points[1]
        local last = points[#points]

        cr:new_path()
        cr:move_to(plot_x, plot_y + plot_h)
        cr:line_to(first.x, first.y)
        trace_compact_line(points)
        cr:line_to(last.x, plot_y + plot_h)
        cr:close_path()
        cr:set_source_rgba(r, g, b, fill_alpha)
        cr:fill_preserve()

        cr:set_source_rgba(r, g, b, glow_alpha)
        cr:set_line_width(glow_width)
        cr:stroke_preserve()

        cr:new_path()
        trace_compact_line(points)
        cr:set_source_rgba(r, g, b, line_alpha)
        cr:set_line_width(line_width)
        cr:stroke()
      end
    end

    return register_redraw_target(widget)
  end

  local function create_hardware_section(title_text, image_path, options)
    options = options or {}

    local metric_row, metric_value = create_info_row(
      options.metric_label or "LOAD",
      options.initial_value or "00%",
      options.accent or palette.accent
    )

    local graph = create_history_trace_graph(options.history or {}, options.accent or palette.accent, {
      height = options.graph_height or dpi(38),
      max_points = options.max_points,
      radius = options.graph_radius or dpi(6),
      bg_alpha = options.graph_bg_alpha or 0.88,
      border_alpha = options.graph_border_alpha or 0.28,
      fill_alpha = options.graph_fill_alpha or 0.22,
      glow_alpha = options.graph_glow_alpha or 0.18,
      line_alpha = options.graph_line_alpha or 0.94,
      line_width = options.graph_line_width or dpi(1.5),
      glow_width = options.graph_glow_width or dpi(4),
      grid_alpha = options.graph_grid_alpha or 0.12,
      vertical_grid_alpha = options.graph_vertical_grid_alpha or 0.04,
    })

    local image_canvas = create_monitor_canvas(image_path, {
      accent = options.accent,
      tint = options.tint,
      glow_alpha = options.glow_alpha,
      tint_alpha = options.tint_alpha,
      band_alpha = options.band_alpha,
      radius = dpi(8),
      image_mode = "contain",
      image_padding = options.image_padding or dpi(4),
    })

    local image_stack = wibox.widget {
      image_canvas,
      {
        {
          graph,
          left = dpi(8),
          right = dpi(8),
          bottom = dpi(8),
          widget = wibox.container.margin,
        },
        valign = "bottom",
        halign = "fill",
        widget = wibox.container.place,
      },
      layout = wibox.layout.stack,
    }

    local section, section_refs = create_monitor_section(title_text, image_path, {
      accent = options.accent,
      tint = options.tint,
      glow_alpha = options.glow_alpha,
      tint_alpha = options.tint_alpha,
      image_height = options.image_height,
      bg_alpha = options.bg_alpha,
      margins = options.margins,
      top_widget = metric_row,
      image_widget = image_stack,
      image_mode = "contain",
      image_padding = options.image_padding or dpi(4),
      content_spacing = options.content_spacing or dpi(4),
      band_alpha = options.band_alpha,
    })

    return section, metric_value, {
      graph = graph,
      image_box = section_refs.image_box,
    }
  end

  local function archive_image(index)
    return archive_images[index] or main_image_path
  end

  local net_card, net_value, net_refs = create_hardware_section("PRIMARY FEED // NET FLOW", main_image_path, {
    accent = palette.net,
    tint = palette.gpu,
    glow_alpha = 0.08,
    tint_alpha = 0.03,
    metric_label = "NET FLOW",
    history = history.net,
    image_height = dpi(306),
    graph_height = dpi(40),
    margins = dpi(8),
    image_padding = dpi(2),
    band_alpha = 0.02,
  })

  local mem_card, mem_value, mem_refs = create_hardware_section("ARCHIVE 01 // MEM BANK", archive_image(1), {
    accent = palette.mem,
    tint = palette.mem,
    glow_alpha = 0.06,
    tint_alpha = 0.03,
    metric_label = "MEM BANK",
    history = history.mem,
    image_height = dpi(306),
    graph_height = dpi(40),
    margins = dpi(8),
    image_padding = dpi(2),
    band_alpha = 0.02,
  })

  local gpu_card, gpu_value, gpu_refs = create_hardware_section("ARCHIVE 02 // GPU CORE", archive_image(2), {
    accent = palette.gpu,
    tint = palette.gpu,
    glow_alpha = 0.06,
    tint_alpha = 0.03,
    metric_label = "GPU TEMP",
    history = history.gpu,
    image_height = dpi(306),
    graph_height = dpi(40),
    margins = dpi(8),
    image_padding = dpi(2),
    band_alpha = 0.02,
  })

  local cpu_card, cpu_value, cpu_refs = create_hardware_section("SUBJECT DX-LN // LAIN CPU", archive_image(3), {
    accent = palette.cpu,
    tint = palette.accent,
    glow_alpha = 0.08,
    tint_alpha = 0.03,
    metric_label = "CPU TEMP",
    history = history.cpu,
    image_height = dpi(306),
    graph_height = dpi(40),
    margins = dpi(8),
    image_padding = dpi(2),
    band_alpha = 0.02,
  })

  local wifi_card, wifi_value = create_hardware_section("FIELD 03 // WIFI NOISE", archive_image(3), {
    accent = palette.net,
    tint = palette.net,
    glow_alpha = 0.06,
    tint_alpha = 0.03,
    metric_label = "WIFI NOISE",
    history = history.wifi,
    image_height = dpi(96),
    graph_height = dpi(24),
    margins = dpi(8),
    image_padding = dpi(2),
    band_alpha = 0.02,
  })

  local audio_card, audio_value = create_hardware_section("FIELD 04 // AUDIO BUS", archive_image(4), {
    accent = palette.cpu,
    tint = palette.cpu,
    glow_alpha = 0.06,
    tint_alpha = 0.03,
    metric_label = "AUDIO BUS",
    history = history.audio,
    image_height = dpi(96),
    graph_height = dpi(24),
    margins = dpi(8),
    image_padding = dpi(2),
    band_alpha = 0.02,
  })

  local threat_segments = {}
  local threat_strip = wibox.layout.fixed.horizontal()
  threat_strip.spacing = dpi(4)

  for index = 1, 12 do
    local segment = wibox.widget {
      forced_width = dpi(18),
      forced_height = dpi(8),
      shape = gears.shape.rounded_bar,
      bg = with_alpha(palette.accent, 0.14),
      widget = wibox.container.background,
    }

    threat_segments[index] = segment
    threat_strip:add(segment)
  end

  local threat_value = wibox.widget {
    text = "IDLE HUM",
    font = "JetBrainsMono Nerd Font, ExtraBold 12",
    align = "right",
    widget = wibox.widget.textbox,
  }

  local graph_widget = register_redraw_target(wibox.widget.base.make_widget())

  local function points_for(values, x, y, w, h)
    local points = {}
    local count = #values
    local step = w / math.max(count - 1, 1)

    for i, value in ipairs(values) do
      points[i] = {
        x = x + (i - 1) * step,
        y = y + h - (h * (clamp(value, 0, 100) / 100)),
      }
    end

    return points
  end

  local function trace_smooth_line(cr, points)
    if #points == 0 then
      return
    end

    cr:move_to(points[1].x, points[1].y)

    for i = 2, #points do
      local previous = points[i - 1]
      local current = points[i]
      local mid_x = (previous.x + current.x) / 2

      cr:curve_to(mid_x, previous.y, mid_x, current.y, current.x, current.y)
    end
  end

  local function draw_area(cr, values, x, y, w, h, color_hex, alpha)
    local count = #values
    if count < 2 then
      return
    end

    local r, g, b = hex_to_rgba(color_hex)
    local points = points_for(values, x, y, w, h)
    local first = points[1]
    local last = points[#points]

    cr:new_path()
    cr:move_to(x, y + h)
    cr:line_to(first.x, first.y)
    trace_smooth_line(cr, points)
    cr:line_to(last.x, y + h)
    cr:close_path()
    cr:set_source_rgba(r, g, b, alpha)
    cr:fill_preserve()

    cr:set_source_rgba(r, g, b, 0.22)
    cr:set_line_width(dpi(6))
    cr:stroke_preserve()

    cr:new_path()
    trace_smooth_line(cr, points)
    cr:set_source_rgba(r, g, b, 0.95)
    cr:set_line_width(dpi(2))
    cr:stroke()
  end

  function graph_widget:fit(_, available_width, _)
    return available_width, dpi(170)
  end

  function graph_widget:set_graph_height(new_height)
    self._graph_height = clamp_dimension(new_height or self._graph_height or dpi(170), dpi(120), dpi(320))
    self:emit_signal("widget::layout_changed")
    self:emit_signal("widget::redraw_needed")
  end

  local original_graph_fit = graph_widget.fit

  function graph_widget:fit(context, available_width, available_height)
    if self._graph_height then
      return available_width, self._graph_height
    end

    return original_graph_fit(self, context, available_width, available_height)
  end

  function graph_widget:draw(_, cr, w, h)
    local x = dpi(8)
    local y = dpi(8)
    local plot_w = w - dpi(16)
    local plot_h = h - dpi(16)
    local grid_r, grid_g, grid_b = hex_to_rgba(palette.grid)

    local accent_r, accent_g, accent_b = hex_to_rgba(palette.accent)

    gears.shape.rounded_rect(cr, w, h, dpi(12))
    cr:set_source_rgba(0.03, 0.03, 0.08, 0.94)
    cr:fill()

    gears.shape.rounded_rect(cr, w, h, dpi(12))
    cr:set_source_rgba(accent_r, accent_g, accent_b, 0.10)
    cr:set_line_width(dpi(8))
    cr:stroke()

    cr:rectangle(x, y + plot_h * 0.55, plot_w, plot_h * 0.45)
    cr:set_source_rgba(accent_r, accent_g, accent_b, 0.05)
    cr:fill()

    for i = 0, 4 do
      local gy = y + (plot_h / 4) * i
      cr:set_source_rgba(grid_r, grid_g, grid_b, i % 2 == 0 and 0.22 or 0.12)
      cr:set_line_width(1)
      cr:move_to(x, gy)
      cr:line_to(x + plot_w, gy)
      cr:stroke()
    end

    for i = 0, 10 do
      local gx = x + (plot_w / 10) * i
      cr:set_source_rgba(accent_r, accent_g, accent_b, i % 2 == 0 and 0.09 or 0.04)
      cr:set_line_width(1)
      cr:move_to(gx, y)
      cr:line_to(gx, y + plot_h)
      cr:stroke()
    end

    draw_area(cr, history.mem, x, y, plot_w, plot_h, palette.mem, 0.34)
    draw_area(cr, history.gpu, x, y, plot_w, plot_h, palette.gpu, 0.26)
    draw_area(cr, history.net, x, y, plot_w, plot_h, palette.net, 0.24)
    draw_area(cr, history.cpu, x, y, plot_w, plot_h, palette.cpu, 0.20)

    cr:set_source_rgba(accent_r, accent_g, accent_b, 0.22)
    cr:set_line_width(dpi(1.5))
    cr:move_to(x + dpi(6), y + dpi(6))
    cr:line_to(x + dpi(54), y + dpi(6))
    cr:line_to(x + dpi(54), y + dpi(22))
    cr:stroke()

    cr:move_to(x + plot_w - dpi(54), y + plot_h - dpi(6))
    cr:line_to(x + plot_w - dpi(6), y + plot_h - dpi(6))
    cr:line_to(x + plot_w - dpi(6), y + plot_h - dpi(22))
    cr:stroke()
  end

  local title = wibox.widget {
    text = "SYSTEM MONITOR",
    font = "JetBrainsMono Nerd Font, ExtraBold 14",
    align = "center",
    widget = wibox.widget.textbox,
  }

  local header_line = wibox.widget {
    forced_height = dpi(3),
    bg = gears.color {
      type = "linear",
      from = { 0, 0 },
      to = { width, 0 },
      stops = {
        { 0, p.line_bright },
        { 0.33, palette.accent },
        { 0.66, palette.gpu },
        { 1, palette.mem },
      }
    },
    shape = gears.shape.rounded_bar,
    widget = wibox.container.background,
  }

  local title_wrap = wibox.widget {
    {
      title,
      margins = dpi(10),
      widget = wibox.container.margin,
    },
    fg = p.text_heading,
    bg = with_alpha(palette.accent, 0.08),
    border_width = dpi(1),
    border_color = with_alpha(palette.accent, 0.32),
    shape = function(cr, w, h)
      gears.shape.rounded_rect(cr, w, h, dpi(8))
    end,
    widget = wibox.container.background,
  }

  local top_left_width = math.floor(width * 0.24)
  local top_mid_width = math.floor(width * 0.17)
  local top_mid2_width = math.floor(width * 0.17)
  local top_right_width = math.max(dpi(330), width - top_left_width - top_mid_width - top_mid2_width - dpi(100))
  local bottom_trace_width = width - dpi(36)

  local net_slot = constrain(net_card, top_left_width, nil)
  local mem_slot = constrain(mem_card, top_mid_width, nil)
  local gpu_slot = constrain(gpu_card, top_mid2_width, nil)
  local cpu_slot = constrain(cpu_card, top_right_width, nil)

  local top_row = wibox.widget {
    net_slot,
    mem_slot,
    gpu_slot,
    cpu_slot,
    spacing = dpi(14),
    layout = wibox.layout.fixed.horizontal,
  }

  local bottom_graph_slot = constrain(graph_widget, nil, dpi(186))

  local bottom_row = constrain(
    create_section_frame(
      "THREAT LEVEL // WIRED TRACE",
      {
        bottom_graph_slot,
        {
          threat_strip,
          nil,
          threat_value,
          expand = "inside",
          layout = wibox.layout.align.horizontal,
        },
        spacing = dpi(10),
        layout = wibox.layout.fixed.vertical,
      },
      palette.accent,
      {
        bg_alpha = 0.66,
        margins = dpi(10),
      }
    ),
    bottom_trace_width,
    nil
  )

  local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}

  local panel = wibox.widget {
    {
      {
        header_line,
        title_wrap,
        top_row,
        bottom_row,
        spacing = dpi(12),
        layout = wibox.layout.fixed.vertical,
      },
      margins = dpi(18),
      widget = wibox.container.margin,
    },
    bg = gears.color {
      type = "linear",
      from = { 0, 0 },
      to = { 0, height },
      stops = {
        { 0, p.a(p.base, 0.94) },
        { 0.55, p.a(p.abyss, 0.94) },
        { 1, p.a(p.void, 0.95) },
      }
    },
    fg = palette.text,
    shape = function(cr, w, h)
      gears.shape.rounded_rect(cr, w, h, radius)
    end,
    border_width = dpi(1),
    border_color = with_alpha(palette.accent, 0.36),
    widget = wibox.container.background,
  }

  local function update_texts()
    local threat_load = (state.cpu * 0.34) + (state.mem * 0.22) + (state.gpu * 0.24) + (state.net * 0.20)
    local threat_label = "IDLE HUM"

    if threat_load >= 82 then
      threat_label = "MAX OVERDRIVE"
    elseif threat_load >= 62 then
      threat_label = "STATIC SURGE"
    elseif threat_load >= 38 then
      threat_label = "WIRED SYNC"
    end

    cpu_value.text = format_temperature(state.cpu_temp)
    mem_value.text = format_percent(state.mem)
    gpu_value.text = format_temperature(state.gpu_temp)
    net_value.text = format_percent(state.net)
    threat_value.text = threat_label

    if state.wifi then
      wifi_value.text = format_percent(state.wifi)
    else
      wifi_value.text = "OFFLINE"
    end

    if state.muted then
      audio_value.text = "MUTED"
    else
      audio_value.text = format_percent(state.audio)
    end

    local active_segments = math.max(1, math.floor((threat_load / 100) * #threat_segments + 0.5))
    for index, segment in ipairs(threat_segments) do
      if index <= active_segments then
        local color = palette.accent
        if index >= 10 then
          color = palette.mem
        elseif index >= 7 then
          color = palette.cpu
        end

        segment.bg = color
      else
        segment.bg = with_alpha(palette.accent, 0.14)
      end
    end
  end

  local top_card_refs = { net_refs, mem_refs, gpu_refs, cpu_refs }
  local minimum_panel_width = dpi(760)
  local minimum_panel_height = dpi(460)

  local function update_header_gradient(current_width)
    header_line.bg = gears.color {
      type = "linear",
      from = { 0, 0 },
      to = { current_width, 0 },
      stops = {
        { 0, p.line_bright },
        { 0.33, palette.accent },
        { 0.66, palette.gpu },
        { 1, palette.mem },
      }
    }
  end

  local function relayout_panel(current_width, current_height)
    width = clamp_dimension(current_width or width, minimum_panel_width, dpi(4096))
    height = clamp_dimension(current_height or height, minimum_panel_height, dpi(4096))

    panel._preferred_segment_width = width
    panel._preferred_segment_height = height

    local row_spacing = dpi(14) * 3
    local row_width = math.max(dpi(640), width - dpi(36))
    local card_budget = math.max(dpi(520), row_width - row_spacing)
    local image_height = clamp_dimension(math.floor(height * 0.42), dpi(180), dpi(360))
    local overlay_graph_height = clamp_dimension(math.floor(height * 0.055), dpi(28), dpi(64))
    local threat_graph_height = clamp_dimension(math.floor(height * 0.25), dpi(136), dpi(280))

    top_left_width = math.floor(card_budget * 0.24)
    top_mid_width = math.floor(card_budget * 0.17)
    top_mid2_width = math.floor(card_budget * 0.17)
    top_right_width = math.max(dpi(240), card_budget - top_left_width - top_mid_width - top_mid2_width)
    bottom_trace_width = row_width

    net_slot.forced_width = top_left_width
    mem_slot.forced_width = top_mid_width
    gpu_slot.forced_width = top_mid2_width
    cpu_slot.forced_width = top_right_width
    bottom_row.forced_width = bottom_trace_width
    bottom_graph_slot.forced_height = threat_graph_height
    graph_widget:set_graph_height(threat_graph_height)

    for _, refs in ipairs(top_card_refs) do
      refs.image_box.forced_height = image_height
      refs.graph:set_graph_height(overlay_graph_height)
    end

    update_header_gradient(width)
    panel:emit_signal("widget::layout_changed")
    panel:emit_signal("widget::redraw_needed")
  end

  panel._preserve_colors = true
  panel._preferred_segment_width = width
  panel._preferred_segment_height = height
  panel._minimum_segment_width = minimum_panel_width
  panel._minimum_segment_height = minimum_panel_height
  panel._always_visible = true
  panel._popup_ontop = false
  panel._popup_type = "utility"
  panel._popup_opacity = panel_transparency.enabled == false and 1 or (panel_transparency.chart or 0.8)
  panel._reserve_space = false
  panel._input_passthrough = false
  panel._allow_modkey_drag = true
  panel._allow_modkey_resize = true
  panel._popup_state_key = "system_monitor_chart"
  panel._handle_popup_resize = relayout_panel

  panel._timer = gears.timer {
    timeout = interval,
    autostart = true,
    call_now = true,
    callback = function()
      tick = tick + 1

      state.cpu = clamp(sample_cpu(), 0, 100)
      state.mem = clamp(sample_mem(), 0, 100)
      state.gpu = clamp(sample_gpu(), 0, 100)
      local net_percent, net_rate = sample_net()
      state.net = clamp(net_percent, 0, 100)
      state.net_rate = net_rate or 0

      if tick == 1 or tick % 3 == 0 then
        state.wifi = sample_wifi()
        state.cpu_temp = sample_cpu_temp()
        state.gpu_temp = sample_gpu_temp()
        state.audio, state.muted = sample_audio()
        state.keyboard = sample_keyboard()
      end

      if tick == 1 or tick % 5 == 0 then
        state.bt_name = sample_bt_name()
      end

      push(history.cpu, state.cpu)
      push(history.mem, state.mem)
      push(history.gpu, state.gpu)
      push(history.net, state.net)
      push(history.wifi, state.wifi or 0)
      push(history.audio, state.muted and 0 or state.audio)

      update_texts()
      for _, widget in ipairs(redraw_targets) do
        widget:emit_signal("widget::redraw_needed")
      end
    end,
  }

  relayout_panel(width, height)
  update_texts()
  return panel
end
