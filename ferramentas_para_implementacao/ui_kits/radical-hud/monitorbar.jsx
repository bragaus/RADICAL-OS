// monitorbar.jsx — VIOLET HUD bottom telemetry dock. The "monitor bar" moved from
// the top center to the bottom of the screen, enlarged and far more descriptive:
// four modules (RTX / AMD / MEMORY / WWW) with OVERLAPPING area graphs (additive
// neon blend), big live readouts, and dense technical footers. Cyberpunk / hacker
// chrome: blinking REC telemetry strip, hazard stripes, scanlines, NODE//STATUS rail.
// Module brand labels use the Xirod display face per the user's request.

const _clamp = (v) => Math.max(0.04, Math.min(0.97, v));
function _seed(n, base, vol) {
  const a = []; let v = base;
  for (let i = 0; i < n; i++) { v = _clamp(v + (Math.random() - 0.5) * vol); a.push(v); }
  return a;
}
const _push = (arr, vol) => [...arr.slice(1), _clamp(arr[arr.length - 1] + (Math.random() - 0.5) * vol)];
const _last = (arr) => arr[arr.length - 1];

// module manifest. colors = overlapping series (front → back). lbl = Xirod size.
const MON_MODS = [
  { key: "gpu", group: "system", label: "RTX",    lbl: 24, sub: "GPU // RTX CORE",   icon: "gpu", accent: "var(--data1)",     colors: ["var(--data1)", "var(--data4)"] },
  { key: "cpu", group: "system", label: "AMD",    lbl: 24, sub: "CPU // RYZEN 16T",  icon: "cpu", accent: "var(--glow-core)", colors: ["var(--glow-core)", "var(--data2)", "var(--v400)"] },
  { key: "mem", group: "system", label: "MEMORY", lbl: 15, sub: "RAM // DDR5 16G",   icon: "mem", accent: "var(--data2)",     colors: ["var(--data2)", "var(--data5)"] },
  { key: "net", group: "network", label: "WWW",   lbl: 22, sub: "NET // UPLINK eno1", icon: "net", accent: "var(--data4)",    colors: ["var(--data4)", "var(--glow-hot)"] },
];

// translate the latest series values into the big number + descriptive footer cells.
function monReadout(key, d) {
  const a = d[key], l = a[0].length - 1;
  const p = a[0][l], s = a[1] ? a[1][l] : 0;
  switch (key) {
    case "gpu":
      return { big: [Math.round(p * 100), "%"], foot: [
        ["USE", Math.round(p * 100) + "%"], ["TEMP", (52 + Math.round(p * 26)) + "°C"],
        ["CLK", (1900 + Math.round(p * 640)) + "MHz"], ["VRAM", (2.4 + s * 9).toFixed(1) + "/12G"],
        ["FAN", (28 + Math.round(p * 46)) + "%"]] };
    case "cpu": {
      const avg = (a[0][l] + a[1][l] + a[2][l]) / 3;
      return { big: [Math.round(avg * 100), "%"], foot: [
        ["LOAD", Math.round(avg * 100) + "%"], ["TEMP", (44 + Math.round(avg * 30)) + "°C"],
        ["CLK", (3.2 + avg * 1.5).toFixed(1) + "GHz"], ["CORES", "16T"],
        ["1m", (0.4 + avg * 3).toFixed(2)]] };
    }
    case "mem":
      return { big: [Math.round(p * 100), "%"], foot: [
        ["USED", (p * 16).toFixed(1) + "/16G"], ["CACHE", (1 + s * 4).toFixed(1) + "G"],
        ["SWAP", (s * 0.6).toFixed(1) + "G"], ["BUFF", (120 + Math.round(s * 480)) + "M"]] };
    case "net":
      return { big: [(p * 42).toFixed(1), "M/s", "↓"], foot: [
        ["DOWN", "↓" + (p * 42).toFixed(1) + "M"], ["UP", "↑" + (s * 14).toFixed(1) + "M"],
        ["PING", (8 + Math.round(s * 40)) + "ms"], ["CONN", (28 + Math.round(p * 40)) + ""],
        ["TX", (0.8 + p * 3).toFixed(1) + "G"]] };
    default: return { big: [0, ""], foot: [] };
  }
}

// measure helper removed — graph uses a fixed viewBox that stretches to its box.

// Overlapping area graph. series:[{data,color}]. additive 'screen' blend so where the
// translucent fills cross, the violet lifts — the layered neon look from the reference.
// Fixed viewBox + preserveAspectRatio:none stretches to any module width; strokes stay
// crisp via non-scaling-stroke.
function MonGraph({ series, gid }) {
  const VW = 1000, VH = 120, top = 4, bot = VH - 1;
  const xy = (data) => data.map((v, i) => [(i / (data.length - 1)) * VW, top + (1 - v) * (bot - top)]);
  const line = (pts) => pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
  const area = (pts) => line(pts) + ` L${VW} ${VH} L0 ${VH} Z`;
  const cols = [0.2, 0.4, 0.6, 0.8];
  return (
    <div className="mg">
      <svg viewBox={`0 0 ${VW} ${VH}`} preserveAspectRatio="none">
        <defs>
          {series.map((s, i) => (
            <linearGradient key={i} id={`mg-${gid}-${i}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={s.color} stopOpacity="0.6" />
              <stop offset="62%" stopColor={s.color} stopOpacity="0.16" />
              <stop offset="100%" stopColor={s.color} stopOpacity="0.02" />
            </linearGradient>
          ))}
        </defs>
        {/* grid */}
        {[0.25, 0.5, 0.75].map((g, i) => (
          <line key={"h" + i} x1="0" x2={VW} y1={top + g * (bot - top)} y2={top + g * (bot - top)}
            stroke="var(--grid)" strokeWidth="1" vectorEffect="non-scaling-stroke" opacity={i % 2 ? 0.16 : 0.28} />
        ))}
        {cols.map((g, i) => (
          <line key={"v" + i} x1={g * VW} x2={g * VW} y1={top} y2={VH} stroke="var(--v400)"
            strokeWidth="1" vectorEffect="non-scaling-stroke" opacity="0.07" />
        ))}
        {/* overlapping series — additive */}
        {series.map((s, i) => {
          const pts = xy(s.data);
          return (
            <g key={i} style={{ mixBlendMode: "screen" }}>
              <path d={area(pts)} fill={`url(#mg-${gid}-${i})`} />
              <path d={line(pts)} fill="none" stroke={s.color} strokeWidth="4" vectorEffect="non-scaling-stroke" opacity="0.22" />
              <path d={line(pts)} fill="none" stroke={s.color} strokeWidth="1.6" vectorEffect="non-scaling-stroke"
                strokeLinejoin="round" strokeLinecap="round" />
            </g>
          );
        })}
      </svg>
    </div>
  );
}

function MonModule({ mod, d, onOpen, z, first }) {
  const r = monReadout(mod.key, d);
  const series = d[mod.key].map((data, i) => ({ data, color: mod.colors[i] }));
  return (
    <div className={"monmod" + (first ? " monmod--first" : "")} style={{ zIndex: z }}
      onClick={() => onOpen(mod.group)} title={"OPEN " + mod.group.toUpperCase() + " DASHBOARD"}>
      <span className="monmod__edge" />
      <div className="monmod__inner">
        <div className="monmod__bg"><MonGraph series={series} gid={mod.key} /></div>
        <div className="monmod__overlay">
          <div className="monmod__head">
            <div className="monmod__id">
              <span className="monmod__label" style={{ fontSize: mod.lbl, textShadow: `0 0 16px ${mod.accent}` }}>{mod.label}</span>
              <span className="monmod__sub">
                <img className="monmod__subicon" src={ICON(mod.icon)} alt="" />{mod.sub}
              </span>
            </div>
            <div className="monmod__big">
              {r.big[2] && <span className="monmod__bigp">{r.big[2]}</span>}
              <span className="monmod__bigv">{r.big[0]}</span>
              <span className="monmod__bigu">{r.big[1]}</span>
            </div>
          </div>
          <div className="monmod__foot">
            {r.foot.slice(0, 4).map((f, i) => (
              <span key={i} className="monfoot"><span className="monfoot__k">{f[0]}</span><span className="monfoot__v">{f[1]}</span></span>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// right status rail — compact arrow segment that closes the powerline ribbon
function MonRail({ d, vol, onVol, z }) {
  const l = d.cpu[0].length - 1;
  const load = Math.round(((d.cpu[0][l] + d.gpu[0][l] + d.mem[0][l]) / 3) * 100);
  return (
    <div className="monrail" style={{ zIndex: z }} onClick={(e) => e.stopPropagation()}>
      <span className="monrail__edge" />
      <div className="monrail__inner">
        <div className="monrail__top">
          <span className="monrail__hd">NODE // STATUS</span>
          <span className="monrail__st"><i />ONLINE</span>
        </div>
        <div className="monrail__vol" onClick={() => onVol && onVol()} title="VOLUME">
          <img src={ICON("vol")} alt="" />
          <span className="monrail__track"><span style={{ width: vol + "%" }} /></span>
          <span className="monrail__volv">{vol}%</span>
        </div>
        <div className="monrail__load">
          <span className="monrail__loadk">AGGREGATE LOAD</span>
          <span className="monrail__loadv">{load}<i>%</i></span>
        </div>
      </div>
    </div>
  );
}

function MonitorBar({ onOpen, vol = 98, onVol }) {
  const N = 58;
  const [d, setD] = React.useState(() => ({
    gpu: [_seed(N, 0.5, 0.18), _seed(N, 0.32, 0.10)],
    cpu: [_seed(N, 0.4, 0.22), _seed(N, 0.28, 0.16), _seed(N, 0.52, 0.12)],
    mem: [_seed(N, 0.56, 0.06), _seed(N, 0.30, 0.05)],
    net: [_seed(N, 0.30, 0.42), _seed(N, 0.18, 0.30)],
  }));
  React.useEffect(() => {
    const t = setInterval(() => setD((p) => ({
      gpu: [_push(p.gpu[0], 0.18), _push(p.gpu[1], 0.10)],
      cpu: [_push(p.cpu[0], 0.22), _push(p.cpu[1], 0.16), _push(p.cpu[2], 0.12)],
      mem: [_push(p.mem[0], 0.06), _push(p.mem[1], 0.05)],
      net: [_push(p.net[0], 0.42), _push(p.net[1], 0.30)],
    })), 1100);
    return () => clearInterval(t);
  }, []);
  return (
    <div className="monitorbar" onClick={(e) => e.stopPropagation()}>
      <div className="monbar__strip">
        <span className="monbar__rec"><i />REC</span>
        <span className="monbar__id">LIVE TELEMETRY · RADICAL-WM // SYSMON</span>
        <span className="monbar__haz" />
        <span className="monbar__flex" />
        <span className="monbar__hex">0x7F3A·E1</span>
        <span className="monbar__node">NODE STATUS: <b>ONLINE</b></span>
      </div>
      <div className="monbar__row">
        {MON_MODS.map((m, i) => <MonModule key={m.key} mod={m} d={d} onOpen={onOpen} z={MON_MODS.length - i + 1} first={i === 0} />)}
        <MonRail d={d} vol={vol} onVol={onVol} z={1} />
      </div>
    </div>
  );
}

Object.assign(window, { MonitorBar });
