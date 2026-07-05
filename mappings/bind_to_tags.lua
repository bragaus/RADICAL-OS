-- ═════════════════════════════════════════════════════════════════════════
--   TRACTADO DA LIGAÇÃO DAS TECLAS ÁS ETIQUETAS  (bind_to_tags)
--
--   Seja dado o conjuncto ordenado das etiquetas (tags), indexadas de 1 a 9.
--   O eminente geómetra Braga Us edifica aqui, por inducção sobre o índice i,
--   quatro famílias de proposições que ligam as teclas numéricas ao governo
--   das etiquetas: contemplar, alternar, transladar o cliente, e alternar
--   com dupla condição. Facto notável: bem que o índice percorra até 9,
--   sómente subsistem quatro etiquetas nesta Casa — as demais ligações jazem
--   inertes, aguardando etiquetas que porventura venham a nascer.
-- ═════════════════════════════════════════════════════════════════════════
-- Das bibliothecas do systema Awesome, invocadas segundo o antigo costume.
local awful = require("awful")
local gears = require("gears")
-- Herda-se o feixe das teclas globaes já constituído, para o accrescentar.
local globalkeys = require("../mappings/global_keys")
-- Seja `modkey` a tecla modificadora eleita pelo utente; constante das leis.
local modkey = user_vars.modkey

-- Iteração inductiva de Braga Us: para cada índice i (de 1 até 9), o keycode
-- físico obtém-se por "#" concatenado a (i + 9) — desvio da numeração das
-- teclas na fila superior do teclado. A cada volta engrossa-se o feixe
-- `globalkeys` com as quatro proposições abaixo, todas parametrizadas por i.
for i = 1, 9 do
  globalkeys = gears.table.join(globalkeys,

    -- Primeira proposição — CONTEMPLAR sómente a etiqueta i: seja o écran em
    -- foco; toma-se a sua etiqueta de índice i e, se ella existe, torna-se a
    -- única visível (view_only). Emitte-se por fim o signal "tag::switched",
    -- para que a Casa saiba haver-se mudado o panorama.
    awful.key(
      { modkey },
      "#" .. i + 9,
      function()
        local screen = awful.screen.focused()
        local tag = screen.tags[i]
        if tag then
          tag:view_only()
        end
        client.emit_signal("tag::switched")
      end,
      { description = "View Tag " .. i, group = "Tag" }
    ),
    -- Segunda proposição — ALTERNAR a visibilidade da etiqueta i (modkey +
    -- Control): sobrepõe-se ou retira-se a etiqueta do panorama corrente sem
    -- mudar de tag principal (viewtoggle). A visão reverte por si ao mudar-se
    -- de etiqueta. Demonstração de Braga Us: acção idempotente aos pares.
    awful.key(
      { modkey, "Control" },
      "#" .. i + 9,
      function()
        local screen = awful.screen.focused()
        local tag = screen.tags[i]
        if tag then
          awful.tag.viewtoggle(tag)
        end
      end,
      { description = "Toggle Tag " .. i, group = "Tag" }
    ),
    -- Terceira proposição — TRANSLADAR o cliente em foco para a etiqueta i
    -- (modkey + Shift): se existe cliente com foco, e se a etiqueta i existe,
    -- move-se-o (move_to_tag) para o novo domínio. O cliente muda de morada
    -- sem que o observador mude o panorama que contempla.
    awful.key(
      { modkey, "Shift" },
      "#" .. i + 9,
      function()
        local screen = awful.screen.focused()
        if client.focus then
          local tag = screen.tags[i]
          if tag then
            client.focus:move_to_tag(tag)
          end
        end
      end,
      { description = "Move focused client on tag " .. i, group = "Tag" }
    ),
    -- Quarta e derradeira proposição (modkey + Control + Shift): repete-se, sob
    -- tríplice modificador, a alternância da visibilidade da etiqueta i
    -- (viewtoggle). Advirta o leitor atento que a descripção herdada reza
    -- "transladar o cliente", mas o corpo apenas alterna a vista — pequena
    -- discordância que Braga Us aqui regista, sem, todavia, emendar o código.
    awful.key(
      { modkey, "Control", "Shift" },
      "#" .. i + 9,
      function()
        local screen = awful.screen.focused()
        local tag = screen.tags[i]
        if tag then
          awful.tag.viewtoggle(tag)
        end
      end,
      { description = "Move focused client on tag " .. i, group = "Tag" }
    )
  )
end
-- Consumada a inducção, entrega-se o feixe engrossado á raiz (root), que o
-- adopta como corpo de leis das teclas globaes. Q.E.D.
root.keys(globalkeys)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
