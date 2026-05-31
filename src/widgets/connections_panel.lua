------------------------------------------------------------------------------------------
-- src/widgets/connections_panel.lua — Painel "CONNECTIONS" (VIOLET HUD §7.4.8)            --
--                                                                                        --
-- Lista as conexões de rede (até 6) via `ss -tunH`. Cada linha:                          --
--   PROTO (text_muted) | peer addr encurtado (text_primary) | ESTADO (colorido à direita) --
-- Estado: ESTAB->ok, LISTEN->text_muted, TIME-WAIT/TIME_WAIT->warn, else text_body.       --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (5s,         --
-- call_now). NUNCA io.popen/os.execute — congela o WM (deadlock conhecido neste repo).    --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")

local FONT = "JetBrainsMono Nerd Font 9"
local ROWS = 6
local PEER_MAX = 22 -- máximo de chars no peer addr antes de encurtar

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

    local row = wibox.widget {
      {
        proto,
        fg = p.text_muted,
        widget = wibox.container.background,
      },
      {
        {
          peer,
          fg = p.text_primary,
          widget = wibox.container.background,
        },
        left = dpi(6),
        right = dpi(6),
        widget = wibox.container.margin,
      },
      state,
      forced_height = dpi(18),
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    }

    row._proto = proto
    row._peer = peer
    row._state = state
    return row
  end

  local rows = {}
  local list = wibox.layout.fixed.vertical()
  list.spacing = dpi(2)
  for i = 1, ROWS do
    rows[i] = make_row()
    list:add(rows[i])
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
    forced_height = dpi(18),
    widget = wibox.container.margin,
  }

  -- Container que troca entre a lista e a linha vazia.
  local body = wibox.widget {
    list,
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
      body:add(list)
      showing_empty = false
    end
  end

  -- Atualiza uma linha com proto/peer/state já parseados.
  local function set_row(i, proto, peer, state)
    local row = rows[i]
    if not row then
      return
    end
    if proto then
      row._proto:set_text(tostring(proto):upper())
      row._peer:set_text(shorten(peer))
      row._state.markup = string.format(
        "<span foreground='%s'>%s</span>",
        state_color(state),
        tostring(state or ""):upper()
      )
      row.visible = true
    else
      -- Limpa linhas não usadas.
      row._proto:set_text("")
      row._peer:set_text("")
      row._state:set_text("")
      row.visible = false
    end
  end

  local function update()
    awful.spawn.easy_async_with_shell(
      "ss -tunH 2>/dev/null | head -n 6",
      function(stdout)
        stdout = stdout or ""
        local count = 0
        for line in stdout:gmatch("[^\n]+") do
          -- Colunas do ss -tunH: netid state recv-q send-q local-addr peer-addr ...
          local fields = {}
          for tok in line:gmatch("%S+") do
            fields[#fields + 1] = tok
          end
          if fields[1] then
            count = count + 1
            local netid = fields[1]
            local state = fields[2]
            -- local addr = fields[5]; peer addr = fields[6] (após recv-q/send-q)
            local peer = fields[6] or fields[5] or ""
            set_row(count, netid, peer, state)
          end
          if count >= ROWS then
            break
          end
        end

        -- Limpa as linhas restantes.
        for i = count + 1, ROWS do
          set_row(i, nil)
        end

        if count == 0 then
          show_empty()
        else
          show_list()
        end
      end
    )
  end

  gears.timer {
    timeout = 5,
    autostart = true,
    call_now = true,
    callback = update,
  }

  return panel({
    title = "CONNECTIONS",
    body = body,
    accent = p.v500,
    w = args.w or dpi(300),
  })
end
