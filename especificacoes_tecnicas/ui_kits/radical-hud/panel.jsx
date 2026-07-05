// panel.jsx — VIOLET HUD panel chrome + data primitives (DS §7.1, §7.4)
// The central motif: header (uppercase) + gradient divider + body + thin border
// + 2-tone bevel + 4 corner ticks. Everything else lives inside one of these.

const ICONS = "../../assets/icons/";
// Resolve an icon by base name. In a bundled/standalone build the inliner populates
// window.__resources[name] with a blob URL (see the ext-resource-dependency metas);
// otherwise we fall back to the on-disk relative path.
const ICON = (n) => (typeof window !== "undefined" && window.__resources && window.__resources[n]) || (ICONS + n + ".svg");

// Panel chrome. props: title, accent, icon (name), focus, width, children
function Panel({ title, accent = "var(--v500)", icon, focus, width, children, style }) {
  return (
    <div className={"hp" + (focus ? " hp--focus" : "")} style={{ width, ...style }}>
      <i className="hp__tick hp__tick--tl" /><i className="hp__tick hp__tick--tr" />
      <i className="hp__tick hp__tick--bl" /><i className="hp__tick hp__tick--br" />
      <div className="hp__hd">
        <span className="hp__title">{title}</span>
        {icon && <img className="hp__hdicon" src={ICON(icon)} alt="" />}
      </div>
      <div className="hp__dv" style={{ background: `linear-gradient(90deg, ${accent}, color-mix(in srgb, ${accent} 22%, transparent) 55%, transparent)` }} />
      <div className="hp__bd">{children}</div>
    </div>
  );
}

// Key/value row. right number, left label.
function InfoRow({ k, v, vColor, chip }) {
  return (
    <div className={"ir" + (chip ? " ir--chip" : "")}>
      <span className="ir__k">{k}</span>
      <span className="ir__v" style={vColor ? { color: vColor } : null}>{v}</span>
    </div>
  );
}

// Horizontal bar meter (USAGE). pct 0..100, alert flips to glow_hot.
function BarMeter({ label, pct, alert }) {
  const hot = alert || pct >= 90;
  return (
    <div className="bm">
      <span className="bm__lbl">{label}</span>
      <span className="bm__track">
        <span className="bm__fill" style={{
          width: pct + "%",
          background: hot ? "var(--glow-hot)" : "linear-gradient(90deg,var(--v700),var(--v500))"
        }} />
      </span>
      <span className="bm__val" style={hot ? { color: "var(--glow-hot)" } : null}>{pct}%</span>
    </div>
  );
}

// Tabular row used by PROCESS / CONNECTIONS / USAGE tables.
function TableRow({ cells, header, onKill, killHover }) {
  return (
    <div className={"tr" + (header ? " tr--hd" : "")}>
      {cells.map((c, i) => (
        <span key={i} className="tr__c" style={{ width: c.w, textAlign: c.align || "left", color: c.color || (header ? "var(--text-faint)" : "var(--text-primary)") }}>{c.t}</span>
      ))}
      {onKill !== undefined && (
        header
          ? <span className="tr__c" style={{ width: 26 }} />
          : <KillBtn onKill={onKill} />
      )}
    </div>
  );
}

function KillBtn({ onKill }) {
  const [h, setH] = React.useState(false);
  return (
    <span className="killbtn" onMouseEnter={() => setH(true)} onMouseLeave={() => setH(false)}
      onClick={onKill} title="SIGTERM">
      <img src={ICON("kill")} alt="kill" className={h ? "killbtn--hot" : ""} />
    </span>
  );
}

// Thin windowed scroll list: fixed VISIBLE rows, wheel scrolls, thumb on right.
function ScrollList({ rows, visible = 6, rowH = 18, header, empty }) {
  const [offset, setOffset] = React.useState(0);
  const max = Math.max(0, rows.length - visible);
  const clamped = Math.min(offset, max);
  const onWheel = (e) => {
    e.preventDefault();
    setOffset(o => Math.max(0, Math.min(max, o + (e.deltaY > 0 ? 1 : -1))));
  };
  const slice = rows.slice(clamped, clamped + visible);
  const thumbH = rows.length > visible ? Math.max((visible / rows.length) * 100, 14) : 0;
  const thumbT = max > 0 ? (clamped / max) * (100 - thumbH) : 0;
  return (
    <div>
      {header}
      <div className="sl" style={{ height: visible * rowH + (visible - 1) * 2 }} onWheel={onWheel}>
        <div className="sl__rows">
          {slice.length ? slice : <div className="sl__empty">{empty || "NO DATA"}</div>}
        </div>
        {thumbH > 0 && (
          <div className="sl__track">
            <div className="sl__thumb" style={{ height: thumbH + "%", top: thumbT + "%" }} />
          </div>
        )}
      </div>
    </div>
  );
}

Object.assign(window, { Panel, InfoRow, BarMeter, TableRow, KillBtn, ScrollList, ICONS, ICON });
