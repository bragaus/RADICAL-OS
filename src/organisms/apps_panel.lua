-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "APPLICATIONS" — src/organisms/apps_panel.lua (VIOLET HUD §5.1 / §7.4.x)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se a nómina dos CLIENTES
-- abertos (as janelas), e não dos processos de shell. Cada linha:
--   [ícone] NOME/CLASSE (text_primary, abreviado)  ················  KILL (kill_btn)
-- O kill_btn jaz em text_muted e faz-se crit ao pairar (com cursor de mão); o clique-sinistro
-- invoca c:kill(). O ícone do cliente (c.icon) antepõe-se á sinistra da linha.
--
-- Da restructuração (Stage 2): cada linha é ícone + molécula table_row (célula NOME + kill_btn
-- por on_kill). SEM scroll_list: a nómina reconstrói-se de client.get() a cada evento.
--
-- DOS SINAES (correcção R7 / dupla subscripção): os sinaes GLOBAES client/awesome atam-se
-- UMA ÚNICA VEZ no escopo do módulo (guarda `signals_wired`), despachando para a instância
-- ACTIVA. Cada nova instância do factory torna-se a activa (supersede) — a anterior deixa de
-- ser reconstruída (teardown); assim, re-instanciar (hotplug / troca de primary) NÃO vaza N
-- subscripções. O factory recebe só `args` (sem `s`), pelo que o "teardown por tela" se faz
-- por supersede da instância activa (apps_panel é singleton, sómente do primary).
-- ─────────────────────────────────────────────────────────────────────────────────────

local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local txt   = require("src.atoms.txt")
local Icon  = require("src.tools.icons") -- os ícones lavrados em SVG do conjuncto icons/ (§3.13)
local table_row = require("src.molecules.table_row")
local format = require("src.tools.format")

local NAME_MAX = 22 -- cota máxima de caracteres do nome antes de o abreviar
local MAX_ROWS = 12 -- tecto de linhas renderizadas (obsta a que a columna transborde)

-- ── Sinaes globaes atados UMA VEZ; despacham para a instância activa (supersede) ──────
local active_schedule = nil
local signals_wired    = false

-- LEMMA DO DESPACHO (de Braga Us): remette a ordem de reconstrucção á instância activa, se a houver.
local function dispatch_rebuild()
  if active_schedule then active_schedule() end
end

-- LEMMA DA ATADURA ÚNICA (de Braga Us): ata, uma só vez (guarda signals_wired), os sinaes
-- globaes de cliente ao despacho. EMENDA CAPITAL: retira-se o gancho "refresh" do awesome —
-- que disparava a CADA iteração do laço principal (e o GIF de 20fps do launcher o mantinha
-- quente), reconstruindo a nómina inteira ~20×/s PARA SEMPRE, ainda oculto o painel. Os
-- sinaes manage/unmanage/property::name bastam: a nómina é de TODOS os clientes (sem estado
-- de fóco), pelo que só muda quando um cliente nasce, morre ou troca de nome.
local function wire_signals_once()
  if signals_wired then return end
  signals_wired = true
  client.connect_signal("manage", dispatch_rebuild)
  client.connect_signal("unmanage", dispatch_rebuild)
  client.connect_signal("property::name", dispatch_rebuild)
end

-- LEMMA DO RÓTULO DO CLIENTE (de Braga Us). Recebe o cliente `c` (domínio); prefere a class,
-- cae para o name e, na falta de ambos, para "?". Contra-domínio: o rótulo já abreviado.
local function client_label(c)
  local label = c.class or c.name or "?"
  if label == nil or label == "" then
    label = "?"
  end
  return format.shorten(label, NAME_MAX)
end

-- LEMMA DO ÍCONE DO CLIENTE (de Braga Us): devolve o ícone do cliente (havendo-o) ou, em seu
-- logar, um espaçador da mesma largura, para que as linhas se alinhem ainda quando falte ícone.
local function client_icon(c)
  if c.icon then
    return wibox.widget {
      {
        image         = c.icon,
        resize        = true,
        forced_width  = dpi(mt.icon_md),
        forced_height = dpi(mt.icon_md),
        widget        = wibox.widget.imagebox,
      },
      valign = "center",
      halign = "center",
      widget = wibox.container.place,
    }
  end
  local spacer = wibox.widget.base.make_widget()
  spacer.forced_width = dpi(mt.icon_md)
  return spacer
end

-- LEMMA DA CONSTRUCÇÃO DA LINHA (de Braga Us): edifica uma linha de cliente — [ícone] +
-- table_row (NOME flexível + kill_btn). O clique no kill_btn invoca c:kill() se o cliente
-- ainda for válido.
local function build_row(c)
  local tr = table_row {
    cells = {
      { client_label(c), nil, "left", p.text_primary }, -- NOME (flex)
    },
    on_kill = function()
      if c and c.valid then c:kill() end
    end,
  }

  return wibox.widget {
    {
      client_icon(c),
      forced_width = dpi(mt.icon_row),
      widget       = wibox.container.constraint,
    },
    tr,
    fill_space    = true, -- o table_row (filho derradeiro) preenche o resto -> o NOME flexiona
    spacing       = dpi(mt.gap),
    forced_height = dpi(mt.row_h),
    layout        = wibox.layout.fixed.horizontal,
  }
end

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe `args` (domínio:
-- largura `w`) e devolve o widget do painel (contra-domínio). Efeito: institue a nómina
-- vertical, ata os sinaes globaes uma só vez, faz-se a instância activa e renderiza á partida.
return function(args)
  args = args or {}

  -- Nómina vertical, reconstruída a cada mudança no conjuncto de clientes.
  local rows = wibox.widget {
    spacing = dpi(mt.row_gap),
    layout  = wibox.layout.fixed.vertical,
  }

  -- Linha única "no apps" (esmaecida, á sinistra), exhibida quando não há clientes.
  local empty_row = wibox.widget {
    txt { role = "cell", text = "NO OPEN APPS", color = p.text_muted, align = "left" },
    forced_height = dpi(mt.row_h),
    widget        = wibox.container.background,
  }

  -- LEMMA DA RECONSTRUCÇÃO (de Braga Us): esvazia a nómina e torna a povoá-la de client.get(),
  -- descartando os clientes inválidos ou de janela-a-saltar (docks/desktop), sob o tecto
  -- MAX_ROWS. Não havendo cliente algum, apõe a linha de vazio.
  local function rebuild()
    rows:reset()
    local count = 0
    for _, c in ipairs(client.get()) do
      -- Ignoram-se os clientes inválidos ou de janela-a-saltar (ex.: docks/desktop).
      if c and c.valid and not c.skip_taskbar then
        count = count + 1
        if count <= MAX_ROWS then
          rows:add(build_row(c))
        end
      end
    end
    if count == 0 then
      rows:add(empty_row)
    end
  end

  -- Comporta da sondagem (gating): enquanto o painel jaz oculto, os eventos de
  -- cliente NÃO reconstroem a nómina. Nasce fechada (o painel principia oculto).
  local sampling = false

  -- Coalesce as rajadas de eventos (manage/unmanage) numa só reconstrucção.
  local coalesce = gears.timer {
    timeout      = 0.05,
    single_shot  = true,
    callback     = rebuild,
  }
  -- LEMMA DO AGENDAMENTO (de Braga Us): estando aberta a comporta e não pendente o
  -- timer, principia-o; a reconstrucção sobrevém em ~50ms. Fechada a comporta, nada.
  local function schedule_rebuild()
    if sampling and not coalesce.started then
      coalesce:start()
    end
  end

  -- Atam-se os sinaes globaes UMA VEZ e faz-se ESTA a instância activa (supersede: a instância
  -- anterior deixa de ser despachada -> sem vazamento de subscripções).
  wire_signals_once()
  active_schedule = schedule_rebuild

  local panel = require("src.tools.panel")
  local panel_widget = panel({
    title  = "APPLICATIONS",
    body   = rows,
    accent = p.v500,
    w      = args.w or dpi(mt.panel_w_300), -- kit dashboards.jsx: APPLICATIONS width 300
    -- Ícone do cabeçalho (.hp__hdicon): kill_all a 13px e 70% de opacidade (kit APPLICATIONS
    -- icon="kill_all"; o átomo icon só recolore, pelo que a esmaecência vae por invólucro).
    right_icon = wibox.widget {
      Icon("kill_all", { size = dpi(13), color = p.text_muted }),
      opacity = 0.7,
      widget  = wibox.container.background,
    },
  })

  -- COMPORTAS start/stop_sampling (de Braga Us), consumidas pelo control_center ao
  -- abrir/fechar o dashboard NETWORK. Ao abrir, reconstrói-se DE PRONTO (catch-up dos
  -- eventos perdidos enquanto oculto); ao fechar, cessa-se e cancela-se o pendente.
  function panel_widget.start_sampling()
    sampling = true
    rebuild()
  end
  function panel_widget.stop_sampling()
    sampling = false
    if coalesce.started then coalesce:stop() end
  end

  return panel_widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
