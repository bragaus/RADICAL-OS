// charts.jsx — VIOLET HUD data visualizations (DS §7.4.3 line graph, §7.4.4 donut)
// SVG-based. Grid at low alpha, area fill + halo line, donut slices in data1..6.

// Multi-series line graph with grid + area fill.
// props: series [{color, data:[0..1...]}], width, height
function LineGraph({ series, width = 240, height = 96 }) {
  const pad = 4;
  const w = width, h = height;
  const xy = (data) => data.map((v, i) => {
    const x = pad + (i / (data.length - 1)) * (w - pad * 2);
    const y = pad + (1 - v) * (h - pad * 2);
    return [x, y];
  });
  const linePath = (pts) => pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
  const areaPath = (pts) => linePath(pts) + ` L${(w - pad).toFixed(1)} ${h - pad} L${pad} ${h - pad} Z`;
  return (
    <svg width={w} height={h} style={{ display: "block", background: "var(--inset)", borderRadius: 4 }}>
      {/* horizontal grid every 25% */}
      {[0.25, 0.5, 0.75].map((g, i) => (
        <line key={"h" + i} x1={pad} x2={w - pad} y1={pad + g * (h - pad * 2)} y2={pad + g * (h - pad * 2)}
          stroke="var(--grid)" strokeWidth="1" opacity={i % 2 ? 0.12 : 0.22} />
      ))}
      {/* vertical grid */}
      {[0.25, 0.5, 0.75].map((g, i) => (
        <line key={"v" + i} y1={pad} y2={h - pad} x1={pad + g * (w - pad * 2)} x2={pad + g * (w - pad * 2)}
          stroke="var(--v400)" strokeWidth="1" opacity={0.06} />
      ))}
      {series.map((s, i) => {
        const pts = xy(s.data);
        return (
          <g key={i}>
            <path d={areaPath(pts)} fill={s.color} opacity="0.22" />
            <path d={linePath(pts)} fill="none" stroke={s.color} strokeWidth="5" opacity="0.18" />
            <path d={linePath(pts)} fill="none" stroke={s.color} strokeWidth="2"
              strokeLinejoin="round" strokeLinecap="round" />
          </g>
        );
      })}
    </svg>
  );
}

// Donut chart. props: slices [{label, pct, color}]
function Donut({ slices, size = 96 }) {
  const r = size / 2 - 4, cx = size / 2, cy = size / 2, sw = 14;
  const C = 2 * Math.PI * r;
  let acc = 0;
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
      <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
        <circle cx={cx} cy={cy} r={r} fill="none" stroke="var(--inset)" strokeWidth={sw} />
        {slices.map((s, i) => {
          const len = (s.pct / 100) * C;
          const seg = (
            <circle key={i} cx={cx} cy={cy} r={r} fill="none" stroke={s.color} strokeWidth={sw}
              strokeDasharray={`${len} ${C - len}`} strokeDashoffset={-acc} />
          );
          acc += len;
          return seg;
        })}
      </svg>
      <div style={{ display: "flex", flexDirection: "column", gap: 3 }}>
        {slices.map((s, i) => (
          <div key={i} style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 10 }}>
            <span style={{ width: 8, height: 8, borderRadius: 2, background: s.color }} />
            <span style={{ color: "var(--text-muted)", textTransform: "uppercase", letterSpacing: ".3px", flex: 1 }}>{s.label}</span>
            <span style={{ color: "var(--text-bright)", fontWeight: 800 }}>{s.pct}%</span>
          </div>
        ))}
      </div>
    </div>
  );
}

Object.assign(window, { LineGraph, Donut });
