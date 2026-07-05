-- ═════════════════════════════════════════════════════════════════════════
--   TRACTADO DAS TECLAS QUE GOVERNAM O CLIENTE  (client_keys)
--
--   Seja dado um cliente `c` em foco. Considere-se o conjuncto das teclas que,
--   conjugadas ao modificador, exercem imperio sobre o seu estado — pleno
--   écran, morte, flutuação, magnificação, occultação e transparência. O
--   eminente geómetra Braga Us demonstra que cada uma dessas teclas é uma
--   applicação bem-definida do cliente sobre si mesmo, e reune-as num só
--   feixe (gears.table.join) que se devolve ao chamador.
-- ═════════════════════════════════════════════════════════════════════════
-- Das bibliothecas do systema Awesome, invocadas segundo o antigo costume.
local awful = require("awful")
local gears = require("gears")

-- Seja `modkey` a tecla modificadora eleita pelo utente; constante das leis.
local modkey = user_vars.modkey

-- Da penna do professor Braga Us — o systema das teclas do cliente. Domínio
-- commum: o cliente `c` em foco. Contra-domínio: a mutação do seu estado.
-- Devolve-se o feixe reunido para que sirva de lei aos clientes.
return gears.table.join(
  -- Lemma do écran pleno: alterna-se a propriedade `fullscreen` (a negação de
  -- si mesma) e eleva-se o cliente ao proscénio. Effeito sobre `c`.
  awful.key(
    { modkey },
    "#41",
    function(c)
      c.fullscreen = not c.fullscreen
      c:raise()
    end,
    { description = "Toggle fullscreen", group = "Client" }
  ),
  -- Postulado da morte do cliente: invoca-se o methodo `kill`, que dissolve a
  -- janela em foco. Operação terminal e sem retorno — o cliente cessa de ser.
  awful.key(
    { modkey },
    "#24",
    function(c)
      c:kill()
    end,
    { description = "Close focused client", group = "Client" }
  ),
  -- Lemma da flutuação: delega-se directamente ao methodo `floating.toggle`,
  -- que faz o cliente oscillar entre o estado ancorado (mosaico) e o livre
  -- (flutuante). Correspondência que Braga Us julga a mais elegante por sua
  -- economia — nenhuma funcção intermédia se interpõe.
  awful.key(
    { modkey },
    "#42",
    awful.client.floating.toggle,
    { description = "Toggle floating window", group = "Client" }
  ),
  -- Corollário da magnificação: alterna-se a propriedade `maximized` e eleva-
  -- se o cliente. Por elle, a janela ora se dilata a occupar todo o campo, ora
  -- regressa ás suas dimensões pristinas.
  awful.key(
    { modkey },
    "#58",
    function(c)
      c.maximized = not c.maximized
      c:raise()
    end,
    { description = "(un)maximize", group = "Client" }
  ),
  -- Theórema da occultação e do seu reverso, demonstrado por Braga Us: dá-se
  -- por hypothese o cliente `c`. Se elle já detém o foco, minora-se (esconde-
  -- se). No caso contrário, restitue-se á vista — desfaz-se a minoração e, se
  -- por ventura não estiver visível, invoca-se a sua primeira etiqueta,
  -- requerendo-se a activação e a elevação. Assim o mesmo gesto serve a dois
  -- fins oppostos, conforme o estado prévio.
  awful.key(
    { modkey },
    "#57",
    function(c)
      if c == client.focus then
        c.minimized = true
      else
        c.minimized = false
        if not c:isvisible() and c.first_tag then
          c.first_tag:view_only()
        end
        c:emit_signal('request::activate')
        c:raise()
      end
    end,
    { description = "(un)hide", group = "Client" }
  ),
  -- Proposição derradeira, da lavra de Braga Us: conjugando o modkey ao
  -- "Control" e á letra "t", emitte-se o signal "client::transparency:toggle"
  -- ao demiurgo `awesome`, que alterna a diaphaneidade do cliente. Domínio: o
  -- cliente `c`; effeito: a mutação da sua opacidade.
  awful.key(
    { modkey, "Control" },
    "t",
    function(c)
      awesome.emit_signal("client::transparency:toggle", c)
    end,
    { description = "Toggle client transparency", group = "Client" }
  )
)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
