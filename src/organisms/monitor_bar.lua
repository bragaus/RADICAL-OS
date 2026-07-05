-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE A MONITORBAR — DOCA DE TELEMETRIA INFERIOR (VIOLET HUD §7.3.1)
--   src/organisms/monitor_bar.lua
--
--   Seja dada a tela primária: no seu rodapé instale-se esta barra FIXA e
--   sempre patente, que coexiste com a barra superior e com os dashboards de
--   clique — e a nenhum delles substitue. Espelha o `MonitorBar` do toolkit
--   (ferramentas_para_implementacao/ui_kits/radical-hud/monitorbar.jsx). A sua
--   composição, da sinistra á dextra:
--
--     [ FITA DE TELEMETRIA ] [ GPU ][ CPU ][ MEM ][ NET ] [ MONRAIL ]
--
--   NOTA DE ARCHITECTURA: este manuscripto é o organismo `monitor_bar`; os
--   edificadores locaes `make_module` (molécula `mon_module`) e `make_rail`
--   (organismo `mon_rail`) seguem o estylo dos builders-internos de
--   control_center.lua e net_graph_panel.lua — e PERMANECEM internos a este
--   arquivo, não sendo promovidos a módulos próprios.
--
--   Cada MonModule = um gráfico de ÁREA por detrás (duas séries, cores do
--   módulo) + rótulo grande em `Xirod` + sub-rótulo + leitura grande + quatro
--   células de rodapé. O MonRail = NODE//STATUS + VOLUME (bar meter) +
--   AGGREGATE LOAD (número grande).
--
--   POSTULADO DA ASSYNCRONIA: a amostragem é SEMPRE assíncrona (um só
--   gears.timer que invoca awful.spawn.easy_async_with_shell); JÁMAIS
--   io.popen/os.execute/sync, que enregelam o gerente de janellas (deadlock
--   já conhecido neste repositório). Todo o parse de stdout passa por
--   tonumber() e por guarda de nil. Fontes inexistentes (nvidia-smi,
--   sensores) recahem em "--" sem quebra. O `Xirod`, se não instalado,
--   degrada com graça para a fonte padrão.
--
--   Manuscripto da lavra do Doutor Braga Us, Geómetra desta Casa.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local ft    = require("src.theme.typography")
local mt    = require("src.theme.metrics")
local shapes     = require("src.tools.shapes")
local format     = require("src.tools.format")
local line_graph = require("src.molecules.line_graph")
local Icon  = require("src.tools.icons") -- glyphos SVG colhidos do conjuncto icons/ (§3.13)

local MON_H    = dpi(mt.mon_h)         -- altura canónica, do symbolo --mon-h (§7.3.1)
local SAMPLES  = 40                    -- profundidade do histórico de cada série
local INTERVAL = 1                     -- segundos que medeiam entre duas amostras (gráfico vivo)

local XIROD   = ft.display(15)  -- fonte do rótulo de módulo (a de marca/display, §4)
local READOUT = ft.readout      -- fonte da leitura grande
local MICRO   = ft.mon_micro    -- fonte das células de rodapé / do micro-texto
local SUB     = ft.mon_sub      -- fonte do sub-rótulo

-- IDENTIFICADOR HEXADECIMAL do nó, cunhado uma só vez no carregamento (os.time
-- é de custo ínfimo e não bloqueia o systema).
local NODE_ID = string.format("0x%04X", os.time() % 0x10000)

-- ── LEMMA zeros ───────────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que produz um arranjo de N zeros — o
-- histórico inicial de uma série, isento de degrau.
--   DOMÍNIO........: n — a cardinalidade desejada do arranjo.
--   CONTRA-DOMÍNIO.: uma taboa {0, 0, …, 0} de exactamente n elementos.
--   INVARIANTE.....: funcção pura; a cardinalidade do producto iguala n. Q.E.D.
local function zeros(n)
  local t = {}
  for i = 1, n do t[i] = 0 end
  return t
end

-- ── LEMMA fmt_gib ─────────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us para a conversão de octetos á escala dos
-- gibibytes, em fórma abreviada (v.g. "1.2G").
--   DOMÍNIO........: bytes — a grandeza em octetos (número, ou coisa nenhuma).
--   CONTRA-DOMÍNIO.: cadeia textual com uma casa decimal seguida do symbolo G.
--   INVARIANTE.....: argumento não-numérico é tomado por zero (guarda de nil).
local function fmt_gib(bytes)
  return string.format("%.1fG", (tonumber(bytes) or 0) / 1073741824)
end

-- ── LEMMA make_cell ───────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que edifica uma célula de rodapé: em cima
-- o rótulo fixo (micro, esmaecido); embaixo o valor (micro, brilhante).
--   DOMÍNIO........: label — o rótulo fixo da célula.
--   CONTRA-DOMÍNIO.: dois productos — o widget da célula e o textbox do valor,
--                    devolvido este último para que o chamador o possa mutar.
--   EFFEITOS.......: nenhum estado global; sómente compõe widgets.
local function make_cell(label)
  local val = wibox.widget {
    text = "--", font = MICRO, align = "center", valign = "center",
    widget = wibox.widget.textbox,
  }
  local w = wibox.widget {
    {
      { text = label, font = MICRO, align = "center", valign = "center", widget = wibox.widget.textbox },
      fg = p.text_muted, widget = wibox.container.background,
    },
    { val, fg = p.text_bright, widget = wibox.container.background },
    layout = wibox.layout.fixed.vertical,
  }
  return w, val
end

-- ══════════════════════════════════════════════════════════════════════════
-- LEMMA MAIOR make_module — o edificador de um MonModule (a molécula do painel).
-- Como demonstrou o insigne geómetra Braga Us, esta funcção compõe um módulo
-- completo de telemetria a partir da sua configuração.
--   DOMÍNIO........: cfg = { label, sub, c1, c2, icon, cells = {l1,l2,l3,l4},
--                    fixed100 } — os attributos que particularizam o módulo.
--   CONTRA-DOMÍNIO.: taboa { widget, push_a, push_b, set_big, set_cells } — o
--                    widget e os quatro punhos que o chamador manobra.
--   NOTA GEOMÉTRICA: o gráfico de fundo é a molécula line_graph (MonGraph:
--                    gradient_fill e blend "screen"; escala fixa em 0..100
--                    quando fixed100, do contrário dynâmica, própria ás taxas
--                    de rede). As séries dispõem-se {c2 por detrás, c1 na
--                    frente}; donde :push(2,v) alimenta a primária (c1) e
--                    :push(1,v) a secundária (c2).
-- ══════════════════════════════════════════════════════════════════════════
local function make_module(cfg)
  local graph = line_graph({
    series = {
      { color = cfg.c2, data = zeros(SAMPLES) }, -- série B (secundária), por detrás
      { color = cfg.c1, data = zeros(SAMPLES) }, -- série A (primária), na frente
    },
    fill          = true,
    gradient_fill = true,
    blend         = "screen",
    fixed100      = cfg.fixed100,
    grid          = false,
    halo          = false,
    well          = false,
  })

  -- a leitura grande (á dextra)
  local readout = wibox.widget {
    text = "--", font = READOUT, align = "right", valign = "center",
    widget = wibox.widget.textbox,
  }
  local readout_bg = wibox.widget { readout, fg = p.text_bright, widget = wibox.container.background }

  -- as quatro células de rodapé
  local cells, cell_w = {}, {}
  for i = 1, 4 do
    local w, v = make_cell(cfg.cells[i] or "")
    cell_w[i] = w
    cells[i]  = v
  end
  local footer = wibox.widget {
    cell_w[1], cell_w[2], cell_w[3], cell_w[4],
    spacing = dpi(4),
    layout  = wibox.layout.flex.horizontal,
  }

  -- bloco sinistro: ícone + rótulo Xirod (grande) + sub-rótulo
  local left = wibox.widget {
    {
      cfg.icon and Icon(cfg.icon, { size = dpi(16), color = cfg.c1 }) or nil,
      {
        {
          { text = cfg.label, font = XIROD, valign = "center", widget = wibox.widget.textbox },
          fg = p.text_bright, widget = wibox.container.background,
        },
        {
          { text = cfg.sub, font = SUB, valign = "center", widget = wibox.widget.textbox },
          fg = p.text_muted, widget = wibox.container.background,
        },
        layout = wibox.layout.fixed.vertical,
      },
      spacing = dpi(6),
      layout  = wibox.layout.fixed.horizontal,
    },
    valign = "center",
    widget = wibox.container.place,
  }

  -- bloco dextro: leitura grande + rodapé
  local right = wibox.widget {
    { readout_bg, halign = "right", widget = wibox.container.place },
    footer,
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }

  local content = wibox.widget {
    {
      left,
      nil,
      right,
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    },
    margins = dpi(6),
    widget  = wibox.container.margin,
  }

  -- o gráfico ao fundo e o conteúdo sobreposto na frente
  local stack = wibox.widget {
    graph,
    content,
    layout = wibox.layout.stack,
  }

  local frame = wibox.widget {
    stack,
    bg                 = p.a(p.inset, 0.5),
    shape              = shapes.powerline({ tip = dpi(mt.powerline_tip_lg), socket = true }), -- chevron, á feição de .monmod__edge
    shape_border_width = dpi(1),
    shape_border_color = p.line_faint,
    widget             = wibox.container.background,
  }

  return {
    widget = frame,
    push_a = function(v) graph:push(2, v) end, -- alimenta a série primária (c1), na frente
    push_b = function(v) graph:push(1, v) end, -- alimenta a série secundária (c2), ao fundo
    set_big = function(text, alert)
      readout:set_text(text or "--")
      readout_bg.fg = (alert and alert >= mt.pct_hot) and p.glow_hot or p.text_bright
    end,
    set_cells = function(vals)
      for i = 1, 4 do cells[i]:set_text(vals[i] or "--") end
    end,
  }
end

-- ── LEMMA make_strip ──────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que ergue a fita de telemetria (á
-- sinistra): o ponto REC a pulsar + LIVE TELEMETRY + o ID hexadecimal + o
-- estado do nó (NODE STATUS).
--   DOMÍNIO........: nenhum.
--   CONTRA-DOMÍNIO.: o widget da fita.
--   EFFEITOS.......: instala um gears.timer interno que faz pulsar o ponto REC.
local function make_strip()
  local rec_dot = wibox.widget {
    { text = "●", font = SUB, valign = "center", widget = wibox.widget.textbox },
    fg = p.crit, widget = wibox.container.background,
  }
  local function lbl(text, color, font)
    return wibox.widget {
      { text = text, font = font or MICRO, valign = "center", widget = wibox.widget.textbox },
      fg = color, widget = wibox.container.background,
    }
  end

  local w = wibox.widget {
    {
      {
        rec_dot,
        lbl("REC", p.crit, SUB),
        lbl(NODE_ID, p.text_muted),
        spacing = dpi(6),
        layout  = wibox.layout.fixed.horizontal,
      },
      lbl("LIVE TELEMETRY", p.text_heading, SUB),
      lbl("RADICAL-WM // SYSMON", p.text_muted),
      {
        lbl("NODE", p.text_muted),
        lbl("● ONLINE", p.ok),
        spacing = dpi(5),
        layout  = wibox.layout.fixed.horizontal,
      },
      spacing = dpi(2),
      layout  = wibox.layout.fixed.vertical,
    },
    valign = "center",
    widget = wibox.container.place,
  }

  -- pulsação do REC (a cada segundo): alterna entre a cor crítica e a esmaecida.
  local on = true
  gears.timer {
    timeout = 1, autostart = true, call_now = true,
    callback = function()
      on = not on
      rec_dot.fg = on and p.crit or p.a(p.crit, 0.25)
    end,
  }

  return w
end

-- ── LEMMA make_rail ───────────────────────────────────────────────────────
-- Funcção urdida pelo Doutor Braga Us que ergue o MonRail (á dextra): NODE //
-- STATUS (ONLINE) + VOLUME (bar meter) + AGGREGATE LOAD (número grande).
--   DOMÍNIO........: nenhum.
--   CONTRA-DOMÍNIO.: taboa { widget, set_vol, set_load } — o widget e os dois
--                    punhos que ajustam o volume e a carga aggregada.
--   EFFEITOS.......: nenhum estado global; sómente compõe widgets.
local function make_rail()
  local function lbl(text, color, font)
    return wibox.widget {
      { text = text, font = font or MICRO, valign = "center", widget = wibox.widget.textbox },
      fg = color, widget = wibox.container.background,
    }
  end

  local vol_bar = wibox.widget {
    max_value        = 100,
    value            = 0,
    forced_height    = dpi(8),
    forced_width     = dpi(150),
    color            = p.v500,
    background_color = p.inset,
    border_width     = 0,
    bar_shape        = gears.shape.rounded_bar,
    shape            = gears.shape.rounded_bar,
    widget           = wibox.widget.progressbar,
  }

  local load_box = wibox.widget {
    text = "--", font = READOUT, align = "right", valign = "center",
    widget = wibox.widget.textbox,
  }

  local w = wibox.widget {
    {
      -- NODE // STATUS (o estado do nó)
      {
        lbl("NODE // STATUS", p.text_muted, SUB),
        lbl("● ONLINE", p.ok, SUB),
        spacing = dpi(2),
        layout  = wibox.layout.fixed.vertical,
      },
      -- VOLUME (o medidor de volume sonoro)
      {
        lbl("VOLUME", p.text_muted),
        vol_bar,
        spacing = dpi(3),
        layout  = wibox.layout.fixed.vertical,
      },
      -- AGGREGATE LOAD (a carga aggregada)
      {
        lbl("AGGREGATE LOAD", p.text_muted),
        { load_box, fg = p.text_bright, widget = wibox.container.background },
        spacing = dpi(0),
        layout  = wibox.layout.fixed.vertical,
      },
      spacing = dpi(16),
      layout  = wibox.layout.fixed.horizontal,
    },
    valign = "center",
    widget = wibox.container.place,
  }

  return {
    widget   = w,
    set_vol  = function(v) vol_bar.value = math.max(0, math.min(100, tonumber(v) or 0)) end,
    set_load = function(v) load_box:set_text(string.format("%d%%", math.floor((tonumber(v) or 0) + 0.5))) end,
  }
end

-- ══════════════════════════════════════════════════════════════════════════
-- FUNCÇÃO EDIFICADORA do organismo (a peça que este manuscripto restitue).
-- Como demonstrou o insigne geómetra Braga Us, dada uma tela, ergue a barra de
-- telemetria completa e funda o relógio (gears.timer) que a mantém viva.
--   DOMÍNIO........: s — a tela (screen) que hospedará a barra no seu rodapé.
--   CONTRA-DOMÍNIO.: o awful.popup da barra, já visível e ligado á geometria.
--   EFFEITOS.......: guarda-se em s._monitor_bar (previne duplicata em reload);
--                    enlaça-se a property::geometry; funda um gears.timer de
--                    amostragem assíncrona que a cada tick colhe CPU/MEM/NET
--                    (e, a cada dois, GPU/CPU-extras/VOL) e recalcula a carga.
-- ══════════════════════════════════════════════════════════════════════════
return function(s)
  -- os quatro módulos de telemetria (cores por DESIGN_SYSTEM §7.3.1).
  local mod_gpu = make_module {
    label = "GPU", sub = "RTX", icon = "gpu", c1 = p.data1, c2 = p.data4, fixed100 = true,
    cells = { "TEMP", "CLK", "VRAM", "FAN" },
  }
  local mod_cpu = make_module {
    label = "CPU", sub = "AMD", icon = "cpu", c1 = p.glow_core, c2 = p.data2, fixed100 = true,
    cells = { "TEMP", "CLK", "CORES", "1m" },
  }
  local mod_mem = make_module {
    label = "MEM", sub = "MEMORY", icon = "mem", c1 = p.data2, c2 = p.data5, fixed100 = true,
    cells = { "USED", "TOTAL", "SWAP", "CACHE" },
  }
  local mod_net = make_module {
    label = "NET", sub = "WWW", icon = "net", c1 = p.data4, c2 = p.glow_hot, fixed100 = false,
    cells = { "UP", "RX", "TX", "IF" },
  }

  local strip = make_strip()
  local rail  = make_rail()

  local strip_box = wibox.widget {
    strip, forced_width = dpi(220), widget = wibox.container.background,
  }
  local rail_box = wibox.widget {
    rail, forced_width = dpi(300), widget = wibox.container.background,
  }
  local modules_row = wibox.widget {
    mod_gpu.widget, mod_cpu.widget, mod_mem.widget, mod_net.widget,
    spacing = dpi(8),
    layout  = wibox.layout.flex.horizontal,
  }

  local inner = wibox.widget {
    strip_box,
    {
      modules_row,
      left   = dpi(10),
      right  = dpi(10),
      widget = wibox.container.margin,
    },
    rail_box,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  local bar_widget = wibox.widget {
    { forced_height = dpi(1), bg = p.line_base, widget = wibox.container.background }, -- filete de base, ao alto
    {
      inner,
      left = dpi(8), right = dpi(8), top = dpi(5), bottom = dpi(5),
      widget = wibox.container.margin,
    },
    forced_height = MON_H,
    layout        = wibox.layout.fixed.vertical,
  }
  bar_widget.forced_width = s.geometry.width

  -- GUARDA contra duplicata em novo carregamento: occulta-se a barra pretérita desta tela.
  if s._monitor_bar then s._monitor_bar.visible = false end

  local bar = awful.popup {
    widget    = bar_widget,
    ontop     = false,
    visible   = true,
    screen    = s,
    bg        = p.a(p.base, 0.8), -- a cor base com opacidade @cc
    placement = function(c) awful.placement.bottom_left(c, { margins = 0 }) end,
  }
  s._monitor_bar = bar

  -- REAJUSTA a largura e a posição sempre que a geometria da tela se altere.
  s:connect_signal("property::geometry", function()
    bar_widget.forced_width = s.geometry.width
    awful.placement.bottom_left(bar, { margins = 0 })
  end)

  -- ── ESTADO PERSISTENTE entre ticks ─────────────────────────────────────────
  -- Grandezas conservadas de um tick ao seguinte (os deltas de CPU e de NET),
  -- e as últimas percentagens colhidas, de que se serve o AGGREGATE LOAD.
  local prev_cpu_total, prev_cpu_idle = nil, nil
  local prev_rx, prev_tx, prev_net_time = nil, nil, nil
  local last_cpu, last_mem, last_gpu = 0, 0, 0
  local tick = 0

  -- ── COROLLÁRIO update_cpu ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que apura a percentagem de CPU por meio
  -- de /proc/stat (o delta entre o tempo occupado e o ocioso).
  --   DOMÍNIO........: nenhum (lê do systema e da clausura dos prev_cpu_*).
  --   CONTRA-DOMÍNIO.: nada — labora por effeito, alimentando a leitura e o
  --                    gráfico A do módulo CPU, e conservando last_cpu.
  --   NOTA...........: a colheita é assíncrona; a percentagem é constrangida ao
  --                    intervallo [0, 100].
  local function update_cpu()
    awful.spawn.easy_async_with_shell("cat /proc/stat 2>/dev/null | head -n 1", function(out)
      out = out or ""
      local nums = {}
      for tok in out:gmatch("%d+") do nums[#nums + 1] = tonumber(tok) end
      if #nums < 4 then return end
      local idle = (nums[4] or 0) + (nums[5] or 0)
      local total = 0
      for i = 1, #nums do total = total + (nums[i] or 0) end
      local pct = 0
      if prev_cpu_total and prev_cpu_idle then
        local dt, di = total - prev_cpu_total, idle - prev_cpu_idle
        if dt > 0 then pct = (dt - di) / dt * 100 end
      end
      prev_cpu_total, prev_cpu_idle = total, idle
      if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
      local r = math.floor(pct + 0.5)
      last_cpu = r
      mod_cpu.set_big(string.format("%d%%", r), r)
      mod_cpu.push_a(r)
    end)
  end

  -- ── COROLLÁRIO update_cpu_extra ─────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que colhe os predicados accessórios do
  -- CPU (temperatura, frequência, número de núcleos e carga de 1 minuto) num
  -- único invólucro de shell.
  --   DOMÍNIO........: nenhum.
  --   CONTRA-DOMÍNIO.: nada — por effeito, povoa as quatro células do módulo
  --                    CPU e faz a temperatura alimentar o gráfico B.
  local function update_cpu_extra()
    local script = [[
      T=--; for h in /sys/class/hwmon/hwmon*; do n=$(cat "$h/name" 2>/dev/null); case "$n" in
        k10temp|zenpower|coretemp) T=$(cat "$h/temp1_input" 2>/dev/null); break;; esac; done
      echo "TEMP:$T"
      echo "MHZ:$(awk '/cpu MHz/{s+=$4;n++} END{if(n>0)printf "%.0f", s/n}' /proc/cpuinfo 2>/dev/null)"
      echo "CORES:$(nproc 2>/dev/null)"
      echo "LOAD:$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)"
    ]]
    awful.spawn.easy_async_with_shell(script, function(out)
      out = out or ""
      local temp_m = tonumber(out:match("TEMP:(%d+)"))
      local mhz    = tonumber(out:match("MHZ:(%d+)"))
      local cores  = tonumber(out:match("CORES:(%d+)"))
      local load1  = tonumber(out:match("LOAD:([%d%.]+)"))
      local tc = temp_m and string.format("%d°", math.floor(temp_m / 1000 + 0.5)) or "--"
      mod_cpu.set_cells {
        tc,
        mhz and string.format("%.1fG", mhz / 1000) or "--",
        cores and tostring(cores) or "--",
        load1 and string.format("%.2f", load1) or "--",
      }
      if temp_m then
        mod_cpu.push_b(math.min(100, temp_m / 1000)) -- temperatura em graus centígrados, no intervallo ~0..100
      end
    end)
  end

  -- ── COROLLÁRIO update_mem ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que afere a memória por /proc/meminfo.
  --   DOMÍNIO........: nenhum.
  --   CONTRA-DOMÍNIO.: nada — por effeito, alimenta a leitura, as células e o
  --                    gráfico do módulo MEM (série A = uso %, série B = swap %).
  --   INVARIANTE.....: abstem-se se faltarem MemTotal/MemAvailable ou se o total
  --                    não for positivo (guarda contra a divisão por zero).
  local function update_mem()
    awful.spawn.easy_async_with_shell("cat /proc/meminfo 2>/dev/null", function(out)
      out = out or ""
      local total = tonumber(out:match("MemTotal:%s*(%d+)"))      -- em kibibytes
      local avail = tonumber(out:match("MemAvailable:%s*(%d+)"))
      local cached = tonumber(out:match("\nCached:%s*(%d+)")) or tonumber(out:match("^Cached:%s*(%d+)"))
      local sw_t = tonumber(out:match("SwapTotal:%s*(%d+)"))
      local sw_f = tonumber(out:match("SwapFree:%s*(%d+)"))
      if not total or not avail or total <= 0 then return end
      local used = total - avail
      if used < 0 then used = 0 end
      local pct = math.floor(used / total * 100 + 0.5)
      last_mem = pct
      local swap_pct = 0
      if sw_t and sw_f and sw_t > 0 then swap_pct = math.floor((sw_t - sw_f) / sw_t * 100 + 0.5) end
      mod_mem.set_big(string.format("%d%%", pct), pct)
      mod_mem.set_cells {
        fmt_gib(used * 1024),
        fmt_gib(total * 1024),
        string.format("%d%%", swap_pct),
        cached and fmt_gib(cached * 1024) or "--",
      }
      mod_mem.push_a(pct)
      mod_mem.push_b(swap_pct)
    end)
  end

  -- ── COROLLÁRIO update_gpu ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que interroga a placa gráphica por meio
  -- de nvidia-smi (uma só chamada, em fórma CSV).
  --   DOMÍNIO........: nenhum.
  --   CONTRA-DOMÍNIO.: nada — por effeito, alimenta a leitura, as células e o
  --                    gráfico do módulo GPU.
  --   GUARDA.........: faltando o apparato (nvidia-smi ausente), tudo recahe em
  --                    "--" sem quebra alguma.
  local function update_gpu()
    awful.spawn.easy_async_with_shell(
      "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,clocks.current.graphics,memory.used,memory.total,fan.speed --format=csv,noheader,nounits 2>/dev/null",
      function(out)
        out = out or ""
        -- partição por vírgula (preserva a posição; o campo "[N/A]" torna-se nil sem deslocar os índices)
        local f, i = {}, 0
        for tok in out:gmatch("[^,]+") do
          i = i + 1
          f[i] = tonumber(tok:match("[%d%.]+"))
        end
        if not f[1] then
          mod_gpu.set_big("--")
          mod_gpu.set_cells { "--", "--", "--", "--" }
          return
        end
        local util  = f[1] or 0
        local temp  = f[2]
        local clk   = f[3]
        local mused = f[4]
        local mtot  = f[5]
        local fan   = f[6]
        if util < 0 then util = 0 elseif util > 100 then util = 100 end
        local r = math.floor(util + 0.5)
        last_gpu = r
        mod_gpu.set_big(string.format("%d%%", r), r)
        mod_gpu.set_cells {
          temp and string.format("%d°", math.floor(temp + 0.5)) or "--",
          clk and string.format("%d", math.floor(clk + 0.5)) or "--",
          (mused and mtot and mtot > 0) and string.format("%.1fG", mused / 1024) or "--",
          fan and string.format("%d%%", math.floor(fan + 0.5)) or "--",
        }
        mod_gpu.push_a(r)
        if temp then mod_gpu.push_b(math.min(100, temp)) end
      end
    )
  end

  -- ── COROLLÁRIO update_net ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que mede a rede por /proc/net/dev,
  -- sommando todas as interfaces excepto a de loopback (lo) e derivando a taxa
  -- do delta entre duas amostras.
  --   DOMÍNIO........: nenhum.
  --   CONTRA-DOMÍNIO.: nada — por effeito, alimenta a leitura, as células e o
  --                    gráfico do módulo NET.
  local function update_net()
    awful.spawn.easy_async_with_shell("cat /proc/net/dev 2>/dev/null", function(out)
      out = out or ""
      local rx_sum, tx_sum = 0, 0
      for line in out:gmatch("[^\r\n]+") do
        local iface, rest = line:match("^%s*([%w%-%._]+):%s*(.+)$")
        if iface and iface ~= "lo" and rest then
          local fields = {}
          for tok in rest:gmatch("%S+") do fields[#fields + 1] = tonumber(tok) end
          if fields[1] then rx_sum = rx_sum + fields[1] end
          if fields[9] then tx_sum = tx_sum + fields[9] end
        end
      end
      local now = os.time()
      local up_rate, down_rate = 0, 0
      if prev_rx and prev_tx and prev_net_time then
        local dt = now - prev_net_time
        if dt <= 0 then dt = INTERVAL end
        local d_rx, d_tx = rx_sum - prev_rx, tx_sum - prev_tx
        if d_rx < 0 then d_rx = 0 end
        if d_tx < 0 then d_tx = 0 end
        down_rate = d_rx / dt
        up_rate   = d_tx / dt
      end
      prev_rx, prev_tx, prev_net_time = rx_sum, tx_sum, now
      mod_net.set_big(format.rate(down_rate, "compact"))
      mod_net.set_cells {
        format.rate(up_rate, "compact"),
        fmt_gib(rx_sum),
        fmt_gib(tx_sum),
        (user_vars.network and user_vars.network.ethernet) or "eno1",
      }
      mod_net.push_a(down_rate / 1024) -- em kibibytes por segundo (escala dynâmica)
      mod_net.push_b(up_rate / 1024)
    end)
  end

  -- ── COROLLÁRIO update_vol ───────────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que interroga o volume sonoro por pactl.
  --   DOMÍNIO........: nenhum.
  --   CONTRA-DOMÍNIO.: nada — por effeito, ajusta o bar meter do MonRail.
  local function update_vol()
    awful.spawn.easy_async_with_shell("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null", function(out)
      out = out or ""
      local v = tonumber(out:match("(%d+)%%"))
      if v then rail.set_vol(v) end
    end)
  end

  -- ── COROLLÁRIO update_aggregate ─────────────────────────────────────────────
  -- Funcção urdida pelo Doutor Braga Us que compõe a carga aggregada, tomada
  -- por média arithmética das últimas percentagens de cpu, mem e gpu.
  --   DOMÍNIO........: nenhum (lê last_cpu, last_mem, last_gpu da clausura).
  --   CONTRA-DOMÍNIO.: nada — por effeito, ajusta a carga exhibida no MonRail.
  --   INVARIANTE.....: recalculada a cada tick do relógio.
  local function update_aggregate()
    rail.set_load((last_cpu + last_mem + last_gpu) / 3)
  end

  gears.timer {
    timeout   = INTERVAL,
    call_now  = true,
    autostart = true,
    callback  = function()
      tick = tick + 1
      update_cpu()
      update_mem()
      update_net()
      if tick % 2 == 1 then -- os invólucros de shell mais custosos, a cada dois segundos
        update_gpu()
        update_cpu_extra()
        update_vol()
      end
      update_aggregate()
    end,
  }

  return bar
end
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
