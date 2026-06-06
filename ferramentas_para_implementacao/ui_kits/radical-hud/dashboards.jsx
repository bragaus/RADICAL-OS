// dashboards.jsx — VIOLET HUD on-click dashboard popups (DS §5.2).
// Clicking a stat lozenge opens one of these grouped panel sets, anchored under the bar.

const PROC = [
  ["3208", "firefox", "22.4", "8.1"], ["1142", "Xorg", "12.3", "3.2"],
  ["4471", "awesome", "7.0", "1.4"], ["5012", "alacritty", "4.5", "0.9"],
  ["6633", "node", "4.4", "2.1"], ["7781", "zsh", "1.2", "0.3"],
  ["8890", "pipewire", "0.8", "0.2"], ["9021", "nmap", "0.5", "0.4"],
  ["9210", "tmux", "0.3", "0.1"], ["9344", "picom", "0.2", "0.5"],
];
const CONNS = [
  ["tcp", "10.10.10.139:443", "ESTABLISHED", "var(--ok)"],
  ["tcp", "lad23b05:8080", "ESTABLISHED", "var(--ok)"],
  ["tcp", "0.0.0.0:22", "LISTEN", "var(--text-muted)"],
  ["udp", "rajaniemi:51820", "ESTABLISHED", "var(--ok)"],
  ["tcp", "127.0.0.1:6463", "TIME_WAIT", "var(--warn)"],
  ["tcp", "0.0.0.0:5432", "LISTEN", "var(--text-muted)"],
  ["tcp", "fe80::204:8080", "ESTABLISHED", "var(--ok)"],
];

function SystemDashboard({ history, onKill }) {
  return (
    <div className="dash">
      <div className="dash__col">
        <Panel title="INFO" icon="cpu" width={236}>
          <InfoRow k="kernel" v="6.18.5" />
          <InfoRow k="uptime" v="04:21:55" />
          <InfoRow k="packages" v="1487" />
          <InfoRow k="shell" v="zsh 5.9" />
          <InfoRow k="wm" v="awesome 4.3" />
        </Panel>
        <Panel title="USAGE" icon="cpu_temp" width={236}>
          <TableRow header cells={[{ t: "CORE", w: 52 }, { t: "GHZ", w: 52, align: "right" }, { t: "TEMP", w: 56, align: "right" }, { t: "USE%", w: 52, align: "right" }]} />
          {[["C0", "3.8", "42°C", "36"], ["C1", "2.1", "40°C", "12"], ["C2", "3.4", "40°C", "44"], ["C3", "1.9", "38°C", "8"]].map((r, i) => (
            <TableRow key={i} cells={[
              { t: r[0], w: 52, color: "var(--text-muted)" },
              { t: r[1], w: 52, align: "right", color: "var(--text-bright)" },
              { t: r[2], w: 56, align: "right", color: parseInt(r[2]) >= 80 ? "var(--crit)" : "var(--text-primary)" },
              { t: r[3] + "%", w: 52, align: "right", color: "var(--text-bright)" }]} />
          ))}
        </Panel>
      </div>
      <div className="dash__col">
        <Panel title="GRAPH" icon="net" width={264}>
          <LineGraph width={248} height={92} series={[
            { color: "var(--data1)", data: history.cpu },
            { color: "var(--data2)", data: history.mem },
          ]} />
          <div className="glegend">
            <span><i style={{ background: "var(--data1)" }} />CPU</span>
            <span><i style={{ background: "var(--data2)" }} />MEM</span>
          </div>
        </Panel>
        <Panel title="PROCESS" icon="kill_all" width={264}>
          <ScrollList visible={6} rows={PROC.map((r, i) => (
            <TableRow key={i} onKill={() => onKill(r[1])} cells={[
              { t: r[0], w: 44, color: "var(--text-muted)" },
              { t: r[1], w: 96, color: "var(--text-primary)" },
              { t: r[2], w: 40, align: "right", color: "var(--text-bright)" },
              { t: r[3], w: 40, align: "right", color: "var(--text-bright)" }]} />
          ))}
            header={<TableRow header onKill={() => {}} cells={[{ t: "PID", w: 44 }, { t: "NAME", w: 96 }, { t: "CPU%", w: 40, align: "right" }, { t: "MEM%", w: 40, align: "right" }]} />} />
        </Panel>
      </div>
    </div>
  );
}

function NetworkDashboard({ history, onKill }) {
  return (
    <div className="dash">
      <div className="dash__col">
        <Panel title="GRAPH" icon="net" width={236}>
          <LineGraph width={220} height={80} series={[
            { color: "var(--data4)", data: history.net },
            { color: "var(--v400)", data: history.cpu },
          ]} />
          <div className="glegend">
            <span><img src={ICON("net_up")} style={{ width: 12, height: 12 }} />UP</span>
            <span><img src={ICON("net_down")} style={{ width: 12, height: 12 }} />DOWN</span>
          </div>
        </Panel>
        <Panel title="IP" icon="net" width={236}>
          <InfoRow k="iface" v="eno1" />
          <InfoRow k="ipv4" v="10.10.10.139" />
          <InfoRow k="gateway" v="10.10.10.1" />
          <InfoRow k="dns" v="1.1.1.1" />
        </Panel>
        <Panel title="PROTOCOLS" icon="send_signal" width={236}>
          <Donut size={84} slices={[
            { label: "https", pct: 52, color: "var(--data1)" },
            { label: "ircd", pct: 23, color: "var(--data2)" },
            { label: "ssh", pct: 14, color: "var(--data3)" },
            { label: "dns", pct: 11, color: "var(--data4)" },
          ]} />
        </Panel>
      </div>
      <div className="dash__col">
        <Panel title="CONNECTIONS" icon="send_signal" width={300}>
          <ScrollList visible={6} rows={CONNS.map((r, i) => (
            <div key={i} className="connrow" onClick={() => {}}>
              <span style={{ width: 36, color: "var(--text-muted)" }}>{r[0]}</span>
              <span style={{ flex: 1, color: "var(--text-primary)" }}>{r[1]}</span>
              <span style={{ width: 96, textAlign: "right", color: r[3] }}>{r[2]}</span>
            </div>
          ))}
            empty="NO CONNECTIONS"
            header={<TableRow header cells={[{ t: "PROTO", w: 36 }, { t: "ADDRESS", w: 150 }, { t: "STATE", w: 96, align: "right" }]} />} />
        </Panel>
        <Panel title="APPLICATIONS" icon="kill_all" width={300}>
          {[["konversation", "0.4"], ["firefox", "8.1"], ["nmap", "0.5"]].map((r, i) => (
            <TableRow key={i} onKill={() => onKill(r[0])} cells={[
              { t: r[0], w: 200, color: "var(--text-primary)" },
              { t: r[1] + "%", w: 48, align: "right", color: "var(--text-bright)" }]} />
          ))}
        </Panel>
      </div>
    </div>
  );
}

const CAL = (() => {
  const days = []; for (let i = 1; i <= 31; i++) days.push(i); return days;
})();

function TimeDashboard() {
  return (
    <div className="dash">
      <div className="dash__col">
        <Panel title="CALENDAR" icon="calendar" width={252}>
          <div className="calhd">JANUARY 2026</div>
          <div className="calgrid">
            {["SU","MO","TU","WE","TH","FR","SA"].map(d => <span key={d} className="caldow">{d}</span>)}
            {[null,null,null].map((_, i) => <span key={"e" + i} />)}
            {CAL.map(d => <span key={d} className={"calday" + (d === 2 ? " calday--today" : "") + ([3,4,10,11,17,18,24,25,31].includes(d) ? " calday--we" : "")}>{d}</span>)}
          </div>
        </Panel>
      </div>
      <div className="dash__col">
        <Panel title="INTERNATIONAL" icon="clock" width={236}>
          {[["UTC", "06:42:36"], ["CET", "07:42:36"], ["EST", "01:42:36"], ["JST", "15:42:36"]].map((z, i) => (
            <div key={i} className="wclock">
              <span className="wclock__city">{z[0]}</span>
              <span className="wclock__dash" />
              <span className="wclock__hm">{z[1]}</span>
            </div>
          ))}
        </Panel>
        <Panel title="SATELLITE" icon="internet" width={236}>
          <InfoRow k="next pass" v="14:42:36" />
          <InfoRow k="elevation" v="42°" />
          <InfoRow k="status" v="TRACKING" vColor="var(--ok)" />
        </Panel>
      </div>
    </div>
  );
}

function VolumeDashboard() {
  return (
    <div className="dash">
      <Panel title="VOLUME" icon="vol" width={252}>
        <BarMeter label="MASTER" pct={98} />
        <BarMeter label="CAPTURE" pct={64} />
        <BarMeter label="FRONT" pct={72} />
        <div style={{ marginTop: 6 }}><InfoRow k="sink" v="DEFAULT" /></div>
      </Panel>
    </div>
  );
}

Object.assign(window, { SystemDashboard, NetworkDashboard, TimeDashboard, VolumeDashboard });
