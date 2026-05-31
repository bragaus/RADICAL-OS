------------------------------------------------------------------------------------------
-- src/widgets/apps_panel.lua — Painel "APPLICATIONS" (VIOLET HUD §5.1 / §7.4.x)            --
--                                                                                        --
-- Lista os CLIENTES abertos (janelas), não processos de shell. Cada linha:               --
--   [ícone] NOME/CLASSE (text_primary, encurtado)  ················  KILL (skull)         --
-- O glyph de KILL (`` skull) fica em text_muted e vira crit no hover (Hover_signal,      --
-- que também troca o cursor p/ hand1); clique-esquerdo chama c:kill().                   --
--                                                                                        --
-- SEM amostragem de shell: a lista é reconstruída de client.get() sempre que o conjunto  --
-- ou o nome dos clientes muda — sinais "manage"/"unmanage"/"property::name" e o sinal     --
-- "refresh" do awesome. Reconstruções são coalescidas via gears.timer single_shot p/     --
-- não reconstruir N vezes numa rajada de eventos.                                        --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")

local MONO       = "JetBrainsMono Nerd Font"
local KILL_GLYPH = "" -- nf-md-skull
local NAME_MAX   = 22 -- chars máximos do nome antes de encurtar
local MAX_ROWS   = 12 -- teto de linhas renderizadas (evita estourar a coluna)

-- Encurta o nome do cliente para ~NAME_MAX chars (com reticências).
local function shorten(name, max)
  name = tostring(name or "")
  max = max or NAME_MAX
  if #name > max then
    return name:sub(1, max - 1) .. "…"
  end
  return name
end

-- Rótulo de exibição de um cliente: prefere class, cai p/ name, depois "?".
local function client_label(c)
  local label = c.class or c.name or "?"
  if label == nil or label == "" then
    label = "?"
  end
  return shorten(label)
end

-- Célula de KILL: glyph skull; hover -> crit (+ hand1); clique-esquerdo -> c:kill().
local function kill_cell(c)
  local skull = wibox.widget {
    text   = KILL_GLYPH,
    font   = MONO .. " 9",
    align  = "center",
    valign = "center",
    widget = wibox.widget.textbox,
  }
  local cellbg = wibox.widget {
    skull,
    fg           = p.text_muted,
    forced_width = dpi(28),
    widget       = wibox.container.background,
  }

  -- bg=nil -> só recolore o fg p/ crit no hover; Hover_signal já seta cursor hand1.
  Hover_signal(cellbg, nil, p.crit)

  cellbg:buttons(awful.util.table.join(
    awful.button({}, 1, function()
      if c and c.valid then
        c:kill()
      end
    end)
  ))

  return cellbg
end

-- Constrói uma linha de cliente: [ícone] NOME ················ KILL.
local function build_row(c)
  -- Ícone do cliente (se houver); senão um espaçador da mesma largura.
  local icon_w
  if c.icon then
    icon_w = wibox.widget {
      {
        image         = c.icon,
        resize        = true,
        forced_width  = dpi(14),
        forced_height = dpi(14),
        widget        = wibox.widget.imagebox,
      },
      valign = "center",
      halign = "center",
      widget = wibox.container.place,
    }
  else
    icon_w = wibox.widget.base.make_widget()
    icon_w.forced_width = dpi(14)
  end

  local name_box = wibox.widget {
    text      = client_label(c),
    font      = MONO .. " 9",
    align     = "left",
    valign    = "center",
    ellipsize = "end",
    widget    = wibox.widget.textbox,
  }

  return wibox.widget {
    {
      icon_w,
      forced_width = dpi(18),
      widget       = wibox.container.constraint,
    },
    {
      {
        name_box,
        fg     = p.text_primary,
        widget = wibox.container.background,
      },
      layout = wibox.layout.flex.horizontal,
    },
    kill_cell(c),
    forced_height = dpi(18),
    spacing       = dpi(6),
    layout        = wibox.layout.align.horizontal,
  }
end

return function(args)
  args = args or {}

  -- Lista vertical reconstruída a cada mudança no conjunto de clientes.
  local rows = wibox.widget {
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }

  -- Linha única "no apps" (muted) exibida quando não há clientes.
  local empty_row = wibox.widget {
    {
      text   = "NO OPEN APPS",
      font   = MONO .. " 9",
      align  = "left",
      valign = "center",
      widget = wibox.widget.textbox,
    },
    fg            = p.text_muted,
    forced_height = dpi(18),
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

  client.connect_signal("manage", schedule_rebuild)
  client.connect_signal("unmanage", schedule_rebuild)
  client.connect_signal("property::name", schedule_rebuild)
  -- "refresh" cobre mudanças de conjunto/foco que não disparam manage/unmanage.
  awesome.connect_signal("refresh", schedule_rebuild)

  -- Render inicial.
  rebuild()

  local panel = require("src.tools.panel")
  return panel({
    title  = "APPLICATIONS",
    body   = rows,
    accent = p.v500,
    w      = args.w or dpi(260),
  })
end
