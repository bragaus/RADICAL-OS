// menus.jsx — context menu, app launcher, power menu, mock desktop windows.

// Context menu (DS §7.5): gradient title band + dense items + Send Signal submenu.
const MENU_ITEMS = [
  { icon: "visible", label: "Visible" },
  { icon: "sticky", label: "Sticky" },
  { icon: "floating", label: "Floating" },
  { icon: "fullscreen", label: "Fullscreen" },
  { icon: "send_signal", label: "Send Signal", sub: true },
  { icon: "close", label: "Close" },
];
const SIGNALS = ["SIGHUP", "SIGINT", "SIGQUIT", "SIGKILL", "SIGTERM", "SIGSTOP", "SIGCONT", "SIGUSR1", "SIGUSR2"];

function ContextMenu({ x, y, onClose }) {
  const [subOpen, setSubOpen] = React.useState(false);
  return (
    <div className="ctxwrap" onMouseLeave={onClose}>
      <div className="ctx" style={{ left: x, top: y }}>
        <div className="ctx__band">CLIENT · alacritty</div>
        {MENU_ITEMS.map((it) => (
          <div key={it.label} className="ctx__item"
            onMouseEnter={() => setSubOpen(it.sub)}
            onClick={() => { if (!it.sub) onClose(); }}>
            <img src={ICON(it.icon)} alt="" />
            <span>{it.label}</span>
            {it.sub && <span className="ctx__arrow">▸</span>}
          </div>
        ))}
      </div>
      {subOpen && (
        <div className="ctx ctx--sub" style={{ left: x + 208, top: y + 120 }}>
          <div className="ctx__band">SEND SIGNAL</div>
          {SIGNALS.map((s) => (
            <div key={s} className={"ctx__sig" + (s === "SIGKILL" || s === "SIGTERM" ? " ctx__sig--danger" : "")}
              onClick={onClose}>{s}</div>
          ))}
        </div>
      )}
    </div>
  );
}

// Power menu (DS §7.6 powermenu): chip buttons with recolored icons.
const POWER = [
  { icon: "shutdown", label: "Shutdown" },
  { icon: "reboot", label: "Reboot" },
  { icon: "suspend", label: "Suspend" },
  { icon: "lock", label: "Lock" },
  { icon: "logout", label: "Logout" },
];
function PowerMenu({ onClose }) {
  return (
    <div className="pmwrap" onClick={onClose}>
      <div className="pm" onClick={(e) => e.stopPropagation()}>
        {POWER.map((p) => (
          <button key={p.label} className="pm__chip">
            <img src={ICON(p.icon)} alt="" />
            <span>{p.label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

// App launcher (DS §7.6) — orbital "gear": the animated logo.gif is the hub; apps
// orbit around it and the mouse wheel spins the ring like a gear, enlarging the app
// at the focus angle (up-left, toward the screen).
const APPS = [
  { icon: "internet", label: "Firefox" },
  { icon: "develop", label: "Neovim" },
  { icon: "term", label: "Alacritty" },
  { icon: "files", label: "Yazi" },
  { icon: "media", label: "MPV" },
  { icon: "edit", label: "GIMP" },
  { icon: "doc", label: "Zathura" },
  { icon: "send_signal", label: "Wireshark" },
  { icon: "calendar", label: "Calendar" },
];
function AppLauncher({ open, onToggle, onLaunch }) {
  const [rot, setRot] = React.useState(0);
  const rotRef = React.useRef(0);
  const velRef = React.useRef(0);
  const rafRef = React.useRef(null);
  const R = 168;            // ring radius
  const FOCUS = 225;        // focus angle (up-left, into the screen)
  const n = APPS.length;
  const step = 360 / n;
  // momentum loop: apply velocity to rotation, decay with friction (keeps spinning, slows down)
  const spin = React.useCallback(() => {
    velRef.current *= 0.95;
    rotRef.current += velRef.current;
    setRot(rotRef.current);
    if (Math.abs(velRef.current) < 0.04) { velRef.current = 0; rafRef.current = null; return; }
    rafRef.current = requestAnimationFrame(spin);
  }, []);
  const onWheel = (e) => {
    if (!open) return;
    e.preventDefault();
    velRef.current += (e.deltaY > 0 ? -1 : 1) * 5.5;        // impulse per notch
    velRef.current = Math.max(-26, Math.min(26, velRef.current)); // clamp top speed
    if (!rafRef.current) rafRef.current = requestAnimationFrame(spin);
  };
  React.useEffect(() => () => { if (rafRef.current) cancelAnimationFrame(rafRef.current); }, []);
  React.useEffect(() => {
    if (!open && rafRef.current) { cancelAnimationFrame(rafRef.current); rafRef.current = null; velRef.current = 0; }
  }, [open]);
  return (
    <div className="launcher" onClick={(e) => e.stopPropagation()} onWheel={onWheel}>
      {open && (
        <div className="orbit">
          <span className="orbit__zone" onClick={onToggle} />
          <span className="orbit__glow" />
          <span className="orbit__guide" />
          {APPS.map((a, i) => {
            const ang = i * step + rot;
            const rad = (ang * Math.PI) / 180;
            const x = Math.cos(rad) * R;
            const y = Math.sin(rad) * R;
            let diff = Math.abs((((ang - FOCUS) % 360) + 360) % 360);
            if (diff > 180) diff = 360 - diff;
            const active = diff < step / 2;
            const vis = x < 46 && y < 46;        // on-screen (upper-left) arc
            return (
              <button key={a.label}
                className={"orbit__app" + (active ? " orbit__app--on" : "")}
                style={{ transform: `translate(${x}px, ${y}px) scale(${active ? 1.28 : 1})`,
                         opacity: vis ? 1 : 0, pointerEvents: vis ? "auto" : "none",
                         zIndex: active ? 3 : 2 }}
                onClick={() => onLaunch(a)}>
                <img src={ICON(a.icon)} alt="" />
                {active && <span className="orbit__lbl">{a.label}</span>}
              </button>
            );
          })}
        </div>
      )}
      <button className={"launcher__btn" + (open ? " launcher__btn--on" : "")} onClick={onToggle} title="applications">
        <span className="launcher__gif" />
        <span className="launcher__ring" />
      </button>
    </div>
  );
}

Object.assign(window, { ContextMenu, PowerMenu, AppLauncher });
