-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/bar_meter.lua — Da lavra do Doutor BRAGA US.
--
-- TRACTADO SOBRE O MEDIDOR DE PROGRESSO ROTULADO (VIOLET HUD BarMeter, kit .bm),
-- engenho do insigne geómetra Braga Us. Sua disposição, RECONDUZIDA à spec do kit,
-- é UMA só linha horizontal: [rótulo 56px][vão 9][trilho flexível h8][vão 9][valor 38px].
--   RÓTULO — text_muted, em CAIXA-ALTA, à esquerda, largura fixa 56px (.bm__lbl).
--   NN%    — à direita, largura fixa 38px; text_bright em regime ordinário,
--            p.glow_hot quando quente (.bm__val, ExtraBold 11).
--   trilho — leito p.inset (sem borda), raio radius_bar; enchimento frio em
--            gradiente horizontal v700->v500, ou p.glow_hot quando quente (.bm__fill).
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
--   m:set_value(97)          -- quente (>= pct_hot): enchimento glow_hot + texto glow_hot
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

  -- Gradiente frio do enchimento: v700 -> v500, horizontal (.bm__fill). As
  -- coordenadas do gears.color são absolutas; adopta-se a extensão nominal de
  -- 140px (largura típica do trilho num painel de 236 — 56 rótulo, 38 valor, 2×9
  -- de vão, 16 de enchimento), bastante para a transição se ler. Fixa-se uma só
  -- vez, pois independe do valor corrente.
  local FILL_COOL = gears.color {
    type = "linear", from = { 0, 0 }, to = { dpi(140), 0 },
    stops = { { 0, p.v700 }, { 1, p.v500 } },
  }

  -- RÓTULO (56px, esmaecido, CAIXA-ALTA — .bm__lbl) + VALOR (38px, à direita —
  -- .bm__val, ExtraBold 11). Ambos coloridos por markup via txt (único soberano).
  local label_box = txt {
    role         = "label",
    text         = args.label,
    color        = p.text_muted,
    upper        = true,
    forced_width = dpi(56),
  }
  local value_box = txt {
    role         = "ir_value",
    text         = string.format("%d%%", math.floor(init_disp + 0.5)),
    color        = init_hot and p.glow_hot or p.text_bright,
    align        = "right",
    forced_width = dpi(38),
  }

  -- TRILHO: leito p.inset (SEM borda), raio radius_bar (2px); enchimento frio
  -- (gradiente) no ordinário, p.glow_hot quando quente. Altura fixa 8px (.bm__track).
  local bar = wibox.widget {
    max_value        = 100,
    value            = init_disp,
    forced_height    = dpi(8),
    color            = init_hot and p.glow_hot or FILL_COOL,
    background_color = p.inset,
    border_width     = 0,
    shape            = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_bar)) end,
    bar_shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_bar)) end,
    widget           = wibox.widget.progressbar,
  }

  -- O trilho flexiona (flex:1) e centra-se na vertical (kit .bm align-items:center):
  -- container.place com content_fill_horizontal estica-o em largura, valign centra-o.
  local track_wrap = wibox.widget {
    bar,
    valign                  = "center",
    content_fill_horizontal = true,
    widget                  = wibox.container.place,
  }

  -- Disposição horizontal única: [rótulo 56][vão 9][trilho flex][vão 9][valor 38].
  -- O align.horizontal dilata o widget do meio (o trilho) ao espaço restante; os
  -- vãos de 9px vêm de margens (.bm gap:9px — sem token dedicado, px verbatim).
  local w = wibox.widget {
    { label_box, right = dpi(9), widget = wibox.container.margin },
    track_wrap,
    { value_box, left = dpi(9), widget = wibox.container.margin },
    expand = "inside",
    layout = wibox.layout.align.horizontal,
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
    bar.color = hot and p.glow_hot or FILL_COOL
    value_box:set_span(string.format("%d%%", math.floor(disp + 0.5)), hot and p.glow_hot or p.text_bright)
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
