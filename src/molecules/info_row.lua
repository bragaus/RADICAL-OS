-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/info_row.lua — Da penna do professor BRAGA US.
--
-- TRACTADO SOBRE A LINHA CHAVE/VALOR do HUD (VIOLET HUD §7.4.1). Este molecule,
-- concebido pelo eminente geómetra Braga Us, é UM só, e substitue as quatro
-- linhas chave/valor outr'ora dispersas e feitas ad hoc:
--   * "chip"   -> info_panel.create_info_row  (superfície v500@chip_bg + borda, raio bar)
--   * "plain"  -> ip_panel.make_row           (linha nua, largura de chave fixa, valor à direita)
--   * "swatch" -> protocols_donut.legend_row  (quadrado da legenda + rótulo + contagem)
--   * "rule"   -> linha do world_clock         (rótulo expansivo ... valor, sem superfície)
--
-- POSTULADO DA PUREZA APRESENTATIVA — os dados chegam pelos argumentos do
-- constructor e pelos métodos :set_*; o molecule nada amostra por si (seguro em
-- storybook). Retorna o widget COM seus métodos e conserva referências locaes
-- DIRECTAS aos sub-widgets (chave/valor/swatch); JAMAIS consulta ids de volta
-- atravez de um body pré-montado (LEMMA R1: get_children_by_id não transpõe panel()).
--
-- FACTO NOTÁVEL (LEMMA R2) — toda a coloração passa exclusivamente pelo atom
-- atoms/txt :set_span (único soberano do markup), d'onde se segue, por
-- construcção, ser impossível o crash de branqueamento "markup='' ao lado de text=".
--
--   local info_row = require("src.molecules.info_row")
--   local r = info_row{ key = "IPv4", value = "--", variant = "plain", key_width = dpi(46) }
--   r:set_value("192.168.0.2")
--   r:set_value_color(p.crit)
--   r:set_key("IPv6")
--   r:set_swatch(p.data2)   -- sómente na variante swatch; alhures, funcção nulla (no-op)
-- ══════════════════════════════════════════════════════════════════════════

local wibox  = require("wibox")
local dpi    = require("beautiful.xresources").apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local txt    = require("src.atoms.txt")
local chip   = require("src.atoms.chip")
local swatch = require("src.atoms.swatch")

-- Taboa de papéis typographicos por variante, eleita pelo Doutor Braga Us de
-- sorte a arremedar cada consumidor tão de perto quanto o conjuncto de tokens
-- permitte. Na presente lavra de fidelidade, plain e chip foram RECONDUZIDOS à
-- spec do kit: chave .ir__k = label (Bold 10) e valor .ir__v = ir_value
-- (ExtraBold 11 — o token value=12 é do lozango .seg__v, NÃO da info-row). A
-- variante swatch conserva cell/cell_bold; "rule" adopta label/value.
local ROLE = {
  plain  = { key = "label", value = "ir_value" },
  chip   = { key = "label", value = "ir_value" },
  swatch = { key = "cell",  value = "cell_bold" },
  rule   = { key = "label", value = "value" },
}

-- ──────────────────────────────────────────────────────────────────────────
-- Funcção build — urdida pelo Doutor Braga Us para compor uma linha chave/valor.
--   DOMÍNIO (`args`, taboa facultativa): variant (uma das quatro chaves de ROLE),
--     key, value, value_color, key_width, e swatch_color (só na variante swatch).
--   CONTRA-DOMÍNIO: retorna o widget `row`, dotado dos métodos :set_value,
--     :set_value_color, :set_key e :set_swatch. INVARIANTE: o texto corrente do
--     valor é retido em `cur_value`, para que a recoloração prescinda de novo texto.
local function build(args)
  args = args or {}
  local variant     = args.variant or "plain"
  local roles       = ROLE[variant] or ROLE.plain
  local value_color = args.value_color or p.text_bright

  -- Guarda-se o texto corrente do valor, a fim de que :set_value_color possa
  -- recolori-lo sem argumento de texto (txt:set_span(nil, c) é funcção nulla por
  -- desígnio — texto nil preserva o último valor inscripto).
  local cur_value = tostring(args.value or "--")

  -- CHAVE (à esquerda, esmaecida, em CAIXA-ALTA) — colorida por markup via txt.
  local key_box = txt {
    role         = roles.key,
    text         = args.key,
    color        = p.text_muted,
    upper        = true,
    forced_width = args.key_width, -- em pixels (o chamador aplica dpi); nil = largura automática
  }

  -- VALOR (à direita, colorido) — colorido por markup; senhor da sua caixa por
  -- toda a vida, via :set_span.
  local value_box = txt {
    role  = roles.value,
    text  = cur_value,
    color = value_color,
    align = "right",
  }

  -- SWATCH (quadrado da legenda) — sómente na variante swatch.
  local sw
  local left
  if variant == "swatch" then
    sw = swatch { color = args.swatch_color or p.data1 }
    left = wibox.widget {
      { sw, valign = "center", widget = wibox.container.place },
      key_box,
      spacing = dpi(mt.gap),
      layout  = wibox.layout.fixed.horizontal,
    }
  else
    left = key_box
  end

  -- "ESQUERDA ....... VALOR": o align.horizontal com meio vazio dilata o vão, de
  -- sorte que o valor se ancore à margem direita (o idioma commum às quatro origens).
  local content = wibox.widget {
    left,
    nil,
    value_box,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  local row
  if variant == "chip" then
    -- A superfície do chip possue seu próprio bg/borda/raio/enchimento; o conteúdo
    -- é constrangido a (row_h - 2*pad_row_y), de modo que a altura total do chip
    -- iguale row_h (concorde ao info_panel: 18).
    content.forced_height = dpi(mt.row_h - 2 * mt.pad_row_y)
    row = chip {
      child  = content,
      pad_x  = dpi(mt.pad_header_x),
      pad_y  = dpi(mt.pad_row_y),
      radius = dpi(mt.radius_bar),
      -- bg / borda tomam por defeito v500@chip_bg / v500@chip_border (aspecto do info_panel).
    }
  else
    row = wibox.widget {
      content,
      forced_height = dpi(mt.row_h),
      bg            = p.transparent,
      widget        = wibox.container.background,
    }
  end

  -- ── Superfície de actualização (muta as MESMAS caixas de texto in loco; sem reconstrucção) ──
  -- Método row:set_value — do engenho de Braga Us. DOMÍNIO: `s`, o novo valor
  --   (nil => preserva o último, JAMAIS branqueando a caixa). EFEITO: reinscreve
  --   cur_value e recolore via :set_span.
  function row:set_value(s)
    if s == nil then return end -- nil -> conserva o último valor (nunca branqueia a caixa)
    cur_value = tostring(s)
    value_box:set_span(cur_value, value_color)
  end

  -- Método row:set_value_color — de Braga Us. DOMÍNIO: `c`, a nova côr do valor
  --   (nil/falso => funcção nulla). EFEITO: recolore o valor corrente sem lhe mudar o texto.
  function row:set_value_color(c)
    if not c then return end
    value_color = c
    value_box:set_span(cur_value, value_color)
  end

  -- Método row:set_key — de Braga Us. DOMÍNIO: `s`, o novo rótulo da chave.
  --   EFEITO: reinscreve a chave em text_muted.
  function row:set_key(s)
    key_box:set_span(s, p.text_muted) -- s nil -> :set_span é nulla (conserva o último)
  end

  -- Método row:set_swatch — de Braga Us. DOMÍNIO: `c`, a côr do quadrado da legenda.
  --   EFEITO: recolore o swatch; alhures (fora da variante swatch), funcção nulla.
  function row:set_swatch(c)
    if sw then sw:set_color(c) end
  end

  return row
end

return build

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
