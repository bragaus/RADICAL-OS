// topbar.jsx — VIOLET HUD top bar (DS §7.2): tags + control cluster (left),
// clickable stat lozenges + clock (center), power (right). The only always-visible chrome.

// Interlocking powerline tag tabs (DS §7.2): each arrow point nests into the back of
// the next tab. icon + index + label. states: empty/occupied/selected/urgent.
function TagTabs({ tags, selected, onSelect, onTagMenu, renamingId, onRenameCommit }) {
  return (
    <div className="tags">
      {tags.map((t, i) => {
        let st = "empty";
        if (t.urgent) st = "urgent";
        else if (t.id === selected) st = "selected";
        else if (t.clients > 0) st = "occupied";
        return (
          <button key={t.id}
            className={"tag tag--" + st + (i === 0 ? " tag--first" : "")}
            style={{ zIndex: tags.length - i }}
            onClick={() => onSelect(t.id)}
            onContextMenu={(e) => { e.preventDefault(); onTagMenu(t.id, e.currentTarget); }}
            title="right-click for tag menu">
            <span className="tag__edge" />
            <span className="tag__fill" />
            <span className="tag__content">
              <img src={ICON(t.icon)} alt="" />
              <span className="tag__idx">{i + 1}</span>
              {renamingId === t.id
                ? <input className="tag__rename" autoFocus defaultValue={t.name}
                    onClick={(e) => e.stopPropagation()}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") onRenameCommit(t.id, e.target.value.trim() || t.name);
                      if (e.key === "Escape") onRenameCommit(t.id, t.name);
                    }}
                    onBlur={(e) => onRenameCommit(t.id, e.target.value.trim() || t.name)} />
                : <span className="tag__lbl">{t.name}</span>}
            </span>
          </button>
        );
      })}
    </div>
  );
}

// Tag control cluster (DS §7.2) — "military technology" treatment: chamfered angular
// shell, hex-mesh texture, hazard accent + technical label, chamfered glowing buttons.
function TagControls({ onAdd, onRemove, onMoveLeft, onMoveRight }) {
  const btns = [
    { icon: "add", fn: onAdd, title: "add tag" },
    { icon: "remove", fn: onRemove, title: "remove tag" },
    { icon: "move_left", fn: onMoveLeft, title: "move left" },
    { icon: "move_right", fn: onMoveRight, title: "move right" },
  ];
  return (
    <div className="tagctl">
      <span className="tagctl__mesh" />
      <span className="tagctl__haz" />
      {btns.map((b) => (
        <button key={b.icon} className="tagctl__b" title={b.title} onClick={b.fn}>
          <img src={ICON(b.icon)} alt={b.title} />
        </button>
      ))}
    </div>
  );
}

// Per-tag management menu (right-click a tag). Anchored to the tag.
const TAG_ICON_CYCLE = ["term", "internet", "files", "develop", "edit", "media", "doc"];
function TagMenu({ menu, onClose, onRename, onMoveLeft, onMoveRight, onChangeIcon, onRemove, canRemove }) {
  const [picking, setPicking] = React.useState(false);
  React.useEffect(() => { setPicking(false); }, [menu]);
  if (!menu) return null;
  const items = [
    { icon: "edit", label: "Rename", fn: onRename },
    { icon: "move_left", label: "Move Left", fn: onMoveLeft },
    { icon: "move_right", label: "Move Right", fn: onMoveRight },
    { icon: "edit", label: "Change Icon", fn: () => setPicking(true), keep: true, arrow: true },
    { icon: "remove", label: "Remove", fn: onRemove, danger: true, disabled: !canRemove },
  ];
  return (
    <div className="ctxwrap" onMouseLeave={onClose} onClick={onClose}>
      <div className="ctx" style={{ left: menu.x, top: menu.y }} onClick={(e) => e.stopPropagation()}>
        <div className="ctx__band">{picking ? "CHANGE ICON · PICK" : "TAG · " + menu.name}</div>
        {picking ? (
          <div className="iconpick">
            {TAG_ICON_CYCLE.map((ic) => (
              <button key={ic} className="iconpick__b" title={ic} onClick={() => { onChangeIcon(ic); onClose(); }}>
                <img src={ICON(ic)} alt={ic} />
                <span>{ic}</span>
              </button>
            ))}
          </div>
        ) : items.map((it) => (
          <div key={it.label}
            className={"ctx__item" + (it.danger ? " ctx__item--danger" : "") + (it.disabled ? " ctx__item--off" : "")}
            onClick={() => { if (!it.disabled) { it.fn(); if (!it.keep && it.label !== "Rename") onClose(); } }}>
            <img src={ICON(it.icon)} alt="" />
            <span>{it.label}</span>
            {it.arrow && <span className="ctx__arrow">▸</span>}
          </div>
        ))}
      </div>
    </div>
  );
}

// Clickable stat lozenges + clock. props: stats {cpu,mem,gpu,net,vol}, onOpen(group)
// Nested concave-arrow "blind" ribbon (matches the reference rice).
function StatLozenges({ stats, active, onOpen, clock }) {
  const seg = (group, icon, val, z, first) => {
    // VOL stays the same color as the other central widgets (no red/hot alert).
    const hot = group !== "volume" && typeof val === "string" && val.endsWith("%") && parseInt(val) >= 90;
    return (
      <button className={"seg" + (first ? " seg--first" : "") + (active === group ? " seg--on" : "")} style={{ zIndex: z }} onClick={() => onOpen(group)}>
        <span className="arrow seg__edge" />
        <span className="arrow seg__fill" />
        <span className="seg__content">
          <img src={ICON(icon)} alt="" />
          <span className="seg__v" style={hot ? { color: "var(--glow-hot)" } : null}>{val}</span>
        </span>
      </button>
    );
  };
  return (
    <div className="lozstrip">
      {seg("system", "cpu", stats.cpu, 6, true)}
      {seg("system", "mem", stats.mem, 5)}
      {seg("system", "gpu", stats.gpu, 4)}
      {seg("network", "net", stats.net, 3)}
      {seg("volume", "vol", stats.vol, 2)}
    </div>
  );
}

// Right side: clock + date (top-right) · systray · keyboard · power
function RightCluster({ onPower, clock, onOpenTime, timeActive }) {
  return (
    <div className="rightc">
      <span className="loztail__hm">{clock.hm}</span>
      <button className={"datepill" + (timeActive ? " datepill--on" : "")} onClick={onOpenTime}>{clock.dt}</button>
      <span className="systray"><i /><i /><i /></span>
      <span className="kbl">US</span>
      <button className="powerbtn" onClick={onPower} title="power">
        <img src={ICON("shutdown")} alt="power" />
      </button>
    </div>
  );
}

Object.assign(window, { TagTabs, TagControls, TagMenu, StatLozenges, RightCluster });
