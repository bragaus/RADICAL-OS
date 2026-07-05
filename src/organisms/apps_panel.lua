------------------------------------------------------------------------------------------
-- src/organisms/apps_panel.lua — Painel "APPLICATIONS" (VIOLET HUD §5.1 / §7.4.x)            --
--                                                                                        --
-- Lista os CLIENTES abertos (janelas), não processos de shell. Cada linha:               --
--   [ícone] NOME/CLASSE (text_primary, encurtado)  ················  KILL (kill_btn)      --
-- O kill_btn fica em text_muted e vira crit no hover (+ cursor hand2); clique-esquerdo    --
-- chama c:kill(). O ícone do cliente (c.icon) é prefixado à esquerda da linha.            --
--                                                                                        --
-- REWIRED (Stage 2): cada linha = ícone + molecule table_row (célula NOME + kill_btn via  --
-- on_kill). SEM scroll_list: a lista é reconstruída de client.get() por evento.           --
--                                                                                        --
-- SINAIS (fix R7/double-subscribe): os sinais GLOBAIS client/awesome são conectados       --
-- UMA ÚNICA VEZ no escopo do módulo (guard `signals_wired`), despachando para a instância --
-- ATIVA. Cada nova instância do factory se torna a ativa (supersede) — a anterior deixa   --
-- de ser reconstruída (teardown), então re-instanciar (hotplug/troca de primary) NÃO       --
-- vaza N assinaturas. O factory recebe só `args` (sem `s`), então o "teardown por tela"    --
-- é feito por supersede da instância ativa (apps_panel é singleton primary-only).         --
------------------------------------------------------------------------------------------

local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local txt   = require("src.atoms.txt")
local table_row = require("src.molecules.table_row")
local format = require("src.tools.format")

local NAME_MAX = 22 -- chars máximos do nome antes de encurtar
local MAX_ROWS = 12 -- teto de linhas renderizadas (evita estourar a coluna)

-- ── Sinais globais conectados UMA VEZ; despacham para a instância ativa (supersede) ──────
local active_schedule = nil
local signals_wired    = false

local function dispatch_rebuild()
  if active_schedule then active_schedule() end
end

local function wire_signals_once()
  if signals_wired then return end
  signals_wired = true
  client.connect_signal("manage", dispatch_rebuild)
  client.connect_signal("unmanage", dispatch_rebuild)
  client.connect_signal("property::name", dispatch_rebuild)
  -- "refresh" cobre mudanças de conjunto/foco que não disparam manage/unmanage.
  awesome.connect_signal("refresh", dispatch_rebuild)
end

-- Rótulo de exibição de um cliente: prefere class, cai p/ name, depois "?".
local function client_label(c)
  local label = c.class or c.name or "?"
  if label == nil or label == "" then
    label = "?"
  end
  return format.shorten(label, NAME_MAX)
end

-- Ícone do cliente (se houver); senão um espaçador da mesma largura.
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

-- Constrói uma linha de cliente: [ícone] table_row(NOME flex + kill_btn).
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
    fill_space    = true, -- table_row (último filho) preenche o resto -> NOME flexiona
    spacing       = dpi(mt.gap),
    forced_height = dpi(mt.row_h),
    layout        = wibox.layout.fixed.horizontal,
  }
end

return function(args)
  args = args or {}

  -- Lista vertical reconstruída a cada mudança no conjunto de clientes.
  local rows = wibox.widget {
    spacing = dpi(mt.row_gap),
    layout  = wibox.layout.fixed.vertical,
  }

  -- Linha única "no apps" (muted, esquerda) exibida quando não há clientes.
  local empty_row = wibox.widget {
    txt { role = "cell", text = "NO OPEN APPS", color = p.text_muted, align = "left" },
    forced_height = dpi(mt.row_h),
    widget        = wibox.container.background,
  }

  local function rebuild()
    rows:reset()
    local count = 0
    for _, c in ipairs(client.get()) do
      -- Ignora clientes inválidos ou janelas-skip (ex.: docks/desktop).
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

  -- Coalesce rajadas de eventos (manage/unmanage/refresh) numa única reconstrução.
  local coalesce = gears.timer {
    timeout      = 0.05,
    single_shot  = true,
    callback     = rebuild,
  }
  -- Inicia o timer só se ainda não estiver pendente. NÃO usar :again() aqui — o
  -- sinal "refresh" do awesome dispara a cada iteração do loop e resetar a deadline
  -- repetidamente faria a reconstrução nunca ocorrer. Assim ela ocorre em ~50ms.
  local function schedule_rebuild()
    if not coalesce.started then
      coalesce:start()
    end
  end

  -- Conecta os sinais globais UMA VEZ e torna ESTA instância a ativa (supersede: a
  -- instância anterior deixa de ser despachada -> sem vazamento de assinaturas).
  wire_signals_once()
  active_schedule = schedule_rebuild

  -- Render inicial.
  rebuild()

  local panel = require("src.tools.panel")
  return panel({
    title  = "APPLICATIONS",
    body   = rows,
    accent = p.v500,
    w      = args.w or dpi(mt.panel_w_sm),
  })
end
