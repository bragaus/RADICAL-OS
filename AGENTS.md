# AGENTS.md

> **Doc map:** this file is the agent-facing digest. Authoritative siblings: **CLAUDE.md** (boot /
> load order / verify), **ARCHITECTURE.md** (Atomic Design layout + restructure), **DESIGN_SYSTEM.md**
> (violet-HUD appearance), and **`ferramentas_para_implementacao/`** (the design toolkit = token /
> type / icon / component source). On conflict the sibling doc wins; CLAUDE.md wins on boot facts.

## Verify
- This repo is an AwesomeWM config, not a package/workspace repo. There are no repo-local test, lint, formatter, or CI configs to run.
- The only verified fast check in-repo is `awesome -k rc.lua` from the repo root. It catches config load/syntax issues, but not missing desktop binaries or live screen behavior.

## Entry Point
- `rc.lua` is the real entrypoint, and its require order is intentional.
- `src.theme.user_variables` defines global `user_vars`; `src.theme.init` defines global `Theme` and `Theme_path`; `src.core.signals` defines global `Hover_signal`. Many later modules assume those globals already exist.
- The `user_vars.autostart` table is consumed by `src/tools/auto_starter.lua`, invoked last in `rc.lua` (line 24).
- Add screen UI in `radical_wm/init.lua`, not `rc.lua`, unless it must happen before screen setup.

## Structure
- `src/core/`: startup behavior, rules, notifications, shared signals.
- `src/theme/`: theme globals and user-tunable settings. `.luarc.json` targets Lua 5.3 and points language tooling at `/usr/share/awesome/lib`.
- `src/molecules/`: leaf widgets (one job each); many shell out to external Linux desktop tools. (Atomic Design restructure per ARCHITECTURE.md §5 is **complete** — `src/widgets/` is gone.)
- `src/organisms/`: panels, lists, popups, OSDs, controllers, menus, the bottom `monitor_bar` (the former `src/widgets/` panels + all of the former `src/modules/`).
- `src/_attic/`: quarantined dead blocking-IO code (`gpt.lua`, `sysBackup.lua`); not a layer, never required.
- `mappings/`: root/client key and mouse bindings.
- `radical_wm/`: actual bar/popup composition. Edit the non-backup files that `radical_wm/init.lua` requires; ignore `*_backup.lua` and `*.backup.lua` unless the user explicitly wants them touched.

## Repo Gotchas
- Globals are part of the design here. Do not “clean up” `user_vars`, `Theme`, `Theme_path`, or `Hover_signal` into locals without updating consumers across the repo.
- `radical_wm/init.lua` is screen-specific: it branches on `s == screen.primary`. **Non-primary** screens stay minimal (tags only). The **primary** screen gets the full violet-HUD composition: top `radical_bar` (taglist + `tag_controls` + `control_center` lozenges + clock/systray/power), the on-click dashboard popups, `status_dock`, `app_launcher`, and the bottom **MonitorBar** (DESIGN_SYSTEM.md §7.3.1). Retired: `system_monitor_chart`, `center_bar`, macOS `dock`.
- `mappings/bind_to_tags.lua` binds keys for tags 1..9, but `radical_wm/init.lua` currently creates 4 named tags (`PLANO-WEB3`, `VIBE-STUDING`, `GHOST-SIGN`, `NEW-ICHIMOKU`). Treat tag-count changes as coordinated edits across both files.
- Floating rules are partly data-driven: `src/core/rules.lua` loads `src/assets/rules.txt`, and `mappings/global_keys.lua` appends/removes classes in that same file at runtime.
- Path handling is mixed. Most assets use `awful.util.getdir("config")` or `gears.filesystem.get_configuration_dir()`, but some shell snippets hardcode `~/.config/awesome`.
- `src/molecules/plano_gif.lua` preloads `src/assets/logo.gif` at startup and caches extracted frames under `/tmp/awesome_plano_gif_frames/`. Stale cache can affect GIF-related changes.
- `radical_wm/radical_bar.lua` recolors child widgets unless they set `_preserve_colors` or `_preserve_segment`. Set one of those flags for widgets that must keep their own colors.
- Widget behavior depends on external desktop commands such as `rofi`, `pactl`, `playerctl`, `iw`, `ping`, `pkexec xfpm-power-backlight-helper`, and ImageMagick `convert`. Preserve those shell command contracts when editing related widgets.
