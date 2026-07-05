------------------------------------------------------------------------------------------
-- src/organisms/net_graph_panel.lua — Painel "GRAPH" (VIOLET HUD §5.1 col. meio, §7.4.3)    --
--                                                                                        --
-- Coluna do meio da Image #6. Corpo = dois mini line-graphs empilhados:                  --
--   "↑ UPLOAD"   (acento p.data4)   rótulo text_muted em cima, taxa atual à direita      --
--   "↓ DOWNLOAD" (acento p.v400)    idem                                                 --
--                                                                                        --
-- Cada gráfico mantém um histórico de ~30 amostras (KB/s) renderizado pela molécula       --
-- compartilhada line_graph (well + grid + fill suave + halo + linha 2px, escala dinâmica).--
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
local mt = require("src.theme.metrics")
local format = require("src.tools.format")
local line_graph = require("src.molecules.line_graph")
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)
local ft = require("src.theme.typography")

local MONO = ft.mono_family
local SAMPLES = 30 -- profundidade do histórico (≈30s a 1s/amostra)
local INTERVAL = 1 -- segundos entre amostras

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- históricos (KB/s) inicializados em 0 p/ a 1a amostra não dar degrau vertical
  local up_hist, down_hist = {}, {}
  for i = 1, SAMPLES do
    up_hist[i] = 0
    down_hist[i] = 0
  end

  -- Mini line-graphs (molécula line_graph, estilo net_graph: well + grid + halo, escala
  -- dinâmica com piso mt.net_floor_kbps). `data` semeia a profundidade; :push(1, v) empurra.
  local up_graph = line_graph({
    series = { { color = p.data4, data = up_hist } },
    grid = true,
    halo = true,
    well = true,
    floor = mt.net_floor_kbps,
  })
  local down_graph = line_graph({
    series = { { color = p.v400, data = down_hist } },
    grid = true,
    halo = true,
    well = true,
    floor = mt.net_floor_kbps,
  })

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

  -- cabeçalho de uma série: ícone SVG (net_up/net_down) + rótulo (text_muted, esquerda)
  -- + taxa (acento, direita).
  local function make_header(icon_name, label_text, rate_widget, accent)
    return wibox.widget {
      {
        Icon(icon_name, { size = dpi(12), color = accent }),
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
        spacing = dpi(5),
        layout = wibox.layout.fixed.horizontal,
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
  local function make_block(icon_name, label_text, rate_widget, graph, accent)
    return wibox.widget {
      make_header(icon_name, label_text, rate_widget, accent),
      graph,
      spacing = dpi(4),
      layout = wibox.layout.fixed.vertical,
    }
  end

  local body = wibox.widget {
    make_block("net_up", "UPLOAD", up_rate, up_graph, p.data4),
    make_block("net_down", "DOWNLOAD", down_rate, down_graph, p.v400),
    spacing = dpi(10),
    layout = wibox.layout.fixed.vertical,
  }

  -- estado de amostragem: prev totais + contador de tick p/ taxa por segundo
  local prev_rx, prev_tx = nil, nil
  local tick = 0

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

        -- históricos guardam KB/s (cru); o line_graph escala dinamicamente. :push emite redraw.
        up_graph:push(1, up_bps / 1024)
        down_graph:push(1, down_bps / 1024)

        up_rate:set_text(format.rate(up_bps))
        down_rate:set_text(format.rate(down_bps))
      end
    )
  end

  local sample_timer = gears.timer {
    timeout = INTERVAL,
    autostart = false,
    call_now = false,
    callback = update,
  }

  local outer = panel({
    title = "GRAPH",
    body = body,
    accent = p.v500,
    w = args.w or dpi(260),
    right_icon = Icon("net", { size = dpi(14), color = p.text_muted }),
  })

  -- Sampling gated por visibilidade (control_center liga ao abrir / desliga ao fechar o
  -- dashboard): não lê /proc/net/dev nem redesenha enquanto o popup está oculto (perf).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    update()
    sample_timer:start()
  end
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
    -- Drop the byte counters so the first sample after a REOPEN re-seeds (prev==nil branch)
    -- instead of dividing a whole hidden-gap's accumulated bytes by INTERVAL -> false spike.
    prev_rx, prev_tx = nil, nil
  end

  return outer
end
