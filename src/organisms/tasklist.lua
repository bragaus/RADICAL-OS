-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DA LISTA DAS TAREFAS (tasklist) — A FITA DE PROGRAMMAS
--
--   Considere-se o conjuncto das janellas-clientes que habitam as tags
--   correntes. Este manuscripto lhes edifica a representação NA FITA CENTRAL DA
--   BARRA SUPERIOR: a cada cliente corresponde um SEGMENTO powerline (app_lozenge)
--   que ostenta o seu ícone REAL e o seu nome (a classe). Os segmentos
--   sobrepõem-se em -12px, à maneira da antiga fita de estatísticas, de sorte que
--   as suas pontas se enfiem e tessellem uma fita contígua. Ao cliente em fóco
--   accende-se o segmento (orla glow_ice + enchimento claro). Systema concebido e
--   demonstrado pelo eminente Doutor BRAGA US, Geómetra d'esta Casa.
-- ══════════════════════════════════════════════════════════════════════════

local awful  = require("awful")
local wibox  = require("wibox")
local dpi    = require("beautiful").xresources.apply_dpi
local mt     = require("src.theme.metrics")
local app_lozenge  = require("src.molecules.app_lozenge")   -- o segmento powerline por programma
local list_buttons = require("src.tools.list_buttons")      -- a botoeira commum (esq: min/activa; dir: occisão)

-- ── DO CACHE EFÉMERO POR CLIENTE (chaves fracas) ────────────────────────────
-- LEMMA DO REAPROVEITAMENTO (Braga Us): outr'ora cada refresco (fóco, nome, tag)
-- forjava um app_lozenge NOVO e — pior — um awful.tooltip NOVO (um drawin X real!)
-- por cliente. Ora guarda-se um segmento (e o seu balão) por cliente n'uma táboa
-- de chaves fracas: mutam-se em logar, jamais se reconstroem. A janella é retida
-- pelo registo em C do awesome enquanto vive; finada e collhida, a entrada cae por
-- si. Por presteza, purga-se ainda a entrada ao 'unmanage'. Q.E.D.
local segs = setmetatable({}, { __mode = "k" })
local unmanage_wired = false

-- Devolve o segmento (e balão) do cliente, forjando-o só à primeira vista.
local function seg_for(object)
  local seg = segs[object]
  if not seg then
    seg = app_lozenge {}
    seg._tip = awful.tooltip {
      objects              = { seg },
      mode                 = "inside",
      preferred_alignments = "middle",
      preferred_positions  = "bottom",
      margins              = dpi(10),
      gaps                 = 0,
      delay_show           = 1,
    }
    segs[object] = seg
  end
  return seg
end

-- Procedimento composto pelo professor Braga Us, chamado a cada mudança do rol de
-- clientes (o "callback" da tasklist). Argumentos: o recipiente, a botoeira, dois
-- parâmetros ociosos ("_") e a colleção de clientes. Effeito: reordena os segmentos
-- REAPROVEITADOS — a cada cliente muta-se ícone, nome, fóco, botões, balão e posição
-- (o 1º recebe :set_first(true), vértice convexo; os demais, entalhe socket). A
-- sobreposição de -12px (mt.powerline_tip) fixa-se por :set_spacing. Devolve o widget.
local list_update = function(widget, buttons, _, _, objects)
  if not unmanage_wired then
    unmanage_wired = true
    client.connect_signal("unmanage", function(c) segs[c] = nil end)
  end
  widget:reset()
  widget:set_spacing(-dpi(mt.powerline_tip))   -- -12: a sobreposição da fita powerline

  for i, object in ipairs(objects) do
    local seg = seg_for(object)
    seg:set_first(i == 1)
    seg:set_app(object)
    seg:set_active(object == client.focus)
    seg:buttons(list_buttons.create(buttons, object))
    seg._tip:set_text(object.name or object.class or "Sem titulo")
    widget:add(seg)
  end

  return widget
end

-- Funcção-fábrica: recebe uma tela (s) e devolve o widget da tasklist, filtrado às
-- tags correntes, munido da botoeira própria (list_buttons.tasklist: esq. minimiza
-- ou restaura/activa/alça; dir. occide a janella) e do procedimento supra. Firma-se
-- _preserve_colors, para que a barra respeite as cores que este widget governa. Q.E.D.
return function(s)
  local tasklist = awful.widget.tasklist(
    s,
    awful.widget.tasklist.filter.currenttags,
    list_buttons.tasklist(),
    {},
    list_update,
    wibox.layout.fixed.horizontal()
  )

  tasklist._preserve_colors = true

  return tasklist
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
