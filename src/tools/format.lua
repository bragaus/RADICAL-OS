-- src/tools/format.lua
-- Pure string/number humanizers. Requires NOTHING (no theme, no beautiful).
-- Every value is tonumber/nil-guarded BEFORE any math/format — this is the
-- canonical shell-stdout crash-family backstop for rate/pct labels.

local format = {}

-- rate(bps, mode) : bytes/second -> a human-readable string. tonumber-guarded
-- (nil / negative -> 0). Three byte-for-byte modes so each existing caller keeps
-- its exact prior output (zero visual churn):
--   "long"    (default) : "0 B/s" / "12.3 KB/s" / "1.2 MB/s" / "1.2 GB/s"
--                         -> net_graph_panel.fmt_rate
--   "compact"           : "0B" / "12K" / "1.2M"
--                         -> monitor_bar.fmt_rate (M >= 1048576, K >= 1024)
--   "kbps"              : ">=1MB -> "%.0fM"; else KB rounded, NO unit ("%.0f")
--                         -> control_center.fmt_rate ("↑%s ↓%s")
function format.rate(bps, mode)
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

  -- "long"
  if bps < 1024 then return string.format("%.0f B/s", bps) end
  local kb = bps / 1024
  if kb < 1024 then return string.format("%.1f KB/s", kb) end
  local mb = kb / 1024
  if mb < 1024 then return string.format("%.1f MB/s", mb) end
  return string.format("%.1f GB/s", mb / 1024)
end

-- shorten(s, max, mode) : truncate to <= max chars. BYTE-wise (matches the
-- existing sub()-based callers verbatim — deliberately NOT UTF-8-aware).
--   "end"    (default) : "verylongna…"  (s:sub(1, max-1) .. "…")
--                        -> apps_panel / process_panel / info_panel.shorten
--   "middle"           : "veryl…name"   (head 60% / tail, connections_panel.shorten)
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

  -- "end"
  return s:sub(1, max - 1) .. "…"
end

-- pct(n) : integer percent label rounded to nearest ("%d%%", matching every
-- live caller's `string.format("%d%%", math.floor(v + 0.5))`). nil -> "--"
-- (safe placeholder; never crashes).
function format.pct(n)
  n = tonumber(n)
  if not n then return "--" end
  return string.format("%d%%", math.floor(n + 0.5))
end

return format
