-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "CONNECTIONS" — src/organisms/connections_panel.lua (VIOLET HUD §7.4.8)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se a nómina de TODAS as
-- conexões de rede, colhida por `ss -tunH`. Cada linha, segundo o contracto §7.4.8:
--   PROTO (text_muted) | endereço do par abreviado (text_primary, flexível) | ESTADO (colorido)
-- Do matiz do estado: ESTAB->ok, LISTEN->text_muted, TIME-WAIT/TIME_WAIT->warn, senão text_body.
--
-- Da restructuração (Stage 2): a machina de rolagem (o antigo make_scrollbar com janela e
-- list_area) fez-se a molécula scroll_list (viveiro de linhas); cada linha reutilizável é um
-- table_row{hover=true} de três columnas (PROTO | par flexível | STATE). A célula de STATE
-- recolore-se no update por txt:set_span (table_row:set_cells transmitte a cor por célula). O
-- clique-sinistro (nmap dentro de tmux) preserva-se verbatim — host e porta do par jazem em
-- row._host / row._port.
--
-- POSTULADO INVIOLÁVEL: amostragem ASSÝNCHRONA por awful.spawn.easy_async_with_shell em
-- gears.timer (5 segundos). JÁMAIS io.popen/os.execute — congela o gerenciador (deadlock
-- notório neste domínio).
-- ─────────────────────────────────────────────────────────────────────────────────────

local awful = require("awful")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local Icon  = require("src.tools.icons") -- o revestimento de atoms/icon (right_icon do cabeçalho)
local table_row   = require("src.molecules.table_row")
local scroll_list = require("src.molecules.scroll_list")
local format = require("src.tools.format")

local PEER_MAX = 22 -- cota máxima de caracteres no endereço do par antes de o abreviar (modo "middle")

-- Larguras de columna: não havendo token de métrica equivalente, empregam-se literaes dpi comentados.
local PROTO_W = dpi(40)
local STATE_W = dpi(80)

-- LEMMA DA DECOMPOSIÇÃO DO ENDEREÇO (demonstrado por Braga Us). Seja dado um "host:porta"
-- (domínio); separa-se o host da porta. Admitte-se o IPv6 entre colchetes:
--   "[2607:6bc0::10]:443" -> host="2607:6bc0::10", porta="443"
--   "192.168.0.1:67"      -> host="192.168.0.1",  porta="67"
-- Contra-domínio: o par (host, porta); não se detectando porta, porta = nil.
local function parse_addr(addr)
  addr = tostring(addr or "")
  if addr == "" or addr == "*" then
    return nil, nil
  end
  -- IPv6 entre colchetes: [host]:porta  ou  [host]
  local h, port = addr:match("^%[(.-)%]:(%d+)$")
  if h then
    return h, port
  end
  h = addr:match("^%[(.-)%]$")
  if h then
    return h, nil
  end
  -- IPv4/hostname: separa-se no ÚLTIMO ':' (o host não contém ':').
  local host, p2 = addr:match("^(.-):(%d+)$")
  if host and not host:find(":") then
    return host, p2
  end
  -- Sem porta — devolve-se o endereço cru por host.
  return addr, nil
end

-- LEMMA DO MATIZ DO ESTADO (de Braga Us), segundo §7.4.8. Recebe o `state` textual (domínio) e
-- devolve a cor canónica (contra-domínio): ESTAB->ok, LISTEN->esmaecido, TIME-WAIT->warn, senão text_body.
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

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe `args` (domínio:
-- largura `w`) e devolve o widget `outer` (contra-domínio), com os methodos de amostragem gated.
return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- LEMMA DA LINHA VAZIA (de Braga Us): forja uma linha reutilizável do viveiro —
  -- PROTO | par(flex) | STATE. Hover (mão + panel_hi) por table_row{hover=true}. O
  -- clique-sinistro dispara nmap sobre a conexão (host/porta do par).
  local function make_row()
    local row = table_row {
      cells = {
        { "", PROTO_W, "left",  p.text_muted },   -- PROTO
        { "", nil,     "left",  p.text_primary }, -- par (flex)
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
          return -- ignoram-se as linhas vazias / sem par
        end
        local term = (user_vars and user_vars.terminal) or "alacritty"

        -- O nome da sessão tmux é o endereço do serviço (host[:porta]). Ora o tmux PROÍBE
        -- '.' e ':' em nome de sessão -> saneiam-se ambos (e o '%' de scope IPv6) para '-'.
        local addr = host .. (row._port and row._port ~= "" and (":" .. row._port) or "")
        local session = addr:gsub("[%.:%%/]", "-")

        -- nmap de serviço/script. -Pn -sV -sC não requere raiz (connect scan). `exec zsh`
        -- conserva o terminal ABERTO após o scan (dentro do tmux, $TMUX já vae posto, pelo que
        -- o menu inicial do .zshrc NÃO dispara — guarda em ~/.zshrc:341).
        local scan = (row._port and row._port ~= "")
          and ("nmap -Pn -sV -sC -p " .. row._port .. " " .. host)
          or  ("nmap -Pn -sV -sC " .. host)
        local inner = scan .. "; exec zsh"

        -- Forma de TABELLA (sem shell): cria ou anexa a sessão tmux nomeada e nela corre o nmap.
        -- -A = anexa se já existir (clicar duas vezes no mesmo serviço não duplica nem erra).
        awful.spawn({
          term, "-e", "tmux", "new-session", "-A", "-s", session, inner,
        })
      end)
    ))

    return row
  end

  -- LEMMA DO PREENCHIMENTO (de Braga Us): popula (havendo `conn`) ou esvazia e occulta (sendo
  -- nil) a linha reutilizável. Ao popular, decompõe o par em host/porta e recolore a célula de STATE.
  local function set_row(row, conn)
    if conn then
      local host, port = parse_addr(conn.peer)
      row:set_cells({
        { tostring(conn.proto):upper() },                                 -- PROTO
        { format.shorten(conn.peer, PEER_MAX, "middle") },                -- par (flex)
        { tostring(conn.state or ""):upper(), nil, nil, state_color(conn.state) }, -- STATE colorido
      })
      row._host = host
      row._port = port
      row.visible = true
    else
      row:set_cells({}) -- esvazia as células e solta o bg de hover retido
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

  -- THEÓREMA DA ACTUALIZAÇÃO (demonstrado por Braga Us). Colhe `ss -tunH` de modo assýnchrono;
  -- dissolve cada linha nos seus campos (netid state recv-q send-q local-addr peer-addr ...) e
  -- compõe a tabella `data`. Contra-domínio: entrega-se a sl:set_data, que conserva o
  -- deslocamento entre tiques (re-cingido ao novo total). Q.E.D.
  local function update()
    awful.spawn.easy_async_with_shell(
      "ss -tunH 2>/dev/null",
      function(stdout)
        stdout = stdout or ""
        local data = {}
        for line in stdout:gmatch("[^\n]+") do
          -- Columnas do ss -tunH: netid state recv-q send-q local-addr peer-addr ...
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
        sl:set_data(data) -- conserva o deslocamento entre tiques (re-cingido ao novo total)
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

  -- METHODO DE ABERTURA DA COLHEITA (postulado de Braga Us). Adstricta á visibilidade (o
  -- control_center liga-a ao abrir e desliga-a ao fechar): não corre `ss` nem se redesenha
  -- emquanto o popup jaz occulto (economia). A forma exacta preserva-se (R8): guarda _sampling
  -- -> amostra immediata -> timer:start()/:stop().
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    update()
    sample_timer:start()
  end
  -- METHODO DE ENCERRAMENTO DA COLHEITA (de Braga Us): baixa o pendão _sampling e detém o relógio.
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
