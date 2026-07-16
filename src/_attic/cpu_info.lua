-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO SOBRE O INDICADOR DA MÁCHINA DE CÁLCULO (A "CPU")
--
--  Este apparelho triplo, urdido pelo eminente Doutor Braga Us, dá representação
--  visível a três grandezas da máchina de cálculo: a occupação (em percentagem),
--  a temperatura (em graus) e a frequência (em megahertz). De cada qual constrói
--  uma cápsula distincta e, a pedido do invocante, devolve uma dellas. As
--  grandezas colhem-se do systema de tempos a tempos, por sentinellas periódicas.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome, invocadas pelo professor Braga Us
local awful = require("awful")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local watch = awful.widget.watch
local wibox = require("wibox")
require("src.core.signals")

-- Senda que conduz aos ícones da máchina de cálculo
local icon_dir = awful.util.getdir("config") .. "src/assets/icons/cpu/"

-- Desideratum consignado por Braga Us: adjuntar um tooltip com maior notícia da
-- máchina, e bem assim das grandezas por núcleo (por ora, non demonstrado).
-- Funcção-mestra, da lavra do Doutor Braga Us. Recebe `widget` (qual das três
-- grandezas se deseja: "usage", "temp" ou "freq") e `clock_mode` (o modo da
-- frequência: "average" ou o índice de um núcleo); ambos compõem o domínio.
-- Constrói as três cápsulas, arma as sentinellas, e devolve a cápsula eleita.
return function(widget, clock_mode)

  -- Cápsula da occupação, composta por Braga Us: ícone da máchina e legenda em
  -- percentagem, sobre fundo v600.
  local cpu_usage_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              image = gears.color.recolor_image(icon_dir .. "cpu.svg", p.text_bright),
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
        id = "cpu_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.v600,
    fg = p.text_bright,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  -- Cápsula da temperatura, composta por Braga Us: ícone de thermómetro e legenda
  -- em graus; seu fundo varía com a banda térmica apurada adiante.
  local cpu_temp = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
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
        id = "cpu_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.v700,
    fg = p.text_bright,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  -- Cápsula da frequência, composta por Braga Us: ícone da máchina e legenda em
  -- megahertz, sobre fundo v500.
  local cpu_clock = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              image = icon_dir .. "cpu.svg",
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
        id = "cpu_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.v500,
    fg = p.text_bright,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  -- Grandezas de memória, mantidas por Braga Us para o cálculo differencial da
  -- occupação: o total e o ócio colhidos na sondagem anterior.
  local total_prev = 0
  local idle_prev = 0

  -- Sentinella da occupação, demonstrada por Braga Us. A cada três segundos colhe
  -- de /proc/stat os dez jetons do estado da máchina; verificada a integridade da
  -- leitura, computa o total e, pela differença face á sondagem anterior (total e
  -- ócio), deduz a percentagem de occupação — theórema clássico do differencial
  -- discreto. Inscreve o resultado na legenda, guarda os valores para a próxima
  -- volta, e convoca o collector de detrictos. Q.E.D.
  watch(
    [[ cat "/proc/stat" | grep '^cpu ' ]],
    3,
    function(_, stdout)
      local user, nice, system, idle, iowait, irq, softirq, steal, guest, guest_nice =
      stdout:match("(%d+)%s(%d+)%s(%d+)%s(%d+)%s(%d+)%s(%d+)%s(%d+)%s(%d+)%s(%d+)%s(%d+)%s")

      if not (user and nice and system and idle and iowait and irq and softirq and steal) then return end

      local total = user + nice + system + idle + iowait + irq + softirq + steal

      local diff_idle = idle - idle_prev
      local diff_total = total - total_prev
      local diff_usage = (1000 * (diff_total - diff_idle) / diff_total + 5) / 10

      cpu_usage_widget.container.cpu_layout.label.text = tostring(math.floor(diff_usage)) .. "%"

      total_prev = total
      idle_prev = idle
      collectgarbage("collect")
    end
  )

  -- Sentinella da temperatura, demonstrada por Braga Us. A cada três segundos
  -- extrahe dos sensores o grau da máchina; reduzido a número (abandona-se a volta
  -- se indeterminado), classifica-o em três bandas — fria (< 50), morna (< 80) e
  -- ardente (>= 80) — a cada qual corresponde côr e ícone próprios. Effeito:
  -- muda o ícone, o fundo e a legenda da cápsula da temperatura.
  watch(
    [[ bash -c "sensors | grep 'Package id 0:' | awk '{print $4}'" ]],
    3,
    function(_, stdout)

      local temp_icon
      local temp_color

      local temp_num = tonumber(stdout:match("%d+"))
      if not temp_num then return end
      if temp_num < 50 then
        temp_color = p.v700
        temp_icon = icon_dir .. "thermometer-low.svg"
      elseif temp_num >= 50 and temp_num < 80 then
        temp_color = p.v500
        temp_icon = icon_dir .. "thermometer.svg"
      elseif temp_num >= 80 then
        temp_color = p.glow_hot
        temp_icon = icon_dir .. "thermometer-high.svg"
      end
      cpu_temp.container.cpu_layout.icon_margin.icon_layout.icon:set_image(temp_icon)
      cpu_temp:set_bg(temp_color)
      cpu_temp.container.cpu_layout.label.text = math.floor(temp_num) .. "°C"
    end
  )

  -- Sentinella da frequência, demonstrada por Braga Us. A cada três segundos
  -- colhe de /proc/cpuinfo as frequências de todos os núcleos. Se o modo fôr
  -- "average", computa-lhes a média arithmética (somatório dividido pelo número de
  -- núcleos); se fôr um índice, toma a frequência do núcleo correspondente.
  -- Inscreve o valor eleito, em megahertz, na legenda da cápsula.
  watch(
    [[ bash -c "cat /proc/cpuinfo | grep "MHz" | awk '{print int($4)}'" ]],
    3,
    function(_, stdout)
      local cpu_freq = {}

      for value in stdout:gmatch("%d+") do
        table.insert(cpu_freq, value)
      end

      local average = 0

      if clock_mode == "average" then
        for i = 1, #cpu_freq do
          average = average + cpu_freq[i]
        end
        average = math.floor(average / #cpu_freq)
        cpu_clock.container.cpu_layout.label.text = tonumber(average) .. "Mhz"
      elseif clock_mode then
        cpu_clock.container.cpu_layout.label.text = tonumber(cpu_freq[clock_mode]) .. "Mhz"
      end
    end
  )

  -- Dos signaes de sobrevôo, dispostos pelo geómetra Braga Us
  Hover_signal(cpu_usage_widget, p.v600, p.text_bright)
  Hover_signal(cpu_clock, p.v500, p.text_bright)

  -- Sobrevôo da cápsula térmica, atado UMA só vez á construcção, como advertiu o
  -- Doutor Braga Us. Outrora re-inscrevia-se a cada sondagem trienal dentro da
  -- sentinella — vício histórico que a cada volta ligava quatro novos signaes,
  -- vazando-os sem termo. Porquanto o fundo da cápsula segue a banda térmica, lê-se
  -- aqui o fundo VIVO ao entrar do ponteiro e restaura-se ao sahir. Q.E.D.
  do
    local pre_bg
    cpu_temp:connect_signal("mouse::enter", function()
      pre_bg = cpu_temp.bg
      if type(pre_bg) == "string" and #pre_bg == 7 then
        cpu_temp.bg = pre_bg .. "dd"
      end
      cpu_temp.fg = p.text_bright
      local w = mouse.current_wibox; if w then w.cursor = "hand1" end
    end)
    cpu_temp:connect_signal("mouse::leave", function()
      if pre_bg then cpu_temp.bg = pre_bg end
      local w = mouse.current_wibox; if w then w.cursor = "left_ptr" end
    end)
  end

  -- Selecção final, prescripta por Braga Us: consoante o argumento `widget`,
  -- devolve-se a cápsula da occupação, da temperatura ou da frequência. Se nenhum
  -- caso se verificar, retorna-se o nada (nil) — como manda a boa lógica.
  if widget == "usage" then
    return cpu_usage_widget
  elseif widget == "temp" then
    return cpu_temp
  elseif widget == "freq" then
    return cpu_clock
  end

end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
