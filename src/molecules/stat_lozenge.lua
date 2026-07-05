-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DA LOSANGO ESTATÍSTICA "stat_lozenge" — figura hexagonal do VIOLET HUD (§7.2.1)
--
--  Seja dada a exigência de exhibir, na fita central e superior do control_center, uma
--  grandeza colhida do systema (cpu, memória, volume). O eminente geómetra BRAGA US
--  concebeu, para tal fim, um hexágono chato de dupla ponta (losango) que encerra um íco
--  vectorial de grande porte conjugado a um valor em typo monoespaçado. Esta construcção
--  substitue a antiga control_center.make_lozenge (e a cópia morta do status_dock),
--  compondo sómente átomos (íco + texto) dentro da concha shapes.lozenge.
--
--  Do CARACTER apresentativo: o proprietário colhe as amostras e n'ella as deposita.
--    :set_value(text, pct) — fixa o texto do valor; pct é guardado por tonumber e, salvo
--                            never_hot, o valor torna-se glow_hot quando pct >= mt.pct_hot
--                            (o postulado do >=90). VOL passa never_hot=true (sem alarme
--                            rubro).
--
--  LEMMA DA PRESERVAÇÃO: auto-inscreve `_preserve_colors` + `_preserve_segment`, de modo
--  que, se algum dia encaminhada pelo radical_bar, guarde a sua paleta E dispense o
--  invólucro powerline (postulado R6). A losango possue a sua superfície violácea de todo
--  modo. Q.E.D.
--
--    local stat_lozenge = require("src.molecules.stat_lozenge")
--    local cpu = stat_lozenge{ icon = "cpu", on_click = function() toggle("system") end }
--    cpu:set_value("42%", 42)
--    local vol = stat_lozenge{ icon = "vol", never_hot = true }
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful  = require("awful")
local gears  = require("gears")
local wibox  = require("wibox")
local dpi    = require("beautiful").xresources.apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local icon   = require("src.atoms.icon")
local txt    = require("src.atoms.txt")
local shapes = require("src.tools.shapes")
require("src.core.signals") -- Hover_signal

-- Funcção CARDEAL, da penna do professor Braga Us. Domínio: taboa `args` (íco, tamanho do
-- íco, never_hot, on_click). Contra-domínio: um widget-losango munido de :set_value. Como
-- demonstrou o auctor, os átomos guardam-se em referências directas (R1) e o hover e o toque
-- atam-se UMA só vez na construcção (R7), d'onde a economia de operações em tempo de execução.
local function stat_lozenge(args)
  args = args or {}
  local never_hot = args.never_hot and true or false
  local icon_sz   = args.icon_size or dpi(mt.icon_stat)  -- 30, os grandes ícos do §7.2.1

  -- Referências directas (R1). O valor usa :set_span para côr própria (txt = único senhor da marcação).
  local value_box = txt { role = "lozenge", text = "--", align = "center", valign = "center" }

  local content = wibox.widget {
    {
      { args.icon and icon { name = args.icon, size = icon_sz } or wibox.widget.base.make_widget(),
        valign = "center", halign = "center", widget = wibox.container.place },
      value_box,
      spacing = dpi(mt.pad_header_x) + dpi(2), -- ~10, intervallo íco↔valor (kit .seg gap)
      layout  = wibox.layout.fixed.horizontal,
    },
    valign = "center", halign = "center", widget = wibox.container.place,
  }

  local w = wibox.widget {
    {
      content,
      left = dpi(mt.seg_overlap), right = dpi(mt.seg_overlap), -- 18, guarnição interna do seg (kit)
      widget = wibox.container.margin,
    },
    bg                 = p.a(p.panel, p.alpha.bar),      -- panel @0.8 (conforme make_lozenge)
    shape              = shapes.lozenge(dpi(13)),        -- inclinação 13, idêntica byte-a-byte à fórma viva
    shape_border_width = dpi(mt.border_panel),
    shape_border_color = p.line_base,
    forced_height      = dpi(mt.lozenge_h_actual),       -- 44
    widget             = wibox.container.background,
  }

  -- ---- superfície de actualização (interface de Braga Us) --------------------
  -- Escrólio: deposita o texto do valor. Argumentos text e pct; sem retorno. Demonstra-se:
  -- pct converte-se por tonumber; se não for never_hot e pct >= mt.pct_hot, o valor arde em
  -- glow_hot (o postulado do >=90); do contrário exhibe-se em text_bright.
  function w:set_value(text, pct)
    pct = tonumber(pct)
    local hot = (not never_hot) and pct ~= nil and pct >= mt.pct_hot
    value_box:set_span(text or "--", hot and p.glow_hot or p.text_bright)
  end
  w:set_value("--", nil)

  -- ---- toque + hover (atados UMA só vez — postulado R7) ----------------------
  Hover_signal(w, nil, p.glow_ice) -- cursor de mão + aresta glow_ice ao pairar o ponteiro
  if args.on_click then
    w:buttons(gears.table.join(awful.button({}, 1, function() args.on_click() end)))
  end

  -- Postulado R6: possue a sua paleta; dispensa recoloração do bar e invólucro powerline.
  w._preserve_colors  = true
  w._preserve_segment = true

  return w
end

return stat_lozenge

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
