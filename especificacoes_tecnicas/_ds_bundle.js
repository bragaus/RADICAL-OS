/* @ds-bundle: {"format":3,"namespace":"RADICALWMVioletHUDDesignSystem_199d75","components":[],"sourceHashes":{"ui_kits/radical-hud/app.jsx":"8b5d3278d652","ui_kits/radical-hud/charts.jsx":"4bccfcb8c949","ui_kits/radical-hud/dashboards.jsx":"1b64368c4a3f","ui_kits/radical-hud/menus.jsx":"7fc583adb0b3","ui_kits/radical-hud/monitorbar.jsx":"e6c70c6d35af","ui_kits/radical-hud/panel.jsx":"4dd5b2f473a7","ui_kits/radical-hud/topbar.jsx":"fa45501d95c7","ui_kits/radical-hud/windows.jsx":"e70c0c109dcc"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.RADICALWMVioletHUDDesignSystem_199d75 = window.RADICALWMVioletHUDDesignSystem_199d75 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// ui_kits/radical-hud/app.jsx
try { (() => {
// app.jsx — RADICAL-WM VIOLET HUD desktop. Wires the top bar, on-click dashboards,
// context menu, power menu, app launcher, and mock tiled terminal windows.

const INITIAL_TAGS = [{
  id: "t1",
  name: "Term",
  icon: "term",
  clients: 1
}, {
  id: "t2",
  name: "Internet",
  icon: "internet",
  clients: 2
}, {
  id: "t3",
  name: "Files",
  icon: "files",
  clients: 0
}, {
  id: "t4",
  name: "Develop",
  icon: "develop",
  clients: 1
}, {
  id: "t5",
  name: "Edit",
  icon: "edit",
  clients: 0
}, {
  id: "t6",
  name: "Media",
  icon: "media",
  clients: 0
}];
const NEW_TAG_ICONS = ["doc", "term", "internet", "files", "develop", "edit", "media"];

// seed a wandering 0..1 history series
function seedHist(n, base) {
  const a = [];
  let v = base;
  for (let i = 0; i < n; i++) {
    v = Math.max(0.05, Math.min(0.95, v + (Math.random() - 0.5) * 0.25));
    a.push(v);
  }
  return a;
}
function App() {
  const [tags, setTags] = React.useState(INITIAL_TAGS);
  const [selected, setSelected] = React.useState("t1");
  const [tagMenu, setTagMenu] = React.useState(null); // {id,x,y,name}
  const [renamingId, setRenamingId] = React.useState(null);
  const newCount = React.useRef(0);
  const [popup, setPopup] = React.useState(null); // system|network|time|volume
  const [ctx, setCtx] = React.useState(null); // {x,y}
  const [power, setPower] = React.useState(false);
  const [launcher, setLauncher] = React.useState(false);
  const [focusWin, setFocusWin] = React.useState("htop");
  const [toast, setToast] = React.useState(null);
  const [hist, setHist] = React.useState({
    cpu: seedHist(40, 0.4),
    mem: seedHist(40, 0.6),
    net: seedHist(40, 0.3)
  });
  const [stats, setStats] = React.useState({
    cpu: "23%",
    mem: "61%",
    gpu: "12%",
    net: "↑12 ↓4",
    vol: "98%"
  });

  // live tick — push new graph samples + jitter the lozenge stats
  React.useEffect(() => {
    const t = setInterval(() => {
      setHist(h => ({
        cpu: [...h.cpu.slice(1), Math.max(0.05, Math.min(0.95, h.cpu[h.cpu.length - 1] + (Math.random() - 0.5) * 0.22))],
        mem: [...h.mem.slice(1), Math.max(0.05, Math.min(0.95, h.mem[h.mem.length - 1] + (Math.random() - 0.5) * 0.12))],
        net: [...h.net.slice(1), Math.max(0.05, Math.min(0.95, h.net[h.net.length - 1] + (Math.random() - 0.5) * 0.35))]
      }));
      setStats(s => ({
        ...s,
        cpu: Math.round(10 + Math.random() * 40) + "%",
        mem: Math.round(50 + Math.random() * 25) + "%",
        gpu: Math.round(5 + Math.random() * 30) + "%",
        net: `↑${Math.round(Math.random() * 40)} ↓${Math.round(Math.random() * 12)}`
      }));
    }, 1500);
    return () => clearInterval(t);
  }, []);
  const showToast = msg => {
    setToast(msg);
    setTimeout(() => setToast(null), 2200);
  };
  const onKill = name => showToast(`SIGTERM → ${name}`);
  const togglePopup = g => {
    if (g === "volume") {
      setPopup(p => p === "volume" ? null : "volume");
      return;
    }
    setPopup(p => p === g ? null : g);
  };

  // ---- tag management (add / remove / rename / relocate) ----
  const addTag = icon => {
    newCount.current += 1;
    const id = "n" + Date.now();
    const ic = typeof icon === "string" && icon ? icon : NEW_TAG_ICONS[newCount.current % NEW_TAG_ICONS.length];
    setTags(ts => [...ts, {
      id,
      name: "NewTag",
      icon: ic,
      clients: 0
    }]);
    setSelected(id);
    showToast("ADD TAG → NewTag");
  };
  const changeIcon = (id, icon) => {
    setTags(ts => ts.map(t => t.id === id ? {
      ...t,
      icon
    } : t));
    showToast("ICON \u2192 " + (icon || "").toUpperCase());
  };
  const removeTag = id => {
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
    setTags(ts => ts.map(t => t.id === id ? {
      ...t,
      name
    } : t));
    setRenamingId(null);
  };
  const openTagMenu = (id, el) => {
    const r = el.getBoundingClientRect();
    const t = tags.find(x => x.id === id);
    setSelected(id);
    setTagMenu({
      id,
      x: r.left,
      y: r.bottom + 4,
      name: t ? t.name : ""
    });
  };
  const popupNode = {
    system: /*#__PURE__*/React.createElement(SystemDashboard, {
      history: hist,
      onKill: onKill
    }),
    network: /*#__PURE__*/React.createElement(NetworkDashboard, {
      history: hist,
      onKill: onKill
    }),
    time: /*#__PURE__*/React.createElement(TimeDashboard, null),
    volume: /*#__PURE__*/React.createElement(VolumeDashboard, null)
  }[popup];
  return /*#__PURE__*/React.createElement("div", {
    className: "desktop",
    onClick: () => {
      setCtx(null);
      setTagMenu(null);
      if (launcher) setLauncher(false);
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "grid-bg"
  }, /*#__PURE__*/React.createElement(TermWindow, {
    title: "lepagee@radical:~/htop \xB7 120x36",
    focused: focusWin === "htop",
    style: {
      gridArea: "a"
    },
    onClick: e => {
      e.stopPropagation();
      setFocusWin("htop");
    },
    onContext: e => {
      e.preventDefault();
      setFocusWin("htop");
      setCtx({
        x: e.clientX,
        y: e.clientY
      });
    }
  }, /*#__PURE__*/React.createElement(HtopContent, null)), /*#__PURE__*/React.createElement(TermWindow, {
    title: "root@radical:~ \xB7 neofetch",
    focused: focusWin === "neo",
    style: {
      gridArea: "b"
    },
    onClick: e => {
      e.stopPropagation();
      setFocusWin("neo");
    },
    onContext: e => {
      e.preventDefault();
      setFocusWin("neo");
      setCtx({
        x: e.clientX,
        y: e.clientY
      });
    }
  }, /*#__PURE__*/React.createElement(NeofetchContent, null)), /*#__PURE__*/React.createElement(TermWindow, {
    title: "lepagee@radical:~/src \xB7 zsh",
    focused: focusWin === "log",
    style: {
      gridArea: "c"
    },
    onClick: e => {
      e.stopPropagation();
      setFocusWin("log");
    },
    onContext: e => {
      e.preventDefault();
      setFocusWin("log");
      setCtx({
        x: e.clientX,
        y: e.clientY
      });
    }
  }, /*#__PURE__*/React.createElement(LogContent, null))), /*#__PURE__*/React.createElement("div", {
    className: "topbar",
    onClick: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement("div", {
    className: "topbar__left"
  }, /*#__PURE__*/React.createElement(TagTabs, {
    tags: tags,
    selected: selected,
    onSelect: setSelected,
    onTagMenu: openTagMenu,
    renamingId: renamingId,
    onRenameCommit: renameCommit
  }), /*#__PURE__*/React.createElement(TagControls, {
    onAdd: addTag,
    onRemove: () => removeTag(selected),
    onMoveLeft: () => moveTag(selected, -1),
    onMoveRight: () => moveTag(selected, 1)
  })), /*#__PURE__*/React.createElement("div", {
    className: "topbar__center"
  }), /*#__PURE__*/React.createElement("div", {
    className: "topbar__right"
  }, /*#__PURE__*/React.createElement(RightCluster, {
    onPower: () => setPower(true),
    clock: {
      hm: "01:42",
      dt: "Jan 02"
    },
    onOpenTime: () => togglePopup("time"),
    timeActive: popup === "time"
  }))), /*#__PURE__*/React.createElement(MonitorBar, {
    onOpen: togglePopup,
    vol: parseInt(stats.vol),
    onVol: () => togglePopup("volume")
  }), popupNode && /*#__PURE__*/React.createElement("div", {
    className: "popup" + (popup === "time" ? " popup--right" : " popup--bottom"),
    onClick: e => e.stopPropagation()
  }, popupNode), ctx && /*#__PURE__*/React.createElement(ContextMenu, {
    x: ctx.x,
    y: ctx.y,
    onClose: () => setCtx(null)
  }), /*#__PURE__*/React.createElement(TagMenu, {
    menu: tagMenu,
    onClose: () => setTagMenu(null),
    canRemove: tags.length > 1,
    onRename: () => {
      setRenamingId(tagMenu.id);
      setTagMenu(null);
    },
    onMoveLeft: () => moveTag(tagMenu.id, -1),
    onMoveRight: () => moveTag(tagMenu.id, 1),
    onChangeIcon: ic => changeIcon(tagMenu.id, ic),
    onRemove: () => removeTag(tagMenu.id)
  }), power && /*#__PURE__*/React.createElement(PowerMenu, {
    onClose: () => setPower(false)
  }), /*#__PURE__*/React.createElement(AppLauncher, {
    open: launcher,
    onToggle: e => {
      setLauncher(o => !o);
    },
    onLaunch: a => {
      setLauncher(false);
      showToast(`LAUNCH → ${a.label}`);
    }
  }), toast && /*#__PURE__*/React.createElement("div", {
    className: "toast"
  }, toast), /*#__PURE__*/React.createElement("div", {
    className: "hint"
  }, "CLICK A MONITOR MODULE \xB7 RIGHT-CLICK A TAG OR WINDOW \xB7 \u2295\u2296\u2039\u203A MANAGE TAGS \xB7 \u23FB POWER"));
}
ReactDOM.createRoot(document.getElementById("root")).render(/*#__PURE__*/React.createElement(App, null));
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/radical-hud/app.jsx", error: String((e && e.message) || e) }); }

// ui_kits/radical-hud/charts.jsx
try { (() => {
// charts.jsx — VIOLET HUD data visualizations (DS §7.4.3 line graph, §7.4.4 donut)
// SVG-based. Grid at low alpha, area fill + halo line, donut slices in data1..6.

// Multi-series line graph with grid + area fill.
// props: series [{color, data:[0..1...]}], width, height
function LineGraph({
  series,
  width = 240,
  height = 96
}) {
  const pad = 4;
  const w = width,
    h = height;
  const xy = data => data.map((v, i) => {
    const x = pad + i / (data.length - 1) * (w - pad * 2);
    const y = pad + (1 - v) * (h - pad * 2);
    return [x, y];
  });
  const linePath = pts => pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
  const areaPath = pts => linePath(pts) + ` L${(w - pad).toFixed(1)} ${h - pad} L${pad} ${h - pad} Z`;
  return /*#__PURE__*/React.createElement("svg", {
    width: w,
    height: h,
    style: {
      display: "block",
      background: "var(--inset)",
      borderRadius: 4
    }
  }, [0.25, 0.5, 0.75].map((g, i) => /*#__PURE__*/React.createElement("line", {
    key: "h" + i,
    x1: pad,
    x2: w - pad,
    y1: pad + g * (h - pad * 2),
    y2: pad + g * (h - pad * 2),
    stroke: "var(--grid)",
    strokeWidth: "1",
    opacity: i % 2 ? 0.12 : 0.22
  })), [0.25, 0.5, 0.75].map((g, i) => /*#__PURE__*/React.createElement("line", {
    key: "v" + i,
    y1: pad,
    y2: h - pad,
    x1: pad + g * (w - pad * 2),
    x2: pad + g * (w - pad * 2),
    stroke: "var(--v400)",
    strokeWidth: "1",
    opacity: 0.06
  })), series.map((s, i) => {
    const pts = xy(s.data);
    return /*#__PURE__*/React.createElement("g", {
      key: i
    }, /*#__PURE__*/React.createElement("path", {
      d: areaPath(pts),
      fill: s.color,
      opacity: "0.22"
    }), /*#__PURE__*/React.createElement("path", {
      d: linePath(pts),
      fill: "none",
      stroke: s.color,
      strokeWidth: "5",
      opacity: "0.18"
    }), /*#__PURE__*/React.createElement("path", {
      d: linePath(pts),
      fill: "none",
      stroke: s.color,
      strokeWidth: "2",
      strokeLinejoin: "round",
      strokeLinecap: "round"
    }));
  }));
}

// Donut chart. props: slices [{label, pct, color}]
function Donut({
  slices,
  size = 96
}) {
  const r = size / 2 - 4,
    cx = size / 2,
    cy = size / 2,
    sw = 14;
  const C = 2 * Math.PI * r;
  let acc = 0;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    style: {
      transform: "rotate(-90deg)"
    }
  }, /*#__PURE__*/React.createElement("circle", {
    cx: cx,
    cy: cy,
    r: r,
    fill: "none",
    stroke: "var(--inset)",
    strokeWidth: sw
  }), slices.map((s, i) => {
    const len = s.pct / 100 * C;
    const seg = /*#__PURE__*/React.createElement("circle", {
      key: i,
      cx: cx,
      cy: cy,
      r: r,
      fill: "none",
      stroke: s.color,
      strokeWidth: sw,
      strokeDasharray: `${len} ${C - len}`,
      strokeDashoffset: -acc
    });
    acc += len;
    return seg;
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 3
    }
  }, slices.map((s, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: "flex",
      alignItems: "center",
      gap: 6,
      fontSize: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8,
      height: 8,
      borderRadius: 2,
      background: s.color
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-muted)",
      textTransform: "uppercase",
      letterSpacing: ".3px",
      flex: 1
    }
  }, s.label), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-bright)",
      fontWeight: 800
    }
  }, s.pct, "%")))));
}
Object.assign(window, {
  LineGraph,
  Donut
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/radical-hud/charts.jsx", error: String((e && e.message) || e) }); }

// ui_kits/radical-hud/dashboards.jsx
try { (() => {
// dashboards.jsx — VIOLET HUD on-click dashboard popups (DS §5.2).
// Clicking a stat lozenge opens one of these grouped panel sets, anchored under the bar.

const PROC = [["3208", "firefox", "22.4", "8.1"], ["1142", "Xorg", "12.3", "3.2"], ["4471", "awesome", "7.0", "1.4"], ["5012", "alacritty", "4.5", "0.9"], ["6633", "node", "4.4", "2.1"], ["7781", "zsh", "1.2", "0.3"], ["8890", "pipewire", "0.8", "0.2"], ["9021", "nmap", "0.5", "0.4"], ["9210", "tmux", "0.3", "0.1"], ["9344", "picom", "0.2", "0.5"]];
const CONNS = [["tcp", "10.10.10.139:443", "ESTABLISHED", "var(--ok)"], ["tcp", "lad23b05:8080", "ESTABLISHED", "var(--ok)"], ["tcp", "0.0.0.0:22", "LISTEN", "var(--text-muted)"], ["udp", "rajaniemi:51820", "ESTABLISHED", "var(--ok)"], ["tcp", "127.0.0.1:6463", "TIME_WAIT", "var(--warn)"], ["tcp", "0.0.0.0:5432", "LISTEN", "var(--text-muted)"], ["tcp", "fe80::204:8080", "ESTABLISHED", "var(--ok)"]];
function SystemDashboard({
  history,
  onKill
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "dash"
  }, /*#__PURE__*/React.createElement("div", {
    className: "dash__col"
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "INFO",
    icon: "cpu",
    width: 236
  }, /*#__PURE__*/React.createElement(InfoRow, {
    k: "kernel",
    v: "6.18.5"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "uptime",
    v: "04:21:55"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "packages",
    v: "1487"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "shell",
    v: "zsh 5.9"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "wm",
    v: "awesome 4.3"
  })), /*#__PURE__*/React.createElement(Panel, {
    title: "USAGE",
    icon: "cpu_temp",
    width: 236
  }, /*#__PURE__*/React.createElement(TableRow, {
    header: true,
    cells: [{
      t: "CORE",
      w: 52
    }, {
      t: "GHZ",
      w: 52,
      align: "right"
    }, {
      t: "TEMP",
      w: 56,
      align: "right"
    }, {
      t: "USE%",
      w: 52,
      align: "right"
    }]
  }), [["C0", "3.8", "42°C", "36"], ["C1", "2.1", "40°C", "12"], ["C2", "3.4", "40°C", "44"], ["C3", "1.9", "38°C", "8"]].map((r, i) => /*#__PURE__*/React.createElement(TableRow, {
    key: i,
    cells: [{
      t: r[0],
      w: 52,
      color: "var(--text-muted)"
    }, {
      t: r[1],
      w: 52,
      align: "right",
      color: "var(--text-bright)"
    }, {
      t: r[2],
      w: 56,
      align: "right",
      color: parseInt(r[2]) >= 80 ? "var(--crit)" : "var(--text-primary)"
    }, {
      t: r[3] + "%",
      w: 52,
      align: "right",
      color: "var(--text-bright)"
    }]
  })))), /*#__PURE__*/React.createElement("div", {
    className: "dash__col"
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "GRAPH",
    icon: "net",
    width: 264
  }, /*#__PURE__*/React.createElement(LineGraph, {
    width: 248,
    height: 92,
    series: [{
      color: "var(--data1)",
      data: history.cpu
    }, {
      color: "var(--data2)",
      data: history.mem
    }]
  }), /*#__PURE__*/React.createElement("div", {
    className: "glegend"
  }, /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("i", {
    style: {
      background: "var(--data1)"
    }
  }), "CPU"), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("i", {
    style: {
      background: "var(--data2)"
    }
  }), "MEM"))), /*#__PURE__*/React.createElement(Panel, {
    title: "PROCESS",
    icon: "kill_all",
    width: 264
  }, /*#__PURE__*/React.createElement(ScrollList, {
    visible: 6,
    rows: PROC.map((r, i) => /*#__PURE__*/React.createElement(TableRow, {
      key: i,
      onKill: () => onKill(r[1]),
      cells: [{
        t: r[0],
        w: 44,
        color: "var(--text-muted)"
      }, {
        t: r[1],
        w: 96,
        color: "var(--text-primary)"
      }, {
        t: r[2],
        w: 40,
        align: "right",
        color: "var(--text-bright)"
      }, {
        t: r[3],
        w: 40,
        align: "right",
        color: "var(--text-bright)"
      }]
    })),
    header: /*#__PURE__*/React.createElement(TableRow, {
      header: true,
      onKill: () => {},
      cells: [{
        t: "PID",
        w: 44
      }, {
        t: "NAME",
        w: 96
      }, {
        t: "CPU%",
        w: 40,
        align: "right"
      }, {
        t: "MEM%",
        w: 40,
        align: "right"
      }]
    })
  }))));
}
function NetworkDashboard({
  history,
  onKill
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "dash"
  }, /*#__PURE__*/React.createElement("div", {
    className: "dash__col"
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "GRAPH",
    icon: "net",
    width: 236
  }, /*#__PURE__*/React.createElement(LineGraph, {
    width: 220,
    height: 80,
    series: [{
      color: "var(--data4)",
      data: history.net
    }, {
      color: "var(--v400)",
      data: history.cpu
    }]
  }), /*#__PURE__*/React.createElement("div", {
    className: "glegend"
  }, /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("img", {
    src: ICON("net_up"),
    style: {
      width: 12,
      height: 12
    }
  }), "UP"), /*#__PURE__*/React.createElement("span", null, /*#__PURE__*/React.createElement("img", {
    src: ICON("net_down"),
    style: {
      width: 12,
      height: 12
    }
  }), "DOWN"))), /*#__PURE__*/React.createElement(Panel, {
    title: "IP",
    icon: "net",
    width: 236
  }, /*#__PURE__*/React.createElement(InfoRow, {
    k: "iface",
    v: "eno1"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "ipv4",
    v: "10.10.10.139"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "gateway",
    v: "10.10.10.1"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "dns",
    v: "1.1.1.1"
  })), /*#__PURE__*/React.createElement(Panel, {
    title: "PROTOCOLS",
    icon: "send_signal",
    width: 236
  }, /*#__PURE__*/React.createElement(Donut, {
    size: 84,
    slices: [{
      label: "https",
      pct: 52,
      color: "var(--data1)"
    }, {
      label: "ircd",
      pct: 23,
      color: "var(--data2)"
    }, {
      label: "ssh",
      pct: 14,
      color: "var(--data3)"
    }, {
      label: "dns",
      pct: 11,
      color: "var(--data4)"
    }]
  }))), /*#__PURE__*/React.createElement("div", {
    className: "dash__col"
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "CONNECTIONS",
    icon: "send_signal",
    width: 300
  }, /*#__PURE__*/React.createElement(ScrollList, {
    visible: 6,
    rows: CONNS.map((r, i) => /*#__PURE__*/React.createElement("div", {
      key: i,
      className: "connrow",
      onClick: () => {}
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        width: 36,
        color: "var(--text-muted)"
      }
    }, r[0]), /*#__PURE__*/React.createElement("span", {
      style: {
        flex: 1,
        color: "var(--text-primary)"
      }
    }, r[1]), /*#__PURE__*/React.createElement("span", {
      style: {
        width: 96,
        textAlign: "right",
        color: r[3]
      }
    }, r[2]))),
    empty: "NO CONNECTIONS",
    header: /*#__PURE__*/React.createElement(TableRow, {
      header: true,
      cells: [{
        t: "PROTO",
        w: 36
      }, {
        t: "ADDRESS",
        w: 150
      }, {
        t: "STATE",
        w: 96,
        align: "right"
      }]
    })
  })), /*#__PURE__*/React.createElement(Panel, {
    title: "APPLICATIONS",
    icon: "kill_all",
    width: 300
  }, [["konversation", "0.4"], ["firefox", "8.1"], ["nmap", "0.5"]].map((r, i) => /*#__PURE__*/React.createElement(TableRow, {
    key: i,
    onKill: () => onKill(r[0]),
    cells: [{
      t: r[0],
      w: 200,
      color: "var(--text-primary)"
    }, {
      t: r[1] + "%",
      w: 48,
      align: "right",
      color: "var(--text-bright)"
    }]
  })))));
}
const CAL = (() => {
  const days = [];
  for (let i = 1; i <= 31; i++) days.push(i);
  return days;
})();
function TimeDashboard() {
  return /*#__PURE__*/React.createElement("div", {
    className: "dash"
  }, /*#__PURE__*/React.createElement("div", {
    className: "dash__col"
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "CALENDAR",
    icon: "calendar",
    width: 252
  }, /*#__PURE__*/React.createElement("div", {
    className: "calhd"
  }, "JANUARY 2026"), /*#__PURE__*/React.createElement("div", {
    className: "calgrid"
  }, ["SU", "MO", "TU", "WE", "TH", "FR", "SA"].map(d => /*#__PURE__*/React.createElement("span", {
    key: d,
    className: "caldow"
  }, d)), [null, null, null].map((_, i) => /*#__PURE__*/React.createElement("span", {
    key: "e" + i
  })), CAL.map(d => /*#__PURE__*/React.createElement("span", {
    key: d,
    className: "calday" + (d === 2 ? " calday--today" : "") + ([3, 4, 10, 11, 17, 18, 24, 25, 31].includes(d) ? " calday--we" : "")
  }, d))))), /*#__PURE__*/React.createElement("div", {
    className: "dash__col"
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "INTERNATIONAL",
    icon: "clock",
    width: 236
  }, [["UTC", "06:42:36"], ["CET", "07:42:36"], ["EST", "01:42:36"], ["JST", "15:42:36"]].map((z, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    className: "wclock"
  }, /*#__PURE__*/React.createElement("span", {
    className: "wclock__city"
  }, z[0]), /*#__PURE__*/React.createElement("span", {
    className: "wclock__dash"
  }), /*#__PURE__*/React.createElement("span", {
    className: "wclock__hm"
  }, z[1])))), /*#__PURE__*/React.createElement(Panel, {
    title: "SATELLITE",
    icon: "internet",
    width: 236
  }, /*#__PURE__*/React.createElement(InfoRow, {
    k: "next pass",
    v: "14:42:36"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "elevation",
    v: "42\xB0"
  }), /*#__PURE__*/React.createElement(InfoRow, {
    k: "status",
    v: "TRACKING",
    vColor: "var(--ok)"
  }))));
}
function VolumeDashboard() {
  return /*#__PURE__*/React.createElement("div", {
    className: "dash"
  }, /*#__PURE__*/React.createElement(Panel, {
    title: "VOLUME",
    icon: "vol",
    width: 252
  }, /*#__PURE__*/React.createElement(BarMeter, {
    label: "MASTER",
    pct: 98
  }), /*#__PURE__*/React.createElement(BarMeter, {
    label: "CAPTURE",
    pct: 64
  }), /*#__PURE__*/React.createElement(BarMeter, {
    label: "FRONT",
    pct: 72
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 6
    }
  }, /*#__PURE__*/React.createElement(InfoRow, {
    k: "sink",
    v: "DEFAULT"
  }))));
}
Object.assign(window, {
  SystemDashboard,
  NetworkDashboard,
  TimeDashboard,
  VolumeDashboard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/radical-hud/dashboards.jsx", error: String((e && e.message) || e) }); }

// ui_kits/radical-hud/menus.jsx
try { (() => {
// menus.jsx — context menu, app launcher, power menu, mock desktop windows.

// Context menu (DS §7.5): gradient title band + dense items + Send Signal submenu.
const MENU_ITEMS = [{
  icon: "visible",
  label: "Visible"
}, {
  icon: "sticky",
  label: "Sticky"
}, {
  icon: "floating",
  label: "Floating"
}, {
  icon: "fullscreen",
  label: "Fullscreen"
}, {
  icon: "send_signal",
  label: "Send Signal",
  sub: true
}, {
  icon: "close",
  label: "Close"
}];
const SIGNALS = ["SIGHUP", "SIGINT", "SIGQUIT", "SIGKILL", "SIGTERM", "SIGSTOP", "SIGCONT", "SIGUSR1", "SIGUSR2"];
function ContextMenu({
  x,
  y,
  onClose
}) {
  const [subOpen, setSubOpen] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", {
    className: "ctxwrap",
    onMouseLeave: onClose
  }, /*#__PURE__*/React.createElement("div", {
    className: "ctx",
    style: {
      left: x,
      top: y
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ctx__band"
  }, "CLIENT \xB7 alacritty"), MENU_ITEMS.map(it => /*#__PURE__*/React.createElement("div", {
    key: it.label,
    className: "ctx__item",
    onMouseEnter: () => setSubOpen(it.sub),
    onClick: () => {
      if (!it.sub) onClose();
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: ICON(it.icon),
    alt: ""
  }), /*#__PURE__*/React.createElement("span", null, it.label), it.sub && /*#__PURE__*/React.createElement("span", {
    className: "ctx__arrow"
  }, "\u25B8")))), subOpen && /*#__PURE__*/React.createElement("div", {
    className: "ctx ctx--sub",
    style: {
      left: x + 208,
      top: y + 120
    }
  }, /*#__PURE__*/React.createElement("div", {
    className: "ctx__band"
  }, "SEND SIGNAL"), SIGNALS.map(s => /*#__PURE__*/React.createElement("div", {
    key: s,
    className: "ctx__sig" + (s === "SIGKILL" || s === "SIGTERM" ? " ctx__sig--danger" : ""),
    onClick: onClose
  }, s))));
}

// Power menu (DS §7.6 powermenu): chip buttons with recolored icons.
const POWER = [{
  icon: "shutdown",
  label: "Shutdown"
}, {
  icon: "reboot",
  label: "Reboot"
}, {
  icon: "suspend",
  label: "Suspend"
}, {
  icon: "lock",
  label: "Lock"
}, {
  icon: "logout",
  label: "Logout"
}];
function PowerMenu({
  onClose
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "pmwrap",
    onClick: onClose
  }, /*#__PURE__*/React.createElement("div", {
    className: "pm",
    onClick: e => e.stopPropagation()
  }, POWER.map(p => /*#__PURE__*/React.createElement("button", {
    key: p.label,
    className: "pm__chip"
  }, /*#__PURE__*/React.createElement("img", {
    src: ICON(p.icon),
    alt: ""
  }), /*#__PURE__*/React.createElement("span", null, p.label)))));
}

// App launcher (DS §7.6) — orbital "gear": the animated logo.gif is the hub; apps
// orbit around it and the mouse wheel spins the ring like a gear, enlarging the app
// at the focus angle (up-left, toward the screen).
const APPS = [{
  icon: "internet",
  label: "Firefox"
}, {
  icon: "develop",
  label: "Neovim"
}, {
  icon: "term",
  label: "Alacritty"
}, {
  icon: "files",
  label: "Yazi"
}, {
  icon: "media",
  label: "MPV"
}, {
  icon: "edit",
  label: "GIMP"
}, {
  icon: "doc",
  label: "Zathura"
}, {
  icon: "send_signal",
  label: "Wireshark"
}, {
  icon: "calendar",
  label: "Calendar"
}];
function AppLauncher({
  open,
  onToggle,
  onLaunch
}) {
  const [rot, setRot] = React.useState(0);
  const rotRef = React.useRef(0);
  const velRef = React.useRef(0);
  const rafRef = React.useRef(null);
  const R = 168; // ring radius
  const FOCUS = 225; // focus angle (up-left, into the screen)
  const n = APPS.length;
  const step = 360 / n;
  // momentum loop: apply velocity to rotation, decay with friction (keeps spinning, slows down)
  const spin = React.useCallback(() => {
    velRef.current *= 0.95;
    rotRef.current += velRef.current;
    setRot(rotRef.current);
    if (Math.abs(velRef.current) < 0.04) {
      velRef.current = 0;
      rafRef.current = null;
      return;
    }
    rafRef.current = requestAnimationFrame(spin);
  }, []);
  const onWheel = e => {
    if (!open) return;
    e.preventDefault();
    velRef.current += (e.deltaY > 0 ? -1 : 1) * 5.5; // impulse per notch
    velRef.current = Math.max(-26, Math.min(26, velRef.current)); // clamp top speed
    if (!rafRef.current) rafRef.current = requestAnimationFrame(spin);
  };
  React.useEffect(() => () => {
    if (rafRef.current) cancelAnimationFrame(rafRef.current);
  }, []);
  React.useEffect(() => {
    if (!open && rafRef.current) {
      cancelAnimationFrame(rafRef.current);
      rafRef.current = null;
      velRef.current = 0;
    }
  }, [open]);
  return /*#__PURE__*/React.createElement("div", {
    className: "launcher",
    onClick: e => e.stopPropagation(),
    onWheel: onWheel
  }, open && /*#__PURE__*/React.createElement("div", {
    className: "orbit"
  }, /*#__PURE__*/React.createElement("span", {
    className: "orbit__zone",
    onClick: onToggle
  }), /*#__PURE__*/React.createElement("span", {
    className: "orbit__glow"
  }), /*#__PURE__*/React.createElement("span", {
    className: "orbit__guide"
  }), APPS.map((a, i) => {
    const ang = i * step + rot;
    const rad = ang * Math.PI / 180;
    const x = Math.cos(rad) * R;
    const y = Math.sin(rad) * R;
    let diff = Math.abs(((ang - FOCUS) % 360 + 360) % 360);
    if (diff > 180) diff = 360 - diff;
    const active = diff < step / 2;
    const vis = x < 46 && y < 46; // on-screen (upper-left) arc
    return /*#__PURE__*/React.createElement("button", {
      key: a.label,
      className: "orbit__app" + (active ? " orbit__app--on" : ""),
      style: {
        transform: `translate(${x}px, ${y}px) scale(${active ? 1.28 : 1})`,
        opacity: vis ? 1 : 0,
        pointerEvents: vis ? "auto" : "none",
        zIndex: active ? 3 : 2
      },
      onClick: () => onLaunch(a)
    }, /*#__PURE__*/React.createElement("img", {
      src: ICON(a.icon),
      alt: ""
    }), active && /*#__PURE__*/React.createElement("span", {
      className: "orbit__lbl"
    }, a.label));
  })), /*#__PURE__*/React.createElement("button", {
    className: "launcher__btn" + (open ? " launcher__btn--on" : ""),
    onClick: onToggle,
    title: "applications"
  }, /*#__PURE__*/React.createElement("span", {
    className: "launcher__gif"
  }), /*#__PURE__*/React.createElement("span", {
    className: "launcher__ring"
  })));
}
Object.assign(window, {
  ContextMenu,
  PowerMenu,
  AppLauncher
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/radical-hud/menus.jsx", error: String((e && e.message) || e) }); }

// ui_kits/radical-hud/monitorbar.jsx
try { (() => {
// monitorbar.jsx — VIOLET HUD bottom telemetry dock. The "monitor bar" moved from
// the top center to the bottom of the screen, enlarged and far more descriptive:
// four modules (RTX / AMD / MEMORY / WWW) with OVERLAPPING area graphs (additive
// neon blend), big live readouts, and dense technical footers. Cyberpunk / hacker
// chrome: blinking REC telemetry strip, hazard stripes, scanlines, NODE//STATUS rail.
// Module brand labels use the Xirod display face per the user's request.

const _clamp = v => Math.max(0.04, Math.min(0.97, v));
function _seed(n, base, vol) {
  const a = [];
  let v = base;
  for (let i = 0; i < n; i++) {
    v = _clamp(v + (Math.random() - 0.5) * vol);
    a.push(v);
  }
  return a;
}
const _push = (arr, vol) => [...arr.slice(1), _clamp(arr[arr.length - 1] + (Math.random() - 0.5) * vol)];
const _last = arr => arr[arr.length - 1];

// module manifest. colors = overlapping series (front → back). lbl = Xirod size.
const MON_MODS = [{
  key: "gpu",
  group: "system",
  label: "RTX",
  lbl: 24,
  sub: "GPU // RTX CORE",
  icon: "gpu",
  accent: "var(--data1)",
  colors: ["var(--data1)", "var(--data4)"]
}, {
  key: "cpu",
  group: "system",
  label: "AMD",
  lbl: 24,
  sub: "CPU // RYZEN 16T",
  icon: "cpu",
  accent: "var(--glow-core)",
  colors: ["var(--glow-core)", "var(--data2)", "var(--v400)"]
}, {
  key: "mem",
  group: "system",
  label: "MEMORY",
  lbl: 15,
  sub: "RAM // DDR5 16G",
  icon: "mem",
  accent: "var(--data2)",
  colors: ["var(--data2)", "var(--data5)"]
}, {
  key: "net",
  group: "network",
  label: "WWW",
  lbl: 22,
  sub: "NET // UPLINK eno1",
  icon: "net",
  accent: "var(--data4)",
  colors: ["var(--data4)", "var(--glow-hot)"]
}];

// translate the latest series values into the big number + descriptive footer cells.
function monReadout(key, d) {
  const a = d[key],
    l = a[0].length - 1;
  const p = a[0][l],
    s = a[1] ? a[1][l] : 0;
  switch (key) {
    case "gpu":
      return {
        big: [Math.round(p * 100), "%"],
        foot: [["USE", Math.round(p * 100) + "%"], ["TEMP", 52 + Math.round(p * 26) + "°C"], ["CLK", 1900 + Math.round(p * 640) + "MHz"], ["VRAM", (2.4 + s * 9).toFixed(1) + "/12G"], ["FAN", 28 + Math.round(p * 46) + "%"]]
      };
    case "cpu":
      {
        const avg = (a[0][l] + a[1][l] + a[2][l]) / 3;
        return {
          big: [Math.round(avg * 100), "%"],
          foot: [["LOAD", Math.round(avg * 100) + "%"], ["TEMP", 44 + Math.round(avg * 30) + "°C"], ["CLK", (3.2 + avg * 1.5).toFixed(1) + "GHz"], ["CORES", "16T"], ["1m", (0.4 + avg * 3).toFixed(2)]]
        };
      }
    case "mem":
      return {
        big: [Math.round(p * 100), "%"],
        foot: [["USED", (p * 16).toFixed(1) + "/16G"], ["CACHE", (1 + s * 4).toFixed(1) + "G"], ["SWAP", (s * 0.6).toFixed(1) + "G"], ["BUFF", 120 + Math.round(s * 480) + "M"]]
      };
    case "net":
      return {
        big: [(p * 42).toFixed(1), "M/s", "↓"],
        foot: [["DOWN", "↓" + (p * 42).toFixed(1) + "M"], ["UP", "↑" + (s * 14).toFixed(1) + "M"], ["PING", 8 + Math.round(s * 40) + "ms"], ["CONN", 28 + Math.round(p * 40) + ""], ["TX", (0.8 + p * 3).toFixed(1) + "G"]]
      };
    default:
      return {
        big: [0, ""],
        foot: []
      };
  }
}

// measure helper removed — graph uses a fixed viewBox that stretches to its box.

// Overlapping area graph. series:[{data,color}]. additive 'screen' blend so where the
// translucent fills cross, the violet lifts — the layered neon look from the reference.
// Fixed viewBox + preserveAspectRatio:none stretches to any module width; strokes stay
// crisp via non-scaling-stroke.
function MonGraph({
  series,
  gid
}) {
  const VW = 1000,
    VH = 120,
    top = 4,
    bot = VH - 1;
  const xy = data => data.map((v, i) => [i / (data.length - 1) * VW, top + (1 - v) * (bot - top)]);
  const line = pts => pts.map((p, i) => (i ? "L" : "M") + p[0].toFixed(1) + " " + p[1].toFixed(1)).join(" ");
  const area = pts => line(pts) + ` L${VW} ${VH} L0 ${VH} Z`;
  const cols = [0.2, 0.4, 0.6, 0.8];
  return /*#__PURE__*/React.createElement("div", {
    className: "mg"
  }, /*#__PURE__*/React.createElement("svg", {
    viewBox: `0 0 ${VW} ${VH}`,
    preserveAspectRatio: "none"
  }, /*#__PURE__*/React.createElement("defs", null, series.map((s, i) => /*#__PURE__*/React.createElement("linearGradient", {
    key: i,
    id: `mg-${gid}-${i}`,
    x1: "0",
    y1: "0",
    x2: "0",
    y2: "1"
  }, /*#__PURE__*/React.createElement("stop", {
    offset: "0%",
    stopColor: s.color,
    stopOpacity: "0.6"
  }), /*#__PURE__*/React.createElement("stop", {
    offset: "62%",
    stopColor: s.color,
    stopOpacity: "0.16"
  }), /*#__PURE__*/React.createElement("stop", {
    offset: "100%",
    stopColor: s.color,
    stopOpacity: "0.02"
  })))), [0.25, 0.5, 0.75].map((g, i) => /*#__PURE__*/React.createElement("line", {
    key: "h" + i,
    x1: "0",
    x2: VW,
    y1: top + g * (bot - top),
    y2: top + g * (bot - top),
    stroke: "var(--grid)",
    strokeWidth: "1",
    vectorEffect: "non-scaling-stroke",
    opacity: i % 2 ? 0.16 : 0.28
  })), cols.map((g, i) => /*#__PURE__*/React.createElement("line", {
    key: "v" + i,
    x1: g * VW,
    x2: g * VW,
    y1: top,
    y2: VH,
    stroke: "var(--v400)",
    strokeWidth: "1",
    vectorEffect: "non-scaling-stroke",
    opacity: "0.07"
  })), series.map((s, i) => {
    const pts = xy(s.data);
    return /*#__PURE__*/React.createElement("g", {
      key: i,
      style: {
        mixBlendMode: "screen"
      }
    }, /*#__PURE__*/React.createElement("path", {
      d: area(pts),
      fill: `url(#mg-${gid}-${i})`
    }), /*#__PURE__*/React.createElement("path", {
      d: line(pts),
      fill: "none",
      stroke: s.color,
      strokeWidth: "4",
      vectorEffect: "non-scaling-stroke",
      opacity: "0.22"
    }), /*#__PURE__*/React.createElement("path", {
      d: line(pts),
      fill: "none",
      stroke: s.color,
      strokeWidth: "1.6",
      vectorEffect: "non-scaling-stroke",
      strokeLinejoin: "round",
      strokeLinecap: "round"
    }));
  })));
}
function MonModule({
  mod,
  d,
  onOpen,
  z,
  first
}) {
  const r = monReadout(mod.key, d);
  const series = d[mod.key].map((data, i) => ({
    data,
    color: mod.colors[i]
  }));
  return /*#__PURE__*/React.createElement("div", {
    className: "monmod" + (first ? " monmod--first" : ""),
    style: {
      zIndex: z
    },
    onClick: () => onOpen(mod.group),
    title: "OPEN " + mod.group.toUpperCase() + " DASHBOARD"
  }, /*#__PURE__*/React.createElement("span", {
    className: "monmod__edge"
  }), /*#__PURE__*/React.createElement("div", {
    className: "monmod__inner"
  }, /*#__PURE__*/React.createElement("div", {
    className: "monmod__bg"
  }, /*#__PURE__*/React.createElement(MonGraph, {
    series: series,
    gid: mod.key
  })), /*#__PURE__*/React.createElement("div", {
    className: "monmod__overlay"
  }, /*#__PURE__*/React.createElement("div", {
    className: "monmod__head"
  }, /*#__PURE__*/React.createElement("div", {
    className: "monmod__id"
  }, /*#__PURE__*/React.createElement("span", {
    className: "monmod__label",
    style: {
      fontSize: mod.lbl,
      textShadow: `0 0 16px ${mod.accent}`
    }
  }, mod.label), /*#__PURE__*/React.createElement("span", {
    className: "monmod__sub"
  }, /*#__PURE__*/React.createElement("img", {
    className: "monmod__subicon",
    src: ICON(mod.icon),
    alt: ""
  }), mod.sub)), /*#__PURE__*/React.createElement("div", {
    className: "monmod__big"
  }, r.big[2] && /*#__PURE__*/React.createElement("span", {
    className: "monmod__bigp"
  }, r.big[2]), /*#__PURE__*/React.createElement("span", {
    className: "monmod__bigv"
  }, r.big[0]), /*#__PURE__*/React.createElement("span", {
    className: "monmod__bigu"
  }, r.big[1]))), /*#__PURE__*/React.createElement("div", {
    className: "monmod__foot"
  }, r.foot.slice(0, 4).map((f, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    className: "monfoot"
  }, /*#__PURE__*/React.createElement("span", {
    className: "monfoot__k"
  }, f[0]), /*#__PURE__*/React.createElement("span", {
    className: "monfoot__v"
  }, f[1])))))));
}

// right status rail — compact arrow segment that closes the powerline ribbon
function MonRail({
  d,
  vol,
  onVol,
  z
}) {
  const l = d.cpu[0].length - 1;
  const load = Math.round((d.cpu[0][l] + d.gpu[0][l] + d.mem[0][l]) / 3 * 100);
  return /*#__PURE__*/React.createElement("div", {
    className: "monrail",
    style: {
      zIndex: z
    },
    onClick: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement("span", {
    className: "monrail__edge"
  }), /*#__PURE__*/React.createElement("div", {
    className: "monrail__inner"
  }, /*#__PURE__*/React.createElement("div", {
    className: "monrail__top"
  }, /*#__PURE__*/React.createElement("span", {
    className: "monrail__hd"
  }, "NODE // STATUS"), /*#__PURE__*/React.createElement("span", {
    className: "monrail__st"
  }, /*#__PURE__*/React.createElement("i", null), "ONLINE")), /*#__PURE__*/React.createElement("div", {
    className: "monrail__vol",
    onClick: () => onVol && onVol(),
    title: "VOLUME"
  }, /*#__PURE__*/React.createElement("img", {
    src: ICON("vol"),
    alt: ""
  }), /*#__PURE__*/React.createElement("span", {
    className: "monrail__track"
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: vol + "%"
    }
  })), /*#__PURE__*/React.createElement("span", {
    className: "monrail__volv"
  }, vol, "%")), /*#__PURE__*/React.createElement("div", {
    className: "monrail__load"
  }, /*#__PURE__*/React.createElement("span", {
    className: "monrail__loadk"
  }, "AGGREGATE LOAD"), /*#__PURE__*/React.createElement("span", {
    className: "monrail__loadv"
  }, load, /*#__PURE__*/React.createElement("i", null, "%")))));
}
function MonitorBar({
  onOpen,
  vol = 98,
  onVol
}) {
  const N = 58;
  const [d, setD] = React.useState(() => ({
    gpu: [_seed(N, 0.5, 0.18), _seed(N, 0.32, 0.10)],
    cpu: [_seed(N, 0.4, 0.22), _seed(N, 0.28, 0.16), _seed(N, 0.52, 0.12)],
    mem: [_seed(N, 0.56, 0.06), _seed(N, 0.30, 0.05)],
    net: [_seed(N, 0.30, 0.42), _seed(N, 0.18, 0.30)]
  }));
  React.useEffect(() => {
    const t = setInterval(() => setD(p => ({
      gpu: [_push(p.gpu[0], 0.18), _push(p.gpu[1], 0.10)],
      cpu: [_push(p.cpu[0], 0.22), _push(p.cpu[1], 0.16), _push(p.cpu[2], 0.12)],
      mem: [_push(p.mem[0], 0.06), _push(p.mem[1], 0.05)],
      net: [_push(p.net[0], 0.42), _push(p.net[1], 0.30)]
    })), 1100);
    return () => clearInterval(t);
  }, []);
  return /*#__PURE__*/React.createElement("div", {
    className: "monitorbar",
    onClick: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement("div", {
    className: "monbar__strip"
  }, /*#__PURE__*/React.createElement("span", {
    className: "monbar__rec"
  }, /*#__PURE__*/React.createElement("i", null), "REC"), /*#__PURE__*/React.createElement("span", {
    className: "monbar__id"
  }, "LIVE TELEMETRY \xB7 RADICAL-WM // SYSMON"), /*#__PURE__*/React.createElement("span", {
    className: "monbar__haz"
  }), /*#__PURE__*/React.createElement("span", {
    className: "monbar__flex"
  }), /*#__PURE__*/React.createElement("span", {
    className: "monbar__hex"
  }, "0x7F3A\xB7E1"), /*#__PURE__*/React.createElement("span", {
    className: "monbar__node"
  }, "NODE STATUS: ", /*#__PURE__*/React.createElement("b", null, "ONLINE"))), /*#__PURE__*/React.createElement("div", {
    className: "monbar__row"
  }, MON_MODS.map((m, i) => /*#__PURE__*/React.createElement(MonModule, {
    key: m.key,
    mod: m,
    d: d,
    onOpen: onOpen,
    z: MON_MODS.length - i + 1,
    first: i === 0
  })), /*#__PURE__*/React.createElement(MonRail, {
    d: d,
    vol: vol,
    onVol: onVol,
    z: 1
  })));
}
Object.assign(window, {
  MonitorBar
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/radical-hud/monitorbar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/radical-hud/panel.jsx
try { (() => {
// panel.jsx — VIOLET HUD panel chrome + data primitives (DS §7.1, §7.4)
// The central motif: header (uppercase) + gradient divider + body + thin border
// + 2-tone bevel + 4 corner ticks. Everything else lives inside one of these.

const ICONS = "../../assets/icons/";
// Resolve an icon by base name. In a bundled/standalone build the inliner populates
// window.__resources[name] with a blob URL (see the ext-resource-dependency metas);
// otherwise we fall back to the on-disk relative path.
const ICON = n => typeof window !== "undefined" && window.__resources && window.__resources[n] || ICONS + n + ".svg";

// Panel chrome. props: title, accent, icon (name), focus, width, children
function Panel({
  title,
  accent = "var(--v500)",
  icon,
  focus,
  width,
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "hp" + (focus ? " hp--focus" : ""),
    style: {
      width,
      ...style
    }
  }, /*#__PURE__*/React.createElement("i", {
    className: "hp__tick hp__tick--tl"
  }), /*#__PURE__*/React.createElement("i", {
    className: "hp__tick hp__tick--tr"
  }), /*#__PURE__*/React.createElement("i", {
    className: "hp__tick hp__tick--bl"
  }), /*#__PURE__*/React.createElement("i", {
    className: "hp__tick hp__tick--br"
  }), /*#__PURE__*/React.createElement("div", {
    className: "hp__hd"
  }, /*#__PURE__*/React.createElement("span", {
    className: "hp__title"
  }, title), icon && /*#__PURE__*/React.createElement("img", {
    className: "hp__hdicon",
    src: ICON(icon),
    alt: ""
  })), /*#__PURE__*/React.createElement("div", {
    className: "hp__dv",
    style: {
      background: `linear-gradient(90deg, ${accent}, color-mix(in srgb, ${accent} 22%, transparent) 55%, transparent)`
    }
  }), /*#__PURE__*/React.createElement("div", {
    className: "hp__bd"
  }, children));
}

// Key/value row. right number, left label.
function InfoRow({
  k,
  v,
  vColor,
  chip
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "ir" + (chip ? " ir--chip" : "")
  }, /*#__PURE__*/React.createElement("span", {
    className: "ir__k"
  }, k), /*#__PURE__*/React.createElement("span", {
    className: "ir__v",
    style: vColor ? {
      color: vColor
    } : null
  }, v));
}

// Horizontal bar meter (USAGE). pct 0..100, alert flips to glow_hot.
function BarMeter({
  label,
  pct,
  alert
}) {
  const hot = alert || pct >= 90;
  return /*#__PURE__*/React.createElement("div", {
    className: "bm"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bm__lbl"
  }, label), /*#__PURE__*/React.createElement("span", {
    className: "bm__track"
  }, /*#__PURE__*/React.createElement("span", {
    className: "bm__fill",
    style: {
      width: pct + "%",
      background: hot ? "var(--glow-hot)" : "linear-gradient(90deg,var(--v700),var(--v500))"
    }
  })), /*#__PURE__*/React.createElement("span", {
    className: "bm__val",
    style: hot ? {
      color: "var(--glow-hot)"
    } : null
  }, pct, "%"));
}

// Tabular row used by PROCESS / CONNECTIONS / USAGE tables.
function TableRow({
  cells,
  header,
  onKill,
  killHover
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "tr" + (header ? " tr--hd" : "")
  }, cells.map((c, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    className: "tr__c",
    style: {
      width: c.w,
      textAlign: c.align || "left",
      color: c.color || (header ? "var(--text-faint)" : "var(--text-primary)")
    }
  }, c.t)), onKill !== undefined && (header ? /*#__PURE__*/React.createElement("span", {
    className: "tr__c",
    style: {
      width: 26
    }
  }) : /*#__PURE__*/React.createElement(KillBtn, {
    onKill: onKill
  })));
}
function KillBtn({
  onKill
}) {
  const [h, setH] = React.useState(false);
  return /*#__PURE__*/React.createElement("span", {
    className: "killbtn",
    onMouseEnter: () => setH(true),
    onMouseLeave: () => setH(false),
    onClick: onKill,
    title: "SIGTERM"
  }, /*#__PURE__*/React.createElement("img", {
    src: ICON("kill"),
    alt: "kill",
    className: h ? "killbtn--hot" : ""
  }));
}

// Thin windowed scroll list: fixed VISIBLE rows, wheel scrolls, thumb on right.
function ScrollList({
  rows,
  visible = 6,
  rowH = 18,
  header,
  empty
}) {
  const [offset, setOffset] = React.useState(0);
  const max = Math.max(0, rows.length - visible);
  const clamped = Math.min(offset, max);
  const onWheel = e => {
    e.preventDefault();
    setOffset(o => Math.max(0, Math.min(max, o + (e.deltaY > 0 ? 1 : -1))));
  };
  const slice = rows.slice(clamped, clamped + visible);
  const thumbH = rows.length > visible ? Math.max(visible / rows.length * 100, 14) : 0;
  const thumbT = max > 0 ? clamped / max * (100 - thumbH) : 0;
  return /*#__PURE__*/React.createElement("div", null, header, /*#__PURE__*/React.createElement("div", {
    className: "sl",
    style: {
      height: visible * rowH + (visible - 1) * 2
    },
    onWheel: onWheel
  }, /*#__PURE__*/React.createElement("div", {
    className: "sl__rows"
  }, slice.length ? slice : /*#__PURE__*/React.createElement("div", {
    className: "sl__empty"
  }, empty || "NO DATA")), thumbH > 0 && /*#__PURE__*/React.createElement("div", {
    className: "sl__track"
  }, /*#__PURE__*/React.createElement("div", {
    className: "sl__thumb",
    style: {
      height: thumbH + "%",
      top: thumbT + "%"
    }
  }))));
}
Object.assign(window, {
  Panel,
  InfoRow,
  BarMeter,
  TableRow,
  KillBtn,
  ScrollList,
  ICONS,
  ICON
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/radical-hud/panel.jsx", error: String((e && e.message) || e) }); }

// ui_kits/radical-hud/topbar.jsx
try { (() => {
// topbar.jsx — VIOLET HUD top bar (DS §7.2): tags + control cluster (left),
// clickable stat lozenges + clock (center), power (right). The only always-visible chrome.

// Interlocking powerline tag tabs (DS §7.2): each arrow point nests into the back of
// the next tab. icon + index + label. states: empty/occupied/selected/urgent.
function TagTabs({
  tags,
  selected,
  onSelect,
  onTagMenu,
  renamingId,
  onRenameCommit
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "tags"
  }, tags.map((t, i) => {
    let st = "empty";
    if (t.urgent) st = "urgent";else if (t.id === selected) st = "selected";else if (t.clients > 0) st = "occupied";
    return /*#__PURE__*/React.createElement("button", {
      key: t.id,
      className: "tag tag--" + st + (i === 0 ? " tag--first" : ""),
      style: {
        zIndex: tags.length - i
      },
      onClick: () => onSelect(t.id),
      onContextMenu: e => {
        e.preventDefault();
        onTagMenu(t.id, e.currentTarget);
      },
      title: "right-click for tag menu"
    }, /*#__PURE__*/React.createElement("span", {
      className: "tag__edge"
    }), /*#__PURE__*/React.createElement("span", {
      className: "tag__fill"
    }), /*#__PURE__*/React.createElement("span", {
      className: "tag__content"
    }, /*#__PURE__*/React.createElement("img", {
      src: ICON(t.icon),
      alt: ""
    }), /*#__PURE__*/React.createElement("span", {
      className: "tag__idx"
    }, i + 1), renamingId === t.id ? /*#__PURE__*/React.createElement("input", {
      className: "tag__rename",
      autoFocus: true,
      defaultValue: t.name,
      onClick: e => e.stopPropagation(),
      onKeyDown: e => {
        if (e.key === "Enter") onRenameCommit(t.id, e.target.value.trim() || t.name);
        if (e.key === "Escape") onRenameCommit(t.id, t.name);
      },
      onBlur: e => onRenameCommit(t.id, e.target.value.trim() || t.name)
    }) : /*#__PURE__*/React.createElement("span", {
      className: "tag__lbl"
    }, t.name)));
  }));
}

// Tag control cluster (DS §7.2) — "military technology" treatment: chamfered angular
// shell, hex-mesh texture, hazard accent + technical label, chamfered glowing buttons.
function TagControls({
  onAdd,
  onRemove,
  onMoveLeft,
  onMoveRight
}) {
  const btns = [{
    icon: "add",
    fn: onAdd,
    title: "add tag"
  }, {
    icon: "remove",
    fn: onRemove,
    title: "remove tag"
  }, {
    icon: "move_left",
    fn: onMoveLeft,
    title: "move left"
  }, {
    icon: "move_right",
    fn: onMoveRight,
    title: "move right"
  }];
  return /*#__PURE__*/React.createElement("div", {
    className: "tagctl"
  }, /*#__PURE__*/React.createElement("span", {
    className: "tagctl__mesh"
  }), /*#__PURE__*/React.createElement("span", {
    className: "tagctl__haz"
  }), btns.map(b => /*#__PURE__*/React.createElement("button", {
    key: b.icon,
    className: "tagctl__b",
    title: b.title,
    onClick: b.fn
  }, /*#__PURE__*/React.createElement("img", {
    src: ICON(b.icon),
    alt: b.title
  }))));
}

// Per-tag management menu (right-click a tag). Anchored to the tag.
const TAG_ICON_CYCLE = ["term", "internet", "files", "develop", "edit", "media", "doc"];
function TagMenu({
  menu,
  onClose,
  onRename,
  onMoveLeft,
  onMoveRight,
  onChangeIcon,
  onRemove,
  canRemove
}) {
  const [picking, setPicking] = React.useState(false);
  React.useEffect(() => {
    setPicking(false);
  }, [menu]);
  if (!menu) return null;
  const items = [{
    icon: "edit",
    label: "Rename",
    fn: onRename
  }, {
    icon: "move_left",
    label: "Move Left",
    fn: onMoveLeft
  }, {
    icon: "move_right",
    label: "Move Right",
    fn: onMoveRight
  }, {
    icon: "edit",
    label: "Change Icon",
    fn: () => setPicking(true),
    keep: true,
    arrow: true
  }, {
    icon: "remove",
    label: "Remove",
    fn: onRemove,
    danger: true,
    disabled: !canRemove
  }];
  return /*#__PURE__*/React.createElement("div", {
    className: "ctxwrap",
    onMouseLeave: onClose,
    onClick: onClose
  }, /*#__PURE__*/React.createElement("div", {
    className: "ctx",
    style: {
      left: menu.x,
      top: menu.y
    },
    onClick: e => e.stopPropagation()
  }, /*#__PURE__*/React.createElement("div", {
    className: "ctx__band"
  }, picking ? "CHANGE ICON · PICK" : "TAG · " + menu.name), picking ? /*#__PURE__*/React.createElement("div", {
    className: "iconpick"
  }, TAG_ICON_CYCLE.map(ic => /*#__PURE__*/React.createElement("button", {
    key: ic,
    className: "iconpick__b",
    title: ic,
    onClick: () => {
      onChangeIcon(ic);
      onClose();
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: ICON(ic),
    alt: ic
  }), /*#__PURE__*/React.createElement("span", null, ic)))) : items.map(it => /*#__PURE__*/React.createElement("div", {
    key: it.label,
    className: "ctx__item" + (it.danger ? " ctx__item--danger" : "") + (it.disabled ? " ctx__item--off" : ""),
    onClick: () => {
      if (!it.disabled) {
        it.fn();
        if (!it.keep && it.label !== "Rename") onClose();
      }
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: ICON(it.icon),
    alt: ""
  }), /*#__PURE__*/React.createElement("span", null, it.label), it.arrow && /*#__PURE__*/React.createElement("span", {
    className: "ctx__arrow"
  }, "\u25B8")))));
}

// Clickable stat lozenges + clock. props: stats {cpu,mem,gpu,net,vol}, onOpen(group)
// Nested concave-arrow "blind" ribbon (matches the reference rice).
function StatLozenges({
  stats,
  active,
  onOpen,
  clock
}) {
  const seg = (group, icon, val, z, first) => {
    // VOL stays the same color as the other central widgets (no red/hot alert).
    const hot = group !== "volume" && typeof val === "string" && val.endsWith("%") && parseInt(val) >= 90;
    return /*#__PURE__*/React.createElement("button", {
      className: "seg" + (first ? " seg--first" : "") + (active === group ? " seg--on" : ""),
      style: {
        zIndex: z
      },
      onClick: () => onOpen(group)
    }, /*#__PURE__*/React.createElement("span", {
      className: "arrow seg__edge"
    }), /*#__PURE__*/React.createElement("span", {
      className: "arrow seg__fill"
    }), /*#__PURE__*/React.createElement("span", {
      className: "seg__content"
    }, /*#__PURE__*/React.createElement("img", {
      src: ICON(icon),
      alt: ""
    }), /*#__PURE__*/React.createElement("span", {
      className: "seg__v",
      style: hot ? {
        color: "var(--glow-hot)"
      } : null
    }, val)));
  };
  return /*#__PURE__*/React.createElement("div", {
    className: "lozstrip"
  }, seg("system", "cpu", stats.cpu, 6, true), seg("system", "mem", stats.mem, 5), seg("system", "gpu", stats.gpu, 4), seg("network", "net", stats.net, 3), seg("volume", "vol", stats.vol, 2));
}

// Right side: clock + date (top-right) · systray · keyboard · power
function RightCluster({
  onPower,
  clock,
  onOpenTime,
  timeActive
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "rightc"
  }, /*#__PURE__*/React.createElement("span", {
    className: "loztail__hm"
  }, clock.hm), /*#__PURE__*/React.createElement("button", {
    className: "datepill" + (timeActive ? " datepill--on" : ""),
    onClick: onOpenTime
  }, clock.dt), /*#__PURE__*/React.createElement("span", {
    className: "systray"
  }, /*#__PURE__*/React.createElement("i", null), /*#__PURE__*/React.createElement("i", null), /*#__PURE__*/React.createElement("i", null)), /*#__PURE__*/React.createElement("span", {
    className: "kbl"
  }, "US"), /*#__PURE__*/React.createElement("button", {
    className: "powerbtn",
    onClick: onPower,
    title: "power"
  }, /*#__PURE__*/React.createElement("img", {
    src: ICON("shutdown"),
    alt: "power"
  })));
}
Object.assign(window, {
  TagTabs,
  TagControls,
  TagMenu,
  StatLozenges,
  RightCluster
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/radical-hud/topbar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/radical-hud/windows.jsx
try { (() => {
// windows.jsx — mock tiled terminal windows that fill the desktop behind the HUD.
// Tiling WM look: thin-bordered terminals, focused = glow_core border. Translucent.

// A tiled terminal window. props: title, focused, lines[], onContext, style
function TermWindow({
  title,
  focused,
  children,
  style,
  onContext,
  onClick
}) {
  return /*#__PURE__*/React.createElement("div", {
    className: "win" + (focused ? " win--focus" : ""),
    style: style,
    onContextMenu: onContext,
    onClick: onClick
  }, /*#__PURE__*/React.createElement("div", {
    className: "win__bar"
  }, /*#__PURE__*/React.createElement("span", {
    className: "win__title"
  }, title), /*#__PURE__*/React.createElement("span", {
    className: "win__btns"
  }, /*#__PURE__*/React.createElement("i", {
    className: "win__b"
  }), /*#__PURE__*/React.createElement("i", {
    className: "win__b"
  }), /*#__PURE__*/React.createElement("i", {
    className: "win__b win__b--x"
  }))), /*#__PURE__*/React.createElement("div", {
    className: "win__body"
  }, children));
}

// htop-ish meters
function HtopContent() {
  const bars = [["1", 0.62, "var(--data1)"], ["2", 0.31, "var(--data1)"], ["3", 0.44, "var(--data2)"], ["4", 0.18, "var(--data1)"]];
  return /*#__PURE__*/React.createElement("div", {
    className: "term"
  }, bars.map(b => /*#__PURE__*/React.createElement("div", {
    key: b[0],
    className: "term__line"
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-muted)"
    }
  }, b[0], " "), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-faint)"
    }
  }, "["), /*#__PURE__*/React.createElement("span", {
    style: {
      color: b[2]
    }
  }, "|".repeat(Math.round(b[1] * 22))), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--line-dim)"
    }
  }, " ".repeat(22 - Math.round(b[1] * 22))), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-faint)"
    }
  }, "]"), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-bright)"
    }
  }, " ", Math.round(b[1] * 100), "%"))), /*#__PURE__*/React.createElement("div", {
    className: "term__line",
    style: {
      color: "var(--text-muted)",
      marginTop: 6
    }
  }, "  PID USER     CPU% MEM%  COMMAND"), [["3208", "root", "22.4", "8.1", "firefox"], ["1142", "root", "12.3", "3.2", "Xorg"], ["4471", "lepagee", "7.0", "1.4", "awesome"], ["6633", "lepagee", "4.4", "2.1", "node"]].map(r => /*#__PURE__*/React.createElement("div", {
    key: r[0],
    className: "term__line"
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--v400)"
    }
  }, r[0].padStart(5)), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-primary)"
    }
  }, " ", r[1].padEnd(8)), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-bright)"
    }
  }, r[2].padStart(5)), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-body)"
    }
  }, r[3].padStart(5)), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--glow-ice)"
    }
  }, "  ", r[4]))));
}
function NeofetchContent() {
  const rows = [["OS", "Linux Radical OS"], ["KERNEL", "6.18.5-radical"], ["WM", "awesome 4.3"], ["SHELL", "zsh 5.9"], ["TERM", "alacritty"], ["THEME", "VIOLET HUD"], ["CPU", "i7 Quad @ 2.40GHz"], ["MEM", "7977MiB / 16GiB"]];
  return /*#__PURE__*/React.createElement("div", {
    className: "term"
  }, /*#__PURE__*/React.createElement("pre", {
    className: "term__art"
  }, ` ▟█▙   RADICAL\n▟███▙  ───────\n█████  user@radical\n▜███▛  uptime 04:21\n ▜█▛   `), rows.map(r => /*#__PURE__*/React.createElement("div", {
    key: r[0],
    className: "term__line"
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--v400)",
      fontWeight: 800
    }
  }, r[0]), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-faint)"
    }
  }, " \xB7 "), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--text-primary)"
    }
  }, r[1]))));
}
function LogContent() {
  const lines = [["~$ ", "git log --oneline", "var(--text-bright)"], ["", "a1b2c3d  feat: violet hud palette", "var(--text-primary)"], ["", "e4f5g6h  fix: tag arrow shape", "var(--text-primary)"], ["", "i7j8k9l  panel chrome factory", "var(--text-primary)"], ["", "m0n1o2p  icon set → 41 svg", "var(--text-primary)"], ["~$ ", "nmap -sV 10.10.10.139", "var(--text-bright)"], ["", "PORT    STATE  SERVICE", "var(--text-muted)"], ["", "443/tcp open   https", "var(--ok)"], ["", "22/tcp  open   ssh", "var(--ok)"], ["~$ ", "_", "var(--glow-ice)"]];
  return /*#__PURE__*/React.createElement("div", {
    className: "term"
  }, lines.map((l, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    className: "term__line"
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--v500)"
    }
  }, l[0]), /*#__PURE__*/React.createElement("span", {
    style: {
      color: l[2]
    }
  }, l[1]))));
}
Object.assign(window, {
  TermWindow,
  HtopContent,
  NeofetchContent,
  LogContent
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/radical-hud/windows.jsx", error: String((e && e.message) || e) }); }

})();
