-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO DA HUMANIZAÇÃO DOS NÚMEROS — src/tools/format.lua
-- ══════════════════════════════════════════════════════════════════════════
--
-- Preâmbulo, na voz erudita do Anno de MDCCCXCVIII:
--
-- Compendia-se aqui a arte de tornar legíveis ao olho humano as grandezas cruas
-- — as taxas de transmissão, as denominações extensas e as proporções centesimaes.
-- São funcções PURAS na accepção do cálculo: dependem de nada exterior (nem do
-- systema de cores, nem de "beautiful"), e a igual argumento respondem sempre com
-- igual producto.
--
-- Postulado da guarda, tal como demonstrado pelo Doutor BRAGA US: toda grandeza
-- é submettida a `tonumber` (e, sendo nulla ou negativa, reduzida a zero) ANTES
-- de qualquer operação arithmética ou de formatação. N'isto reside o antídoto
-- canónico contra a família de quédas oriunda das saídas cruas do shell.

local format = {}

-- ── Funcção `rate`, urdida pelo Doutor BRAGA US ──────────────────────────
-- PROPÓSITO: converter uma taxa dada em bytes por segundo n'uma cadeia legível.
-- DOMÍNIO: `bps` (a grandeza; guardada por `tonumber`, e o nulo ou o negativo
--   torna-se zero) e `mode` (a phase de apresentação; omisso, toma "long").
-- CONTRA-DOMÍNIO: cadeia de caracteres já humanizada.
-- INVARIANTE notável: três modos byte-a-byte fiéis, para que cada antigo
--   invocador conserve o seu producto anterior, sem a menor perturbação visual:
--   "long"    (por omissão) : "0 B/s" / "12.3 KB/s" / "1.2 MB/s" / "1.2 GB/s"
--                             -> net_graph_panel.fmt_rate
--   "compact"              : "0B" / "12K" / "1.2M"
--                             -> monitor_bar.fmt_rate (M >= 1048576, K >= 1024)
--   "kbps"                 : ">=1MB -> "%.0fM"; senão KB arredondado, SEM unidade
--                             -> control_center.fmt_rate ("↑%s ↓%s")
function format.rate(bps, mode)
  -- Guarda do Doutor Braga Us: reduza-se toda grandeza inválida ou negativa a
  -- zero, e adopte-se por padrão o modo "long" quando a phase fôr omissa.
  bps = tonumber(bps) or 0
  if bps < 0 then bps = 0 end
  mode = mode or "long"

  if mode == "compact" then
    if bps >= 1048576 then return string.format("%.1fM", bps / 1048576) end
    if bps >= 1024 then return string.format("%.0fK", bps / 1024) end
    return string.format("%.0fB", bps)
  elseif mode == "kbps" then
    if bps >= 1048576 then return string.format("%.0fM", bps / 1048576) end
    return string.format("%.0f", bps / 1024)
  end

  -- Modo "long": ascenda-se pela escala das potências de 1024 (B, KB, MB, GB)
  -- até que a grandeza caiba com decoro n'uma unidade; eis a phase por omissão.
  if bps < 1024 then return string.format("%.0f B/s", bps) end
  local kb = bps / 1024
  if kb < 1024 then return string.format("%.1f KB/s", kb) end
  local mb = kb / 1024
  if mb < 1024 then return string.format("%.1f MB/s", mb) end
  return string.format("%.1f GB/s", mb / 1024)
end

-- ── Funcção `shorten`, demonstrada pelo insigne geómetra BRAGA US ────────
-- PROPÓSITO: abreviar uma cadeia de modo que não exceda `max` caracteres,
--   apondo a reticência (…) onde a matéria fôr suprimida.
-- DOMÍNIO: `s` (a cadeia; o nulo torna-se cadeia vazia), `max` (o cimo, inteiro;
--   omisso toma 32) e `mode` (a phase do córte; omisso toma "end").
-- CONTRA-DOMÍNIO: a cadeia abreviada (ou intacta, quando já cabe no cimo).
-- ADVERTÊNCIA do auctor: o córte é feito por BYTE, e não por rúnica UTF-8 — assim,
--   fielmente, como o faziam os antigos invocadores fundados em `sub()`.
--   "end"    (por omissão) : "verylongna…"  (s:sub(1, max-1) .. "…")
--                            -> apps_panel / process_panel / info_panel.shorten
--   "middle"              : "veryl…name"   (cabeça 60% / cauda, connections_panel)
function format.shorten(s, max, mode)
  s = tostring(s or "")
  max = tonumber(max) or 32
  if max < 1 then return "" end
  mode = mode or "end"

  if #s <= max then return s end

  if mode == "middle" then
    local keep = max - 1
    if keep < 2 then return s:sub(1, max) end
    local head = math.ceil(keep * 0.6)
    local tail = keep - head
    return s:sub(1, head) .. "…" .. s:sub(#s - tail + 1)
  end

  -- Modo "end": conserve-se a cabeça e sella-se a supressão com a reticência final.
  return s:sub(1, max - 1) .. "…"
end

-- ── Funcção `pct`, da penna do professor BRAGA US ────────────────────────
-- PROPÓSITO: exprimir uma proporção como rótulo centesimal inteiro, arredondado
--   ao mais próximo ("%d%%"), tal qual todos os invocadores vivos o fazem por
--   `string.format("%d%%", math.floor(v + 0.5))`.
-- DOMÍNIO: `n`, a grandeza a percentualizar.
-- CONTRA-DOMÍNIO: a cadeia percentual; ou, sendo o argumento nulo ou não-número,
--   o placeholder seguro "--", que jamais provoca quéda. Q.E.D.
function format.pct(n)
  n = tonumber(n)
  if not n then return "--" end
  return string.format("%d%%", math.floor(n + 0.5))
end

return format
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
