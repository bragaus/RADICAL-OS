------------------------------------------------------------------------------------------
-- src/widgets/info_panel.lua — Painel "INFO" (VIOLET HUD §5.1 col. esquerda / §7.4.1)      --
--                                                                                        --
-- Info-rows key/value (§7.4.1): rótulo à esquerda (text_muted, CAIXA-ALTA) · valor à    --
-- direita (text_bright). Fundo de linha sutil v500@0.06 + borda v500@0.20, raio bar.     --
--                                                                                        --
-- Linhas:                                                                                --
--   CPU     -> primeiro "model name" de /proc/cpuinfo                                    --
--   KERNEL  -> uname -r                                                                  --
--   UPTIME  -> /proc/uptime (campo 1), formatado "Hh Mm"                                 --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (5s,        --
-- call_now). NUNCA io.popen/os.execute — congela o WM (deadlock conhecido neste repo).   --
-- Saída de shell sempre passada por tonumber()/nil-guard antes de qualquer math.         --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")

local MONO = "JetBrainsMono Nerd Font"

-- Encurta um valor longo (ex.: model name da CPU) com reticências.
local function shorten(text, max)
  text = tostring(text or "")
  max = max or 26
  if #text > max then
    return text:sub(1, max - 1) .. "…"
  end
  return text
end

-- Formata segundos de uptime em "Hh Mm" (com guarda numérica).
local function fmt_uptime(secs)
  local n = tonumber(secs)
  if not n or n < 0 then
    return "--"
  end
  local total_min = math.floor(n / 60)
  local hours = math.floor(total_min / 60)
  local mins = total_min % 60
  return string.format("%dh %02dm", hours, mins)
end

-- Cria uma info-row reusando o look do create_info_row do chart (§7.4.1):
-- rótulo text_muted CAIXA-ALTA à esquerda, valor text_bright à direita,
-- fundo sutil v500@0.06 + borda v500@0.20, raio bar.
local function create_info_row(label_text)
  local label = wibox.widget {
    text   = tostring(label_text or ""):upper(),
    font   = MONO .. ", Bold 10",
    valign = "center",
    widget = wibox.widget.textbox,
  }

  local value = wibox.widget {
    text   = "--",
    font   = MONO .. ", ExtraBold 11",
    align  = "right",
    valign = "center",
    widget = wibox.widget.textbox,
  }

  local row = wibox.widget {
    {
      {
        {
          label,
          fg     = p.text_muted,
          widget = wibox.container.background,
        },
        nil,
        {
          value,
          fg     = p.text_bright,
          widget = wibox.container.background,
        },
        expand = "inside",
        layout = wibox.layout.align.horizontal,
      },
      left   = dpi(8),
      right  = dpi(8),
      top    = dpi(3),
      bottom = dpi(3),
      widget = wibox.container.margin,
    },
    forced_height = dpi(24),
    bg            = p.a(p.v500, 0.06),
    border_width  = dpi(1),
    border_color  = p.a(p.v500, 0.20),
    shape         = function(cr, w, h)
      gears.shape.rounded_rect(cr, w, h, dpi(6))
    end,
    widget = wibox.container.background,
  }

  return row, value
end

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  local cpu_row, cpu_value       = create_info_row("CPU")
  local kernel_row, kernel_value = create_info_row("KERNEL")
  local uptime_row, uptime_value = create_info_row("UPTIME")

  local body = wibox.widget {
    cpu_row,
    kernel_row,
    uptime_row,
    spacing = dpi(4),
    layout  = wibox.layout.fixed.vertical,
  }

  -- CPU model e kernel mudam raramente; coletados uma vez (assíncrono).
  awful.spawn.easy_async_with_shell(
    "grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2-",
    function(stdout)
      local model = tostring(stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
      -- Normaliza espaços internos repetidos.
      model = model:gsub("%s%s+", " ")
      if model ~= "" then
        cpu_value:set_text(shorten(model, 26))
      end
    end
  )

  awful.spawn.easy_async_with_shell(
    "uname -r 2>/dev/null",
    function(stdout)
      local kr = tostring(stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if kr ~= "" then
        kernel_value:set_text(shorten(kr, 26))
      end
    end
  )

  -- Uptime é dinâmico — amostrado no timer.
  local function update()
    awful.spawn.easy_async_with_shell(
      "cut -d' ' -f1 /proc/uptime 2>/dev/null",
      function(stdout)
        local secs = tonumber((tostring(stdout or ""):match("[%d%.]+")))
        uptime_value:set_text(fmt_uptime(secs))
      end
    )
  end

  gears.timer {
    timeout   = args.timeout or 5,
    autostart = true,
    call_now  = true,
    callback  = update,
  }

  return panel({
    title  = "INFO",
    body   = body,
    accent = p.v500,
    w      = args.w or dpi(260),
  })
end
