------------------------------------------------------------------------------------------
-- src/organisms/process_panel.lua — Painel "PROCESS" (VIOLET HUD §7.4.7)                    --
--                                                                                        --
-- TODOS os processos por uso de CPU. Cada linha: PID (text_muted) · NOME (text_primary,  --
-- esquerda, ~10 chars) · CPU% (text_bright, direita) · MEM% (text_muted) · KILL (skull,  --
-- text_muted -> crit no hover; clique-esquerdo envia SIGTERM ao PID via awful.spawn).     --
--                                                                                        --
-- SCROLL (VIOLET HUD §7.4.7): a janela mostra VISIBLE linhas de altura FIXA — o painel    --
-- NÃO cresce. A amostra guarda a lista inteira; a roda do mouse (botões 4/5) desliza o    --
-- offset e re-renderiza só a fatia visível. Barra fina à direita (track + thumb v500)     --
-- indica posição/proporção. Padrão reusável p/ qualquer lista densa (ver §7.4.7).         --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (3s).       --
-- NUNCA usar io.popen/os.execute em timer — trava o WM (deadlock conhecido neste repo).  --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)

local KILL_SVG = gears.filesystem.get_configuration_dir() .. "icons/svg/kill.svg"
local MONO = "JetBrainsMono Nerd Font"

local VISIBLE  = 6           -- linhas mostradas (altura fixa do painel — NÃO cresce)
local ROW_H    = dpi(18)     -- altura de cada linha
local ROW_GAP  = dpi(2)      -- espaçamento entre linhas
local GUTTER   = dpi(10)     -- calha à direita onde mora a barra de rolagem
local SB_W     = dpi(4)      -- largura da barra de rolagem
-- altura fixa da área de linhas (VISIBLE linhas + gaps) — trava o tamanho do painel
local AREA_H   = VISIBLE * ROW_H + (VISIBLE - 1) * ROW_GAP
-- Amostra a lista INTEIRA, ordenada por CPU desc (sem head: o scroll mostra todos).
local SAMPLE_CMD = "ps -eo pid,comm,pcpu,pmem --sort=-pcpu --no-headers"

-- "#RRGGBB" + alpha(0..1) -> "#RRGGBBAA"
local function a(hex, alpha)
  return string.format("%s%02x", hex, math.floor((alpha or 1) * 255 + 0.5))
end

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

-- Célula de KILL: ícone SVG (set icons/), clique-esquerdo envia SIGTERM ao PID; hover -> crit.
local function kill_cell(pid)
  local ib = Icon("kill", { size = dpi(14), color = p.text_muted })
  local cellbg = wibox.widget {
    { ib, widget = wibox.container.place },
    forced_width = dpi(28),
    widget       = wibox.container.background,
  }

  -- Recolore a imagem para crit no hover (imagebox não muda cor via fg).
  cellbg:connect_signal("mouse::enter", function() ib.image = gears.color.recolor_image(KILL_SVG, p.crit) end)
  cellbg:connect_signal("mouse::leave", function() ib.image = gears.color.recolor_image(KILL_SVG, p.text_muted) end)
  Hover_signal(cellbg, nil, p.crit) -- cursor hand1

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
      cell(mem, p.text_bright, "right", dpi(44)),
      kill_cell(pid),
      spacing = dpi(4),
      layout  = wibox.layout.fixed.horizontal,
    },
    forced_height = ROW_H,
    spacing       = dpi(6),
    layout        = wibox.layout.align.horizontal,
  }
end

-- Barra de rolagem fina (track + thumb). Reflete total/offset/visible; redesenha sob demanda.
local function make_scrollbar()
  local sb = wibox.widget.base.make_widget()
  sb._total, sb._offset, sb._visible = 0, 0, VISIBLE

  function sb:fit(_, _, height) return SB_W, height end

  function sb:draw(_, cr, width, height)
    -- track
    cr:set_source(gears.color(a(p.line_base, 0.5)))
    gears.shape.rounded_bar(cr, width, height)
    cr:fill()
    -- thumb só quando há overflow
    if self._total <= self._visible then return end
    local thumb_h = math.max(height * self._visible / self._total, dpi(12))
    local max_off = self._total - self._visible
    local t       = max_off > 0 and (self._offset / max_off) or 0
    local y       = t * (height - thumb_h)
    cr:set_source(gears.color(p.v500))
    cr:translate(0, y)
    gears.shape.rounded_bar(cr, width, thumb_h)
    cr:fill()
  end

  function sb:update(total, offset, visible)
    self._total, self._offset, self._visible = total, offset, visible
    self:emit_signal("widget::redraw_needed")
  end

  return sb
end

return function(args)
  args = args or {}

  -- Lista vertical que é :reset() e repopulada com a FATIA visível a cada render.
  local rows = wibox.widget {
    spacing = ROW_GAP,
    layout  = wibox.layout.fixed.vertical,
  }

  local scrollbar = make_scrollbar()

  -- Estado de scroll: dados completos + offset da janela.
  local data   = {} -- { {pid,name,cpu,mem}, ... } ordenado por CPU desc
  local offset = 0  -- índice (0-based) da primeira linha visível

  local function max_offset()
    return math.max(0, #data - VISIBLE)
  end

  -- Renderiza só as VISIBLE linhas a partir de `offset` (janela de rolagem).
  local function render_window()
    if offset > max_offset() then offset = max_offset() end
    if offset < 0 then offset = 0 end
    rows:reset()
    for i = offset + 1, math.min(offset + VISIBLE, #data) do
      local r = data[i]
      rows:add(build_row(r.pid, r.name, r.cpu, r.mem))
    end
    scrollbar:update(#data, offset, VISIBLE)
  end

  -- Desliza a janela (delta em linhas) e re-renderiza.
  local function scroll(delta)
    local new_off = offset + delta
    if new_off < 0 then new_off = 0 end
    if new_off > max_offset() then new_off = max_offset() end
    if new_off ~= offset then
      offset = new_off
      render_window()
    end
  end

  -- Cabeçalho de colunas (estático). Mesma calha à direita que as linhas (alinha colunas).
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

  -- Área de linhas: altura FIXA. Linhas (com calha à direita) + barra sobreposta na calha.
  local rows_area = wibox.widget {
    {
      -- camada 1: linhas, recuadas pela calha p/ não colidir com a barra
      { rows, right = GUTTER, widget = wibox.container.margin },
      -- camada 2: barra fixada à direita, centrada na calha
      {
        nil, nil,
        { scrollbar, right = (GUTTER - SB_W) / 2, widget = wibox.container.margin },
        layout = wibox.layout.align.horizontal,
      },
      layout = wibox.layout.stack,
    },
    forced_height = AREA_H,
    bg            = "#00000000",
    widget        = wibox.container.background,
  }

  -- Roda do mouse desliza a janela (1 linha por entalhe) sobre toda a área.
  rows_area:buttons(awful.util.table.join(
    awful.button({}, 4, function() scroll(-1) end),
    awful.button({}, 5, function() scroll(1) end)
  ))

  -- Cabeçalho com a MESMA calha à direita das linhas (mantém colunas alinhadas).
  local body = wibox.widget {
    { header, right = GUTTER, widget = wibox.container.margin },
    rows_area,
    spacing = dpi(4),
    layout  = wibox.layout.fixed.vertical,
  }

  local function refresh(stdout)
    data = {}
    if type(stdout) == "string" then
      for line in stdout:gmatch("[^\r\n]+") do
        -- ps: pid comm pcpu pmem
        local pid, name, cpu, mem =
          line:match("^%s*(%d+)%s+(.-)%s+([%d%.]+)%s+([%d%.]+)%s*$")

        -- Guardas: só guarda se PID/CPU/MEM forem numéricos.
        if pid and tonumber(pid) and tonumber(cpu) and tonumber(mem) then
          local cpu_n = tonumber(cpu) or 0
          local mem_n = tonumber(mem) or 0
          data[#data + 1] = {
            pid  = pid,
            name = shorten(name ~= "" and name or "?", 10),
            cpu  = string.format("%.1f", cpu_n),
            mem  = string.format("%.1f", mem_n),
          }
        end
      end
    end
    render_window() -- mantém o offset entre ticks (clampado ao novo total)
  end

  local function sample()
    awful.spawn.easy_async_with_shell(SAMPLE_CMD, function(stdout)
      refresh(stdout)
    end)
  end

  local sample_timer = gears.timer {
    timeout   = args.timeout or 3,
    call_now  = false,
    autostart = false,
    callback  = sample,
  }

  local panel = require("src.tools.panel")
  local outer = panel({
    title      = "PROCESS",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(300),
    right_icon = Icon("kill_all", { size = dpi(14), color = p.text_muted }),
  })

  -- Sampling gated por visibilidade (control_center liga ao abrir / desliga ao fechar o
  -- dashboard): não roda `ps` nem redesenha enquanto o popup está oculto (perf).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    sample()
    sample_timer:start()
  end
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end
