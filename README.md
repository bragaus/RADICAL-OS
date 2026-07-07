# RADICAL-WM

Personal **AwesomeWM** (Lua 5.3) desktop configuration — the **RADICAL Violet HUD**: a dense,
cockpit/HUD-style rice in a monochromatic violet palette, structured with **Atomic Design**.

Repo: `bragaus/RADICAL-WM`.

## What this is

- A from-scratch redesign of the AwesomeWM UI into the violet HUD look — panels with titled
  headers, bevel borders, line/donut/bar charts, calendar, world clocks, process/connections
  lists, a clickable top bar with stat lozenges + on-click dashboards, and a bottom MonitorBar
  telemetry dock — driven by a single design toolkit.
- An Atomic Design code layout: leaf widgets in `src/molecules/`, panels / lists / popups /
  OSDs / menus in `src/organisms/` (the old `src/widgets/` + `src/modules/` are gone); see
  ARCHITECTURE.md.

## Doc map (read in this order)

| Doc | Owns |
|---|---|
| **CLAUDE.md** | Boot, `rc.lua` load order, verify, external-command contracts. |
| **ARCHITECTURE.md** | Composition (atoms / molecules / organisms / templates / pages) + the restructure plan. |
| **DESIGN_SYSTEM.md** | Palette/tokens, typography, component looks — the violet HUD spec. |
| **AGENTS.md** | Agent-facing digest of the above. |
| **`especificacoes_tecnicas/`** | The RADICAL Violet HUD **design toolkit** — token / type / icon / component **source of truth** (`_ds_manifest.json`, `colors_and_type.css`, `_adherence.oxlintrc.json`, `ui_kits/radical-hud/`, `fonts/Xirod.otf`, `RADICAL Violet HUD.html`). |

## Boot & verify

- **Syntax/load check:** `awesome -k rc.lua` from the repo root. Catches config load/syntax issues
  only — not missing desktop binaries, runtime widget errors, or visual regressions.
- **Reload the live config:** restart AwesomeWM (`Mod4 + Ctrl + r`, per `mappings/global_keys.lua`,
  or via session restart). There is no hot-reload for arbitrary edits.

## Requirements

AwesomeWM + Lua 5.3. Widgets shell out to desktop tools: `rofi`, `pactl`, `playerctl`, `iw`,
`ping`, `pkexec xfpm-power-backlight-helper`, ImageMagick `convert`, and the user's terminal
(`alacritty` by default via `user_vars.terminal`). Autostart expects `picom` with config at
`~/.config/picom.conf`.

## Layout

See ARCHITECTURE.md for the full tree. Top level:

- `src/` — `theme/` (tokens / user vars), `core/` (startup glue), `tools/`, `scripts/`, `assets/`,
  `widgets/` (→ `molecules/` + `organisms/`), `modules/` (OSDs, powermenu, titlebar, notifications).
- `radical_wm/` — bar / dock / popup composition, wired per screen in `init.lua`.
- `mappings/` — key and mouse bindings.
- `icons/` — the 41-icon violet HUD SVG set (+ PNG fallbacks + `icondata.json`).
- `rc.lua` — entry point (load-bearing require order).

## Tunables

User preferences (modkey, fonts, terminal, wallpaper, autostart, dock programs, network
interfaces, transparency, layouts) live in `src/theme/user_variables.lua`.
