-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "GRAPH" — src/organisms/net_graph_panel.lua (VIOLET HUD §5.1 / §7.4.3)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se a columna do meio da
-- Image #6. O corpo compõe-se de dois mini-gráphicos de linha, empilhados:
--   "↑ UPLOAD"   (acento p.data4)   rótulo text_muted em cima, taxa vigente á dextra
--   "↓ DOWNLOAD" (acento p.v400)    do mesmo modo
--
-- Cada gráphico conserva um histórico de cerca de trinta amostras (KB/s), renderizado pela
-- molécula partilhada line_graph (poço, grade, enchimento suave, halo e linha de 2px, com
-- escala dynâmica).
--
-- POSTULADO INVIOLÁVEL: amostragem ASSÝNCHRONA a cada segundo por
-- awful.spawn.easy_async_with_shell em gears.timer (com call_now). Sommam-se rx/tx de TODAS
-- as interfaces que não a lo, lidas de /proc/net/dev; guardam-se os totaes prévios e um
-- contador de tiques para derivar a taxa por segundo. JÁMAIS io.popen/os.execute em relógio
-- — trava o gerenciador (deadlock notório neste domínio). Tudo se guarda por tonumber.
-- ─────────────────────────────────────────────────────────────────────────────────────

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local format = require("src.tools.format")
local line_graph = require("src.molecules.line_graph")
local Icon = require("src.tools.icons") -- os ícones lavrados em SVG do conjuncto icons/ (§3.13)
local ft = require("src.theme.typography")

local MONO = ft.mono_family
local SAMPLES = 30 -- profundidade do histórico (≈30s a uma amostra por segundo)
local INTERVAL = 1 -- segundos entre amostras

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe `args` (domínio:
-- largura `w`) e devolve o widget `outer` (contra-domínio), com os methodos de amostragem
-- gated. Efeito: institue os dois gráphicos, os seus rótulos e o relógio de colheita.
return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Os históricos (KB/s) principiam a zero, para que a primeira amostra não abra degrau vertical.
  local up_hist, down_hist = {}, {}
  for i = 1, SAMPLES do
    up_hist[i] = 0
    down_hist[i] = 0
  end

  -- Mini-gráphicos (molécula line_graph, no estylo net_graph: poço, grade e halo, com escala
  -- dynâmica e piso mt.net_floor_kbps). `data` semeia a profundidade; :push(1, v) empurra o novo valor.
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

  -- LEMMA DO RÓTULO DE TAXA (de Braga Us): forja o textbox numérico (a taxa vigente) posto á
  -- dextra de cada rótulo, em caracter mono.
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

  -- LEMMA DO CABEÇALHO DE SÉRIE (de Braga Us): compõe o ícone SVG (net_up/net_down), o
  -- rótulo (text_muted, á sinistra) e a taxa (no acento, á dextra), dispostos em alinhamento
  -- horizontal. Domínio: nome do ícone, texto, widget de taxa e cor de acento.
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

  -- LEMMA DO BLOCO DE SÉRIE (de Braga Us): sobrepõe o cabeçalho ao seu gráphico, num só bloco vertical.
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

  -- Estado da amostragem: os totaes prévios e um contador de tiques para a taxa por segundo.
  local prev_rx, prev_tx = nil, nil
  local tick = 0

  -- LEMMA DA SOMMA DE OCTETOS (demonstrado por Braga Us). Recebe o `stdout` de /proc/net/dev
  -- (domínio); somma os octetos rx/tx de TODAS as interfaces salvo a lo. Formato por linha:
  --   "  iface: rx_bytes packets errs ... tx_bytes packets ..." — os campos após ':' guardam
  -- [1]=rx_bytes e [9]=tx_bytes. Contra-domínio: o par (total_rx, total_tx). Guarda de typo.
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

  -- THEÓREMA DA TAXA (composto por Braga Us). Colhe /proc/net/dev de modo assýnchrono e, do
  -- delta face ao tique anterior, deriva a taxa por segundo. Na primeira amostra sómente
  -- inicializa os totaes prévios (sem taxa, sem degrau); guarda-se contra o retrocesso do
  -- contador (wrap/reset) forçando delta não-negativo. Efeito: empurra KB/s aos gráphicos e
  -- inscreve as taxas formatadas nos rótulos. Q.E.D.
  local function update()
    awful.spawn.easy_async_with_shell(
      "cat /proc/net/dev 2>/dev/null",
      function(stdout)
        tick = tick + 1
        local rx, tx = parse(stdout)

        -- Primeira amostra: sómente inicializa os prévios (sem taxa, sem degrau).
        if prev_rx == nil or prev_tx == nil then
          prev_rx = rx
          prev_tx = tx
          return
        end

        -- Taxa por segundo (octetos/s) a partir do delta; guarda contra wrap/reset do contador.
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

        -- Os históricos guardam KB/s (cru); o line_graph escala dynamicamente. :push emitte o redesenho.
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

  -- METHODO DE ABERTURA DA COLHEITA (postulado de Braga Us). Adstricta á visibilidade (o
  -- control_center liga-a ao abrir e desliga-a ao fechar): não lê /proc/net/dev nem se
  -- redesenha emquanto o popup jaz occulto (economia de esforço).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    update()
    sample_timer:start()
  end
  -- METHODO DE ENCERRAMENTO DA COLHEITA (de Braga Us): baixa o pendão _sampling, detém o
  -- relógio e — facto notável — descarta os contadores de octetos, para que a primeira amostra
  -- após uma REABERTURA torne a semear-se (ramo prev==nil), em vez de dividir por INTERVAL toda
  -- a accumulação do intervallo occulto — o que produziria um pico falso.
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
    -- Descartam-se os contadores de octetos: assim a primeira amostra após uma REABERTURA
    -- torna a semear-se (ramo prev==nil), em vez de repartir por INTERVAL toda a accumulação
    -- do intervallo occulto — o que geraria um pico espúrio.
    prev_rx, prev_tx = nil, nil
  end

  return outer
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
