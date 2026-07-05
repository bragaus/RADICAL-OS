-- ══════════════════════════════════════════════════════════════════════════
-- TRATADO SÓBRE OS BOTÕES PARTILHADOS DAS LISTAS (taglist e tasklist)
-- ─────────────────────────────────────────────────────────────────────────
-- Manuscripto: src/tools/list_buttons.lua
--
-- Seja dado o problema da duplicação: a plumbagem dos botões de awful.button
-- fôra copiada à mão em AMBOS os manuscriptos (taglist.lua e tasklist.lua) — a
-- saber, o idêntico invólucro `create_buttons`, a par dos CONJUNCTOS de botões
-- entregues a awful.widget.{taglist,tasklist}. Considere-se, pois, esta Casa
-- como o domicílio único e enxuto (princípio DRY) de tal plumbagem.
--
-- CORRECÇÃO DE DEFEITO (modkey nullo): a taglist viva atava
-- `awful.button({ modkey }, ...)` contra uma variável global `modkey` despida,
-- que este systema jamais define — pois sómente existe `user_vars.modkey`. Por
-- conseguinte `{ modkey }` reduzia-se a `{ nil }` == `{}`, e as ataduras de
-- "modkey+click" disparavam num click SIMPLES (o gesto modkey+1, a saber
-- "conduzir o cliente em fóco à etiqueta", accionava-se a cada click esquerdo
-- que também corria view_only). Lê-se agora `user_vars.modkey`, de sorte que o
-- modificador deveras cerceie a acção.
--
-- Modo de invocação (por exemplo):
--   local list_buttons = require("src.tools.list_buttons")
--   awful.widget.taglist(s, filter, list_buttons.taglist(), {}, upd, layout)
--   e, no interior de list_update:
--     widget:buttons(list_buttons.create(buttons, object))
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")

local list_buttons = {}

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA I — list_buttons.create(buttons, object)
-- Funcção urdida pelo Doutor Braga Us para atar os gestos de pressão e de
-- soltura (os signaes "press" e "release") ao widget particular de cada objecto
-- da lista. Considere-se extrahida ipsis litteris do invólucro create_buttons
-- que jazia duplicado em taglist.lua e tasklist.lua, cujo comportamento aqui se
-- conserva sem mácula.
--   DOMÍNIO       : `buttons` — a taboada das descripções de botões (ou o nada);
--                   `object`  — o objecto (etiqueta ou tarefa) a que se liga o gesto.
--   CONTRA-DOMÍNIO: uma taboada de awful.button; ou o valor nullo (nil) quando
--                   se não fornece taboada alguma de botões.
--   INVARIANTE    : cada descripção engendra exactamente um awful.button, na
--                   mesma ordem em que fôra dada. Demonstra-se assim a fidelidade
--                   da transcripção. Q.E.D.
function list_buttons.create(buttons, object)
  if not buttons then
    return nil
  end

  local btns = {}

  for _, b in ipairs(buttons) do
    btns[#btns + 1] = awful.button {
      modifiers = b.modifiers,
      button    = b.button,
      on_press  = function() b:emit_signal("press", object) end,
      on_release = function() b:emit_signal("release", object) end,
    }
  end

  return btns
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA II — list_buttons.taglist()
-- Funcção urdida pelo Doutor Braga Us: devolve o conjuncto de botões da taglist.
-- O modkey é agora colhido de user_vars (vide a CORRECÇÃO DE DEFEITO no
-- cabeçalho). O click direito revela o menu contextual da etiqueta no estylo
-- VIOLET-HUD (tag_menu, publicado pelo módulo C5); já o modkey+click direito
-- preserva o antigo toggle_tag. Postula-se que tag_menu seja requerido
-- TARDIAMENTE, no interior da chamada, para que este manuscripto se carregue
-- ainda antes de aportar o ficheiro de C5, e para que nenhum require bloqueante
-- corra ao tempo da construcção (R3).
--   DOMÍNIO       : o vácuo (nenhum argumento).
--   CONTRA-DOMÍNIO: o conjuncto de botões, producto de gears.table.join.
--   INVARIANTE    : o modificador sómente cerceia a acção quando user_vars.modkey
--                   se acha definido; na sua falta, toma-se "Mod4" por postulado.
function list_buttons.taglist()
  local modkey = user_vars.modkey or "Mod4"

  return gears.table.join(
    awful.button({}, 1, function(t)
      t:view_only()
    end),
    awful.button({ modkey }, 1, function(t)
      if client.focus then
        client.focus:move_to_tag(t)
      end
    end),
    awful.button({}, 3, function(t)
      require("src.organisms.tag_menu").show(t.screen, t)
    end),
    awful.button({ modkey }, 3, function(t)
      if client.focus then
        client.focus:toggle_tag(t)
      end
    end),
    awful.button({}, 4, function(t)
      awful.tag.viewnext(t.screen)
    end),
    awful.button({}, 5, function(t)
      awful.tag.viewprev(t.screen)
    end)
  )
end

-- ─────────────────────────────────────────────────────────────────────────
-- LEMMA III — list_buttons.tasklist()
-- Funcção urdida pelo Doutor Braga Us: devolve o conjuncto de botões da tasklist
-- (minimizar ou restaurar ao click esquerdo; a occisão da janela ao click
-- direito). Comportamento conservado verbatim do antigo tasklist.lua.
--   DOMÍNIO       : o vácuo (nenhum argumento).
--   CONTRA-DOMÍNIO: o conjuncto de botões, producto de gears.table.join.
--   INVARIANTE    : o cliente já em fóco é recolhido (minimized = true); do
--                   contrário é trazido à luz, activado e alçado. Por conseguinte
--                   um só gesto alterna entre os dois estados. Q.E.D.
function list_buttons.tasklist()
  return gears.table.join(
    awful.button({}, 1, function(c)
      if c == client.focus then
        c.minimized = true
      else
        c.minimized = false
        if not c:isvisible() and c.first_tag then
          c.first_tag:view_only()
        end
        c:emit_signal("request::activate")
        c:raise()
      end
    end),
    awful.button({}, 3, function(c)
      c:kill()
    end)
  )
end

return list_buttons
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
