------------------------------------------------------------------------------------------
-- src/organisms/monitor_bar.lua — MonitorBar (dock de telemetria inferior, VIOLET HUD §7.3.1) --
--                                                                                          --
-- Barra FIXA no rodapé da tela primária, sempre visível (coexiste com a barra superior e   --
-- os dashboards on-click — não os substitui). Espelha o `MonitorBar` do toolkit            --
-- (ferramentas_para_implementacao/ui_kits/radical-hud/monitorbar.jsx). Composição:         --
--                                                                                          --
--   [ FITA DE TELEMETRIA ] [ GPU ][ CPU ][ MEM ][ NET ] [ MONRAIL ]                        --
--                                                                                          --
-- ARCHITECTURE.md: este arquivo é o organismo `monitor_bar`; os builders locais            --
-- `make_module` (molécula `mon_module`) e `make_rail` (organismo `mon_rail`) seguem o       --
-- estilo de builders-internos de control_center.lua / net_graph_panel.lua. Na migração     --
-- Atomic Design ele será realocado p/ src/organisms/ (e os builders podem virar arquivos).  --
--                                                                                          --
-- Cada MonModule = gráfico de ÁREA atrás (2 séries, cores do módulo) + rótulo grande em     --
-- `Xirod` + sub-label + leitura grande + 4 células de rodapé. MonRail = NODE//STATUS +      --
-- VOLUME (bar meter) + AGGREGATE LOAD (número grande).                                     --
--                                                                                          --
-- Amostragem SEMPRE assíncrona (awful.spawn.easy_async_with_shell num único gears.timer);  --
-- NUNCA io.popen/os.execute/sync — congela o WM (deadlock conhecido neste repo). Todo       --
-- parse de stdout passa por tonumber()/guarda de nil. Fontes inexistentes (nvidia-smi,      --
-- sensores) caem p/ "--" sem quebrar. `Xirod` degrada p/ a fonte padrão se não instalada.   --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local Icon  = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)

local MON_H    = dpi(80)               -- token --mon-h: 80px (§7.3.1)
local SAMPLES  = 40                    -- profundidade do histórico de cada série
local INTERVAL = 1                     -- segundos entre amostras (gráfico vivo)

local XIROD   = ((user_vars.font and user_vars.font.display) or "Xirod") .. " 15" -- rótulo de módulo (marca/display, §4)
local READOUT = "JetBrainsMono Nerd Font ExtraBold 20"  -- leitura grande
local MICRO   = "JetBrainsMono Nerd Font Bold 8"        -- células de rodapé / micro
local SUB     = "JetBrainsMono Nerd Font Bold 9"        -- sub-label

-- ID hex do nó (uma vez no load; os.time é barato e não bloqueia).
local NODE_ID = string.format("0x%04X", os.time() % 0x10000)

-- "#RRGGBB"(+AA) -> r,g,b (0..1). Robusto a nil / formato inesperado.
local function hex_rgb(hex)
  hex = tostring(hex or "#ffffff"):gsub("#", "")
  local r = tonumber(hex:sub(1, 2), 16)
  local g = tonumber(hex:sub(3, 4), 16)
  local b = tonumber(hex:sub(5, 6), 16)
  if not (r and g and b) then return 1, 1, 1 end
  return r / 255, g / 255, b / 255
end

-- array de N zeros (histórico inicial sem degrau)
local function zeros(n)
  local t = {}
  for i = 1, n do t[i] = 0 end
  return t
end

-- empurra um novo valor no fim do histórico (descarta o mais antigo)
local function push(arr, v)
  table.remove(arr, 1)
  arr[#arr + 1] = (tonumber(v) or 0)
end

-- taxa em bytes/s -> rótulo curto com unidade ("0B" / "12K" / "1.2M")
local function fmt_rate(bps)
  bps = tonumber(bps) or 0
  if bps < 0 then bps = 0 end
  if bps >= 1048576 then return string.format("%.1fM", bps / 1048576) end
  if bps >= 1024    then return string.format("%.0fK", bps / 1024) end
  return string.format("%.0fB", bps)
end

-- bytes -> GiB curto ("1.2G")
local function fmt_gib(bytes)
  return string.format("%.1fG", (tonumber(bytes) or 0) / 1073741824)
end

------------------------------------------------------------------------------------------
-- Gráfico de área de fundo: 2 séries sobrepostas (blend), sem grid, alpha baixo p/ o texto
-- por cima continuar legível. `fixed100` = escala fixa 0..100 (séries em %); senão escala
-- dinâmica pelo pico do histórico (taxas de rede). Desenhado por wibox.widget.base:draw.
------------------------------------------------------------------------------------------
local function make_area_graph(histA, colA, histB, colB, fixed100)
  local w = wibox.widget.base.make_widget()
  local ar, ag, ab = hex_rgb(colA)
  local br, bg, bb = hex_rgb(colB)

  function w:fit(_, aw, ah) return aw, ah end

  local function draw_series(cr, vals, r, g, b, x, y, pw, ph)
    local count = #vals
    if count < 2 then return end
    local peak = 1
    if fixed100 then
      peak = 100
    else
      for _, v in ipairs(vals) do
        local n = tonumber(v) or 0
        if n > peak then peak = n end
      end
    end
    local step = pw / math.max(count - 1, 1)
    local pts = {}
    for i = 1, count do
      local n = tonumber(vals[i]) or 0
      local frac = n / peak
      if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
      pts[i] = { x = x + (i - 1) * step, y = y + ph - (ph * frac) }
    end

    local function trace()
      cr:move_to(pts[1].x, pts[1].y)
      for i = 2, count do
        local prev, cur = pts[i - 1], pts[i]
        local mx = (prev.x + cur.x) / 2
        cr:curve_to(mx, prev.y, mx, cur.y, cur.x, cur.y)
      end
    end

    -- área (fill suave sob a linha)
    cr:new_path()
    cr:move_to(pts[1].x, y + ph)
    cr:line_to(pts[1].x, pts[1].y)
    trace()
    cr:line_to(pts[count].x, y + ph)
    cr:close_path()
    cr:set_source_rgba(r, g, b, 0.16)
    cr:fill()
    -- linha fina
    cr:new_path()
    trace()
    cr:set_source_rgba(r, g, b, 0.55)
    cr:set_line_width(dpi(1.4))
    cr:stroke()
  end

  function w:draw(_, cr, width, height)
    local x, y = 0, dpi(2)
    local pw = math.max(1, width)
    local ph = math.max(1, height - dpi(4))
    -- série B (secundária) atrás, série A (primária) na frente
    draw_series(cr, histB, br, bg, bb, x, y, pw, ph)
    draw_series(cr, histA, ar, ag, ab, x, y, pw, ph)
  end

  return w
end

------------------------------------------------------------------------------------------
-- Célula de rodapé: LABEL fixo (micro, muted) em cima + valor (micro, bright) embaixo.
-- Retorna (widget, value_textbox).
------------------------------------------------------------------------------------------
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

------------------------------------------------------------------------------------------
-- MonModule (molécula): cfg = { label, sub, c1, c2, icon, cells = {l1,l2,l3,l4}, fixed100 }.
-- Retorna { widget, ha, hb, graph, set_big, set_alert, set_cells }.
------------------------------------------------------------------------------------------
local function make_module(cfg)
  local ha, hb = zeros(SAMPLES), zeros(SAMPLES)
  local graph  = make_area_graph(ha, cfg.c1, hb, cfg.c2, cfg.fixed100)

  -- leitura grande (direita)
  local readout = wibox.widget {
    text = "--", font = READOUT, align = "right", valign = "center",
    widget = wibox.widget.textbox,
  }
  local readout_bg = wibox.widget { readout, fg = p.text_bright, widget = wibox.container.background }

  -- 4 células de rodapé
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

  -- bloco esquerdo: ícone + rótulo Xirod (grande) + sub-label
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

  -- bloco direito: leitura grande + rodapé
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

  -- gráfico de fundo + conteúdo na frente
  local stack = wibox.widget {
    graph,
    content,
    layout = wibox.layout.stack,
  }

  local frame = wibox.widget {
    stack,
    bg                 = p.a(p.inset, 0.5),
    shape              = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(4)) end,
    shape_border_width = dpi(1),
    shape_border_color = p.line_faint,
    widget             = wibox.container.background,
  }

  return {
    widget = frame,
    ha = ha, hb = hb, graph = graph,
    set_big = function(text, alert)
      readout:set_text(text or "--")
      readout_bg.fg = (alert and alert >= 90) and p.glow_hot or p.text_bright
    end,
    set_cells = function(vals)
      for i = 1, 4 do cells[i]:set_text(vals[i] or "--") end
    end,
  }
end

------------------------------------------------------------------------------------------
-- Fita de telemetria (esquerda): REC piscando + LIVE TELEMETRY + ID hex + NODE STATUS.
-- Retorna (widget). O blink é tocado por um gears.timer interno.
------------------------------------------------------------------------------------------
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

  -- blink do REC (1s): alterna crit <-> dim.
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

------------------------------------------------------------------------------------------
-- MonRail (organismo, direita): NODE // STATUS (ONLINE) + VOLUME (bar meter) + AGGREGATE
-- LOAD (número grande). Retorna { widget, set_vol, set_load }.
------------------------------------------------------------------------------------------
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
      -- NODE // STATUS
      {
        lbl("NODE // STATUS", p.text_muted, SUB),
        lbl("● ONLINE", p.ok, SUB),
        spacing = dpi(2),
        layout  = wibox.layout.fixed.vertical,
      },
      -- VOLUME
      {
        lbl("VOLUME", p.text_muted),
        vol_bar,
        spacing = dpi(3),
        layout  = wibox.layout.fixed.vertical,
      },
      -- AGGREGATE LOAD
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

------------------------------------------------------------------------------------------
return function(s)
  -- Módulos (cores por DESIGN_SYSTEM §7.3.1).
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
    { forced_height = dpi(1), bg = p.line_base, widget = wibox.container.background }, -- baseline topo
    {
      inner,
      left = dpi(8), right = dpi(8), top = dpi(5), bottom = dpi(5),
      widget = wibox.container.margin,
    },
    forced_height = MON_H,
    layout        = wibox.layout.fixed.vertical,
  }
  bar_widget.forced_width = s.geometry.width

  -- Guarda contra duplicata em reload: esconde a barra anterior desta tela.
  if s._monitor_bar then s._monitor_bar.visible = false end

  local bar = awful.popup {
    widget    = bar_widget,
    ontop     = false,
    visible   = true,
    screen    = s,
    bg        = p.a(p.base, 0.8), -- base@cc
    placement = function(c) awful.placement.bottom_left(c, { margins = 0 }) end,
  }
  s._monitor_bar = bar

  -- Reajusta largura/posição se a geometria da tela mudar.
  s:connect_signal("property::geometry", function()
    bar_widget.forced_width = s.geometry.width
    awful.placement.bottom_left(bar, { margins = 0 })
  end)

  ----------------------------------------------------------------------------------------
  -- Estado entre ticks (deltas de CPU e NET) + últimos % p/ AGGREGATE LOAD.
  ----------------------------------------------------------------------------------------
  local prev_cpu_total, prev_cpu_idle = nil, nil
  local prev_rx, prev_tx, prev_net_time = nil, nil, nil
  local last_cpu, last_mem, last_gpu = 0, 0, 0
  local tick = 0

  -- CPU % via /proc/stat (delta busy/idle) -> readout + gráfico A.
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
      push(mod_cpu.ha, r)
      mod_cpu.graph:emit_signal("widget::redraw_needed")
    end)
  end

  -- CPU extras (temp/clk/cores/1m) num único shell; temp atrás de gráfico B.
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
        push(mod_cpu.hb, math.min(100, temp_m / 1000)) -- temp °C ~ 0..100
        mod_cpu.graph:emit_signal("widget::redraw_needed")
      end
    end)
  end

  -- MEM via /proc/meminfo -> readout + células + gráfico (A=use%, B=swap%).
  local function update_mem()
    awful.spawn.easy_async_with_shell("cat /proc/meminfo 2>/dev/null", function(out)
      out = out or ""
      local total = tonumber(out:match("MemTotal:%s*(%d+)"))      -- kB
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
      push(mod_mem.ha, pct)
      push(mod_mem.hb, swap_pct)
      mod_mem.graph:emit_signal("widget::redraw_needed")
    end)
  end

  -- GPU via nvidia-smi (uma chamada, CSV). Fallback "--" se ausente.
  local function update_gpu()
    awful.spawn.easy_async_with_shell(
      "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,clocks.current.graphics,memory.used,memory.total,fan.speed --format=csv,noheader,nounits 2>/dev/null",
      function(out)
        out = out or ""
        -- split por vírgula (preserva posição; campo "[N/A]" vira nil sem deslocar índices)
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
        push(mod_gpu.ha, r)
        if temp then push(mod_gpu.hb, math.min(100, temp)) end
        mod_gpu.graph:emit_signal("widget::redraw_needed")
      end
    )
  end

  -- NET via /proc/net/dev (soma não-lo, taxa por delta) -> readout + células + gráfico.
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
      mod_net.set_big(fmt_rate(down_rate))
      mod_net.set_cells {
        fmt_rate(up_rate),
        fmt_gib(rx_sum),
        fmt_gib(tx_sum),
        (user_vars.network and user_vars.network.ethernet) or "eno1",
      }
      push(mod_net.ha, down_rate / 1024) -- KB/s (escala dinâmica)
      push(mod_net.hb, up_rate / 1024)
      mod_net.graph:emit_signal("widget::redraw_needed")
    end)
  end

  -- VOL via pactl -> bar meter do MonRail.
  local function update_vol()
    awful.spawn.easy_async_with_shell("pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null", function(out)
      out = out or ""
      local v = tonumber(out:match("(%d+)%%"))
      if v then rail.set_vol(v) end
    end)
  end

  -- AGGREGATE LOAD = média de cpu/mem/gpu (atualizada a cada tick).
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
      if tick % 2 == 1 then -- shell mais caros a cada 2s
        update_gpu()
        update_cpu_extra()
        update_vol()
      end
      update_aggregate()
    end,
  }

  return bar
end
