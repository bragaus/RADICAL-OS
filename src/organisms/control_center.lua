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
local chevron_seg = require("src.molecules.chevron_seg")   -- casca powerline reutilizável (fita da direita)
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
  -- já existam), porém o fecho de clique da datepill captura-o como upvalue — donde `toggle`
  -- há de ser já um local visível. A fita central deixou de ser de ESTATÍSTICA: os cinco
  -- lozangos (cpu/mem/gpu/net/vol) cederam logar à FITA DE PROGRAMMAS (opts.center_widget, a
  -- tasklist). A telemetria e os seus dashboards seguem accessíveis pela MonitorBar do rodapé
  -- (que consulta s.dashboard_toggle) e o volume pelo seu controlador/OSD/teclas.
  ----------------------------------------------------------------------------------------
  local toggle

  ----------------------------------------------------------------------------------------
  -- RELÓGIO da secção direita (kit `.rightc`). Distinguem-se, à maneira do kit, DUAS peças:
  --   * clock_hm  — o «HH:MM» NU (kit .loztail__hm, ExtraBold 13, text_bright), não clicável;
  --   * datepill  — a pílula da DATA (kit .datepill), clicável, que abre o dashboard TIME.
  ----------------------------------------------------------------------------------------
  local clock_hm = wibox.widget {
    text   = "--:--",
    font   = ft.fill_date,    -- mesma fonte/tamanho da data (a pedido)
    valign = "center",
    widget = wibox.widget.textbox,
  }
  local clock_date = wibox.widget {
    text   = "---",
    font   = ft.fill_date,    -- barra cheia: data grande
    valign = "center",
    widget = wibox.widget.textbox,
  }

  -- A DATA já não é uma pílula própria: vira um chevron_seg (mesmo powerline do DS), erguido na
  -- secção direita. Aqui só sobrevive o `clock_date` (o textbox), que o seg envolve como conteúdo.

  ----------------------------------------------------------------------------------------
  -- REFLEXO DE ESTADO — o kit acende o segmento do grupo cujo dashboard esteja aberto. O
  -- `active_group` retém o grupo vigente; `refresh_active` propaga-o às pílulas (:set_active).
  -- Referencia os lozangos e a datepill, donde carece de estar definido APÓS elles.
  ----------------------------------------------------------------------------------------
  local active_group
  local date_seg            -- fwd-decl: o seg da DATA (chevron) nasce adiante, na secção direita
  local function refresh_active()
    local g = active_group
    if date_seg then date_seg:set_active(g == "time") end   -- só o seg da DATA (TIME) reflecte grupo
  end

  ----------------------------------------------------------------------------------------
  -- COMPOSIÇÃO DAS SECÇÕES da barra (kit `.topbar__left` | `.topbar__center` | `.rightc`).
  ----------------------------------------------------------------------------------------
  -- ESQUERDA (.topbar__left, gap 8): as tags e a concha de controlos. A tagctl encaixa-se
  -- 22px SOB a última aba (kit .tagctl margin-left:-22px). CRÍTICO (kit z-index): a concha
  -- fica ATRÁS e a taglist POR CIMA, de sorte que a ponta afiada da última aba ENTRE no corpo
  -- do tagctl (e não seja coberta por ele). `fixed.horizontal` pinta na ordem de inserção
  -- (a concha, inserida em 2º, ficaria por cima e quadraria a ponta), logo invertemos SÓ a
  -- ordem de PINTURA — as posições (x) permanecem intactas. Espelha o truque do taglist.lua.
  local left_section = wibox.layout.fixed.horizontal()
  left_section.spacing = dpi(8)
  if opts.left_widgets and opts.left_widgets[1] then
    left_section:add(opts.left_widgets[1])                                                         -- taglist (posição 1 = esquerda)
  end
  if opts.left_widgets and opts.left_widgets[2] then
    left_section:add(wibox.widget {                                                                -- tag_controls, tucked -22
      opts.left_widgets[2], left = -dpi(mt.tagctl_tuck), widget = wibox.container.margin,
    })
  end
  do
    -- captura o :layout nativo ANTES de o ensombrar (get_miss resolve p/ o método da classe)
    local native_layout = left_section.layout
    function left_section:layout(context, width, height)
      local placements = native_layout(self, context, width, height)
      -- inverte a ordem de PINTURA mantendo cada (widget, x, y): a concha (agora 1ª) pinta
      -- ao fundo e a taglist por cima → a seta da última aba transborda para dentro do tagctl.
      for i = 1, math.floor(#placements / 2) do
        placements[i], placements[#placements - i + 1] = placements[#placements - i + 1], placements[i]
      end
      return placements
    end
  end

  -- CENTRO (.topbar__center, flex:1): a FITA DE PROGRAMMAS (opts.center_widget, a tasklist), que
  -- já governa a sua própria sobreposição de -12px e as suas cores; centrada por
  -- wibox.container.place — o flex reparte-lhe o resto do vão. Faltando o widget, o centro fica
  -- vácuo (sem erro).
  local center_section = wibox.widget {
    opts.center_widget,
    halign = "center",
    valign = "center",
    widget = wibox.container.place,
  }

  -- DIREITA (.rightc): FITA DE CHEVRONS espelhada (aponta à esquerda) — mesmo powerline roxo do DS.
  -- Ordem esq→dir [relógio, data, systray, kb, poder]; a sobreposição -tip encaixa a ponta esquerda
  -- de cada seg no socket do vizinho; o poder (extremo direito) é o terminus convexo. Cliques ficam
  -- nos segs (data→TIME e acende via refresh_active; kb→toggle; poder→powermenu).
  local rtip = dpi(mt.powerline_tip)
  date_seg = chevron_seg {
    content = { clock_date, fg = p.launcher_ring_on, widget = wibox.container.background },
    on_click = function() toggle("time") end,
  }
  local right_section = wibox.layout.fixed.horizontal()
  right_section.spacing = -rtip
  -- SYSTRAY é o 1º widget da secção (a pedido): entra à frente do relógio.
  if opts.right_extra and opts.right_extra[1] then
    local tray_seg = chevron_seg { content = opts.right_extra[1], hover = false }     -- systray (1º)
    -- some quando não há app de bandeja (0 entradas) — sem deixar buraco na fita; reaparece ao registar
    local function upd_tray() tray_seg.visible = (awesome.systray() or 0) > 0 end
    upd_tray()                                             -- estado inicial (0 no boot → oculto)
    awesome.connect_signal("systray::update", upd_tray)
    right_section:add(tray_seg)
  end
  right_section:add(chevron_seg {
    content = { clock_hm, fg = p.launcher_ring_on, widget = wibox.container.background }, hover = false,
  })
  right_section:add(date_seg)
  if opts.right_extra and opts.right_extra[2] then
    right_section:add(chevron_seg {                                                   -- kblayout
      content = opts.right_extra[2], on_click = function() awesome.emit_signal("kblayout::toggle") end,
    })
  end
  if opts.right_widget then
    right_section:add(chevron_seg {                                                   -- poder (terminus)
      content = opts.right_widget, terminus = true,
      on_click = function() awesome.emit_signal("module::powermenu:show") end,
    })
  end

  -- RAIZ: left | center(flex) | right. Com `expand="inside"`, o widget do meio ocupa o vão
  -- restante (.topbar__center flex:1), donde o ribbon se centra sozinho — sem hack de largura.
  -- Cada seção vem centrada na vertical (place valign) — senão as curtas (tags/relógio) encostam no
  -- topo da fita na align.horizontal, enquanto o centro já se centra. Na barra alta de 80px, isto
  -- alinha esquerda|centro|direita no mesmo eixo vertical.
  local bar_layout = wibox.widget {
    { { left_section,  valign = "center", widget = wibox.container.place }, right = dpi(10), widget = wibox.container.margin },
    center_section,
    { { right_section, valign = "center", widget = wibox.container.place }, left  = dpi(10), widget = wibox.container.margin },
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }
  local bar_inner = wibox.widget {
    {
      nil,
      bar_layout,
      nil,
      expand = "none",   -- centra a fita na vertical (altura natural, y=(H-h)/2) na barra alta de 80px
      layout = wibox.layout.align.vertical,
    },
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
    awful.placement.top_right(c, { margins = { top = dpi(mt.topbar_h) + dpi(8), right = dpi(8) } })
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
  -- CLIQUES — a fita central (tasklist) traz o seu próprio clique/hover por cliente; aqui só se
  -- ata o clique da datepill, que abre/fecha o dashboard TIME.
  ----------------------------------------------------------------------------------------
  -- Funcção de Braga Us que torna tangível um widget: dado (w) o widget e (on_click) a acção,
  -- imprime-lhe o realce de hover (cursor de mão) e liga o botão esquerdo do rato ao dito clique.
  local function make_clickable(w, on_click)
    Hover_signal(w, nil, p.glow_ice)
    w:buttons(gears.table.join(
      awful.button({}, 1, on_click)
    ))
  end

  -- (a data agora é um chevron_seg com on_click próprio — ver right_section)

  ----------------------------------------------------------------------------------------
  -- A BARRA — UMA awful.wibar full-width, rasa (26px), assente flush ao alto. Reserva a área
  -- de trabalho por si (struts automáticos), donde some o antigo hack de :struts manual. Fundo
  -- base @80% (kit .topbar). Salvaguarda contra duplicata na recarga via s._top_bar.
  ----------------------------------------------------------------------------------------
  if s._top_bar then s._top_bar.visible = false end
  local bar = awful.wibar {
    screen   = s,
    position = "top",
    height   = dpi(mt.topbar_h),       -- barra de cima −30% (topbar_h=56, independente do rodapé); struts automáticos
    bg       = p.a(p.base, p.alpha.bar), -- .topbar bg = base @ 80%
    ontop    = false,
    widget   = bar_widget,
  }
  s._top_bar = bar

  -- [As sondagens de CPU/MEM/GPU/NET/VOL — outrora impressas nos cinco lozangos da fita central
  --  — foram removidas junto com a fita de estatística. A telemetria (e o toque que abre os
  --  dashboards / o controlador de volume) vive agora na MonitorBar do rodapé.]

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
