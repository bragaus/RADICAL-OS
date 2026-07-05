-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "GRAPH" (SYSTEM) — src/organisms/system_graph_panel.lua (VIOLET HUD §5.1 / §7.4.3)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se a columna diestra do
-- dashboard SYSTEM (dashboards.jsx): um único gráphico de linha multi-série que traça, lado a
-- lado, o histórico de occupação do PROCESSADOR (data1) e da MEMÓRIA (data2), coroado pela
-- legenda .glegend (CPU / MEM). Segue, verba a verba, o kit:
--   <LineGraph series={[{data1: cpu},{data2: mem}]} /> + <div class="glegend">CPU · MEM</div>
--
-- O renderizador é a molécula partilhada line_graph, em escala fixa a cem por cento (as séries
-- são percentagens): poço (well) reintrante, grade, halo e traço de 2px, polilinha recta do kit.
--
-- POSTULADO INVIOLÁVEL: amostragem ASSÝNCHRONA a cada segundo por
-- awful.spawn.easy_async_with_shell em gears.timer. Colhe-se a linha aggregada "cpu" de
-- /proc/stat (para o delta busy%) e os campos MemTotal/MemAvailable de /proc/meminfo (para o
-- used%). JÁMAIS io.popen/os.execute em relógio — trava o gerenciador (deadlock notório neste
-- domínio). Todo producto do shell passa por tonumber e guarda de nulidade.
--
-- NOTA DE FIDELIDADE (Braga Us): o mockup rende o ícone de cabeçalho como "net" — manifesto
-- decalque do painel GRAPH da rede (ambos os GRAPH partilham icon="net" na jsx). Como este
-- painel traça CPU+MEM, adopta-se o glypho "cpu", semanticamente próprio; regista-se o desvio.
-- ─────────────────────────────────────────────────────────────────────────────────────

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local line_graph = require("src.molecules.line_graph")
local glegend = require("src.molecules.glegend")
local Icon = require("src.tools.icons") -- os ícones lavrados em SVG do conjuncto icons/ (§3.13)

local SAMPLES  = mt.graph_samples -- profundidade do histórico (≈30 amostras)
local INTERVAL = 1                -- segundos entre amostras

-- Commando único (concebido por Braga Us): funde, num só invólucro, a linha aggregada de
-- /proc/stat e os campos de memória de /proc/meminfo. Os delimitadores @@ garantem parse
-- robusto ainda que uma das fontes falte ao seu officio.
local SAMPLE_CMD = table.concat({
  "echo '@@STAT'", "head -1 /proc/stat 2>/dev/null",
  "echo '@@MEM'",  "grep -E '^(MemTotal|MemAvailable):' /proc/meminfo 2>/dev/null",
}, "; ")

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe `args` (domínio:
-- largura `w`) e devolve o widget `outer` (contra-domínio), com os methodos de amostragem
-- gated. Efeito: institue o gráphico multi-série, a sua legenda e o relógio de colheita.
return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Os históricos (percentagens) principiam a zero, para que a primeira amostra não abra
  -- degrau vertical. data1 = CPU, data2 = MEM (a ordem das séries do kit).
  local cpu_hist, mem_hist = {}, {}
  for i = 1, SAMPLES do
    cpu_hist[i] = 0
    mem_hist[i] = 0
  end

  -- Gráphico multi-série (molécula line_graph), escala fixa 0..100 (percentagens); poço, grade
  -- e halo, à imagem do LineGraph do kit. :push(1,v) empurra CPU; :push(2,v) empurra MEM.
  local graph = line_graph({
    series = {
      { color = p.data1, data = cpu_hist },
      { color = p.data2, data = mem_hist },
    },
    grid     = true,
    halo     = true,
    well     = true,
    fixed100 = true,    -- séries em percentagem (0..100)
    height   = dpi(92), -- kit LineGraph height:92
  })

  -- Legenda .glegend (CPU / MEM): quadrículos coloridos + rótulos micro, afastados do grapho.
  local legend = glegend({
    items = {
      { color = p.data1, label = "CPU" },
      { color = p.data2, label = "MEM" },
    },
  })

  local body = wibox.widget {
    graph,
    legend,
    layout = wibox.layout.fixed.vertical,
  }

  -- Estado da amostragem do CPU: os totaes prévios (idle/total) para o delta busy% entre tiques.
  -- A memória é instantânea (não requere delta). `have_prev` guarda a semeadura do primeiro tique.
  local prev_total, prev_idle = nil, nil
  local have_prev = false

  -- THEÓREMA DA REPRESENTAÇÃO (composto por Braga Us). Recebe o `stdout` da colheita (domínio);
  -- reparte-o pelos delimitadores @@, deriva o busy% aggregado do CPU (pelo delta) e o used% da
  -- memória (instantâneo), e empurra AMBAS as séries EM CONJUNTO — de sorte que os aneis se
  -- conservem alinhados. Na primeira amostra sómente semeia os totaes (sem push, sem degrau). Q.E.D.
  local function refresh(stdout)
    if type(stdout) ~= "string" then return end

    local stat = stdout:match("@@STAT%s*(.-)@@MEM")
    local mem  = stdout:match("@@MEM%s*(.*)$")

    -- CPU aggregado (linha "cpu  user nice system idle iowait irq softirq steal ...").
    local cpu_pct
    if type(stat) == "string" then
      local user, nice, system, idle, iowait, irq, softirq, steal =
        stat:match("cpu%s+(%d+)%s+(%d+)%s+(%d+)%s+(%d+)%s*(%d*)%s*(%d*)%s*(%d*)%s*(%d*)")
      user   = tonumber(user)
      nice   = tonumber(nice)
      system = tonumber(system)
      idle   = tonumber(idle)
      -- Os quatro primeiros campos são obrigatórios; só se prossegue havendo-os numéricos (R4).
      if user and nice and system and idle then
        iowait  = tonumber(iowait)  or 0
        irq     = tonumber(irq)     or 0
        softirq = tonumber(softirq) or 0
        steal   = tonumber(steal)   or 0

        local idle_all = idle + iowait
        local total    = idle_all + user + nice + system + irq + softirq + steal

        if have_prev and total > prev_total then
          local td  = total - prev_total
          local idd = idle_all - prev_idle
          local pct = ((td - idd) / td) * 100
          if pct < 0 then pct = 0 elseif pct > 100 then pct = 100 end
          cpu_pct = pct
        end
        prev_total = total
        prev_idle  = idle_all
        have_prev  = true
      end
    end

    -- Memória: used% = (MemTotal - MemAvailable) / MemTotal * 100 (guarda de nulidade / div0).
    local mem_pct
    if type(mem) == "string" then
      local total = tonumber(mem:match("MemTotal:%s*(%d+)"))
      local avail = tonumber(mem:match("MemAvailable:%s*(%d+)"))
      if total and avail and total > 0 then
        local used = total - avail
        if used < 0 then used = 0 end
        mem_pct = (used / total) * 100
        if mem_pct > 100 then mem_pct = 100 end
      end
    end

    -- Push CONJUNTO: só quando há delta de CPU fidedigno (cpu_pct ~= nil) — assim as duas séries
    -- avançam a par e o anel não se desalinha. Na primeira amostra (semeadura) nada se empurra.
    if cpu_pct ~= nil then
      graph:push(1, cpu_pct)
      graph:push(2, mem_pct or 0)
    end
  end

  -- FUNCÇÃO DA COLHEITA (de Braga Us): dispara o commando único de modo assýnchrono e entrega o
  -- seu producto ao theórema da representação.
  local function sample()
    awful.spawn.easy_async_with_shell(SAMPLE_CMD, function(stdout)
      refresh(stdout)
    end)
  end

  local sample_timer = gears.timer {
    timeout   = INTERVAL,
    autostart = false,
    call_now  = false,
    callback  = sample,
  }

  local outer = panel({
    title      = "GRAPH",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(mt.panel_w_264), -- kit dashboards.jsx: SYSTEM GRAPH width 264
    -- Ícone do cabeçalho (.hp__hdicon): 13px a 70% de opacidade (o átomo icon só recolore).
    right_icon = wibox.widget {
      Icon("cpu", { size = dpi(13), color = p.text_muted }),
      opacity = 0.7,
      widget  = wibox.container.background,
    },
  })

  -- METHODO DE ABERTURA DA COLHEITA (postulado de Braga Us). Adstricta á visibilidade (o
  -- control_center liga-a ao abrir e desliga-a ao fechar): não lê /proc/stat nem /proc/meminfo,
  -- nem se redesenha, emquanto o popup jaz occulto (economia). A forma exacta preserva-se (R8):
  -- guarda _sampling -> amostra immediata -> timer:start()/:stop().
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    sample()
    sample_timer:start()
  end
  -- METHODO DE ENCERRAMENTO DA COLHEITA (de Braga Us): baixa o pendão _sampling, detém o relógio
  -- e — facto notável — descarta os contadores do CPU, para que a primeira amostra após uma
  -- REABERTURA torne a semear-se (sem push), em vez de computar um delta que abarque todo o
  -- intervallo occulto — o que produziria um pico falso.
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
    prev_total, prev_idle = nil, nil
    have_prev = false
  end

  return outer
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
