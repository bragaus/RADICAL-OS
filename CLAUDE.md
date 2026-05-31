# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Personal AwesomeWM (Lua 5.3) configuration. No package manifest, no tests, no linter, no CI. Tooling expectations live in `.luarc.json` (Lua 5.3, library path `/usr/share/awesome/lib`, `lfs` global).

## Verify changes

- Syntax/load check: `awesome -k rc.lua` (run from repo root). This is the only repo-local verification — it does **not** catch missing desktop binaries, runtime widget errors, or visual regressions.
- Reloading the live config requires restarting AwesomeWM (`Mod4 + Ctrl + r` per `mappings/global_keys.lua`, or via session restart). There is no hot-reload for arbitrary edits.

## Entry point and load order

`rc.lua` is the real entry point and its `require` order is load-bearing:

1. `src.widgets.plano_gif` (preloaded with a sized hint before theme init so frames are cached for the dock).
2. `src.theme.user_variables` → defines the global `user_vars` table.
3. `src.theme.init` → defines globals `Theme` and `Theme_path`, calls `beautiful.init(Theme)`.
4. `src.widgets.alacritty_lain_overlay`, `src.core.error_handling`.
5. `src.core.signals` → defines global `Hover_signal(widget, bg, fg)`.
6. `src.core.notifications`, `src.core.rules`.
7. `mappings.global_buttons`, `mappings.bind_to_tags`.
8. `radical_wm.init` → builds tags, bars, dock per screen.
9. `src.tools.auto_starter(user_vars.autostart)` runs the autostart commands.

Many later modules assume the globals (`user_vars`, `Theme`, `Theme_path`, `Hover_signal`) already exist. Do **not** localize these without updating every consumer.

## High-level architecture

- `src/core/` — startup glue: error handler, client rules, notifications, shared signals (focus, hover, transparency).
- `src/theme/` — `user_variables.lua` (user-tunable config: modkey, terminal, autostart, network ifaces, dock programs, transparency, fonts, wallpaper, layouts), `init.lua` (builds the `Theme` table consumed by `beautiful`), `theme_variables.lua`, `colors.lua`.
- `src/widgets/` — leaf widgets. Many shell out to external Linux tools (see "External command contracts" below).
- `src/modules/` — popups / OSDs / controllers (powermenu, volume_osd, brightness_osd, titlebar, volume_controller).
- `src/tools/` — `auto_starter.lua` (runs `user_vars.autostart`), `icon_handler.lua`.
- `src/scripts/` — shell helpers invoked by widgets (`vol.sh`, `mic.sh`, `bt.sh`, `pfp.sh`, `display_setup.sh`).
- `src/assets/` — icons, layout glyphs, wallpaper, `logo.gif`, and `rules.txt` (runtime-mutable list of floating-window classes).
- `mappings/` — keybindings and mouse bindings (`global_keys.lua`, `global_buttons.lua`, `client_keys.lua`, `client_buttons.lua`, `bind_to_tags.lua`, `cyber_hotkeys_dashboard.lua`).
- `radical_wm/` — bar/dock composition. `init.lua` wires everything per screen. Edit the non-backup files; ignore `*_backup.lua` / `*.backup.lua` unless explicitly asked.

## Per-screen behavior (`radical_wm/init.lua`)

Runs `awful.screen.connect_for_each_screen` for every screen, then branches on `s == screen.primary`:

- **Every screen** gets: 4 named tags (`PLANO-WEB3`, `VIBE-STUDING`, `GHOST-SIGN`, `NEW-ICHIMOKU`), powermenu, volume/brightness OSDs, titlebar, volume controller, layoutlist, taglist.
- **Primary screen only** gets: `system_monitor_chart` (cyber_chart), tasklist, kblayout, powerbutton, four `world_clock` widgets (BR/FR/JP/US), and the composed `radical_bar` + `center_bar` + `right_bar` + `dock`.

Note: `mappings/bind_to_tags.lua` binds keys for tags 1..9 even though only 4 tags exist. Treat tag-count changes as a coordinated edit across both files.

## Floating-window rules

`src/core/rules.lua` reads `src/assets/rules.txt` to build the floating-class list. `mappings/global_keys.lua` appends/removes classes from that same file at runtime via keybindings. When editing rules logic, preserve the file-as-source-of-truth contract (semicolon-separated class names on a single line).

## Bar composition gotchas

- `radical_wm/radical_bar.lua` recolors child widgets unless they carry `_preserve_colors` or `_preserve_segment`. Widgets that own their palette (e.g. `world_clock` with a custom `segment_bg`) must set one of those flags.
- `src/widgets/plano_gif.lua` preloads `src/assets/logo.gif` and caches extracted frames under `/tmp/awesome_plano_gif_frames/`. If GIF behavior looks stale, clear that directory.
- Path handling is mixed: most code uses `awful.util.getdir("config")` or `gears.filesystem.get_configuration_dir()`, but some shell snippets hardcode `~/.config/awesome`. Don't assume one convention.

## External command contracts

Widgets and scripts depend on system binaries — preserve their CLI contracts when refactoring:
`rofi`, `pactl`, `playerctl`, `iw`, `ping`, `pkexec xfpm-power-backlight-helper`, ImageMagick `convert`, and the user's terminal (`alacritty` by default via `user_vars.terminal`). Autostart also expects `picom` with config at `~/.config/picom.conf`.

## Tunable surface

If a change is "user preference" (modkey, fonts, terminal, wallpaper, autostart commands, dock programs, transparency rules, network interface names), it almost certainly belongs in `src/theme/user_variables.lua` rather than in widget code.
