------------------------------------------------------------------------------------------
-- src/widgets/process_panel.lua — Painel "PROCESS" (VIOLET HUD §7.4.7)                    --
--                                                                                        --
-- Top 6 processos por uso de CPU. Cada linha: PID (text_muted) · NOME (text_primary,     --
-- esquerda, ~10 chars) · CPU% (text_bright, direita) · MEM% (text_muted) · KILL (skull,  --
-- text_muted -> crit no hover; clique-esquerdo envia SIGTERM ao PID via awful.spawn).     --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (3s).       --
-- NUNCA usar io.popen/os.execute em timer — trava o WM (deadlock conhecido neste repo).  --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")

local MONO = "JetBrainsMono Nerd Font"
local ROWS = 6
local SAMPLE_CMD = "ps -eo pid,comm,pcpu,pmem --sort=-pcpu --no-headers | head -n " .. ROWS

-- Encurta o nome do processo para ~10 chars (com reticências).
local function shorten(name, max)
  max = max or 10
  if #name > max then
    return name:sub(1, max - 1) .. "…"
  end
  return name
end

-- Monta uma textbox simples com fonte mono e cor fixa.
local function cell(text, color, align, width)
  return wibox.widget {
    {
      text   = text or "",
      font   = MONO .. " 9",
      align  = align or "left",
      valign = "center",
      widget = wibox.widget.textbox,
    },
    fg            = color,
    forced_width  = width,
    widget        = wibox.container.background,
  }
end

-- Glyph da skull (Nerd Font) usado como controle de KILL.
local KILL_GLYPH = "" -- nf-md-skull

-- Célula de KILL: clique-esquerdo envia SIGTERM ao PID; hover -> crit.
local function kill_cell(pid)
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

  -- Recolore o fg para crit no hover (bg=nil -> só muda o fg).
  Hover_signal(cellbg, nil, p.crit)

  cellbg:buttons(awful.util.table.join(
    awful.button({}, 1, function()
      if pid and tonumber(pid) then
        awful.spawn({ "kill", tostring(pid) }) -- SIGTERM
      end
    end)
  ))

  return cellbg
end

-- Constrói uma linha de processo: PID | NOME | CPU% | MEM% | KILL.
local function build_row(pid, name, cpu, mem)
  return wibox.widget {
    cell(pid,  p.text_muted,   "left",  dpi(44)),
    {
      cell(name, p.text_primary, "left", nil),
      layout = wibox.layout.flex.horizontal,
    },
    {
      cell(cpu, p.text_bright, "right", dpi(44)),
      cell(mem, p.text_muted,  "right", dpi(44)),
      kill_cell(pid),
      spacing = dpi(4),
      layout  = wibox.layout.fixed.horizontal,
    },
    forced_height = dpi(18),
    spacing       = dpi(6),
    layout        = wibox.layout.align.horizontal,
  }
end

return function(args)
  args = args or {}

  -- Lista vertical que é :reset() e repopulada a cada tick.
  local rows = wibox.widget {
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }

  -- Cabeçalho de colunas (estático).
  local header = wibox.widget {
    cell("PID",  p.text_faint, "left",  dpi(44)),
    {
      cell("NAME", p.text_faint, "left", nil),
      layout = wibox.layout.flex.horizontal,
    },
    {
      cell("CPU%", p.text_faint, "right", dpi(44)),
      cell("MEM%", p.text_faint, "right", dpi(44)),
      cell("",     p.text_faint, "center", dpi(28)),
      spacing = dpi(4),
      layout  = wibox.layout.fixed.horizontal,
    },
    forced_height = dpi(16),
    spacing       = dpi(6),
    layout        = wibox.layout.align.horizontal,
  }

  local body = wibox.widget {
    header,
    rows,
    spacing = dpi(4),
    layout  = wibox.layout.fixed.vertical,
  }

  local function refresh(stdout)
    rows:reset()
    if type(stdout) ~= "string" then return end

    for line in stdout:gmatch("[^\r\n]+") do
      -- ps: pid comm pcpu pmem
      local pid, name, cpu, mem =
        line:match("^%s*(%d+)%s+(.-)%s+([%d%.]+)%s+([%d%.]+)%s*$")

      -- Guardas: só renderiza se PID/CPU/MEM forem numéricos.
      if pid and tonumber(pid) and tonumber(cpu) and tonumber(mem) then
        local cpu_n = tonumber(cpu) or 0
        local mem_n = tonumber(mem) or 0
        local disp_name = shorten(name ~= "" and name or "?", 10)
        rows:add(build_row(
          pid,
          disp_name,
          string.format("%.1f", cpu_n),
          string.format("%.1f", mem_n)
        ))
      end
    end
  end

  local timer = gears.timer {
    timeout   = args.timeout or 3,
    call_now  = true,
    autostart = true,
    callback  = function()
      awful.spawn.easy_async_with_shell(SAMPLE_CMD, function(stdout)
        refresh(stdout)
      end)
    end,
  }
  timer:emit_signal("timeout")

  local panel = require("src.tools.panel")
  return panel({
    title  = "PROCESS",
    body   = body,
    accent = p.v500,
    w      = args.w or dpi(300),
  })
end
