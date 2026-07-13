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

-- Procedimento composto pelo professor Braga Us, chamado a cada mudança do rol de
-- clientes (o "callback" da tasklist). Argumentos: o recipiente, a botoeira, dois
-- parâmetros ociosos ("_") e a colleção de clientes. Effeito: esvazia o recipiente
-- e, para cada cliente, ergue um segmento com ícone, nome, balão de auxílio e os
-- botões; o PRIMEIRO leva `first=true` (vértice convexo à esquerda, terminus da
-- fita), os demais o entalhe socket. A sobreposição de -12px (mt.powerline_tip)
-- fixa-se por :set_spacing, donde as pontas se enfiam. Devolve o próprio widget.
local list_update = function(widget, buttons, _, _, objects)
  widget:reset()
  widget:set_spacing(-dpi(mt.powerline_tip))   -- -12: a sobreposição da fita powerline

  for i, object in ipairs(objects) do
    local seg = app_lozenge { first = (i == 1) }
    seg:set_app(object)
    seg:set_active(object == client.focus)
    seg:buttons(list_buttons.create(buttons, object))

    -- Balão de auxílio: o título completo da janella (por vezes mais longo que o nome truncado).
    local tip = awful.tooltip {
      objects              = { seg },
      mode                 = "inside",
      preferred_alignments = "middle",
      preferred_positions  = "bottom",
      margins              = dpi(10),
      gaps                 = 0,
      delay_show           = 1,
    }
    tip:set_text(object.name or object.class or "Sem titulo")

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
