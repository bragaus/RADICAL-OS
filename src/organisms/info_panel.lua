------------------------------------------------------------------------------------------
-- src/organisms/info_panel.lua — Painel "INFO" (VIOLET HUD §5.1 col. esquerda / §7.4.1)      --
--                                                                                        --
-- Info-rows key/value (§7.4.1): rótulo à esquerda (text_muted, CAIXA-ALTA) · valor à    --
-- direita (text_bright). Fundo de linha sutil v500@0.06 + borda v500@0.20, raio bar.     --
-- As linhas usam a molécula compartilhada info_row{variant="chip"} (o "chip" reproduz    --
-- exatamente o antigo create_info_row: superfície v500@chip_bg + borda v500@chip_border, --
-- raio radius_bar, altura row_h).                                                        --
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
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)
local info_row = require("src.molecules.info_row") -- key/value HUD row (§7.4.1)

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

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Info-rows via molécula compartilhada (variant "chip" == look do antigo create_info_row).
  -- Refs diretas às linhas: a molécula devolve o widget COM :set_value; nunca consultamos
  -- ids de volta através do corpo do panel() (R1).
  local cpu_row    = info_row { key = "CPU",    variant = "chip" }
  local kernel_row = info_row { key = "KERNEL", variant = "chip" }
  local uptime_row = info_row { key = "UPTIME", variant = "chip" }

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
        cpu_row:set_value(shorten(model, 26))
      end
    end
  )

  awful.spawn.easy_async_with_shell(
    "uname -r 2>/dev/null",
    function(stdout)
      local kr = tostring(stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if kr ~= "" then
        kernel_row:set_value(shorten(kr, 26))
      end
    end
  )

  -- Uptime é dinâmico — amostrado no timer.
  local function update()
    awful.spawn.easy_async_with_shell(
      "cut -d' ' -f1 /proc/uptime 2>/dev/null",
      function(stdout)
        local secs = tonumber((tostring(stdout or ""):match("[%d%.]+")))
        uptime_row:set_value(fmt_uptime(secs))
      end
    )
  end

  local sample_timer = gears.timer {
    timeout   = args.timeout or 5,
    autostart = false,
    call_now  = false,
    callback  = update,
  }

  local outer = panel({
    title      = "INFO",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(260),
    right_icon = Icon("cpu", { size = dpi(14), color = p.text_muted }),
  })

  -- Sampling gated por visibilidade (control_center liga ao abrir / desliga ao fechar o
  -- dashboard): não amostra nem redesenha enquanto o popup está oculto (perf).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    update()
    sample_timer:start()
  end
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end
