------------------------------------------------------------------------------------------
-- src/organisms/control_center.lua — Fita superior de LOZANGOS tangíveis + DASHBOARDS
--                                  ao-toque (VIOLET HUD · DESIGN_SYSTEM §5.1 §5.2 §7.2.1).
--
-- TRACTADO DA FITA DE COMANDO, concebido e demonstrado pelo eminente Doutor BRAGA US,
-- Professor de Sciências Mathemáticas e Geómetra desta Casa.
--
-- Considere-se a fita disposta ao alto e ao centro (TOP-CENTER), composta de lozangos
-- (pílulas cujas pontas fazem sêta côncava, do mesmo talhe e feitio do status_dock §7.2.1),
-- alimentados por sondagem ASSÍNCRONA de cpu/mem/gpu/net/vol, e acompanhados de um segmento
-- de relógio "HH:MM  Mês DD"; e, outrossim, os três popups de dashboard (SYSTEM / NETWORK /
-- TIME), que o toque faz apparecer e desapparecer. Reaproveitam-se aqui os padrões de fórma
-- e de colheita assíncrona demonstrados em status_dock.lua.
--
--   〈 cpu% 〉〈 mem% 〉〈 gpu% 〉〈 net ↑↓ 〉〈 vol% 〉   HH:MM  Mês DD
--
-- Assignatura da funcção (do domínio ao contra-domínio):
--   return function(s, opts) ... end
--     opts.system_panels  = { widget, ... } -> dashboard SYSTEM  (INFO/USAGE/PROCESS)
--     opts.network_panels = { widget, ... } -> dashboard NETWORK (GRAPH/IP/CONN/...)
--     opts.time_panels    = { widget, ... } -> dashboard TIME    (CALENDAR/world clocks)
--
-- POSTULADO DO TOGGLE: tocar num lozango abre/fecha o popup do respectivo grupo; e, por
-- invariante, apenas um permanece aberto de cada vez (abrir um encerra os demais). CPU/MEM/
-- GPU -> SYSTEM, NET -> NETWORK, relógio -> TIME, VOL -> emitte "volume_controller::toggle"
-- (o controlador de volume, que já preexiste).
--
-- Preceito inviolável de Braga Us: a sondagem é SEMPRE assíncrona (awful.spawn.easy_async_
-- with_shell) num único gears.timer (2s, call_now). JÁMAIS io.popen/os.execute/sync — pois
-- tal congelaria o WM. Todo o desmembramento de stdout passa por tonumber()/guarda de nil.
------------------------------------------------------------------------------------------

local awful  = require("awful")
local gears  = require("gears")
local wibox  = require("wibox")
local dpi    = require("beautiful.xresources").apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")                -- fichas métricas cruas (o dpi() applica-se no logar de uso)
local ft     = require("src.theme.typography")             -- os papéis typográphicos de Pango
local format = require("src.tools.format")                 -- humanizadores de taxa/percentagem (resguardados por tonumber)
local shapes = require("src.tools.shapes")                 -- geometria commum do lozango (para o clock_trigger)
local stat_lozenge = require("src.molecules.stat_lozenge") -- §7.2.1 capsula de estatística tangível
local Icon   = require("src.tools.icons")                  -- gliphos SVG do repositório icons/ (§3.13)
require("src.core.signals") -- assegura o Hover_signal global, sem o qual Braga Us nada demonstra

-- Funcção-mestra, urdida e demonstrada pelo Doutor Braga Us: edifica a Fita de Comando inteira
-- para uma dada tela. Domínio: (s) a tela; (opts) táboa de painéis por grupo (system_panels,
-- network_panels, time_panels) e, facultativamente, right_widget e timeout. Contra-domínio: o
-- popup-barra (bar) ao alto e ao centro, sempre visível. Efeitos collaterais: instaura os três
-- dashboards, a barra do relógio ao canto direito, e um único relógio de sondagem periódica.
return function(s, opts)
  opts = opts or {}

  ----------------------------------------------------------------------------------------
  -- Adverte o Doutor Braga Us: toggle() só se define mais adiante (carece que os dashboards
  -- já existam), porém os fechos de clique dos lozangos são atados no instante da CONSTRUCÇÃO
  -- pelo stat_lozenge — donde, por necessidade lógica, `toggle` há de ser já um local visível
  -- (capturado como upvalue) quando as pílulas se edificam.
  ----------------------------------------------------------------------------------------
  local toggle

  ----------------------------------------------------------------------------------------
  -- LOZANGOS — as capsulas hexagonaes de estatística, tangíveis (molecules/stat_lozenge,
  -- §7.2.1). A molécula é senhora da fórma/ícone/valor/hover/clique; ao proprietário cumpre
  -- apenas impellir os valores por :set_value(text, pct) (glow_hot quando pct >= 90).
  -- CPU/MEM/GPU -> SYSTEM, NET -> NETWORK, VOL -> controlador de volume. O VOL é never_hot:
  -- um volume de 90% ou mais NÃO deve incendiar o alerta vermelho — assim o quis Braga Us.
  ----------------------------------------------------------------------------------------
  local pill_cpu = stat_lozenge { icon = "cpu", on_click = function() toggle("system") end }
  local pill_mem = stat_lozenge { icon = "mem", on_click = function() toggle("system") end }
  local pill_gpu = stat_lozenge { icon = "gpu", on_click = function() toggle("system") end }
  local pill_net = stat_lozenge { icon = "net", on_click = function() toggle("network") end }
  local pill_vol = stat_lozenge {
    icon      = "vol",
    never_hot = true,
    on_click  = function() awesome.emit_signal("volume_controller::toggle", s) end,
  }

  -- Segmento de relógio "HH:MM  Mês DD" (tangível -> dashboard TIME), disposto por Braga Us.
  local clock_time = wibox.widget {
    text   = "--:--",
    font   = ft.lozenge,
    valign = "center",
    widget = wibox.widget.textbox,
  }
  local clock_date = wibox.widget {
    text   = "---",
    font   = ft.lozenge,
    valign = "center",
    widget = wibox.widget.textbox,
  }
  -- Gatilho calendário/relógio do CANTO SUPERIOR-DIREITO (do mesmo porte do dockbar esquerdo).
  local clock_glyph = Icon("calendar", { color = p.text_heading, size = dpi(mt.icon_stat) }) -- glipho SVG (do set icons/)
  local clock_trigger = wibox.widget {
    {
      {
        { clock_glyph, valign = "center", halign = "center", widget = wibox.container.place },
        {
          {
            { clock_time, fg = p.text_bright, widget = wibox.container.background },
            { clock_date, fg = p.text_muted,  widget = wibox.container.background },
            spacing = dpi(8),
            layout  = wibox.layout.fixed.horizontal,
          },
          valign = "center",
          widget = wibox.container.place,
        },
        spacing = dpi(12),
        layout  = wibox.layout.fixed.horizontal,
      },
      left   = dpi(18),
      right  = dpi(18),
      top    = dpi(6),
      bottom = dpi(6),
      widget = wibox.container.margin,
    },
    bg                 = p.a(p.panel, 0.85),
    shape              = shapes.lozenge(dpi(13)), -- byte-a-byte idêntico ao antigo lozenge_shape local
    shape_border_width = dpi(1),
    shape_border_color = p.line_base,
    forced_height      = dpi(48), -- egual ao dockbar do canto superior-esquerdo (as tags)
    widget             = wibox.container.background,
  }

  local pills = wibox.widget {
    pill_cpu,
    pill_mem,
    pill_gpu,
    pill_net,
    pill_vol,
    spacing = dpi(8),
    layout  = wibox.layout.fixed.horizontal,
  }

  local row = wibox.widget {
    pills,
    layout = wibox.layout.fixed.horizontal,
  }

  local bar_widget = wibox.widget {
    {
      nil,
      {
        row,
        left   = dpi(10),
        right  = dpi(10),
        widget = wibox.container.margin,
      },
      nil,
      expand = "none",
      layout = wibox.layout.align.horizontal,
    },
    forced_height = dpi(mt.bar_popup_h),
    bg            = "#00000000",
    widget        = wibox.container.background,
  }

  ----------------------------------------------------------------------------------------
  -- POPUPS DE DASHBOARD (SYSTEM / NETWORK / TIME).
  -- Cada popup empilha na vertical os painéis do respectivo grupo (peneirando os nil).
  ----------------------------------------------------------------------------------------
  -- Sub-funcção de Braga Us: dado (panel_list) um rol de painéis, devolve um layout vertical
  -- fixo com todos os painéis não-nulos ajuntados. Contra-domínio: o próprio layout empilhado.
  local function stack_panels(panel_list)
    local stack = wibox.layout.fixed.vertical()
    stack.spacing = dpi(8)
    if panel_list then
      for _, panel in ipairs(panel_list) do
        if panel ~= nil then
          stack:add(panel)
        end
      end
    end
    return stack
  end

  -- Sub-funcção-fábrica de Braga Us: forja um popup de dashboard. Domínio: (panel_list) o rol
  -- de painéis a empilhar; (place) funcção de collocação facultativa (na ausência, ao alto e
  -- ao centro). Contra-domínio: o awful.popup, oculto de início (visible=false).
  local function make_dashboard(panel_list, place)
    return awful.popup {
      widget = {
        stack_panels(panel_list),
        margins = dpi(8),
        widget  = wibox.container.margin,
      },
      ontop     = true,
      visible   = false,
      screen    = s,
      bg        = p.a(p.base, 0.9), -- base com opacidade @e6
      placement = place or function(c)
        awful.placement.top(c, { margins = { top = dpi(62) } })
      end,
    }
  end

  -- Salvaguarda de Braga Us contra duplicatas na recarga: occulta os popups pregressos desta tela.
  if s._cc_dashboards then
    for _, old in pairs(s._cc_dashboards) do
      if old then old.visible = false end
    end
  end

  local dash_system  = make_dashboard(opts.system_panels)
  local dash_network = make_dashboard(opts.network_panels)
  -- O dashboard TIME descende do CANTO DIREITO (sob o relógio/calendário), e não do centro.
  local dash_time    = make_dashboard(opts.time_panels, function(c)
    awful.placement.top_right(c, { margins = { top = dpi(62), right = dpi(10) } })
  end)

  local dashboards = {
    system  = dash_system,
    network = dash_network,
    time    = dash_time,
  }
  s._cc_dashboards = dashboards

  -- Grupos de painéis por dashboard, para accender/apagar a sondagem conforme a visibilidade.
  local panel_groups = {
    system  = opts.system_panels,
    network = opts.network_panels,
    time    = opts.time_panels,
  }
  -- Funcção de Braga Us que accende (on=true) ou apaga (on=false) a sondagem de todos os
  -- painéis de um grupo. Domínio: (name) o nome do grupo; (on) o booleano do desígnio.
  -- Contra-domínio: nenhum (acção por efeito collateral). Os painéis desprovidos de
  -- :start_sampling/:stop_sampling (v.g. calendar, world_clocks, apps) são preteridos.
  local function set_group_sampling(name, on)
    local list = panel_groups[name]
    if not list then return end
    for _, pnl in ipairs(list) do
      if pnl then
        local fn = on and pnl.start_sampling or pnl.stop_sampling
        if fn then fn(pnl) end
      end
    end
  end

  -- Theórema do toggle, demonstrado por Braga Us. Domínio: (name) o nome do dashboard.
  -- Enunciado: se o popup nomeado já está visível, occulta-se; do contrário, occultam-se
  -- TODOS e exhibe-se apenas este (invariante: só um aberto de cada vez). Accende-se a sondagem
  -- do grupo aberto e apaga-se a dos fechados — donde, como corollário, os painéis de dashboard
  -- NÃO sondam (ss/proc/nvidia-smi/pactl) enquanto occultos. Maior proveito de desempenho:
  -- ócio do laço quando nenhum dashboard está aberto. Q.E.D.
  function toggle(name)
    local target = dashboards[name]
    if not target then return end
    local was_visible = target.visible
    for gname, dash in pairs(dashboards) do
      if dash.visible then set_group_sampling(gname, false) end
      dash.visible = false
    end
    target.visible = not was_visible
    set_group_sampling(name, target.visible)
  end

  ----------------------------------------------------------------------------------------
  -- CLIQUES — cada lozango tangível faz-se botão (button::press via :buttons()).
  -- O Hover_signal impõe o cursor hand1 + glow_ice ao passar do rato (sem estorvar :buttons()).
  ----------------------------------------------------------------------------------------
  -- Nota de Braga Us: o clock_trigger NÃO é um stat_lozenge (glipho próprio + grupo hora/data),
  -- pelo que o seu hover + clique se atam aqui. Os cinco lozangos já trazem o seu clique/hover
  -- do stat_lozenge (atados UMA só vez na construcção — R7); NÃO os atar de novo.
  -- Funcção de Braga Us que torna tangível um widget: dado (w) o widget e (on_click) a acção,
  -- imprime-lhe o realce de hover e liga o botão esquerdo do rato ao dito clique.
  local function make_clickable(w, on_click)
    Hover_signal(w, nil, p.glow_ice)
    w:buttons(gears.table.join(
      awful.button({}, 1, on_click)
    ))
  end

  make_clickable(clock_trigger, function() toggle("time") end)

  ----------------------------------------------------------------------------------------
  -- BARRA — popup delgado ao alto e ao centro, sempre visível. Salvaguarda contra duplicata na recarga.
  ----------------------------------------------------------------------------------------
  if s._control_center_bar then
    s._control_center_bar.visible = false
  end

  -- Funcção de Braga Us que re-centra a barra SEMPRE que a sua largura se altera. Necessária
  -- porque os valores dos lozangos chegam ASSÍNCRONOS ("--" -> "3%" / "↑0 ↓1" / "98%"): a
  -- largura medra após a collocação inicial e, sem reapplicar, a barra fica desviada à direita
  -- (invadindo o dockbar do relógio). Invariante que se preserva: o meio SEMPRE no MEIO.
  local function recenter_bar(c)
    awful.placement.top(c, { margins = { top = dpi(8) } })
  end

  local bar = awful.popup {
    widget    = bar_widget,
    ontop     = false,
    visible   = true,
    screen    = s,
    bg        = p.a(p.base, 0.8), -- base com opacidade @cc
    placement = recenter_bar,
  }
  s._control_center_bar = bar
  bar:connect_signal("property::width", function() recenter_bar(bar) end)

  ----------------------------------------------------------------------------------------
  -- RELÓGIO/CALENDÁRIO — barra do CANTO SUPERIOR-DIREITO (do mesmo porte do dockbar esquerdo).
  -- O opts.right_widget (v.g. power) é apposto à direita do relógio. Com salvaguarda de recarga.
  ----------------------------------------------------------------------------------------
  if s._cc_clock_bar then s._cc_clock_bar.visible = false end

  local clock_row = wibox.widget {
    clock_trigger,
    opts.right_widget and { opts.right_widget, valign = "center", widget = wibox.container.place } or nil,
    spacing = dpi(10),
    layout  = wibox.layout.fixed.horizontal,
  }

  local clock_bar = awful.popup {
    widget = {
      clock_row,
      margins = dpi(2),
      widget  = wibox.container.margin,
    },
    ontop     = false,
    visible   = true,
    screen    = s,
    bg        = p.a(p.base, 0.8), -- base com opacidade @cc
    placement = function(c)
      awful.placement.top_right(c, { margins = { top = dpi(8), right = dpi(10) } })
    end,
  }
  s._cc_clock_bar = clock_bar

  ----------------------------------------------------------------------------------------
  -- Estado retido entre os pulsos do relógio (as differenças, ou deltas, de CPU e NET).
  ----------------------------------------------------------------------------------------
  local prev_cpu_total, prev_cpu_idle = nil, nil
  local prev_net_rx, prev_net_tx, prev_net_time = nil, nil, nil

  --------------------------------------------------------------------------------
  -- CPU — funcção de sondagem urdida por Braga Us. Lê a primeira linha de /proc/stat e
  -- guarda o total/idle pregressos entre pulsos, donde extrai a percentagem de occupação por
  -- differença. Contra-domínio: nenhum (imprime o valor no lozango pill_cpu por efeito).
  --------------------------------------------------------------------------------
  local function update_cpu()
    awful.spawn.easy_async_with_shell(
      "cat /proc/stat 2>/dev/null | head -n 1",
      function(stdout)
        stdout = stdout or ""
        -- cpu  user nice system idle iowait irq softirq steal ... (columnas de /proc/stat)
        local nums = {}
        for tok in stdout:gmatch("%d+") do
          nums[#nums + 1] = tonumber(tok)
        end
        if #nums < 4 then return end

        local idle = (nums[4] or 0) + (nums[5] or 0) -- o ócio, sc. idle + iowait
        local total = 0
        for i = 1, #nums do
          total = total + (nums[i] or 0)
        end

        local pct = 0
        if prev_cpu_total and prev_cpu_idle then
          local dt = total - prev_cpu_total
          local di = idle - prev_cpu_idle
          if dt > 0 then
            pct = (dt - di) / dt * 100
          end
        end
        prev_cpu_total, prev_cpu_idle = total, idle

        if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
        local rounded = math.floor(pct + 0.5)
        pill_cpu:set_value(string.format("%d%%", rounded), rounded)
      end
    )
  end

  --------------------------------------------------------------------------------
  -- MEM — funcção de sondagem de Braga Us. Lê /proc/meminfo e demonstra que a fracção usada
  -- vale (MemTotal - MemAvailable) / MemTotal. Contra-domínio: nenhum (imprime no pill_mem).
  --------------------------------------------------------------------------------
  local function update_mem()
    awful.spawn.easy_async_with_shell(
      "cat /proc/meminfo 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local total = tonumber(stdout:match("MemTotal:%s*(%d+)"))
        local avail = tonumber(stdout:match("MemAvailable:%s*(%d+)"))
        if not total or not avail or total <= 0 then return end

        local used = total - avail
        if used < 0 then used = 0 end
        local pct = used / total * 100
        if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
        local rounded = math.floor(pct + 0.5)
        pill_mem:set_value(string.format("%d%%", rounded), rounded)
      end
    )
  end

  --------------------------------------------------------------------------------
  -- GPU — funcção de sondagem de Braga Us. Interroga nvidia-smi por utilization.gpu (%).
  -- Por prudência, recahe em "--" se o binário não existir ou se a saída não fôr numérica.
  --------------------------------------------------------------------------------
  local function update_gpu()
    awful.spawn.easy_async_with_shell(
      "nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local util = tonumber(stdout:match("%d+"))
        if not util then
          pill_gpu:set_value("--", nil)
          return
        end
        if util < 0 then util = 0 elseif util > 100 then util = 100 end
        pill_gpu:set_value(string.format("%d%%", util), util)
      end
    )
  end

  --------------------------------------------------------------------------------
  -- NET — funcção de sondagem de Braga Us. De /proc/net/dev somma rx/tx de todas as interfaces
  -- excepto lo, e computa a taxa por differença (delta) entre pulsos. Imprime no pill_net.
  --------------------------------------------------------------------------------
  local function update_net()
    awful.spawn.easy_async_with_shell(
      "cat /proc/net/dev 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local rx_sum, tx_sum = 0, 0
        for line in stdout:gmatch("[^\r\n]+") do
          -- fórma da linha: iface: rx_bytes ... tx_bytes ...
          local iface, rest = line:match("^%s*([%w%-_]+):%s*(.+)$")
          if iface and iface ~= "lo" and rest then
            local fields = {}
            for tok in rest:gmatch("%S+") do
              fields[#fields + 1] = tonumber(tok)
            end
            -- campos ordenados: 1=rx_bytes ... 9=tx_bytes
            local rx = fields[1]
            local tx = fields[9]
            if rx then rx_sum = rx_sum + rx end
            if tx then tx_sum = tx_sum + tx end
          end
        end

        local now = os.time()
        local up_rate, down_rate = 0, 0
        if prev_net_rx and prev_net_tx and prev_net_time then
          local dt = now - prev_net_time
          if dt <= 0 then dt = 1 end
          local d_rx = rx_sum - prev_net_rx
          local d_tx = tx_sum - prev_net_tx
          if d_rx < 0 then d_rx = 0 end
          if d_tx < 0 then d_tx = 0 end
          down_rate = d_rx / dt
          up_rate   = d_tx / dt
        end
        prev_net_rx, prev_net_tx, prev_net_time = rx_sum, tx_sum, now

        pill_net:set_value(string.format("↑%s ↓%s", format.rate(up_rate, "kbps"), format.rate(down_rate, "kbps")))
      end
    )
  end

  --------------------------------------------------------------------------------
  -- VOL — funcção de sondagem de Braga Us. De pactl get-sink-volume @DEFAULT_SINK@ colhe o
  -- primeiro "NN%" que se apresente. Contra-domínio: nenhum (imprime no lozango pill_vol).
  --------------------------------------------------------------------------------
  local function update_vol()
    awful.spawn.easy_async_with_shell(
      "pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local vol = tonumber(stdout:match("(%d+)%%"))
        if not vol then return end
        if vol < 0 then vol = 0 end
        pill_vol:set_value(string.format("%d%%", vol), vol)
      end
    )
  end

  --------------------------------------------------------------------------------
  -- RELÓGIO — funcção de Braga Us que verte os textos de hora e data por os.date no próprio
  -- relógio (synchrona, porém de custo ínfimo; não invoca shell algum).
  --------------------------------------------------------------------------------
  local function update_clock()
    clock_time:set_text(os.date("%H:%M"))
    clock_date:set_text(os.date("%b %d"))
  end

  gears.timer {
    timeout   = opts.timeout or 2,
    call_now  = true,
    autostart = true,
    callback  = function()
      update_cpu()
      update_mem()
      update_gpu()
      update_net()
      update_vol()
      update_clock()
    end,
  }

  return bar
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
