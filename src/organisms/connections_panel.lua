------------------------------------------------------------------------------------------
-- src/organisms/connections_panel.lua — Painel "CONNECTIONS" (VIOLET HUD §7.4.8)            --
--                                                                                        --
-- Lista TODAS as conexões de rede via `ss -tunH`. Cada linha (contrato §7.4.8):           --
--   PROTO (text_muted) | peer addr encurtado (text_primary, flex) | ESTADO (colorido)      --
-- Estado: ESTAB->ok, LISTEN->text_muted, TIME-WAIT/TIME_WAIT->warn, else text_body.        --
--                                                                                        --
-- REWIRED (Stage 2): a máquina de scroll (make_scrollbar + janela + list_area) virou o     --
-- molecule scroll_list (row-pool); cada linha reusável é um table_row{hover=true} com 3      --
-- colunas (PROTO | peer flex | STATE). A célula de STATE é recolorida por update via         --
-- txt:set_span (table_row:set_cells passa a cor por célula). O clique-esquerdo (nmap em      --
-- tmux) é preservado verbatim — host/port do peer ficam em row._host/_port.                 --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (5s).       --
-- NUNCA io.popen/os.execute — congela o WM (deadlock conhecido neste repo).              --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local Icon  = require("src.tools.icons") -- shim de atoms/icon (right_icon do header)
local table_row   = require("src.molecules.table_row")
local scroll_list = require("src.molecules.scroll_list")
local format = require("src.tools.format")

local PEER_MAX = 22 -- máximo de chars no peer addr antes de encurtar (modo "middle")

-- Larguras de coluna: sem token de métrica equivalente, literais dpi comentados.
local PROTO_W = dpi(40)
local STATE_W = dpi(80)

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

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Uma linha reusável do pool: PROTO | peer(flex) | STATE. Hover (hand1 + panel_hi) via
  -- table_row{hover=true}. Clique-esquerdo dispara nmap na conexão (host/port do peer).
  local function make_row()
    local row = table_row {
      cells = {
        { "", PROTO_W, "left",  p.text_muted },   -- PROTO
        { "", nil,     "left",  p.text_primary }, -- peer (flex)
        { "", STATE_W, "right", p.text_body },    -- STATE (recolorido por update)
      },
      hover = true,
    }
    row._host = nil
    row._port = nil

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

  -- Popula (conn) ou limpa+esconde (nil) a linha reusável.
  local function set_row(row, conn)
    if conn then
      local host, port = parse_addr(conn.peer)
      row:set_cells({
        { tostring(conn.proto):upper() },                                 -- PROTO
        { format.shorten(conn.peer, PEER_MAX, "middle") },                -- peer (flex)
        { tostring(conn.state or ""):upper(), nil, nil, state_color(conn.state) }, -- STATE colorido
      })
      row._host = host
      row._port = port
      row.visible = true
    else
      row:set_cells({}) -- limpa células + solta bg de hover latcheado
      row._host = nil
      row._port = nil
      row.visible = false
    end
  end

  local sl = scroll_list {
    empty_text = "NO CONNECTIONS",
    make_row   = make_row,
    set_row    = set_row,
  }

  local function update()
    awful.spawn.easy_async_with_shell(
      "ss -tunH 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local data = {}
        for line in stdout:gmatch("[^\n]+") do
          -- Colunas do ss -tunH: netid state recv-q send-q local-addr peer-addr ...
          local fields = {}
          for tok in line:gmatch("%S+") do
            fields[#fields + 1] = tok
          end
          if fields[1] then
            data[#data + 1] = {
              proto = fields[1],
              state = fields[2],
              peer  = fields[6] or "",
            }
          end
        end
        sl:set_data(data) -- mantém o offset entre ticks (re-clampado ao novo total)
      end
    )
  end

  local sample_timer = gears.timer {
    timeout = 5,
    autostart = false,
    call_now = false,
    callback = update,
  }

  local outer = panel({
    title      = "CONNECTIONS",
    body       = sl,
    accent     = p.v500,
    w          = args.w or dpi(mt.panel_w_md),
    right_icon = Icon("send_signal", { size = dpi(mt.icon_md), color = p.text_muted }),
  })

  -- Sampling gated por visibilidade (control_center liga ao abrir / desliga ao fechar o
  -- dashboard): não roda `ss` nem redesenha enquanto o popup está oculto (perf). Shape
  -- exato preservado (R8): guard _sampling -> amostra imediata -> timer:start()/:stop().
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    update()
    sample_timer:start()
  end
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end
