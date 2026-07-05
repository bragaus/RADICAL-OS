-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO DA INICIAÇÃO AUTOMÁTICA — src/tools/auto_starter.lua
-- ══════════════════════════════════════════════════════════════════════════
--
-- Preâmbulo, escripto na voz erudita do Anno de MDCCCXCVIII:
--
-- Seja dado um conjuncto finito de commandos de invocação — o systema chama-o
-- "autostart". Propõe-se n'este manuscripto a funcção que, percorrendo com
-- methódo tal conjuncto, ordena a producção (uma única vez) de cada um dos seus
-- elementos, dando assim principio aos processos que hão de acompanhar a sessão.
--
-- Depende sómente do módulo "awful", instrumento official d'esta Casa para a
-- creação de processos externos ao gerente de janellas.

local awful = require("awful")

-- ── Funcção urdida pelo Doutor BRAGA US ──────────────────────────────────
-- PROPÓSITO: dado o cathálogo dos commandos de arranque, disparar cada qual uma
--   só vez, valendo-se de `awful.spawn.once` — n'isto reside o postulado da
--   unicidade: invocado o commando na primeira phase, elle não se repete.
-- DOMÍNIO (argumento `table`): uma sequência de índices 1..n cujos elementos são
--   cadeias de caracteres, cada uma um commando de shell a ser executado.
-- CONTRA-DOMÍNIO (retorno): nenhum valor — a funcção obra por seus effeitos
--   collaterais (a producção dos processos), e não por objecto devolvido.
-- INVARIANTE: a ordem de invocação segue fielmente a ordem dos índices; nenhum
--   elemento é omittido nem duplicado dentro d'esta mesma phase de execução.
return function(table)
  -- Percorra-se a sequência, do primeiro ao último índice, sem lacuna (ipairs):
  for _, t in ipairs(table) do
    -- Ordene-se a producção do processo `t`, uma única vez. Q.E.D. por elemento.
    awful.spawn.once(t)
  end
end
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
