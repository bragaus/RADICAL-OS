# UI Kit — RADICAL-WM · Violet HUD desktop

An interactive recreation of the **RADICAL-WM** AwesomeWM desktop in the VIOLET HUD style. This
is a cosmetic, click-through recreation — not the real Lua WM. It mirrors the layout, chrome,
type, color and interaction model documented in the root `README.md` and the repo's
`DESIGN_SYSTEM.md`.

## Run it

Open `index.html`. The desktop fills the viewport (it is designed to be viewed full-screen, like
a real desktop). It loads `../../colors_and_type.css` (tokens) + `kit.css` (kit styles).

## What's interactive

- **Top bar** — sharp one-direction **tag tabs** (click to select), the `+ − ‹ ›` tag-control
  cluster, the center **stat lozenges** (CPU/MEM/GPU/NET/VOL, live-updating), a clock, systray
  and a power button. The lozenge values jitter on a timer to feel live.
- **On-click dashboards** — click a lozenge to drop a dashboard popup under the bar (one open at
  a time; click again to close):
  - **CPU / MEM / GPU** → **SYSTEM** (INFO · USAGE core table · GRAPH · scrollable PROCESS with KILL)
  - **NET** → **NETWORK** (GRAPH · IP · PROTOCOLS donut · scrollable CONNECTIONS · APPLICATIONS)
  - **VOL** → **VOLUME** controller
  - **clock** → **TIME** (CALENDAR · INTERNATIONAL world clocks · SATELLITE)
- **Windows** — three mock tiled terminals (htop, neofetch, git/nmap log). Click to focus
  (focused = `glow_core` border). **Right-click a window** → the context menu (gradient title
  band, items, hover *Send Signal* → signal submenu).
- **App launcher** — the circular **R** button (bottom-right, Xirod wordmark) opens an app list.
- **Power** — the ⏻ button opens the full-screen power menu (chip buttons).
- **PROCESS / CONNECTIONS lists** scroll with the mouse wheel (fixed window + right-rail thumb).
- Killing a process / launching an app raises a notification toast.

## Files

| File | What it holds |
|---|---|
| `index.html` | Loads React + Babel + all JSX, mounts `<App/>`. |
| `kit.css` | All kit styles (desktop, windows, top bar, panels, menus). |
| `panel.jsx` | `Panel` chrome + primitives: `InfoRow`, `BarMeter`, `TableRow`, `KillBtn`, `ScrollList`. |
| `charts.jsx` | `LineGraph` (grid + area + halo), `Donut`. |
| `topbar.jsx` | `TagTabs`, `TagControls`, `StatLozenges`, `RightCluster`. |
| `windows.jsx` | `TermWindow` + `HtopContent` / `NeofetchContent` / `LogContent`. |
| `dashboards.jsx` | `SystemDashboard`, `NetworkDashboard`, `TimeDashboard`, `VolumeDashboard`. |
| `menus.jsx` | `ContextMenu`, `PowerMenu`, `AppLauncher`. |
| `app.jsx` | State wiring: selected tag, open popup, context/power/launcher, live stats, toasts. |

## Fidelity notes

- All iconography is the project's own 41-icon SVG set (`../../assets/icons/*`), recolored by
  state where needed (KILL → crit on hover; selected/urgent tabs → light fg).
- Metrics are mocked/animated — there is no real `/proc`, `ps`, or `ss` sampling.
- The real WM reuses only the *data-collection logic* of the old config; this kit reuses none of
  it — it is presentation only.
