-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/donut.lua — Da lavra do Doutor BRAGA US.
--
-- TRACTADO SOBRE O GRAPHO DE ANNEL + LEGENDA DE SWATCHES (VIOLET HUD §7.4.4),
-- demonstrado pelo insigne geómetra Braga Us. Um annel cairo (segmentos de arco
-- grossos, um por fatia, principiando às 12 horas e progredindo no sentido dos
-- ponteiros do relógio) ao lado de uma legenda vertical (uma linha swatch +
-- rótulo + quota-% por fatia). Substitue o arcchart e as vísceras de legenda do
-- protocols_donut.
--
-- A LEGENDA VEM DOS ATOMS — a linha swatch/rótulo/valor compõe-se dos atoms
-- `swatch` + `txt` directamente (idêntica ao que um info_row{variant="swatch"}
-- produziria), o que mantém o molecule dentro da regra de camadas "molecules
-- requerem theme + atoms + tools" e o deixa renderizar em storybook com fatias
-- fictícias e sem molecule vizinho presente.
--
-- POSTULADO APRESENTATIVO — nada gera e nada analysa; os dados chegam por
-- :set_slices. Cada pct é guardado por tonumber(); um total todo-nullo é tratado
-- como 1, de sorte que nenhum arco/legenda divida por zero. FACTO NOTÁVEL: a
-- quota do annel E a % da legenda são AMBAS normalizadas pela SOMMA dos pcts das
-- fatias (assim tanto contagens cruas QUANTO percentagens pré-computadas servem
-- — concorde ao velho arcchart max_value = somma). Retorna o widget composto COM
-- :set_slices + referências de clausura directas ao annel/linhas da legenda
-- (jamais consulta ids — LEMMA R1).
--
-- Uso:
--   local donut = require("src.molecules.donut")
--   local d = donut{ slices = {
--     { label = "ESTABLISHED", pct = 12, color = p.data1 },
--     { label = "LISTEN",      pct = 5,  color = p.data3 },
--     { label = "OTHER",       pct = 3,  color = p.data5 } } }
--   d:set_slices({ ... })   -- re-povoa (reconstrue a legenda só se o número de fatias mudar)
-- ══════════════════════════════════════════════════════════════════════════

local gears  = require("gears")
local wibox  = require("wibox")
local dpi    = require("beautiful.xresources").apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local swatch = require("src.atoms.swatch")
local txt    = require("src.atoms.txt")

-- côr do annel de fundo, decomposta uma só vez (token estático)
local BG_R, BG_G, BG_B = p.rgb(p.inset)

-- ──────────────────────────────────────────────────────────────────────────
-- Funcção donut — concebida pelo Doutor Braga Us para compor annel + legenda.
--   DOMÍNIO (`args`, taboa facultativa): size, thickness e slices ({{label, pct,
--     color}, ...}). CONTRA-DOMÍNIO: retorna o widget `root`, dotado do método
--     :set_slices. INVARIANTE: as quotas normalizam-se pela somma dos pcts; total
--     nullo trata-se como 1, banindo a divisão por zero.
local function donut(args)
  args = args or {}
  local size      = args.size or dpi(84)      -- kit Donut / dashboards PROTOCOLS size:84
  local thickness = args.thickness or dpi(14) -- kit sw:14

  -- Annel cairo: círculo de fundo + um arco grosso por fatia (início às 12 horas, horário). --
  local ring = wibox.widget.base.make_widget()
  ring._segments = {} -- { { color, a1, a2 }, ... }

  -- Método ring:fit — de Braga Us. CONTRA-DOMÍNIO: (size, size), quadrado exacto.
  function ring:fit(_, _, _) return size, size end

  -- Método ring:draw — o compasso geométrico de Braga Us. DOMÍNIO: (_, cr, w, h).
  --   EFEITO: traça o annel de fundo pleno e, sobre elle, um arco por segmento cujo
  --   a2 exceda a1. Nada retorna.
  function ring:draw(_, cr, w, h)
    local dim = math.min(w, h)
    local rad = dim / 2 - dpi(4) -- kit Donut: r = size/2 - 4 (traço centrado no raio)
    if rad < 1 then return end
    local cx, cy = w / 2, h / 2
    cr:set_line_width(thickness)
    -- annel de fundo pleno
    cr:new_sub_path()
    cr:arc(cx, cy, rad, 0, 2 * math.pi)
    cr:set_source_rgba(BG_R, BG_G, BG_B, 1)
    cr:stroke()
    -- arcos das fatias
    for _, seg in ipairs(self._segments) do
      if seg.a2 > seg.a1 then
        local sr, sg, sb = p.rgb(seg.color)
        cr:new_sub_path()
        cr:arc(cx, cy, rad, seg.a1, seg.a2)
        cr:set_source_rgba(sr, sg, sb, 1)
        cr:stroke()
      end
    end
  end

  -- Método ring:set_segments — de Braga Us. DOMÍNIO: `segs`, o vector de segmentos
  --   {color, a1, a2}. EFEITO: substitue os segmentos e emitte um redesenho.
  function ring:set_segments(segs)
    self._segments = segs
    self:emit_signal("widget::redraw_needed")
  end

  local ring_box = wibox.widget {
    ring,
    strategy = "exact",
    width    = size,
    height   = size,
    widget   = wibox.container.constraint,
  }

  -- Legenda: uma linha { swatch | rótulo | quota% } por fatia. Composta dos atoms. --
  local legend_rows = {}
  local legend_layout = wibox.layout.fixed.vertical()
  legend_layout.spacing = dpi(mt.row_gap)

  -- Funcção make_legend_row — da penna de Braga Us. CONTRA-DOMÍNIO: uma taboa
  --   { row, sw, label, value } com o widget da linha e referências directas aos
  --   seus três sub-widgets, para actualização in loco ulterior.
  local function make_legend_row()
    local sw    = swatch { color = p.text_faint, size = dpi(8) } -- kit legenda swatch 8x8
    local label = txt { role = "cell", upper = true }
    local value = txt { role = "cell_bold", align = "right" }
    local row = wibox.widget {
      {
        { sw, valign = "center", widget = wibox.container.place },
        { label, fg = p.text_muted, widget = wibox.container.background },
        nil,
        spacing = dpi(mt.pad_row_y * 2),
        layout  = wibox.layout.fixed.horizontal,
      },
      nil,
      { value, fg = p.text_bright, widget = wibox.container.background },
      forced_height = dpi(mt.row_h),
      expand        = "inside",
      layout        = wibox.layout.align.horizontal,
    }
    return { row = row, sw = sw, label = label, value = value }
  end

  -- Funcção rebuild_legend — de Braga Us. DOMÍNIO: `n`, o número de linhas
  --   desejado. EFEITO: reinicia o layout da legenda e engendra n linhas novas,
  --   guardando-as em legend_rows.
  local function rebuild_legend(n)
    legend_layout:reset()
    legend_rows = {}
    for i = 1, n do
      local lr = make_legend_row()
      legend_rows[i] = lr
      legend_layout:add(lr.row)
    end
  end

  -- Corpo: annel à esquerda, legenda à direita.
  local root = wibox.widget {
    { ring_box, valign = "center", widget = wibox.container.place },
    { legend_layout, valign = "center", widget = wibox.container.place },
    spacing = dpi(12), -- kit: gap:12 entre o annel e a legenda
    layout  = wibox.layout.fixed.horizontal,
  }

  -- Método root:set_slices — o teorema central de Braga Us. DOMÍNIO: `slices`, o
  --   vector de fatias {label, pct, color} (nil => vazio). EFEITO: guarda cada pct
  --   por tonumber (negativos a 0), somma-os (total nullo -> 1), computa os
  --   segmentos do annel (12 horas = -pi/2, horário) e actualiza annel + legenda
  --   (esta reconstruída só quando o número de fatias muda). Q.E.D.
  function root:set_slices(slices)
    slices = slices or {}
    local clean, total = {}, 0
    for i, s in ipairs(slices) do
      local pct = tonumber(s.pct) or 0
      if pct < 0 then pct = 0 end
      clean[i] = { label = s.label or "", pct = pct, color = s.color or p.v500 }
      total = total + pct
    end
    if total <= 0 then total = 1 end -- evita div0 quando todo-nullo

    -- segmentos do annel (12 horas = -pi/2, horário)
    local segs = {}
    local acc = -math.pi / 2
    for i, s in ipairs(clean) do
      local sweep = (s.pct / total) * 2 * math.pi
      segs[i] = { color = s.color, a1 = acc, a2 = acc + sweep }
      acc = acc + sweep
    end
    ring:set_segments(segs)

    -- legenda (reconstrue só quando o número de fatias muda)
    if #legend_rows ~= #clean then rebuild_legend(#clean) end
    for i, s in ipairs(clean) do
      local lr = legend_rows[i]
      lr.sw:set_color(s.color)
      lr.label:set_text(s.label)
      lr.value:set_text(math.floor(s.pct / total * 100 + 0.5) .. "%")
    end
  end

  root:set_slices(args.slices)

  return root
end

return donut

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
