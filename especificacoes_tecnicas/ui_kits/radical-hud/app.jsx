// app.jsx — RADICAL-WM VIOLET HUD desktop. Wires the top bar, on-click dashboards,
// context menu, power menu, app launcher, and mock tiled terminal windows.

const INITIAL_TAGS = [
  { id: "t1", name: "Term", icon: "term", clients: 1 },
  { id: "t2", name: "Internet", icon: "internet", clients: 2 },
  { id: "t3", name: "Files", icon: "files", clients: 0 },
  { id: "t4", name: "Develop", icon: "develop", clients: 1 },
  { id: "t5", name: "Edit", icon: "edit", clients: 0 },
  { id: "t6", name: "Media", icon: "media", clients: 0 },
];
const NEW_TAG_ICONS = ["doc", "term", "internet", "files", "develop", "edit", "media"];

// seed a wandering 0..1 history series
function seedHist(n, base) {
  const a = []; let v = base;
  for (let i = 0; i < n; i++) { v = Math.max(0.05, Math.min(0.95, v + (Math.random() - 0.5) * 0.25)); a.push(v); }
  return a;
}

function App() {
  const [tags, setTags] = React.useState(INITIAL_TAGS);
  const [selected, setSelected] = React.useState("t1");
  const [tagMenu, setTagMenu] = React.useState(null);  // {id,x,y,name}
  const [renamingId, setRenamingId] = React.useState(null);
  const newCount = React.useRef(0);
  const [popup, setPopup] = React.useState(null);      // system|network|time|volume
  const [ctx, setCtx] = React.useState(null);          // {x,y}
  const [power, setPower] = React.useState(false);
  const [launcher, setLauncher] = React.useState(false);
  const [focusWin, setFocusWin] = React.useState("htop");
  const [toast, setToast] = React.useState(null);
  const [hist, setHist] = React.useState({ cpu: seedHist(40, 0.4), mem: seedHist(40, 0.6), net: seedHist(40, 0.3) });
  const [stats, setStats] = React.useState({ cpu: "23%", mem: "61%", gpu: "12%", net: "↑12 ↓4", vol: "98%" });

  // live tick — push new graph samples + jitter the lozenge stats
  React.useEffect(() => {
    const t = setInterval(() => {
      setHist(h => ({
        cpu: [...h.cpu.slice(1), Math.max(0.05, Math.min(0.95, h.cpu[h.cpu.length - 1] + (Math.random() - 0.5) * 0.22))],
        mem: [...h.mem.slice(1), Math.max(0.05, Math.min(0.95, h.mem[h.mem.length - 1] + (Math.random() - 0.5) * 0.12))],
        net: [...h.net.slice(1), Math.max(0.05, Math.min(0.95, h.net[h.net.length - 1] + (Math.random() - 0.5) * 0.35))],
      }));
      setStats(s => ({
        ...s,
        cpu: Math.round(10 + Math.random() * 40) + "%",
        mem: Math.round(50 + Math.random() * 25) + "%",
        gpu: Math.round(5 + Math.random() * 30) + "%",
        net: `↑${Math.round(Math.random() * 40)} ↓${Math.round(Math.random() * 12)}`,
      }));
    }, 1500);
    return () => clearInterval(t);
  }, []);

  const showToast = (msg) => { setToast(msg); setTimeout(() => setToast(null), 2200); };
  const onKill = (name) => showToast(`SIGTERM → ${name}`);
  const togglePopup = (g) => {
    if (g === "volume") { setPopup(p => p === "volume" ? null : "volume"); return; }
    setPopup(p => (p === g ? null : g));
  };

  // ---- tag management (add / remove / rename / relocate) ----
  const addTag = (icon) => {
    newCount.current += 1;
    const id = "n" + Date.now();
    const ic = (typeof icon === "string" && icon) ? icon : NEW_TAG_ICONS[newCount.current % NEW_TAG_ICONS.length];
    setTags(ts => [...ts, { id, name: "NewTag", icon: ic, clients: 0 }]);
    setSelected(id);
    showToast("ADD TAG → NewTag");
  };
  const changeIcon = (id, icon) => {
    setTags(ts => ts.map(t => (t.id === id ? { ...t, icon } : t)));
    showToast("ICON \u2192 " + (icon || "").toUpperCase());
  };
  const removeTag = (id) => {
    setTags(ts => {
      if (ts.length <= 1) return ts;
      const idx = ts.findIndex(t => t.id === id);
      const next = ts.filter(t => t.id !== id);
      if (selected === id) setSelected(next[Math.max(0, idx - 1)].id);
      return next;
    });
  };
  const moveTag = (id, dir) => {
    setTags(ts => {
      const i = ts.findIndex(t => t.id === id);
      const j = i + dir;
      if (i < 0 || j < 0 || j >= ts.length) return ts;
      const next = [...ts];
      [next[i], next[j]] = [next[j], next[i]];
      return next;
    });
  };
  const renameCommit = (id, name) => {
    setTags(ts => ts.map(t => (t.id === id ? { ...t, name } : t)));
    setRenamingId(null);
  };
  const openTagMenu = (id, el) => {
    const r = el.getBoundingClientRect();
    const t = tags.find(x => x.id === id);
    setSelected(id);
    setTagMenu({ id, x: r.left, y: r.bottom + 4, name: t ? t.name : "" });
  };

  const popupNode = {
    system: <SystemDashboard history={hist} onKill={onKill} />,
    network: <NetworkDashboard history={hist} onKill={onKill} />,
    time: <TimeDashboard />,
    volume: <VolumeDashboard />,
  }[popup];

  return (
    <div className="desktop" onClick={() => { setCtx(null); setTagMenu(null); if (launcher) setLauncher(false); }}>
      {/* tiled terminal windows */}
      <div className="grid-bg">
        <TermWindow title="lepagee@radical:~/htop · 120x36" focused={focusWin === "htop"}
          style={{ gridArea: "a" }} onClick={(e) => { e.stopPropagation(); setFocusWin("htop"); }}
          onContext={(e) => { e.preventDefault(); setFocusWin("htop"); setCtx({ x: e.clientX, y: e.clientY }); }}>
          <HtopContent />
        </TermWindow>
        <TermWindow title="root@radical:~ · neofetch" focused={focusWin === "neo"}
          style={{ gridArea: "b" }} onClick={(e) => { e.stopPropagation(); setFocusWin("neo"); }}
          onContext={(e) => { e.preventDefault(); setFocusWin("neo"); setCtx({ x: e.clientX, y: e.clientY }); }}>
          <NeofetchContent />
        </TermWindow>
        <TermWindow title="lepagee@radical:~/src · zsh" focused={focusWin === "log"}
          style={{ gridArea: "c" }} onClick={(e) => { e.stopPropagation(); setFocusWin("log"); }}
          onContext={(e) => { e.preventDefault(); setFocusWin("log"); setCtx({ x: e.clientX, y: e.clientY }); }}>
          <LogContent />
        </TermWindow>
      </div>

      {/* top bar */}
      <div className="topbar" onClick={(e) => e.stopPropagation()}>
        <div className="topbar__left">
          <TagTabs tags={tags} selected={selected} onSelect={setSelected}
            onTagMenu={openTagMenu} renamingId={renamingId} onRenameCommit={renameCommit} />
          <TagControls onAdd={addTag} onRemove={() => removeTag(selected)}
            onMoveLeft={() => moveTag(selected, -1)} onMoveRight={() => moveTag(selected, 1)} />
        </div>
        <div className="topbar__center"></div>
        <div className="topbar__right">
          <RightCluster onPower={() => setPower(true)}
            clock={{ hm: "01:42", dt: "Jan 02" }}
            onOpenTime={() => togglePopup("time")} timeActive={popup === "time"} />
        </div>
      </div>

      {/* bottom telemetry dock — the monitor bar, moved down + enlarged */}
      <MonitorBar onOpen={togglePopup} vol={parseInt(stats.vol)} onVol={() => togglePopup("volume")} />

      {/* on-click dashboard popup, anchored above the dock (time stays top-right) */}
      {popupNode && (
        <div className={"popup" + (popup === "time" ? " popup--right" : " popup--bottom")} onClick={(e) => e.stopPropagation()}>{popupNode}</div>
      )}

      {/* context menu */}
      {ctx && <ContextMenu x={ctx.x} y={ctx.y} onClose={() => setCtx(null)} />}

      {/* tag management menu */}
      <TagMenu menu={tagMenu} onClose={() => setTagMenu(null)} canRemove={tags.length > 1}
        onRename={() => { setRenamingId(tagMenu.id); setTagMenu(null); }}
        onMoveLeft={() => moveTag(tagMenu.id, -1)}
        onMoveRight={() => moveTag(tagMenu.id, 1)}
        onChangeIcon={(ic) => changeIcon(tagMenu.id, ic)}
        onRemove={() => removeTag(tagMenu.id)} />

      {/* power menu */}
      {power && <PowerMenu onClose={() => setPower(false)} />}

      {/* app launcher */}
      <AppLauncher open={launcher} onToggle={(e) => { setLauncher(o => !o); }}
        onLaunch={(a) => { setLauncher(false); showToast(`LAUNCH → ${a.label}`); }} />

      {/* notification toast */}
      {toast && <div className="toast">{toast}</div>}

      {/* hint */}
      <div className="hint">CLICK A MONITOR MODULE · RIGHT-CLICK A TAG OR WINDOW · ⊕⊖‹› MANAGE TAGS · ⏻ POWER</div>
    </div>
  );
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
