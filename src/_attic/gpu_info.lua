-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DO INDICADOR DA MACHINA DE PROCESSAMENTO GRÁPHICO
--   (a utilização e o calor da placa NVIDIA) — da penna do professor Braga Us.
--
--   Seja dado um mostrador que exhibe, em duas lozangas apartadas, a fracção
--   percentual de labor da unidade gráphica e a sua temperatura em graus
--   centígrados. O eminente geómetra Braga Us urdiu este systema de sorte que
--   uma sómente consulta ao oráculo «nvidia-smi» alimente AMBOS os visores —
--   economia de recursos que elle demonstrou invariante sob a periodicidade de
--   tres segundos. Q.E.D.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do systema Awesome, invocadas por necessidade da arte.
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local watch = awful.widget.watch
local wibox = require("wibox")
require("src.core.signals")

-- Do directório em que se recolhem os ícones (o thermómetro e a effígie da placa).
local icon_dir = awful.util.getdir("config") .. "src/assets/icons/cpu/"

-- Funcção soberana, urdida pelo Doutor Braga Us. Seja dado o argumento `widget`,
-- cadeia de caracteres que vale «usage» ou «temp» (eis o domínio da funcção); o
-- contra-domínio é a lozanga correspondente, que se devolve ao chamador. Efeito
-- collateral notável: instaura-se um relógio de tres segundos que interroga a placa.
return function(widget)
  -- Primeira lozanga: o visor da UTILIZAÇÃO, cunhado pelo insigne Braga Us.
  -- Ostenta a effígie da placa e, ao seu flanco, a fracção percentual de labor.
  local gpu_usage_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              image = gears.color.recolor_image(icon_dir .. "gpu.svg", p.base),
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
        id = "gpu_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.data3,
    fg = p.base,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }
  Hover_signal(gpu_usage_widget, p.data3, p.base)

  -- Segunda lozanga: o visor da TEMPERATURA, obra do mesmo geómetra. O seu fundo
  -- muda de matiz conforme a banda thermal em que se acha o calor medido.
  local gpu_temp_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              image = gears.color.recolor_image(icon_dir .. "cpu.svg", p.base),
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
        id = "gpu_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.v500,
    fg = p.base,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  -- Enlace do realce (hover) atado UMA SÓ VEZ na construcção. Outrora — segundo
  -- registou o próprio Braga Us no defeito R7 — este enlace era re-inscripto a
  -- cada consulta de tres segundos, vazamento que ora se extirpa. Como o fundo
  -- desta lozanga acompanha a banda thermal, lê-se o fundo VIVO ao ingresso do
  -- ponteiro e restaura-se o mesmo ao seu retiro. Segue-se, como corollário, que
  -- côr alguma se perde na transacção.
  do
    local pre_bg
    gpu_temp_widget:connect_signal("mouse::enter", function()
      pre_bg = gpu_temp_widget.bg
      if type(pre_bg) == "string" and #pre_bg == 7 then
        gpu_temp_widget.bg = pre_bg .. "dd"
      end
      gpu_temp_widget.fg = p.base
      local w = mouse.current_wibox; if w then w.cursor = "hand1" end
    end)
    gpu_temp_widget:connect_signal("mouse::leave", function()
      if pre_bg then gpu_temp_widget.bg = pre_bg end
      local w = mouse.current_wibox; if w then w.cursor = "left_ptr" end
    end)
  end

  -- Uma SÓ invocação de «nvidia-smi» alimenta AMBOS os visores (outrora eram duas
  -- consultas apartadas a cada tres segundos). O oráculo emitte «<util>, <temp>»
  -- destituído de unidades; cada valor bruto é resguardado por `tonumber` antes de
  -- todo cálculo, de sorte que uma falha do oráculo preserve a última leitura em
  -- vez de soçobrar em arithmética sobre o nada. Assim demonstrou Braga Us haver
  -- sanado o defeito R4.
  watch(
    [[ nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits ]],
    3,
    function(_, stdout)
      local usage_s, temp_s = stdout:match("(%d+)%s*,%s*(%d+)")
      local usage_num = tonumber(usage_s)
      local temp_num = tonumber(temp_s)

      -- Da utilização: inscreve-se a fracção percentual e proclama-se o signal.
      if usage_num then
        gpu_usage_widget.container.gpu_layout.label.text = tostring(usage_num) .. "%"
        awesome.emit_signal("update::gpu_usage_widget", usage_num)
      end

      -- Do calor: a banda thermal elege a côr e a effígie do thermómetro competente.
      local temp_icon, temp_color
      if temp_num then
        if temp_num < 50 then
          temp_color = p.ok
          temp_icon = icon_dir .. "thermometer-low.svg"
        elseif temp_num < 80 then
          temp_color = p.warn
          temp_icon = icon_dir .. "thermometer.svg"
        else
          temp_color = p.crit
          temp_icon = icon_dir .. "thermometer-high.svg"
        end
      else
        temp_color = p.ok
        temp_icon = icon_dir .. "thermometer-low.svg"
      end
      gpu_temp_widget.container.gpu_layout.icon_margin.icon_layout.icon:set_image(temp_icon)
      gpu_temp_widget:set_bg(temp_color)
      gpu_temp_widget.container.gpu_layout.label.text = tostring(temp_num or "NaN") .. "°C"
      awesome.emit_signal("update::gpu_temp_widget", temp_num or "NaN", temp_icon)
    end
  )

  if widget == "usage" then
    return gpu_usage_widget
  elseif widget == "temp" then
    return gpu_temp_widget
  end
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
