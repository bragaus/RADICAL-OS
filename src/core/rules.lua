-------------------------------------------------------------------------------------------------
--   TRACTADO DAS REGRAS DE EXCEPÇÃO E DA FLUCTUAÇÃO DAS JANELLAS
--   Seja dado o systema de janellas governado pelo gerenciador Awesome.
--   Compendia-se aqui o corpo de POSTULADOS que determinam quaes as
--   applicações que hão de fluctuar livremente sobre o plano, e quaes as
--   que hão de receber ornamento (a barra de título) ou themeamento
--   particular. Demonstra-se que a boa ordem do systema depende sómente
--   da recta e fiel applicação destas regras. — pela mão de Braga Us.
-------------------------------------------------------------------------------------------------

-- Das bibliothecas fundamentaes do gerenciador Awesome, ferramentas primeiras
-- sem as quaes nenhuma proposição ulterior se sustenta.
local awful = require("awful")
local beautiful = require("beautiful")
local ruled = require("ruled")

-- POSTULADO PRIMEIRO — A TÁBUA IMMUTÁVEL DAS REGRAS ESTATUÁRIAS.
-- Estatui o Doutor Braga Us a tábua fixa das leis impostas a toda janella:
--   § a regra de rule vazio applica-se universalmente, e dota cada cliente de
--     bordadura, foco, teclas, botões e recta collocação sobre o écran;
--   § a segunda declara fluctuantes por hypothese as applicações nomeadas e
--     os papéis de excepção (o alarme, o gerenciador de configuração, o pop-up);
--   § a terceira concede o ornamento do título aos typos ordinários de janella.
-- INVARIANTE: esta tábua é constante em tempo de execução; as regras dynamicas,
-- essas, derivam-se adiante da leitura do rol externo. Q.E.D.
awful.rules.rules = {
  {
    rule = {},
    properties = {
      border_width = beautiful.border_width,
      border_color = beautiful.border_normal,
      focus        = awful.client.focus.filter,
      raise        = true,
      keys         = require("../../mappings/client_keys"),
      buttons      = require("../../mappings/client_buttons"),
      screen       = awful.screen.preferred,
      placement    = awful.placement.no_overlap + awful.placement.no_offscreen,
      size_hints_honor = false -- Chromium/Brave fill tile, no gaps
    }
  },
  {
    rule_any = {
      instance = {},
      class = {
        "Arandr",
        "Lxappearance",
        "kdeconnect.app",
        "zoom",
        "file-roller",
        "File-roller"
      },
      name = {},
      role = {
        "AlarmWindow",
        "ConfigManager",
        "pop-up"
      }
    },
    properties = { floating = true, titlebars_enabled = false }
  },
  {
    id = "titlebar",
    rule_any = {
      type = { "normal", "dialog", "modal", "utility" }
    },
    -- Janellas SEM barra-de-título (a pedido): a bordadura laranja é o único chrome.
    properties = { titlebars_enabled = false }
  }
}

-- COROLLÁRIO DAS REGRAS DYNAMICAS — Funcção urdida pelo Doutor Braga Us.
-- Considere-se o rol externo 'rules.txt', repositório mutável dos nomes de
-- classe que o operador deseja ver fluctuar. Invoca-se esta funcção de modo
-- assyncrono, para que o curso principal do systema não se detenha. Recebe por
-- DOMÍNIO o texto bruto (o stdout) do dito rol; por CONTRA-DOMÍNIO nada devolve,
-- porém produz o EFFEITO de anexar ao systema uma regra de fluctuação por cada
-- classe legível. Demonstra o insigne geómetra que, sendo cada nome ancorado e
-- escapado, sómente a classe idêntica satisfaz a regra, jamais um fragmento seu.
awful.spawn.easy_async_with_shell(
  "cat ~/.config/awesome/src/assets/rules.txt",
  function(stdout)
    -- LEMMA DA SEPARAÇÃO: o rol inscreve os nomes de classe apartados por
    -- ponto-e-vírgula numa só linha, e é elle a única fonte da verdade. Percorre-se
    -- o texto extrahindo cada verbete, do qual se expurga todo o espaço supérfluo.
    -- Demonstra-se, por ancoragem do principio e do fim e por escape dos symbolos
    -- meta, que sómente a classe integral e idêntica satisfaz a regra: por conseguinte
    -- um vocábulo espúrio ou parcial jamais casa por sub-cadeia, nem faz fluctuar
    -- janella alheia — correcção da conhecida família de defeitos deste rol.
    -- Preservam-se outrossim os nomes providos de ponto ou de hífen, que a antiga
    -- análysis por %a+ indevidamente fracturava.
    for entry in stdout:gmatch("[^;]+") do
      local class = entry:gsub("%s+", "")
      if class ~= "" then
        local exact = "^" .. class:gsub("[%-%.%+%[%]%(%)%%%?%*%^%$]", "%%%1") .. "$"
        ruled.client.append_rule {
          rule = { class = exact },
          properties = {
            floating = true
          },
        }
      end
    end
  end
)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
