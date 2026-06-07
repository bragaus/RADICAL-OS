# RADICAL-WM · VIOLET HUD — Design System

A design system for the **RADICAL-WM** desktop: a custom [AwesomeWM](https://awesomewm.org/)
(Lua) window-manager configuration by **bragaus**. The visual language is a **dense,
ultra-information "cockpit / military HUD"** — a near-black violet desktop tiled with small
rectangular **panels**, each with an uppercase titled header, a thin beveled border, corner
ticks, and data content (line/area charts, donuts, bars, calendars, world clocks, process &
connection lists).

This system is the **VIOLET HUD edition**: the original reference rice
(`assets/imagem_de_referencia.png`) is **blue**; the entire palette has been translated 1:1
to **violet/purple**. The HUD is essentially **monochromatic** — hierarchy comes from
**luminosity and opacity**, not from different hues.

> **"Linux Radical OS"** here means the RADICAL desktop environment: a themed AwesomeWM setup
> plus matching terminal (Alacritty), shell (ZSH), file manager (Yazi) and tooling. This design
> system documents the **window-manager HUD surface** specifically.

---

## Sources

Everything in this system was derived from materials the user provided. The reader may not have
access, but they are recorded here so they can explore further:

- **GitHub — primary source:** [`bragaus/RADICAL-WM`](https://github.com/bragaus/RADICAL-WM)
  · branch `main`. The AwesomeWM module + theme. Key files read:
  - `DESIGN_SYSTEM.md` — the 60 KB "VIOLET HUD" spec (the source of truth for tokens, type,
    components). Mirrored throughout this README.
  - `src/theme/palette.lua` — the violet token table.
  - `src/tools/panel.lua` — the panel-chrome factory (the central motif).
  - `src/organisms/taglist.lua` — the sharp powerline arrow tabs.
  - `src/organisms/process_panel.lua`, `status_dock.lua`, `control_center.lua` — bar + dashboards.
  - `icons/icondata.json` + `icons/svg/*` — the 41-icon VIOLET HUD set (imported, see below).
- **Reference image:** `assets/imagem_de_referencia.png` — the blue rice this HUD recreates in
  violet. **The image is the visual source of truth; the WM only reuses the *data-collection
  logic* of the old config, not its old orange/macOS appearance.**

Related repos by the same author (context only, not used directly):
[`bragaus/RADICAL-YAZI`](https://github.com/bragaus/RADICAL-YAZI),
[`bragaus/RADICAL-ZSH`](https://github.com/bragaus/RADICAL-ZSH),
[`bragaus/AwesomeWm-Files`](https://github.com/bragaus/AwesomeWm-Files).

**To do a better job building designs for this product, explore `bragaus/RADICAL-WM` directly** —
especially `DESIGN_SYSTEM.md` and the `src/organisms/` panels.

---

## CONTENT FUNDAMENTALS

How copy is written across the HUD.

- **Voice:** machine/terminal voice. Terse, technical, declarative. No marketing tone, no
  sentences — the HUD speaks in **labels and values**, like a status readout.
- **Casing:** **ALL-CAPS for every label, header and title.** Panel titles: `INFO`, `USAGE`,
  `GRAPH`, `PROCESS`, `CONNECTIONS`, `PROTOCOLS`, `CALENDAR`, `INTERNATIONAL`, `SATELLITE`,
  `APPLICATIONS`, `IP`, `STATE`, `USERS`. Column heads: `PID`, `NAME`, `CPU%`, `MEM%`,
  `PROTO`, `LOCAL`, `REMOTE`, `STATE`. Mixed/normal case appears only inside *values*
  (process names, hostnames, window titles).
- **Person:** **neither "I" nor "you."** The interface never addresses the user. It reports
  state about the *machine*. Menu actions are bare imperatives: `Visible`, `Sticky`,
  `Floating`, `Fullscreen`, `Move to tag ▸`, `Send Signal ▸`, `Close`.
- **Alignment convention:** **labels left, numbers right.** Units are muted and trail the
  value (`58%`, `6.18.5`, `04:21:55`, `1487`, `↑12 ↓4`).
- **Density over prose:** there is no helper text, no descriptions, no empty-state paragraphs.
  An empty list shows a single terse line: `NO CONNECTIONS`. Signals are raw names:
  `SIGHUP SIGINT SIGKILL SIGTERM SIGSTOP SIGCONT SIGUSR1 SIGUSR2`.
- **Numbers:** tabular, fixed precision (`%.1f` for CPU/MEM), right-aligned, monospaced so
  columns line up. Time as `HH:MM` / `HH:MM:SS`; dates as `Month DD` or `SU MO TU WE TH FR SA`.
- **Emoji:** **none.** Iconography is the SVG hardware-icon set, never emoji.
- **Language:** the project's prose/comments are **Portuguese (BR)**; the *UI surface itself*
  is English technical shorthand (kernel names, signal names, `ESTABLISHED`/`LISTEN`/`TIME_WAIT`).
- **Vibe:** a hacker/sysadmin "glass cockpit." It should feel like you are *monitoring* a
  machine, not *using an app*. Examples from the reference: world-clock rows `UTC 6:42:36`,
  process rows `22.4% xbmc.bin [KILL]`, menu band `SEND SIGNAL ▸`.

---

## VISUAL FOUNDATIONS

- **Color vibe:** near-black violet base (`--base #0c0617`) under everything; **a single
  violet family** builds all hierarchy. **Zero orange, zero teal, zero blue** as accent. Where
  the reference is bright cyan, we use `--glow-ice #d6c2ff`; primary accent is `--v500 #8b5cf6`,
  live focus is `--glow-core #a855f7`, peaks/alerts are `--glow-hot #c026d3`.
- **Hierarchy mechanism:** **luminosity + alpha**, not hue. More important = lighter / more
  opaque; secondary = darker / more transparent. An 8-step opacity ladder (`ff`→`0d`) is used
  for "more/less opaque."
- **Type:** one family — **JetBrains Mono (Nerd Font)**, monospaced, tight. Titles ExtraBold
  uppercase with +1 tracking; values ExtraBold; body Regular/Medium. Sizes are small and dense
  (9–12 px in the WM). A second face — **Xirod** (self-hosted, `fonts/Xirod.otf`) — is a wide,
  angular sci-fi display font reserved **only** for the **RADICAL brand wordmark / hero
  logotype** (`--font-display`, `.hud-display`). It never touches UI data or labels.
- **Backgrounds:** **no images, no gradients-as-decor, no illustrations.** The desktop is a flat
  near-black field. The only gradients allowed are *within the violet family* — the panel
  header divider (`accent → accent@22% → transparent`) and the context-menu title band
  (`line_bright → v950`). Optional subtle wallpaper `--abyss`. Panels and terminals use **slight
  transparency** (panel ~0.90, terminal ~0.85) with optional light blur (picom).
- **The panel chrome (central motif):** every panel is the same mold —
  **header** (`panel_hi`, uppercase title in `text_heading`, optional muted icon right) →
  **divider** (gradient) → **body** (`panel@0.9`, tight padding) → **1px border** (`line_base`,
  or `line_bright` when focused) → **2-tone bevel** (`bevel_hi` top+left, `bevel_lo` bottom+right)
  → **corner ticks** (4 small "L"s in accent). Reuse the same mold everywhere.
- **Spacing / radii:** small, angular. `radius_panel 4`, `radius_chip 3`, `radius_bar 2` — never
  10–15 px rounding. Inter-panel `gap 8`, body `pad 8`, row breathing `3`.
- **Borders & shadows:** **no colored drop-shadows.** Depth is the 2-tone inset bevel only.
  Window focus = thin `glow_core` border; unfocused = `v950`.
- **Cards (panels):** flat, near-square, thin border + inset bevel + corner ticks. They never
  float on a soft shadow — they sit flush, edge-to-edge, like instrument cutouts.
- **Charts:** wells use `--inset`; grid at low alpha (`grid@0.12–0.22` horizontal, accent
  @0.04–0.09 vertical); line 2 px in a data-series color with a 6 px soft halo underneath; area
  fill 0.20–0.34 alpha. Donuts use `data1..6` slices with `base` separators. Bar meters: track
  `inset`, fill gradient `v700 → v500`, ≥ alert threshold flips to `glow_hot`.
- **Animation:** **minimal.** Terminal-style instant state changes. At most an immediate color
  transition on hover. No bounce, no decorative loops, no easing showcases.
- **Hover state:** lighten background by one step (toward `raised`/`v900`), border → `line_bright`,
  text → `text_bright`, cursor `hand1`. SVG icons recolor by swapping the image (an imagebox
  can't recolor via fg).
- **Press state:** background deepens to `v600`; no shrink/scale.
- **Focus/active:** border `glow_core`, item bg `v700`, text `v50`.
- **Urgent:** border + tint `glow_hot`.
- **Transparency & blur:** used on panels/terminals for a "glass HUD" read; never so much that
  text contrast drops. Selectively — not a global frosted look.
- **Tags:** sharp **one-direction powerline arrow** tabs (flat left edge, pointed right tip — NOT
  a bi-directional hexagon). Inactive/empty `v975`, occupied `v975`+`text_primary`, focused
  `v500`+`v50`, urgent `glow_hot`+`v50`. Each tab is `[index] [type-icon] LABEL`.
- **Layout rule:** the only always-visible element is a **thin top bar**. Dense data panels live
  in **on-click dropdown popups** (~2× size) anchored under the bar; one open at a time. No
  static side columns, no macOS dock, no powerline dockbars, no semaphore titlebars.

---

## ICONOGRAPHY

The brand has its **own SVG icon set** — `assets/icons/*.svg` (imported from the repo's
`icons/svg/`). **41 icons, already drawn in the VIOLET HUD palette.** These are the source of
truth for hardware monitors and controls and are **preferred over Nerd-Font glyphs** (which are
only a fallback where no SVG exists — today just the `_` minimize glyph).

- **Style:** 24×24 grid, `viewBox="0 0 24 24"`, `fill="none"` root, round line caps/joins,
  stroke widths `1.4 / 1.6 / 2 / 2.6`. Each icon is **multi-tone** (up to 7 palette tokens in
  one file) — they are NOT monochrome line icons.
- **The 7 tokens the whole set uses:** `text_primary #cbb6ff` (all stroke/outline, ~119 uses),
  `v400 #9d6ff6` (accent fill), `v500 #8b5cf6` (primary fill), `bevel_lo #160c28` (negative
  space — skull eyes, lock keyhole), `glow_ice #d6c2ff` (LED/highlight — wifi dot, signal core),
  `text_muted #6f5a96` (inactive calendar cells), `v800 #5b21b6` (deep fill — folder body).
- **Recolor only by *state*:** because icons are multi-tone, flattening them to one color loses
  the composition. Recolor only for state — e.g. KILL → `crit` on hover, value ≥ 90% → `glow_hot`,
  temp ≥ 80 °C → `crit`. For a permanent highlight, edit the source token, don't recolor at runtime.
- **The 41 icons, by category** (matches `icondata.json`):
  - **stats (11):** `cpu cpu_temp mem gpu gpu_temp net net_up net_down wifi vol battery`
  - **power (5):** `shutdown reboot logout lock suspend`
  - **proc (2):** `kill kill_all`
  - **osd (4):** `notification dnd brightness volume_mute`
  - **menu (6):** `visible sticky floating fullscreen send_signal close`
  - **tagctl (4):** `add remove move_left move_right`
  - **tags (7):** `term internet files develop edit media doc`
  - **time (2):** `clock calendar`
- **No emoji. No unicode-char icons** (except the fallback `_`). **No PNG/raster icons** in the
  HUD surface (the repo ships PNG fallbacks at `icons/png/{16,24,32,48,64}`, but SVG is the
  source — prefer it, it scales without loss).
- **App-launcher icons** come from the system's `.desktop` files via `icon_handler.lua` (real
  freedesktop icon themes), recolored toward `text_primary` when monochrome is wanted.

A live specimen of the full set is in `preview/icons-grid.html`.

---

## File index

Root manifest:

| File | What it is |
|---|---|
| `README.md` | This document. |
| `colors_and_type.css` | All design tokens (CSS vars) + semantic classes + panel-chrome CSS + `@font-face`. |
| `SKILL.md` | Agent-Skills front-matter wrapper so this folder works as a Claude Code skill. |
| `fonts/Xirod.otf` | Brand display face (wordmark/logotype only). |
| `assets/icons/*.svg` | The 41-icon VIOLET HUD set (source of truth for iconography). |
| `assets/imagem_de_referencia.png` | The original blue rice this HUD recreates in violet. |
| `preview/*.html` | Design-system cards (palette, type, spacing, components) for the DS tab. |
| `ui_kits/radical-hud/` | The UI kit — interactive recreation of the violet HUD desktop. |

UI kits:

- **`ui_kits/radical-hud/`** — the AwesomeWM violet HUD desktop. `index.html` is an interactive
  recreation (top bar with sharp tag tabs + clickable stat lozenges → on-click dashboard popups
  with INFO/USAGE/GRAPH/PROCESS/CONNECTIONS/PROTOCOLS/CALENDAR panels; right-click-style context
  menu; app launcher). JSX components in the same folder. See its `README.md`.

---

*Living document. Update tokens/measures in `DESIGN_SYSTEM.md` (in the repo) and here before
propagating color changes through the code.*
