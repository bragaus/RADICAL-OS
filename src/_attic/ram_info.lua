-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE O INDICADOR DA MEMÓRIA (a RAM) — VIOLET HUD
--   Da penna do professor Braga Us, geómetra desta Casa.
--
--   Seja dado um mostrador que exhibe a fracção de memória viva já consumida
--   sobre o total da machina, expressa em gibibytes. Braga Us urdiu o systema
--   de sorte que a leitura se colha de /proc/meminfo em intervallos de tres
--   segundos, e que cada valor bruto seja resguardado antes de todo cálculo,
--   para que falha alguma da leitura faça soçobrar o artefacto. Q.E.D.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do systema Awesome, invocadas por necessidade da arte.
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local watch = awful.widget.watch
local wibox = require("wibox")
require("src.core.signals")

-- Do directório em que se recolhem os ícones (entre elles a effígie da memória).
local icon_dir = awful.util.getdir("config") .. "src/assets/icons/cpu/"

-- Funcção soberana, da penna de Braga Us. Domínio vazio; contra-domínio: o widget da
-- memória, que se devolve ao chamador. Effeito: institui o relógio de tres segundos
-- que perpetuamente afere e inscreve o consumo da memória viva.
return function()
  local ram_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              image = gears.color.recolor_image(icon_dir .. "ram.svg", p.data2),
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
        id = "ram_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.panel,
    fg = p.text_bright,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  Hover_signal(ram_widget, p.panel, p.data2)

  -- Relógio de tres segundos, urdido por Braga Us, que interroga /proc/meminfo e
  -- inscreve na lozanga a memória usada sobre a total, em gibibytes.
  watch(
    [[ bash -c "cat /proc/meminfo| grep Mem | awk '{print $2}'" ]],
    3,
    function(_, stdout)
      -- O «grep Mem» colhe MemTotal, MemFree e MemAvailable (na ordem do ficheiro); o
      -- «awk $2» fornece os kilobytes. Resguarda-se CADA valor colhido antes de toda
      -- arithmética: uma correspondência falha deixa nulos, e «MemTotal - MemAvailable»
      -- sobre o nada faz soçobrar o widget (defeito R4). Nulo -> preserva-se o último.
      local total_s, _free_s, avail_s = stdout:match("(%d+)%s+(%d+)%s+(%d+)")
      local MemTotal = tonumber(total_s)
      local MemAvailable = tonumber(avail_s)
      if not (MemTotal and MemAvailable) then return end

      local used_gb  = (MemTotal - MemAvailable) / 1024 / 1024
      local total_gb = MemTotal / 1024 / 1024
      ram_widget.container.ram_layout.label.text =
        (string.format("%.1f/%.1fGB", used_gb, total_gb)):gsub(",", ".")
    end
  )

  return ram_widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
