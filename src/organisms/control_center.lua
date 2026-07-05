------------------------------------------------------------------------------------------
-- src/organisms/control_center.lua — A BARRA SUPERIOR unificada (kit `.topbar`) + os
--                                    DASHBOARDS ao-toque (VIOLET HUD · DESIGN_SYSTEM §5 §7.2.1).
--
-- TRACTADO DA BARRA DE COMANDO, concebido e demonstrado pelo eminente Doutor BRAGA US,
-- Professor de Sciências Mathemáticas e Geómetra desta Casa.
--
-- Abandonadas as TRÊS ilhas flutuantes de outrora (a ilha-esquerda da radical_bar, o popup
-- central dos lozangos e o popup direito do relógio), o auctor as reune n'UMA só barra rasa
-- e contígua — a `awful.wibar` full-width, assente flush ao alto (top:0), de 26 pixels de
-- altura, que por si reserva a área de trabalho (struts automáticos, sem o antigo hack manual):
--
--   [ tags · tagctl ]            〈 cpu 〉〈 mem 〉〈 gpu 〉〈 net 〉〈 vol 〉            HH:MM [DATA] ⌨ ⏻
--   └─── esquerda ───┘           └────────────── centro (flex) ──────────────┘     └─── direita ───┘
--
-- Assignatura da funcção (do domínio ao contra-domínio):
--   return function(s, opts) ... end
--     opts.left_widgets = { taglist, tag_controls }  -> a secção esquerda (tagctl encaixa -22)
--     opts.right_extra  = { systray, kblayout }       -> apostos entre o relógio e o poder
--     opts.right_widget = power                        -> o botão do poder, ao extremo direito
--     opts.system_cols  = { {painel,...}, {painel,...} } -> dashboard SYSTEM  (listas-de-colunas)
--     opts.network_cols = { {painel,...}, {painel,...} } -> dashboard NETWORK (listas-de-colunas)
--     opts.time_cols    = { {painel,...}, {painel,...} } -> dashboard TIME    (listas-de-colunas)
--
-- POSTULADO DO TOGGLE: tocar num lozango abre/fecha o popup do respectivo grupo; e, por
-- invariante, apenas um permanece aberto de cada vez (abrir um encerra os demais). CPU/MEM/
-- GPU -> SYSTEM, NET -> NETWORK, a pílula da DATA -> TIME, VOL -> emitte "volume_controller::
-- toggle" (o controlador de volume, que já preexiste). O toggle acende, outrossim, o segmento
-- do grupo aberto (:set_active) — reflexo de estado que o kit exhibe. O toggle exporta-se em
-- `s.dashboard_toggle`, para que a MonitorBar o consulte preguiçosamente em tempo de execução.
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
local stat_lozenge = require("src.molecules.stat_lozenge") -- §7.2.1 capsula de estatística tangível (fita powerline)
require("src.core.signals") -- assegura o Hover_signal global, sem o qual Braga Us nada demonstra

-- Funcção-mestra, urdida e demonstrada pelo Doutor Braga Us: edifica a Barra de Comando inteira
-- para uma dada tela. Domínio: (s) a tela; (opts) táboa das secções (left_widgets, right_extra,
-- right_widget) e das colunas por grupo (system_cols/network_cols/time_cols). Contra-domínio: a
-- wibar superior. Efeitos collaterais: instaura os três dashboards ao-toque, exporta
-- s.dashboard_toggle, e institue um único relógio de sondagem periódica.
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
  -- LOZANGOS — os segmentos powerline de estatística, tangíveis (molecules/stat_lozenge,
  -- §7.2.1). A molécula é senhora da fórma/ícone/valor/hover/clique/estado-activo; ao
  -- proprietário cumpre apenas impellir os valores por :set_value(text, pct) (glow_hot quando
  -- pct >= mt.pct_hot). O primeiro segmento (cpu) leva `first=true` — vértice convexo à
  -- esquerda, terminus da fita. CPU/MEM/GPU -> SYSTEM, NET -> NETWORK, VOL -> controlador de
  -- volume. O VOL é never_hot: um volume de 90% ou mais NÃO deve incendiar o alerta vermelho.
  ----------------------------------------------------------------------------------------
  local pill_cpu = stat_lozenge { icon = "cpu", first = true, on_click = function() toggle("system") end }
  local pill_mem = stat_lozenge { icon = "mem", on_click = function() toggle("system") end }
  local pill_gpu = stat_lozenge { icon = "gpu", on_click = function() toggle("system") end }
  local pill_net = stat_lozenge { icon = "net", on_click = function() toggle("network") end }
  local pill_vol = stat_lozenge {
    icon      = "vol",
    never_hot = true,
    on_click  = function() awesome.emit_signal("volume_controller::toggle", s) end,
  }

  ----------------------------------------------------------------------------------------
  -- RELÓGIO da secção direita (kit `.rightc`). Distinguem-se, à maneira do kit, DUAS peças:
  --   * clock_hm  — o «HH:MM» NU (kit .loztail__hm, ExtraBold 13, text_bright), não clicável;
  --   * datepill  — a pílula da DATA (kit .datepill), clicável, que abre o dashboard TIME.
  ----------------------------------------------------------------------------------------
  local clock_hm = wibox.widget {
    text   = "--:--",
    font   = ft.clock_hm,     -- .loztail__hm 13/800
    valign = "center",
    widget = wibox.widget.textbox,
  }
  local clock_date = wibox.widget {
    text   = "---",
    font   = ft.label,        -- .datepill ≈ 11/700 (o Bold 10 do theme é o mais próximo consagrado)
    valign = "center",
    widget = wibox.widget.textbox,
  }

  -- A pílula da DATA (.datepill): gradiente vertical v700->v900, orla de 1px em glow_soft,
  -- raio de 9px e texto glow_ice. O estado `--on` (dashboard TIME aberto) verte-a para v500->
  -- v700 com orla glow_ice. Os gradientes fixam-se UMA só vez (economia de Braga Us).
  local DATE_H = dpi(20)
  local date_grad_rest = gears.color { type = "linear", from = { 0, 0 }, to = { 0, DATE_H }, stops = { { 0, p.v700 }, { 1, p.v900 } } }
  local date_grad_on   = gears.color { type = "linear", from = { 0, 0 }, to = { 0, DATE_H }, stops = { { 0, p.v500 }, { 1, p.v700 } } }
  local datepill = wibox.widget {
    {
      { clock_date, fg = p.glow_ice, widget = wibox.container.background },
      left   = dpi(10),
      right  = dpi(10),
      top    = dpi(2),
      bottom = dpi(2),
      widget = wibox.container.margin,
    },
    bg                 = date_grad_rest,
    shape              = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(9)) end,
    shape_border_width = dpi(1),
    shape_border_color = p.glow_soft,
    fg                 = p.glow_ice,
    widget             = wibox.container.background,
  }
  -- Methodo `:set_active` da pílula da DATA (kit `.datepill--on`): permuta o gradiente e a orla.
  function datepill:set_active(on)
    self.bg                 = on and date_grad_on or date_grad_rest
    self.shape_border_color = on and p.glow_ice or p.glow_soft
  end

  ----------------------------------------------------------------------------------------
  -- REFLEXO DE ESTADO — o kit acende o segmento do grupo cujo dashboard esteja aberto. O
  -- `active_group` retém o grupo vigente; `refresh_active` propaga-o às pílulas (:set_active).
  -- Referencia os lozangos e a datepill, donde carece de estar definido APÓS elles.
  ----------------------------------------------------------------------------------------
  local active_group
  local function refresh_active()
    local g = active_group
    pill_cpu:set_active(g == "system")
    pill_mem:set_active(g == "system")
    pill_gpu:set_active(g == "system")
    pill_net:set_active(g == "network")
    datepill:set_active(g == "time")
  end

  ----------------------------------------------------------------------------------------
  -- COMPOSIÇÃO DAS SECÇÕES da barra (kit `.topbar__left` | `.topbar__center` | `.rightc`).
  ----------------------------------------------------------------------------------------
  -- ESQUERDA (.topbar__left, gap 8): as tags e a concha de controlos. A tagctl encaixa-se
  -- 22px SOB a última aba (kit .tagctl margin-left:-22px), com a taglist desenhada por cima.
  local left_section = wibox.widget {
    opts.left_widgets and opts.left_widgets[1] or nil,                                            -- taglist (forma/cor próprias)
    opts.left_widgets and opts.left_widgets[2]
      and { opts.left_widgets[2], left = -dpi(mt.tagctl_tuck), widget = wibox.container.margin }   -- tag_controls, tucked -22
      or nil,
    spacing = dpi(8),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- CENTRO (.topbar__center, flex:1): a fita dos cinco lozangos, sobrepostos -12px (kit .seg
  -- margin-right:-12px), centrada por wibox.container.place — o flex reparte-lhe o resto do vão.
  local ribbon = wibox.widget {
    pill_cpu,
    pill_mem,
    pill_gpu,
    pill_net,
    pill_vol,
    spacing = -dpi(mt.powerline_tip),   -- -12 (a sobreposição da fita powerline)
    layout  = wibox.layout.fixed.horizontal,
  }
  local center_section = wibox.widget {
    ribbon,
    halign = "center",
    valign = "center",
    widget = wibox.container.place,
  }

  -- DIREITA (.rightc, gap 10): HH:MM nu + datepill(->TIME) + systray + kblayout + poder.
  local right_section = wibox.widget {
    { clock_hm, fg = p.text_bright, widget = wibox.container.background },
    datepill,
    opts.right_extra and opts.right_extra[1] or nil,   -- s.systray
    opts.right_extra and opts.right_extra[2] or nil,   -- s.kblayout
    opts.right_widget,                                 -- power (.powerbtn)
    spacing = dpi(10),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- RAIZ: left | center(flex) | right. Com `expand="inside"`, o widget do meio ocupa o vão
  -- restante (.topbar__center flex:1), donde o ribbon se centra sozinho — sem hack de largura.
  local bar_layout = wibox.widget {
    { left_section,  right = dpi(10), widget = wibox.container.margin },   -- gap 10 após a esquerda
    center_section,
    { right_section, left  = dpi(10), widget = wibox.container.margin },   -- gap 10 antes da direita
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }
  local bar_inner = wibox.widget {
    bar_layout,
    left   = dpi(mt.pad_panel),   -- .topbar padding 0 8
    right  = dpi(mt.pad_panel),
    widget = wibox.container.margin,
  }
  -- Filete de 1px no RODAPÉ (kit .topbar border-bottom:1px line-base) — espelho do padrão que
  -- a monitor_bar usa no topo. O align.vertical fixa a linha ao pé e deixa o miolo expandir.
  local bar_widget = wibox.widget {
    nil,
    bar_inner,
    { forced_height = dpi(1), bg = p.line_base, widget = wibox.container.background },
    layout = wibox.layout.align.vertical,
  }

  ----------------------------------------------------------------------------------------
  -- DASHBOARDS ao-toque (SYSTEM / NETWORK / TIME). Cada popup arruma os painéis em COLUNAS
  -- (kit `.dash` = fila de `.dash__col`), fila de intervallo 8 sobre columnas de intervallo 8.
  ----------------------------------------------------------------------------------------
  -- Sub-funcção de Braga Us: dado (cols) um rol de COLUNAS (cada coluna um rol de painéis),
  -- devolve o `.dash` — uma fila horizontal (spacing 8) de columnas verticaes (spacing 8),
  -- peneirando os nil. [DESVIO documentado do blueprint §1.4: as antigas listas planas
  -- system_panels/network_panels/time_panels dão logar a listas-DE-COLUNAS.]
  local function compose_columns(cols)
    local dash = wibox.layout.fixed.horizontal()
    dash.spacing = dpi(8)
    if cols then
      for _, col in ipairs(cols) do
        local column = wibox.layout.fixed.vertical()
        column.spacing = dpi(8)
        if col then
          for _, pnl in ipairs(col) do
            if pnl ~= nil then column:add(pnl) end
          end
        end
        dash:add(column)
      end
    end
    return dash
  end

  -- Sub-funcção de Braga Us: aplaina o rol de colunas n'uma lista chã de painéis — necessária
  -- para accender/apagar a sondagem de um grupo inteiro (que ignora a arrumação em colunas).
  local function flatten_columns(cols)
    local out = {}
    if cols then
      for _, col in ipairs(cols) do
        if col then
          for _, pnl in ipairs(col) do
            if pnl ~= nil then out[#out + 1] = pnl end
          end
        end
      end
    end
    return out
  end

  -- Sub-funcção-fábrica de Braga Us: forja um popup de dashboard. Domínio: (cols) o rol de
  -- colunas a compor; (place) a funcção de collocação. Contra-domínio: o awful.popup, oculto
  -- de início (visible=false). Ontop, para pairar sobre as janellas ao apparecer.
  local function make_dashboard(cols, place)
    return awful.popup {
      widget = {
        compose_columns(cols),
        margins = dpi(8),
        widget  = wibox.container.margin,
      },
      ontop     = true,
      visible   = false,
      screen    = s,
      bg        = p.a(p.base, p.alpha.dash), -- base @ opacidade de dashboard
      placement = place,
    }
  end

  -- Salvaguarda de Braga Us contra duplicatas na recarga: occulta os popups pregressos desta tela.
  if s._cc_dashboards then
    for _, old in pairs(s._cc_dashboards) do
      if old then old.visible = false end
    end
  end

  -- Collocações (kit `.popup`): SYSTEM/NETWORK ancoram-se ao FUNDO, abrindo para cima (acima da
  -- MonitorBar de 80px, com folga de 10); TIME desce do canto superior-direito, sob a datepill.
  local dash_system  = make_dashboard(opts.system_cols, function(c)
    awful.placement.bottom(c, { margins = { bottom = dpi(mt.mon_h) + dpi(10) } })
  end)
  local dash_network = make_dashboard(opts.network_cols, function(c)
    awful.placement.bottom(c, { margins = { bottom = dpi(mt.mon_h) + dpi(10) } })
  end)
  local dash_time    = make_dashboard(opts.time_cols, function(c)
    awful.placement.top_right(c, { margins = { top = dpi(mt.bar_h) + dpi(8), right = dpi(8) } })
  end)

  local dashboards = {
    system  = dash_system,
    network = dash_network,
    time    = dash_time,
  }
  s._cc_dashboards = dashboards

  -- Grupos de painéis (aplainados) por dashboard, para accender/apagar a sondagem conforme a visibilidade.
  local panel_groups = {
    system  = flatten_columns(opts.system_cols),
    network = flatten_columns(opts.network_cols),
    time    = flatten_columns(opts.time_cols),
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
  -- NÃO sondam (ss/proc/nvidia-smi/pactl) enquanto occultos. Ao cabo, retém-se o grupo activo e
  -- reflecte-se o seu realce nos segmentos (:set_active). Q.E.D.
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
    active_group = target.visible and name or nil   -- NOVO: retém o grupo vigente
    refresh_active()                                -- NOVO: acende o segmento do grupo aberto
  end
  s.dashboard_toggle = toggle                        -- NOVO: export p/ a MonitorBar (consulta preguiçosa)

  ----------------------------------------------------------------------------------------
  -- CLIQUES — os cinco lozangos já trazem o seu clique/hover do stat_lozenge (atados UMA só vez
  -- na construcção — R7); NÃO os atar de novo. A datepill, porém, tem o seu clique atado aqui.
  ----------------------------------------------------------------------------------------
  -- Funcção de Braga Us que torna tangível um widget: dado (w) o widget e (on_click) a acção,
  -- imprime-lhe o realce de hover (cursor de mão) e liga o botão esquerdo do rato ao dito clique.
  local function make_clickable(w, on_click)
    Hover_signal(w, nil, p.glow_ice)
    w:buttons(gears.table.join(
      awful.button({}, 1, on_click)
    ))
  end

  make_clickable(datepill, function() toggle("time") end)

  ----------------------------------------------------------------------------------------
  -- A BARRA — UMA awful.wibar full-width, rasa (26px), assente flush ao alto. Reserva a área
  -- de trabalho por si (struts automáticos), donde some o antigo hack de :struts manual. Fundo
  -- base @80% (kit .topbar). Salvaguarda contra duplicata na recarga via s._top_bar.
  ----------------------------------------------------------------------------------------
  if s._top_bar then s._top_bar.visible = false end
  local bar = awful.wibar {
    screen   = s,
    position = "top",
    height   = dpi(mt.bar_h),          -- 26; struts reservados automaticamente
    bg       = p.a(p.base, p.alpha.bar), -- .topbar bg = base @ 80%
    ontop    = false,
    widget   = bar_widget,
  }
  s._top_bar = bar

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
  -- RELÓGIO — funcção de Braga Us que verte os textos de hora e data por os.date nas próprias
  -- peças (synchrona, porém de custo ínfimo; não invoca shell algum). O «HH:MM» vai ao clock_hm
  -- nu; a data «Mês DD» vai à datepill clicável.
  --------------------------------------------------------------------------------
  local function update_clock()
    clock_hm:set_text(os.date("%H:%M"))
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
