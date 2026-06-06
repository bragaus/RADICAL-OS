# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal AwesomeWM (Lua 5.3) config. No package manifest, no tests, no linter, no CI. Tooling expectations live in `.luarc.json` (Lua 5.3, library path `/usr/share/awesome/lib`, `lfs` global). One **runtime** dependency beyond Lua: `python3` (for `src/scripts/app_usage.py`, used by the app launcher — `app_menu.sh` calls it with no fallback).

## Verify changes

- Syntax/load check: `awesome -k rc.lua` — **must run from repo root** (`/home/bragaus/.config/awesome`) or with an absolute path, because `rc.lua` uses CWD-relative requires (`require('src.theme.user_variables')` etc.). Prints `Checking config ... OK` when valid. This is the **only** repo-local verification; it does **not** catch missing binaries, runtime widget errors, shell/Python failures, or visual regressions.
- Reloading the live config requires restarting AwesomeWM (`Mod4 + Ctrl + r` per `mappings/global_keys.lua`, or session restart). No hot-reload. (`display_setup.sh` can be rerun independently.)
- `python3 src/scripts/app_usage.py list-tsv` exercises the Python app-discovery path; `src/scripts/app_menu.sh` is an end-to-end launcher test (needs rofi + X + running WM).

## Entry point and load order

`rc.lua` is the real entry point and its order is load-bearing:

0. **Locale setup first** (`rc.lua` ~lines 17-19): set `LC_TIME` *before any requires*. If `LC_TIME` is a non-UTF-8 codeset, Pango rejects accented month/weekday bytes (e.g. `março`) and `set_markup` crashes in the calendar/clock widgets.
1. `require('src.theme.user_variables')` → global `user_vars`.
2. `require('src.core.error_handling')` → global `err`.
3. Everything after is wrapped in **`err.safe_call(name, fn)`**: `plano_gif.preload(...)`, `src.theme.init` (→ globals `Theme`, `Theme_path`; calls `beautiful.init(Theme)`), `src.widgets.alacritty_lain_overlay`, `src.core.signals` (→ global `Hover_signal(widget, bg, fg)`), `src.core.notifications`, `src.core.rules`, `mappings.global_buttons`, `mappings.bind_to_tags`, `radical_wm.init`, and finally `src.tools.auto_starter(user_vars.autostart)`.

`err.safe_call` means one broken module no longer freezes the session; errors route through the `debug::error` signal — which also **masks** load-order mistakes (a module that requires `Theme`/`Theme_path` before `src.theme.init` ran just gets `nil` and partially breaks). Do **not** reorder these requires or add a new require that depends on a global before its initializer runs. Later modules assume the globals (`user_vars`, `Theme`, `Theme_path`, `Hover_signal`) already exist — do **not** localize them without updating every consumer. **Note:** `src/theme/palette.lua` is *not* a global; ~20+ modules import it locally as `local p = require('src.theme.palette')` (see Color system).

## High-level architecture

- `src/core/` — startup glue: `error_handling.lua` (installs `debug::error` handler + `safe_call`), `rules.lua` (client rules), `notifications.lua`, `signals.lua` (focus/hover/transparency).
- `src/theme/` — `user_variables.lua` (user-tunable config), `palette.lua` (**color source of truth**, see below), `theme_variables.lua` (the active AwesomeWM theme handler — bridges palette → `beautiful`), `init.lua` (builds/inits `Theme`). `colors.lua` is the **legacy** Material Design palette — superseded by `palette.lua` for new code, but **still live**: `radical_wm/radical_bar.lua` (the active bar) uses its `color.with_alpha()` for segment alpha, and `taglist`/`power`/`battery`/`volume_controller` still import it. The violet-HUD migration is incomplete — don't delete `colors.lua` without porting those consumers to `palette.lua`.
- `src/widgets/` — leaf widgets and dashboard panels. Many shell out to system tools (see "External command contracts").
- `src/modules/` — popups/OSDs/controllers: `powermenu`, `volume_osd`, `brightness_osd`, `titlebar`, `volume_controller`.
- `src/tools/` — `auto_starter.lua`, `icon_handler.lua`, plus two shared factories used everywhere: **`panel.lua`** (dashboard chrome) and **`icons.lua`** (SVG loader). See "Panel/dashboard pattern".
- `src/scripts/` — shell + Python helpers invoked by widgets/mappings: `vol.sh`, `mic.sh`, `bt.sh`, `pfp.sh`, `display_setup.sh`, `brightness.sh`, `app_menu.sh`, `app_usage.py`.
- `src/assets/` — icons, layout glyphs, wallpaper, `logo.gif`, and `rules.txt` (runtime-mutable floating-class list).
- `icons/svg/` — the violet-palette SVG icon set loaded by `src/tools/icons.lua`.
- `mappings/` — keybindings/mouse bindings (`global_keys.lua`, `global_buttons.lua`, `client_keys.lua`, `client_buttons.lua`, `bind_to_tags.lua`, `cyber_hotkeys_dashboard.lua`).
- `radical_wm/` — bar/dock composition; `init.lua` wires per screen. Edit non-backup files only; **`radical_bar.backup.lua` and `center_bar_backup.lua` are dead** (never required).
- `especificacoes_tecnicas/` — untracked design-system kit (see "Design system").

**Stale/dead code to ignore:** `radical_wm/center_bar_backup.lua`, `radical_wm/radical_bar.backup.lua`, `src/widgets/tasklist.lua` and `src/widgets/kblayout.lua` (both exist but are **never instantiated** — `s.tasklist`/`s.kblayout` are not created; `global_keys.lua:293` still emits a `kblayout::toggle` signal nothing consumes), any `*.swp`/`*.swo`/`__pycache__` artifacts.

## Color system (palette.lua)

`src/theme/palette.lua` is the **Lua source of truth** for the "VIOLET HUD" color system. It exports 50+ named tokens — backgrounds (`void`, `abyss`, `base`, `inset`, `panel`, `panel_hi`, `raised`), the violet ramp (`v50`–`v975`), neon glow (`glow_ice`, `glow_soft`, `glow_core`, `glow_hot`), text (`text_bright`, `text_primary`, `text_heading`, `text_body`, `text_muted`, `text_faint`, `text_disabled`), lines/bevels (`line_faint`…`line_bright`, `bevel_hi`, `bevel_lo`, `grid`), data series (`data1`–`data6`), status (`ok`, `warn`, `crit`, `info`) — plus a runtime alpha helper **`p.a(hex, alpha)`** (e.g. `p.a(p.panel, 0.90)`). Use these tokens for all colors in widget code.

`src/theme/theme_variables.lua` is the bridge: it requires palette as `p` and maps tokens onto the `beautiful` `Theme` table, concatenating alpha as hex suffixes (e.g. `Theme.menu_bg_normal = p.panel .. 'f2'`). Alpha is **baked in at color-creation time** (via `p.a(...)` or a hex-suffix concat) — you cannot make a widget translucent by setting opacity *after* the background is built. This is a Lua idiom that does not port to CSS.

## Design system (`especificacoes_tecnicas/`)

Two layers — one **tracked**, one **untracked**:

- **`DESIGN_SYSTEM.md`** (repo root, ~1069 lines) — the authoritative violet-HUD visual spec, maintained current (last touched at HEAD). The Lua code `§`-cites it pervasively and the anchors resolve: `§3.13` icon set, `§5`/`§5.1`/`§5.2` top-bar + on-click dashboards, `§7.2.1` status lozenges, `§7.5` context menus (see `radical_wm/init.lua:54`, `control_center.lua`, `context_menu.lua`, `status_dock.lua`, `theme_variables.lua`). Treat it as a living spec — update it when the violet-HUD layout/components change.
- **`especificacoes_tecnicas/`** — an **untracked** design-handoff export of that spec titled "RADICAL VIOLET HUD": `colors_and_type.css` (CSS tokens mirroring `palette.lua` 1:1 — `--v500` == `p.v500` == `#8b5cf6`), a 41-icon SVG set, preview HTML cards, an interactive React UI kit under `ui_kits/radical-hud/`, and brand fonts (JetBrains Mono + Xirod). Documentation/prototype layer, **not the runtime source** — the Lua WM uses only JetBrains Mono (`user_vars.font`); Xirod and the CSS tokens are web-prototype only.

`palette.lua`, `DESIGN_SYSTEM.md`, and `especificacoes_tecnicas/colors_and_type.css` are kept in sync **by hand** — editing one does not update the others.

## Per-screen behavior (`radical_wm/init.lua`)

Runs `awful.screen.connect_for_each_screen`, then branches on `s == resolve_primary()`. `resolve_primary()` (lines 14-25) validates `screen.primary.geometry` (width/height > 0) and falls back to the first usable screen if a disconnected output is marked primary — **test multi-screen changes**.

- **Every screen** gets only the 4 named tags: `PLANO-WEB3`, `VIBE-STUDING`, `GHOST-SIGN`, `NEW-ICHIMOKU` (with `user_vars.layouts[1]`). Secondary screens stay otherwise clean — no bars/widgets/menus/OSDs.
- **Primary screen only** gets: the modules (`powermenu`, `volume_osd`, `brightness_osd`, `titlebar`, `volume_controller`), the tag/layout widgets (`layoutlist`, `taglist`, `tag_controls`), `powerbutton`, the `radical_bar`, the dashboard panels, the `control_center`, and `app_launcher`.

`mappings/bind_to_tags.lua` binds keys for tags 1..9 although only 4 tags exist — treat tag-count changes as a coordinated edit across both files.

### Bar + dashboard composition (current — the old "center_bar/right_bar/dock/cyber_chart" model is gone)

- `radical_wm/radical_bar.lua` is a **single top-left popup**: signature `function(s, widgets_top, widgets_bottom)`. `init.lua:63` calls it as `radical_bar(s, {s.layoutlist, s.taglist, s.tag_controls})` — **no `widgets_bottom`**, so the optional second popup is not created. There is **no** `center_bar`, `right_bar`, `dock`, `system_monitor_chart`, or `cyber_chart` in active code.
- It wraps each top widget in a powerline segment (padding, bg, rightward arrow). It **recolors children unless they carry `_preserve_colors` or `_preserve_segment`** — `tag_controls` sets `_preserve_colors = true` (`init.lua:61`) to opt out. Widgets owning their palette (e.g. a `world_clock` with custom `segment_bg`) must set one of these flags.
- System metrics show via **`src/widgets/control_center.lua`** (top-center bar of lozenge/hexagon pills: CPU/MEM/GPU/NET/VOL + a clock trigger, plus a top-right clock). Clicking a pill toggles one of three dashboard popups; opening one closes the others. `init.lua` calls `control_center{system_panels=…, network_panels=…, time_panels=…}` with these groups:
  - **SYSTEM:** `info_panel`, `usage_panel`, `process_panel`
  - **NETWORK:** `net_graph_panel`, `ip_panel`, `connections_panel`, `protocols_donut`, `apps_panel`
  - **TIME:** `calendar_panel`, plus `international_panel` (built from four `world_clock` instances — `clock_br`/`clock_fr`/`clock_jp`/`clock_us`; if any crashes, the whole panel fails)
- `status_dock.lua` is a separate, older thin status bar (own lozenge implementation, smaller sizing, not wrapped in `panel()`). It shares the `lozenge_shape()`/`make_lozenge()` patterns with `control_center` but is a distinct implementation — don't conflate the two.

## Panel/dashboard pattern

- **`src/tools/panel.lua`** is the shared chrome factory for dashboards: `panel{title, body, accent, w, h, header_height, radius, focus, right_icon, pad}` → a `wibox.container.background`. It draws (via `bgimage`) a header band (uppercase title; `v700` bg when focused else `panel_hi`), a gradient divider, a 2-tone bevel (`bevel_hi`/`bevel_lo`), and accent corner ticks. Focus toggles via `outer:panel_set_focus(bool)` (updates `shape_border_color`). Alpha must be baked in at creation (`p.a(hex, alpha)`), not applied after build.
- **`src/tools/icons.lua`**: `Icon(name, {color=, size=})` → `imagebox`, reading `icons/svg/<name>.svg`. `opts.color` recolors the **entire** SVG via `gears.color.recolor_image` — recolor only on state change (e.g. KILL → `crit` on hover), since recoloring a multitone icon flattens it to monochrome.
- **Async sampling (mandatory):** never use `io.popen`/`os.execute` inside a timer — it deadlocks the WM main loop. Always `awful.spawn.easy_async_with_shell`, `tonumber()`/nil-guard stdout before any math, and keep deltas (`prev_total`, `prev_rx`, …) in closure state across callbacks. Timers use `call_now = true`; most intervals 2-5s, network 1s.
- **Scrollable lists** (`process_panel`, `connections_panel`): a fixed `VISIBLE`-row viewport over full `data`, a 0-based `offset` clamped to `max(0, #data - VISIBLE)`, a custom proportional scrollbar drawn in the gutter, and mouse buttons 4/5 shifting the offset. `offset` intentionally persists across rebuilds but must be re-clamped each tick.

**Adding a new panel:** (1) create `src/widgets/<name>_panel.lua` returning `function(args)` → `panel{title=…, body=…, accent=p.v500, w=args.w or …, right_icon=Icon(…)}`; (2) sample via `gears.timer{timeout=N, call_now=true, callback=…}` using `easy_async_with_shell`; (3) instantiate on the **primary screen only** in `radical_wm/init.lua` as `s.<name>_panel = require('src.widgets.<name>_panel'){w=dpi(520)}`; (4) add it to the right `system_panels`/`network_panels`/`time_panels` array in the `control_center{}` call; (5) colors via palette tokens, icons via `Icon()`.

## Floating-window rules (file-as-source-of-truth)

`src/core/rules.lua` reads `src/assets/rules.txt` (a **single line of semicolon-separated WM_CLASS names**) at startup via `easy_async_with_shell` to build the floating-class list. `mappings/global_keys.lua` mutates it at runtime: `Mod4 + BackSpace` appends the focused window's class (via `xprop`), `Mod4 + Shift + BackSpace` removes it. Preserve the single-line/semicolon contract. Two real defects to know about:

- **Non-atomic append:** the runtime add uses plain `echo >>` (unlike `app_usage.py`, which writes via tempfile + `os.replace`), so concurrent writes can corrupt the file.
- **`%a+` parse bug:** `rules.lua` extracts names with `%a+`, so any class containing non-letters (dots/digits/hyphens — e.g. `Com.github.donadigo.eddy`, or a class polluted by a pasted URL) is silently split, and only the first alphabetic run matches → the wrong windows float. A safer parse would split on `;` and trim. Treat this as a latent bug, not just a gotcha.

## App launcher / usage tracking

`src/scripts/app_usage.py` (python3) scans `/usr/share/applications` and `~/.local/share/applications` for `.desktop` files and tracks launch counts in `$XDG_CACHE_HOME/awesome_app_usage.tsv` (atomic writes). Subcommands: `list-tsv`, `list-rofi`, `bump <app_id>`, `launch-index <i>`. Two consumers share that same store and both `bump` on launch (so ordering stays consistent): `src/scripts/app_menu.sh` (rofi front-end, bound to `Mod4 + g`, launches via `gtk-launch`) and `src/widgets/app_launcher.lua` (carousel widget, uses `list-tsv`).

## Brightness

**Software-only via xrandr** — this machine (NVIDIA RTX 3060 desktop, external DP monitor) has no hardware backlight. `src/scripts/brightness.sh` runs `xrandr --output <primary> --brightness <0.10-1.0>`, persists state in `/tmp/awesome_brightness` (plain text; survives session restart, not reboot), and needs **no root/pkexec**. Called from `global_keys.lua` (`XF86MonBrightnessUp`/`Down`) and `src/modules/brightness_osd.lua`. The OSD uses a `syncing_slider` guard to avoid a feedback loop when programmatically setting the slider after applying xrandr. (The old `pkexec xfpm-power-backlight-helper` path no longer exists.)

## External command contracts

Widgets/scripts depend on system binaries — preserve CLI contracts when refactoring.

- **Hard deps** (feature is dead without them): `pactl` (volume/mute), `playerctl` (media), `rofi` (launcher/window switch), `xrandr` (display + brightness), `xprop` (WM_CLASS detection), `python3` + `gtk-launch` (app launcher), `convert` (ImageMagick, GIF frames), `bluetoothctl` (`bt.sh`), the terminal (`alacritty` via `user_vars.terminal`).
- **Soft/optional** (degrade or no-op if absent): `nmap` + `tmux` (connections_panel left-click runs nmap in tmux — **silent** fail if either missing), `nvidia-settings` (`display_setup.sh` sets `GPUPowerMizerMode=1` only if present), `picom` (autostart compositor; WM still starts without it, config `~/.config/picom.conf`), `iw` / `ping` (network state/strength), `gnome-control-center`, `systemctl`, `dm-tool`, `shutdown`/`reboot`, `nautilus`, `flameshot`.
- **No tool** — read directly: `network.lua` reads `/sys/class/net/<iface>/operstate` and `/proc/net/wireless`; the panels read `/proc/stat`, `/proc/meminfo`, `/proc/net/dev`.

## GIF frame caches

`src/widgets/plano_gif.lua` preloads `src/assets/logo.gif` early (`rc.lua`) at `math.max(72, user_vars.dock_icon_size + 36)` and caches extracted frames under `/tmp/awesome_plano_gif_frames_v4/<size>/`; `app_launcher.lua` caches under `/tmp/awesome_launcher_gif_v2_<px>/`. Both use ImageMagick `convert`. Caches are **size-keyed and never cleaned up** — if you change `user_vars.dock_icon_size`, or GIF behavior looks stale, the old size's frames are reused. Fix by clearing: `rm -rf /tmp/awesome_plano_gif_frames_v4 /tmp/awesome_launcher_gif_v2_*`.

## Tunable surface

If a change is "user preference" — modkey, fonts, terminal, wallpaper, autostart commands, dock programs (and `dock_icon_size`), transparency rules, network interface names, gaps/border widths (`dpi()` values), layouts — it almost certainly belongs in `src/theme/user_variables.lua`, not in widget code. Color-token changes belong in `src/theme/palette.lua` (and, if design handoff matters, mirrored into `especificacoes_tecnicas/colors_and_type.css`).

## Path handling caveat

Mixed conventions: most code uses `awful.util.getdir("config")` or `gears.filesystem.get_configuration_dir()`, but some shell snippets hardcode `~/.config/awesome`. Don't assume one convention.
