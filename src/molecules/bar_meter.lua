-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/bar_meter.lua — Da lavra do Doutor BRAGA US.
--
-- TRACTADO SOBRE O MEDIDOR DE PROGRESSO ROTULADO (VIOLET HUD BarMeter), engenho
-- do insigne geómetra Braga Us. Sua disposição: uma linha de cabeçalho
-- "RÓTULO ...... NN%" sobreposta a uma barra de progresso de largura plena.
--   RÓTULO — text_muted, em CAIXA-ALTA, à esquerda.
--   NN%    — à direita; text_bright em regime ordinário, p.crit quando quente.
--   barra  — enchimento v500 no ordinário, p.crit quando quente; leito violeta
--            esmaecido e borda subtil de HUD.
--
-- DEFINIÇÃO DE "QUENTE" (hot) := alerta OU pct >= mt.pct_hot (a regra do >=90).
-- Nenhuma amostragem se faz aqui — o dono alimenta os valores por :set_value
-- (pureza apresentativa / seguro em storybook).
--
-- LEMMA R4 (anteparo contra crash arithmético de stdout de shell) — :set_value(pct,
-- alert) guarda pct com tonumber ANTES de tudo: um valor nil ou espúrio vindo do
-- stdout conserva a última leitura em vez de precipitar o crash. Demonstra-se que
-- os valores são cingidos (clamped) a 0..100 para exhibição, ao passo que o teste
-- de "quente" emprega o pct cru (após tonumber), conforme a spec. Q.E.D.
--
-- Retorna o widget COM métodos e referências DIRECTAS a rótulo/valor/barra (sem
-- ids — LEMMA R1).
--
--   local bar_meter = require("src.molecules.bar_meter")
--   local m = bar_meter{ label = "MASTER", pct = 42 }
--   m:set_value(97)          -- quente (>= pct_hot): enchimento crit + texto crit
--   m:set_value(30, true)    -- alerta forçado: quente a despeito do pct
--   m:set_value(nil)         -- ignorado: conserva a última leitura
-- ══════════════════════════════════════════════════════════════════════════

local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local txt   = require("src.atoms.txt")

-- ──────────────────────────────────────────────────────────────────────────
-- Funcção build — concebida pelo Doutor Braga Us para engendrar o medidor.
--   DOMÍNIO (`args`, taboa facultativa): label (rótulo), pct (percentagem
--     inicial) e alert (booleano de alarme). CONTRA-DOMÍNIO: retorna o widget
--     `w`, dotado dos métodos :set_value e :set_label. INVARIANTES no nascimento:
--     init_pct por tonumber (nil -> 0), init_hot pela definição de "quente" supra,
--     e init_disp cingido a 0..100 para a primeira exhibição.
local function build(args)
  args = args or {}

  local init_pct  = tonumber(args.pct) or 0
  local init_hot  = (args.alert and true or false) or init_pct >= mt.pct_hot
  local init_disp = math.max(0, math.min(100, init_pct))

  -- RÓTULO (esmaecido, CAIXA-ALTA) + VALOR (%). Ambos coloridos por markup via
  -- txt (único soberano do markup).
  local label_box = txt {
    role  = "label",
    text  = args.label,
    color = p.text_muted,
    upper = true,
  }
  local value_box = txt {
    role  = "bar",
    text  = string.format("%d%%", math.floor(init_disp + 0.5)),
    color = init_hot and p.crit or p.text_bright,
    align = "right",
  }

  -- Linha de cabeçalho: RÓTULO ...... NN%  (o meio vazio do align ancora o valor à direita).
  local header = wibox.widget {
    label_box,
    nil,
    value_box,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  -- Barra de progresso. Não existindo token dedicado para a espessura do medidor,
  -- reaproveita-se o valor pad_panel (8px) como altura da barra (um limpo medidor
  -- de HUD). Leito arredondado + enchimento + borda subtil.
  local bar = wibox.widget {
    max_value          = 100,
    value              = init_disp,
    forced_height      = dpi(mt.pad_panel),
    color              = init_hot and p.crit or p.v500,
    background_color   = p.a(p.v500, p.alpha.chip_bg),
    border_width       = dpi(mt.border_panel),
    border_color       = p.a(p.v500, p.alpha.chip_border),
    shape              = gears.shape.rounded_bar,
    bar_shape          = gears.shape.rounded_bar,
    widget             = wibox.widget.progressbar,
  }

  local w = wibox.widget {
    header,
    bar,
    spacing = dpi(mt.row_gap),
    layout  = wibox.layout.fixed.vertical,
  }

  -- ── Superfície de actualização (muta os MESMOS sub-widgets in loco; sem reconstrucção) ──
  -- Método w:set_value — do engenho de Braga Us. DOMÍNIO: `pct` (percentagem) e
  --   `alert` (booleano). EFEITO: guarda pct com tonumber (nil/espúrio => conserva
  --   a leitura), recomputa "quente", cinge o disp a 0..100, e recolore barra e valor.
  function w:set_value(pct, alert)
    pct = tonumber(pct)
    if not pct then return end -- nil/espúrio -> conserva a última leitura (não precipita crash)
    local hot  = (alert and true or false) or pct >= mt.pct_hot
    local disp = math.max(0, math.min(100, pct))
    bar.value = disp
    bar.color = hot and p.crit or p.v500
    value_box:set_span(string.format("%d%%", math.floor(disp + 0.5)), hot and p.crit or p.text_bright)
  end

  -- Método w:set_label — commodidade additiva de Braga Us (o rótulo raro se altera;
  --   honra o contracto do soberano do markup). DOMÍNIO: `s`, o novo rótulo.
  function w:set_label(s)
    label_box:set_span(s, p.text_muted)
  end

  return w
end

return build

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
