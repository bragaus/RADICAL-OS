# AGENTS.md

> For full architecture, load order, and gotchas see **`CLAUDE.md`**. For the visual/design spec (colors, layout, icons, components) see **`DESIGN_SYSTEM.md`** (`§`-cited throughout the Lua code). This file is the short agent-facing summary.

## Verify
- This repo is an AwesomeWM (Lua 5.3) config, not a package/workspace repo. No repo-local test, lint, formatter, or CI configs.
- Only fast in-repo check: `awesome -k rc.lua` from the repo root (CWD-relative requires demand it). Catches Lua load/syntax issues — **not** missing desktop binaries, runtime widget errors, or live screen behavior.
- One runtime dep beyond Lua: `python3` (for `src/scripts/app_usage.py`, used by the app launcher).

## Entry Point
- `rc.lua` is the real entrypoint; its require order is intentional and load-bearing.
- `LC_TIME` is set **before any requires** (Pango crashes on accented month/weekday bytes under a non-UTF-8 codeset).
- `src.theme.user_variables` → global `user_vars`; `src.core.error_handling` → global `err`; `src.theme.init` → globals `Theme`/`Theme_path`; `src.core.signals` → global `Hover_signal`. Everything after `error_handling` is wrapped in `err.safe_call(name, fn)` (one broken module no longer freezes the session). Many later modules assume those globals exist.
- `user_vars.autostart` is consumed by `src/tools/auto_starter.lua` (last call in `rc.lua`).
- Add screen UI in `radical_wm/init.lua`, not `rc.lua`, unless it must happen before screen setup.

## Structure
- `src/core/`: startup behavior, client rules, notifications, shared signals.
- `src/theme/`: `user_variables.lua` (user-tunable settings), `palette.lua` (**color source of truth** — `v50`–`v975`, text/line/status tokens, `p.a(hex,alpha)`; imported locally by ~20+ modules), `theme_variables.lua` (bridges palette → `beautiful`), `init.lua`. `colors.lua` is the **legacy** Material palette — still **live** (`radical_bar.lua` uses its `with_alpha()`; `taglist`/`power`/`battery`/`volume_controller` import it), so don't delete it without porting consumers to `palette.lua`. `.luarc.json` targets Lua 5.3, library `/usr/share/awesome/lib`.
- `src/widgets/`: leaf widgets **and** dashboard panels; many shell out to desktop tools.
- `src/modules/`: popups, OSDs, controllers.
- `src/tools/`: `auto_starter`, `icon_handler`, plus shared factories `panel.lua` (dashboard chrome) and `icons.lua` (`Icon(name,{color,size})` from `icons/svg/`).
- `mappings/`: root/client key and mouse bindings.
- `radical_wm/`: actual bar/popup composition. Edit only the non-backup files `radical_wm/init.lua` requires; ignore `*_backup.lua` / `*.backup.lua`.
- `especificacoes_tecnicas/`: untracked "VIOLET HUD" design-handoff kit (CSS tokens, SVG icons, React UI kit). Docs/prototype only — not loaded at runtime.

## Repo Gotchas
- Globals are part of the design. Do not "clean up" `user_vars`, `Theme`, `Theme_path`, `Hover_signal` (or localize `palette`'s consumers) without updating every consumer. Do not reorder requires past their initializer — `safe_call` masks the resulting `nil` crashes.
- `radical_wm/init.lua` is screen-specific: secondary screens get **only** the 4 tags. The **primary** screen gets the modules/OSDs, a single top-left `radical_bar(s, {layoutlist, taglist, tag_controls})`, the `control_center` (top-center stat pills + on-click SYSTEM/NETWORK/TIME dashboard popups), the dashboard panels, and `app_launcher`. There is **no** `right_bar`, `center_bar`, `dock`, or monolithic chart widget anymore (those names survive only in dead `*_backup.lua`).
- The 4 tags are `PLANO-WEB3`, `VIBE-STUDING`, `GHOST-SIGN`, `NEW-ICHIMOKU`. `mappings/bind_to_tags.lua` binds keys for tags 1..9 — treat tag-count changes as coordinated edits across both files.
- Floating rules are data-driven: `src/core/rules.lua` loads `src/assets/rules.txt` (single line, semicolon-separated WM_CLASS names); `mappings/global_keys.lua` appends/removes classes there at runtime. Its `%a+` parse silently mangles class names with dots/digits — latent bug.
- `src/widgets/plano_gif.lua` preloads `src/assets/logo.gif` and caches frames under `/tmp/awesome_plano_gif_frames_v4/<size>/` (size-keyed, never cleaned). `app_launcher.lua` caches under `/tmp/awesome_launcher_gif_v2_<px>/`. Clear those dirs if GIF behavior looks stale.
- `radical_wm/radical_bar.lua` recolors child widgets unless they set `_preserve_colors` or `_preserve_segment` (e.g. `tag_controls` sets `_preserve_colors = true`).
- Panels must sample async: `awful.spawn.easy_async_with_shell` + `tonumber()`/nil-guards inside `gears.timer` — never `io.popen`/`os.execute` in a timer (deadlocks the WM main loop).
- Brightness is **software xrandr** via `src/scripts/brightness.sh` (no hardware backlight on this NVIDIA desktop) — no `pkexec`/`xfpm`. State in `/tmp/awesome_brightness`.
- Widget behavior depends on external desktop commands — hard: `pactl`, `playerctl`, `rofi`, `xrandr`, `xprop`, `python3`+`gtk-launch`, ImageMagick `convert`, `bluetoothctl`; soft/optional: `nmap`+`tmux` (connections_panel), `nvidia-settings`, `picom`, `iw`, `ping`. Preserve those shell contracts when editing related widgets.
- Path handling is mixed: most code uses `awful.util.getdir("config")` / `gears.filesystem.get_configuration_dir()`, but some shell snippets hardcode `~/.config/awesome`.
