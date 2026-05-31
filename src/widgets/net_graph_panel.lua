------------------------------------------------------------------------------------------
-- src/widgets/net_graph_panel.lua — Painel "GRAPH" (VIOLET HUD §5.1 col. meio, §7.4.3)    --
--                                                                                        --
-- Coluna do meio da Image #6. Corpo = dois mini line-graphs empilhados:                  --
--   "↑ UPLOAD"   (acento p.data4)   rótulo text_muted em cima, taxa atual à direita      --
--   "↓ DOWNLOAD" (acento p.v400)    idem                                                 --
--                                                                                        --
-- Cada gráfico mantém um histórico de ~30 amostras (KB/s) desenhado por um               --
-- wibox.widget.base com :draw customizado (linha 2px + fill suave + halo + grid).        --
--                                                                                        --
-- Amostragem ASSÍNCRONA a cada 1s via awful.spawn.easy_async_with_shell em gears.timer   --
-- (call_now). Soma rx/tx de TODAS as interfaces não-lo de /proc/net/dev; guarda prev     --
-- rx/tx + usa um contador de tick p/ derivar taxa por segundo. NUNCA io.popen/os.execute --
-- em timer — trava o WM (deadlock conhecido neste repo). Tudo guardado com tonumber.     --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")

local MONO = "JetBrainsMono Nerd Font"
local SAMPLES = 30 -- profundidade do histórico (≈30s a 1s/amostra)
local INTERVAL = 1 -- segundos entre amostras
local GRAPH_H = dpi(40) -- altura de cada mini-gráfico

-- "#RRGGBB"(+AA) -> r,g,b (0..1). Robusto a nil / formato inesperado.
local function hex_rgb(hex)
  hex = tostring(hex or "#ffffff"):gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  if not (r and g and b) then
    return 1, 1, 1
  end
  return r / 255, g / 255, b / 255
end

-- Formata uma taxa em bytes/s para "x.x U/s" (B/KB/MB/GB).
local function fmt_rate(bps)
  bps = tonumber(bps) or 0
  if bps < 0 then
    bps = 0
  end
  if bps < 1024 then
    return string.format("%.0f B/s", bps)
  end
  local kb = bps / 1024
  if kb < 1024 then
    return string.format("%.1f KB/s", kb)
  end
  local mb = kb / 1024
  if mb < 1024 then
    return string.format("%.1f MB/s", mb)
  end
  return string.format("%.1f GB/s", mb / 1024)
end

-- Cria um mini line-graph desenhado por :draw. `values` = array de KB/s (cru, não %).
-- A escala é dinâmica (relativa ao pico do próprio histórico, com piso) p/ a linha
-- nunca colar no topo/fundo. Retorna o widget (registre p/ redraw no tick).
local function make_graph(values, accent)
  local widget = wibox.widget.base.make_widget()
  local r, g, b = hex_rgb(accent)
  local gr, gg, gb = hex_rgb(p.grid)

  function widget:fit(_, available_width, _)
    return available_width, GRAPH_H
  end

  function widget:draw(_, cr, w, h)
    local inset = dpi(4)
    local x = inset
    local y = inset
    local pw = math.max(1, w - inset * 2)
    local ph = math.max(1, h - inset * 2)

    -- poço (inset) + borda fina do acento
    local ir, ig, ib = hex_rgb(p.inset)
    gears.shape.rounded_rect(cr, w, h, dpi(6))
    cr:set_source_rgba(ir, ig, ib, 0.96)
    cr:fill()
    gears.shape.rounded_rect(cr, w, h, dpi(6))
    cr:set_source_rgba(r, g, b, 0.22)
    cr:set_line_width(dpi(1))
    cr:stroke()

    -- grid horizontal a cada 25% (alterna 0.22 / 0.12) — §7.4.3
    for i = 0, 4 do
      local gy = y + (ph / 4) * i
      cr:set_source_rgba(gr, gg, gb, (i % 2 == 0) and 0.22 or 0.12)
      cr:set_line_width(1)
      cr:move_to(x, gy)
      cr:line_to(x + pw, gy)
      cr:stroke()
    end
    -- grid vertical (accent@0.09/0.04)
    for i = 0, 6 do
      local gx = x + (pw / 6) * i
      cr:set_source_rgba(r, g, b, (i % 2 == 0) and 0.09 or 0.04)
      cr:set_line_width(1)
      cr:move_to(gx, y)
      cr:line_to(gx, y + ph)
      cr:stroke()
    end

    -- escala dinâmica: pico do histórico com piso de 64 KB/s p/ ruído baixo não estourar
    local peak = 64
    for _, v in ipairs(values) do
      local n = tonumber(v) or 0
      if n > peak then
        peak = n
      end
    end

    local count = #values
    if count < 2 then
      return
    end

    local step = pw / math.max(count - 1, 1)
    local points = {}
    for i = 1, count do
      local n = tonumber(values[i]) or 0
      local frac = n / peak
      if frac < 0 then
        frac = 0
      elseif frac > 1 then
        frac = 1
      end
      points[i] = {
        x = x + (i - 1) * step,
        y = y + ph - (ph * frac),
      }
    end

    -- traça uma linha suave (curva de Bézier entre pontos médios)
    local function trace()
      cr:move_to(points[1].x, points[1].y)
      for i = 2, count do
        local prev = points[i - 1]
        local cur = points[i]
        local mid_x = (prev.x + cur.x) / 2
        cr:curve_to(mid_x, prev.y, mid_x, cur.y, cur.x, cur.y)
      end
    end

    -- área (fill suave sob a linha)
    cr:new_path()
    cr:move_to(points[1].x, y + ph)
    cr:line_to(points[1].x, points[1].y)
    trace()
    cr:line_to(points[count].x, y + ph)
    cr:close_path()
    cr:set_source_rgba(r, g, b, 0.24)
    cr:fill()

    -- halo (linha grossa translúcida por baixo)
    cr:new_path()
    trace()
    cr:set_source_rgba(r, g, b, 0.22)
    cr:set_line_width(dpi(6))
    cr:stroke()

    -- linha principal 2px
    cr:new_path()
    trace()
    cr:set_source_rgba(r, g, b, 0.95)
    cr:set_line_width(dpi(2))
    cr:stroke()
  end

  return widget
end

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- históricos (KB/s) inicializados em 0 p/ a 1a amostra não dar degrau vertical
  local up_hist, down_hist = {}, {}
  for i = 1, SAMPLES do
    up_hist[i] = 0
    down_hist[i] = 0
  end

  local up_graph = make_graph(up_hist, p.data4)
  local down_graph = make_graph(down_hist, p.v400)

  -- valor numérico (taxa atual) à direita de cada rótulo
  local function make_rate_label()
    return wibox.widget {
      text = "0 B/s",
      font = MONO .. ", Bold 9",
      align = "right",
      valign = "center",
      widget = wibox.widget.textbox,
    }
  end
  local up_rate = make_rate_label()
  local down_rate = make_rate_label()

  -- cabeçalho de uma série: rótulo (text_muted, esquerda) + taxa (acento, direita)
  local function make_header(label_text, rate_widget, accent)
    return wibox.widget {
      {
        {
          text = label_text,
          font = MONO .. " 9",
          valign = "center",
          widget = wibox.widget.textbox,
        },
        fg = p.text_muted,
        widget = wibox.container.background,
      },
      nil,
      {
        rate_widget,
        fg = accent,
        widget = wibox.container.background,
      },
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    }
  end

  -- bloco de uma série: header + gráfico
  local function make_block(label_text, rate_widget, graph, accent)
    return wibox.widget {
      make_header(label_text, rate_widget, accent),
      graph,
      spacing = dpi(4),
      layout = wibox.layout.fixed.vertical,
    }
  end

  local body = wibox.widget {
    make_block("↑ UPLOAD", up_rate, up_graph, p.data4),
    make_block("↓ DOWNLOAD", down_rate, down_graph, p.v400),
    spacing = dpi(10),
    layout = wibox.layout.fixed.vertical,
  }

  -- estado de amostragem: prev totais + contador de tick p/ taxa por segundo
  local prev_rx, prev_tx = nil, nil
  local tick = 0

  -- empurra um novo valor no fim do histórico (descarta o mais antigo)
  local function push(arr, val)
    table.remove(arr, 1)
    arr[#arr + 1] = (tonumber(val) or 0)
  end

  -- parseia /proc/net/dev: soma rx/tx (bytes) de TODAS as interfaces != lo.
  -- Formato por linha: "  iface: rx_bytes packets errs ... tx_bytes packets ..."
  --   campos após ':' -> [1]=rx_bytes ... [9]=tx_bytes
  local function parse(stdout)
    local total_rx, total_tx = 0, 0
    if type(stdout) ~= "string" then
      return total_rx, total_tx
    end
    for line in stdout:gmatch("[^\r\n]+") do
      local iface, rest = line:match("^%s*([%w%-%._]+):%s*(.+)$")
      if iface and iface ~= "lo" then
        local fields = {}
        for tok in rest:gmatch("%S+") do
          fields[#fields + 1] = tok
        end
        local rx = tonumber(fields[1])
        local tx = tonumber(fields[9])
        if rx then
          total_rx = total_rx + rx
        end
        if tx then
          total_tx = total_tx + tx
        end
      end
    end
    return total_rx, total_tx
  end

  local function update()
    awful.spawn.easy_async_with_shell(
      "cat /proc/net/dev 2>/dev/null",
      function(stdout)
        tick = tick + 1
        local rx, tx = parse(stdout)

        -- 1a amostra: só inicializa os prev (sem taxa, sem degrau).
        if prev_rx == nil or prev_tx == nil then
          prev_rx = rx
          prev_tx = tx
          return
        end

        -- taxa por segundo (bytes/s) a partir do delta; guarda contra wrap/reset.
        local d_rx = rx - prev_rx
        local d_tx = tx - prev_tx
        if d_rx < 0 then
          d_rx = 0
        end
        if d_tx < 0 then
          d_tx = 0
        end
        prev_rx = rx
        prev_tx = tx

        local down_bps = d_rx / INTERVAL
        local up_bps = d_tx / INTERVAL

        -- históricos guardam KB/s (cru); o :draw escala dinamicamente.
        push(up_hist, up_bps / 1024)
        push(down_hist, down_bps / 1024)

        up_rate:set_text(fmt_rate(up_bps))
        down_rate:set_text(fmt_rate(down_bps))

        up_graph:emit_signal("widget::redraw_needed")
        down_graph:emit_signal("widget::redraw_needed")
      end
    )
  end

  gears.timer {
    timeout = INTERVAL,
    autostart = true,
    call_now = true,
    callback = update,
  }

  return panel({
    title = "GRAPH",
    body = body,
    accent = p.v500,
    w = args.w or dpi(260),
  })
end
