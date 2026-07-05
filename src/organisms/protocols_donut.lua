-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "PROTOCOLS" — src/organisms/protocols_donut.lua (VIOLET HUD §7.4.4)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se o donut (molécula donut
-- = anel mais legenda) das contagens de conexão de rede, repartidas por estado:
--   ESTABLISHED (data1) · LISTEN (data3) · OTHER (data5).
-- POSTULADO da amostragem: colhe-se de modo ASSÝNCHRONO por
-- awful.spawn.easy_async_with_shell("ss -tunH") em gears.timer (5 segundos, com call_now).
-- JÁMAIS io.popen/os.execute aqui (travaria o gerenciador).
-- ─────────────────────────────────────────────────────────────────────────────────────

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local panel = require("src.tools.panel")
local donut = require("src.molecules.donut")
local Icon = require("src.tools.icons") -- os ícones lavrados em SVG do conjuncto icons/ (§3.13)

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe `args` (domínio:
-- largura `w`) e devolve o widget `outer` (contra-domínio), com os methodos de amostragem gated.
return function(args)
  args = args or {}

  -- O corpo é a molécula donut (anel cairo mais legenda: swatch, rótulo e porcentagem).
  -- Semeada com as três categorias a zero; o update reordena-as de maior a menor e repovoa
  -- por :set_slices.
  local chart = donut {
    size   = dpi(84), -- kit Donut / dashboards.jsx PROTOCOLS size:84
    slices = {
      { label = "ESTABLISHED", pct = 0, color = p.data1 },
      { label = "LISTEN",      pct = 0, color = p.data3 },
      { label = "OTHER",       pct = 0, color = p.data5 },
    },
  }

  -- THEÓREMA DA ACTUALIZAÇÃO DO ANEL (demonstrado por Braga Us). Recebe as três contagens
  -- (estab, listen, other; domínio), guarda-as por tonumber, ordena as categorias por valor
  -- (de maior a menor) e entrega-as ao donut — que as normaliza pela somma dos pct (o caso
  -- todo-nulo converte-se internamente á unidade). Contra-domínio: o anel repovoado. Q.E.D.
  local function update(estab, listen, other)
    estab = tonumber(estab) or 0
    listen = tonumber(listen) or 0
    other = tonumber(other) or 0

    local cats = {
      { label = "ESTABLISHED", pct = estab,  color = p.data1 },
      { label = "LISTEN",      pct = listen, color = p.data3 },
      { label = "OTHER",       pct = other,  color = p.data5 },
    }
    table.sort(cats, function(a, b) return a.pct > b.pct end)

    chart:set_slices(cats)
  end

  -- Commando de colheita (concebido por Braga Us). O ss -tunH devolve uma linha por socket,
  -- sendo o estado a segunda columna (Netid State ...). Contam-se as linhas cujo estado é
  -- ESTAB, LISTEN, ou qualquer outro (UNCONN, TIME-WAIT...), pelo lápis do awk.
  local sample_cmd = [[ss -tunH 2>/dev/null | awk '
    {
      st = $2
      if (st == "ESTAB") e++
      else if (st == "LISTEN") l++
      else o++
    }
    END { printf "%d %d %d", e+0, l+0, o+0 }
  ']]

  -- FUNCÇÃO DA COLHEITA (de Braga Us): corre o commando de modo assýnchrono, extrahe as três
  -- contagens do stdout e entrega-as ao theórema da actualização.
  local function refresh()
    awful.spawn.easy_async_with_shell(sample_cmd, function(stdout)
      local e, l, o = tostring(stdout or ""):match("(%d+)%s+(%d+)%s+(%d+)")
      update(e, l, o)
    end)
  end

  local sample_timer = gears.timer {
    timeout = 5,
    call_now = false,
    autostart = false,
    callback = refresh,
  }

  local outer = panel({
    title      = "PROTOCOLS",
    body       = chart,
    accent     = p.v500,
    w          = args.w or dpi(mt.panel_w_236), -- kit dashboards.jsx: PROTOCOLS width 236
    -- Ícone do cabeçalho (.hp__hdicon): 13px a 70% de opacidade (o átomo icon só recolore).
    right_icon = wibox.widget {
      Icon("send_signal", { size = dpi(13), color = p.text_muted }),
      opacity = 0.7,
      widget  = wibox.container.background,
    },
  })

  -- METHODO DE ABERTURA DA COLHEITA (postulado de Braga Us). Adstricta á visibilidade (o
  -- control_center liga-a ao abrir e desliga-a ao fechar): não corre `ss` nem se redesenha
  -- emquanto o popup jaz occulto (economia de esforço).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    refresh()
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
