-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/glegend.lua — Da penna do professor BRAGA US.
--
-- TRACTADO SOBRE A LEGENDA DE GRÁPHICO (VIOLET HUD .glegend), engenho do insigne
-- geómetra Braga Us. É a fila horizontal de rótulos que acompanha o painel GRAPH
-- dos dashboards: cada verba compõe-se de uma MARCA (quadrículo 8×8, ou ícone
-- 12×12 na variante de rede UP/DOWN) seguida de um rótulo micro em CAIXA-ALTA.
-- Espelha, verba a verba, o kit:
--   .glegend        gap:14px; margin-top:5px; font-size:9px; text_muted; uppercase.
--   .glegend span   gap:5px  (entre a marca e o rótulo).
--   .glegend i      8×8; border-radius:2  (o quadrículo da variante de séries).
--
-- POSTULADO APRESENTATIVO / ESTÁTICO — os rótulos (CPU/MEM, UP/DOWN) não mudam ao
-- longo da vida; os valores vivem no grapho vizinho. Por conseguinte esta obra nada
-- amostra e nada muta: recebe as verbas pelo constructor e devolve o widget, puro
-- (renderiza em storybook sem backend algum). Compõe-se dos atoms swatch/txt/icon,
-- conservando-se na camada de moléculas; jamais consulta ids de volta (LEMMA R1).
--
-- TODA a coloração do rótulo passa pelo atom atoms/txt :set_span (único soberano do
-- markup — LEMMA R2), d'onde é impossível o crash de branqueamento da caixa.
--
--   local glegend = require("src.molecules.glegend")
--   -- variante de séries (SYSTEM GRAPH): quadrículos coloridos.
--   local lg = glegend{ items = {
--     { color = p.data1, label = "CPU" },
--     { color = p.data2, label = "MEM" } } }
--   -- variante de rede (NETWORK GRAPH): ícones net_up / net_down.
--   local ln = glegend{ items = {
--     { icon = "net_up",   label = "UP"   },
--     { icon = "net_down", label = "DOWN" } } }
--   -- margem de topo à falta => dpi(5) (kit .glegend margin-top); margin_top=0 anulla.
-- ══════════════════════════════════════════════════════════════════════════

local wibox  = require("wibox")
local dpi    = require("beautiful.xresources").apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local txt    = require("src.atoms.txt")
local swatch = require("src.atoms.swatch")
local icon   = require("src.atoms.icon")

-- ──────────────────────────────────────────────────────────────────────────
-- Funcção build — urdida pelo Doutor Braga Us para compor a legenda.
--   DOMÍNIO (`args`, taboa facultativa): items (vector de verbas {color, label,
--     icon?}) e margin_top (dflt dpi(5); 0 anulla a margem superior).
--   CONTRA-DOMÍNIO: retorna o widget da legenda (uma fila horizontal envolta na
--     margem de topo). INVARIANTE: cada verba com `icon` renderiza um ícone 12×12;
--     do contrario, um quadrículo 8×8 de raio 2 na côr da verba.
local function build(args)
  args = args or {}
  local items = args.items or {}
  local mtop  = args.margin_top == nil and dpi(5) or args.margin_top

  -- Fila das verbas, separadas por 14px (.glegend gap).
  local row = wibox.layout.fixed.horizontal()
  row.spacing = dpi(14)

  for _, it in ipairs(items) do
    -- MARCA: ícone 12×12 (variante de rede) OU quadrículo 8×8 raio 2 (.glegend i).
    local mark
    if it.icon then
      mark = icon({ name = it.icon, size = dpi(12) })
    else
      mark = swatch { color = it.color or p.v500, size = dpi(8), radius = dpi(mt.radius_bar) }
    end

    -- RÓTULO micro (9px), CAIXA-ALTA, esmaecido — colorido por markup via txt.
    local label = txt {
      role  = "micro",
      text  = it.label,
      color = p.text_muted,
      upper = true,
    }

    -- Verba: [marca][vão 5][rótulo]  (.glegend span gap:5px). A marca centra-se
    -- na vertical para acompanhar a linha de base do rótulo.
    local span = wibox.widget {
      { mark, valign = "center", widget = wibox.container.place },
      label,
      spacing = dpi(5),
      layout  = wibox.layout.fixed.horizontal,
    }
    row:add(span)
  end

  -- Margem de topo (.glegend margin-top:5px) — afasta a legenda do grapho acima.
  return wibox.widget {
    row,
    top    = mtop,
    widget = wibox.container.margin,
  }
end

return build

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
