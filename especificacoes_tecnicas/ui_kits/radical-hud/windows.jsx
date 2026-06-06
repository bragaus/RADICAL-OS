// windows.jsx — mock tiled terminal windows that fill the desktop behind the HUD.
// Tiling WM look: thin-bordered terminals, focused = glow_core border. Translucent.

// A tiled terminal window. props: title, focused, lines[], onContext, style
function TermWindow({ title, focused, children, style, onContext, onClick }) {
  return (
    <div className={"win" + (focused ? " win--focus" : "")} style={style}
      onContextMenu={onContext} onClick={onClick}>
      <div className="win__bar">
        <span className="win__title">{title}</span>
        <span className="win__btns">
          <i className="win__b" />
          <i className="win__b" />
          <i className="win__b win__b--x" />
        </span>
      </div>
      <div className="win__body">{children}</div>
    </div>
  );
}

// htop-ish meters
function HtopContent() {
  const bars = [["1", 0.62, "var(--data1)"], ["2", 0.31, "var(--data1)"], ["3", 0.44, "var(--data2)"], ["4", 0.18, "var(--data1)"]];
  return (
    <div className="term">
      {bars.map((b) => (
        <div key={b[0]} className="term__line">
          <span style={{ color: "var(--text-muted)" }}>{b[0]} </span>
          <span style={{ color: "var(--text-faint)" }}>[</span>
          <span style={{ color: b[2] }}>{"|".repeat(Math.round(b[1] * 22))}</span>
          <span style={{ color: "var(--line-dim)" }}>{" ".repeat(22 - Math.round(b[1] * 22))}</span>
          <span style={{ color: "var(--text-faint)" }}>]</span>
          <span style={{ color: "var(--text-bright)" }}> {Math.round(b[1] * 100)}%</span>
        </div>
      ))}
      <div className="term__line" style={{ color: "var(--text-muted)", marginTop: 6 }}>  PID USER     CPU% MEM%  COMMAND</div>
      {[["3208", "root", "22.4", "8.1", "firefox"], ["1142", "root", "12.3", "3.2", "Xorg"], ["4471", "lepagee", "7.0", "1.4", "awesome"], ["6633", "lepagee", "4.4", "2.1", "node"]].map((r) => (
        <div key={r[0]} className="term__line">
          <span style={{ color: "var(--v400)" }}>{r[0].padStart(5)}</span>
          <span style={{ color: "var(--text-primary)" }}> {r[1].padEnd(8)}</span>
          <span style={{ color: "var(--text-bright)" }}>{r[2].padStart(5)}</span>
          <span style={{ color: "var(--text-body)" }}>{r[3].padStart(5)}</span>
          <span style={{ color: "var(--glow-ice)" }}>  {r[4]}</span>
        </div>
      ))}
    </div>
  );
}

function NeofetchContent() {
  const rows = [["OS", "Linux Radical OS"], ["KERNEL", "6.18.5-radical"], ["WM", "awesome 4.3"], ["SHELL", "zsh 5.9"], ["TERM", "alacritty"], ["THEME", "VIOLET HUD"], ["CPU", "i7 Quad @ 2.40GHz"], ["MEM", "7977MiB / 16GiB"]];
  return (
    <div className="term">
      <pre className="term__art">{` ▟█▙   RADICAL\n▟███▙  ───────\n█████  user@radical\n▜███▛  uptime 04:21\n ▜█▛   `}</pre>
      {rows.map((r) => (
        <div key={r[0]} className="term__line">
          <span style={{ color: "var(--v400)", fontWeight: 800 }}>{r[0]}</span>
          <span style={{ color: "var(--text-faint)" }}> · </span>
          <span style={{ color: "var(--text-primary)" }}>{r[1]}</span>
        </div>
      ))}
    </div>
  );
}

function LogContent() {
  const lines = [
    ["~$ ", "git log --oneline", "var(--text-bright)"],
    ["", "a1b2c3d  feat: violet hud palette", "var(--text-primary)"],
    ["", "e4f5g6h  fix: tag arrow shape", "var(--text-primary)"],
    ["", "i7j8k9l  panel chrome factory", "var(--text-primary)"],
    ["", "m0n1o2p  icon set → 41 svg", "var(--text-primary)"],
    ["~$ ", "nmap -sV 10.10.10.139", "var(--text-bright)"],
    ["", "PORT    STATE  SERVICE", "var(--text-muted)"],
    ["", "443/tcp open   https", "var(--ok)"],
    ["", "22/tcp  open   ssh", "var(--ok)"],
    ["~$ ", "_", "var(--glow-ice)"],
  ];
  return (
    <div className="term">
      {lines.map((l, i) => (
        <div key={i} className="term__line">
          <span style={{ color: "var(--v500)" }}>{l[0]}</span>
          <span style={{ color: l[2] }}>{l[1]}</span>
        </div>
      ))}
    </div>
  );
}

Object.assign(window, { TermWindow, HtopContent, NeofetchContent, LogContent });
