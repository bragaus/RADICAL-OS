------------------------------------------------------------------------------------------
-- src/widgets/connections_panel.lua — Painel "CONNECTIONS" (VIOLET HUD §7.4.8)            --
--                                                                                        --
-- Lista TODAS as conexões de rede via `ss -tunH`. Cada linha:                            --
--   PROTO (text_muted) | peer addr encurtado (text_primary) | ESTADO (colorido à direita) --
-- Estado: ESTAB->ok, LISTEN->text_muted, TIME-WAIT/TIME_WAIT->warn, else text_body.       --
--                                                                                        --
-- SCROLL (VIOLET HUD §7.4.7/§7.4.8): a janela mostra VISIBLE linhas de altura FIXA — o     --
-- painel NÃO cresce. A amostra guarda a lista inteira; a roda do mouse (botões 4/5)        --
-- desliza o offset e re-renderiza só a fatia visível nas VISIBLE linhas reusáveis. Barra   --
-- fina à direita (track + thumb v500) indica posição/proporção. Mesmo padrão do PROCESS.   --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (5s,         --
-- call_now). NUNCA io.popen/os.execute — congela o WM (deadlock conhecido neste repo).    --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)

local FONT = "JetBrainsMono Nerd Font 9"
local VISIBLE  = 6           -- linhas mostradas (altura fixa — o painel NÃO cresce)
local ROW_H    = dpi(18)     -- altura de cada linha
local ROW_GAP  = dpi(2)      -- espaçamento entre linhas
local GUTTER   = dpi(10)     -- calha à direita onde mora a barra de rolagem
local SB_W     = dpi(4)      -- largura da barra de rolagem
local AREA_H   = VISIBLE * ROW_H + (VISIBLE - 1) * ROW_GAP -- altura fixa da área de linhas
local PEER_MAX = 22 -- máximo de chars no peer addr antes de encurtar

-- "#RRGGBB" + alpha(0..1) -> "#RRGGBBAA"
local function a(hex, alpha)
  return string.format("%s%02x", hex, math.floor((alpha or 1) * 255 + 0.5))
end

-- Encurta um endereço peer longo mantendo o início e o fim (ex.: "1.2.3.4:443").
local function shorten(addr)
  addr = tostring(addr or "")
  if #addr <= PEER_MAX then
    return addr
  end
  local keep = PEER_MAX - 1
  local head = math.ceil(keep * 0.6)
  local tail = keep - head
  return addr:sub(1, head) .. "…" .. addr:sub(#addr - tail + 1)
end

-- Parseia "host:port" em host e port. Suporta IPv6 entre colchetes:
--   "[2607:6bc0::10]:443" -> host="2607:6bc0::10", port="443"
--   "192.168.0.1:67"      -> host="192.168.0.1",  port="67"
-- Sem porta detectável -> port = nil.
local function parse_addr(addr)
  addr = tostring(addr or "")
  if addr == "" or addr == "*" then
    return nil, nil
  end
  -- IPv6 entre colchetes: [host]:port  ou  [host]
  local h, port = addr:match("^%[(.-)%]:(%d+)$")
  if h then
    return h, port
  end
  h = addr:match("^%[(.-)%]$")
  if h then
    return h, nil
  end
  -- IPv4/hostname: separa no ÚLTIMO ':' (host não contém ':').
  local host, p2 = addr:match("^(.-):(%d+)$")
  if host and not host:find(":") then
    return host, p2
  end
  -- Sem porta — devolve o endereço cru como host.
  return addr, nil
end

-- Cor do estado segundo §7.4.8.
local function state_color(state)
  local s = tostring(state or ""):upper()
  if s == "ESTAB" or s == "ESTABLISHED" then
    return p.ok
  elseif s == "LISTEN" then
    return p.text_muted
  elseif s == "TIME-WAIT" or s == "TIME_WAIT" then
    return p.warn
  else
    return p.text_body
  end
end

-- Barra de rolagem fina (track + thumb). Reflete total/offset/visible; redesenha sob demanda.
local function make_scrollbar()
  local sb = wibox.widget.base.make_widget()
  sb._total, sb._offset, sb._visible = 0, 0, VISIBLE

  function sb:fit(_, _, height) return SB_W, height end

  function sb:draw(_, cr, width, height)
    cr:set_source(gears.color(a(p.line_base, 0.5)))
    gears.shape.rounded_bar(cr, width, height)
    cr:fill()
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
  local panel = require("src.tools.panel")

  -- Constrói uma linha reutilizável: PROTO | peer | STATE.
  local function make_row()
    local proto = wibox.widget {
      font = FONT,
      valign = "center",
      forced_width = dpi(40),
      widget = wibox.widget.textbox,
    }
    -- Endereço local (text_muted) → seta (text_muted) → remoto (text_primary).
    local localaddr = wibox.widget {
      font = FONT,
      valign = "center",
      ellipsize = "end",
      widget = wibox.widget.textbox,
    }
    local arrow = wibox.widget {
      font = FONT,
      valign = "center",
      text = "→",
      widget = wibox.widget.textbox,
    }
    local peer = wibox.widget {
      font = FONT,
      valign = "center",
      ellipsize = "end",
      widget = wibox.widget.textbox,
    }
    local state = wibox.widget {
      font = FONT,
      valign = "center",
      halign = "right",
      forced_width = dpi(80),
      widget = wibox.widget.textbox,
    }

    local inner = wibox.widget {
      {
        proto,
        fg = p.text_muted,
        widget = wibox.container.background,
      },
      {
        {
          {
            localaddr,
            fg = p.text_muted,
            widget = wibox.container.background,
          },
          {
            arrow,
            fg = p.text_muted,
            widget = wibox.container.background,
          },
          {
            peer,
            fg = p.text_primary,
            widget = wibox.container.background,
          },
          spacing = dpi(4),
          layout = wibox.layout.fixed.horizontal,
        },
        left = dpi(6),
        right = dpi(6),
        widget = wibox.container.margin,
      },
      state,
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    }

    -- Container clicável: hover (hand1) + left-click dispara nmap na conexão.
    local row = wibox.widget {
      inner,
      forced_height = ROW_H,
      bg = "#00000000",
      widget = wibox.container.background,
    }

    row._proto = proto
    row._local = localaddr
    row._arrow = arrow
    row._peer = peer
    row._state = state
    row._host = nil
    row._port = nil

    -- Hover (hand1 + bg panel_hi) em todas as linhas reusáveis; as linhas limpas ficam
    -- visible=false (não recebem hover). O bg é re-zerado em set_row p/ não latchar realce.
    Hover_signal(row, p.panel_hi, nil)

    row:buttons(awful.util.table.join(
      awful.button({}, 1, function()
        local host = row._host
        if not host or host == "" then
          return -- ignora linhas vazias / sem peer
        end
        local term = (user_vars and user_vars.terminal) or "alacritty"

        -- Nome da sessão tmux = endereço do serviço (host[:porta]). tmux PROÍBE
        -- '.' e ':' em nomes de sessão -> sanitiza ambos (e '%' de scope IPv6) para '-'.
        local addr = host .. (row._port and row._port ~= "" and (":" .. row._port) or "")
        local session = addr:gsub("[%.:%%/]", "-")

        -- nmap de serviço/script. -Pn -sV -sC não exige root (connect scan). `exec zsh`
        -- mantém o terminal ABERTO após o scan (dentro do tmux $TMUX já está setado, então
        -- o menu inicial do .zshrc NÃO dispara — guarda em ~/.zshrc:341).
        local scan = (row._port and row._port ~= "")
          and ("nmap -Pn -sV -sC -p " .. row._port .. " " .. host)
          or  ("nmap -Pn -sV -sC " .. host)
        local inner = scan .. "; exec zsh"

        -- Forma de TABELA (sem shell): cria/anexa sessão tmux nomeada e roda nmap nela.
        -- -A = anexa se já existir (clicar 2x no mesmo serviço não duplica/erra).
        awful.spawn({
          term, "-e", "tmux", "new-session", "-A", "-s", session, inner,
        })
      end)
    ))

    return row
  end

  local rows = {}
  local list = wibox.layout.fixed.vertical()
  list.spacing = ROW_GAP
  for i = 1, VISIBLE do
    rows[i] = make_row()
    list:add(rows[i])
  end

  local scrollbar = make_scrollbar()

  -- Estado de scroll: dados completos + offset da janela.
  local data   = {} -- { {proto, localaddr, peer, state}, ... }
  local offset = 0  -- índice (0-based) da primeira conexão visível

  local function max_offset()
    return math.max(0, #data - VISIBLE)
  end

  -- Linha única "no connections" (muted) exibida quando não há dados.
  local empty_row = wibox.widget {
    {
      {
        text = "NO CONNECTIONS",
        font = FONT,
        valign = "center",
        halign = "left",
        widget = wibox.widget.textbox,
      },
      fg = p.text_muted,
      widget = wibox.container.background,
    },
    forced_height = ROW_H,
    widget = wibox.container.margin,
  }

  -- Área de linhas: altura FIXA. Lista (com calha à direita) + barra sobreposta na calha.
  local list_area = wibox.widget {
    {
      { list, right = GUTTER, widget = wibox.container.margin },
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

  -- Container que troca entre a área de lista e a linha vazia.
  local body = wibox.widget {
    list_area,
    layout = wibox.layout.fixed.vertical,
  }

  local showing_empty = false
  local function show_empty()
    if not showing_empty then
      body:reset()
      body:add(empty_row)
      showing_empty = true
    end
  end
  local function show_list()
    if showing_empty then
      body:reset()
      body:add(list_area)
      showing_empty = false
    end
  end

  -- Aplica conexão (ou limpa) na linha visual `i`.
  local function set_row(i, conn)
    local row = rows[i]
    if not row then
      return
    end
    if conn then
      row._proto:set_text(tostring(conn.proto):upper())
      row._local:set_text(shorten(conn.localaddr))
      row._arrow:set_text((conn.peer and conn.peer ~= "") and "→" or "")
      row._peer:set_text(shorten(conn.peer))
      row._state.markup = string.format(
        "<span foreground='%s'>%s</span>",
        state_color(conn.state),
        tostring(conn.state or ""):upper()
      )
      -- Guarda host/port do peer para o clique (nmap).
      local host, port = parse_addr(conn.peer)
      row._host = host
      row._port = port
      row.visible = true
    else
      -- Limpa linhas não usadas.
      row._proto:set_text("")
      row._local:set_text("")
      row._arrow:set_text("")
      row._peer:set_text("")
      row._state:set_text("")
      row._host = nil
      row._port = nil
      row.bg = "#00000000" -- limpa realce de hover latcheado se a linha sumir sob o cursor
      row.visible = false
    end
  end

  -- Renderiza só as VISIBLE conexões a partir de `offset` (janela de rolagem).
  local function render_window()
    if offset > max_offset() then offset = max_offset() end
    if offset < 0 then offset = 0 end
    if #data == 0 then
      show_empty()
      scrollbar:update(0, 0, VISIBLE)
      return
    end
    show_list()
    for i = 1, VISIBLE do
      set_row(i, data[offset + i]) -- nil além do fim -> limpa a linha
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

  -- Roda do mouse desliza a janela (1 linha por entalhe) sobre toda a área.
  list_area:buttons(awful.util.table.join(
    awful.button({}, 4, function() scroll(-1) end),
    awful.button({}, 5, function() scroll(1) end)
  ))

  local function update()
    awful.spawn.easy_async_with_shell(
      "ss -tunH 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        data = {}
        for line in stdout:gmatch("[^\n]+") do
          -- Colunas do ss -tunH: netid state recv-q send-q local-addr peer-addr ...
          local fields = {}
          for tok in line:gmatch("%S+") do
            fields[#fields + 1] = tok
          end
          if fields[1] then
            data[#data + 1] = {
              proto     = fields[1],
              state     = fields[2],
              localaddr = fields[5] or "",
              peer      = fields[6] or "",
            }
          end
        end
        render_window() -- mantém o offset entre ticks (clampado ao novo total)
      end
    )
  end

  render_window() -- 1º frame coerente (estado vazio) antes do 1º resultado assíncrono do ss

  gears.timer {
    timeout = 5,
    autostart = true,
    call_now = true,
    callback = update,
  } -- call_now = true já dispara a 1ª amostragem na construção

  return panel({
    title      = "CONNECTIONS",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(300),
    right_icon = Icon("send_signal", { size = dpi(14), color = p.text_muted }),
  })
end
