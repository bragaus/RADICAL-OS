# ARCHITECTURE.md — RADICAL-WM · Composition / Atomic Design

> Governs **code composition & structure**. Sibling to `DESIGN_SYSTEM.md` (visuals/tokens)
> and `CLAUDE.md` (verify/load-order). On overlap: `DESIGN_SYSTEM.md` owns *appearance*,
> this doc owns *structure*, `CLAUDE.md` owns *boot/verify*.

## 0. How Claude Code must use this doc
- Read order: `CLAUDE.md` (boot/verify) → this (structure) → `DESIGN_SYSTEM.md` (visuals).
- **Validate after EVERY change:** `awesome -k rc.lua` from repo root. Syntax/load only — it
  does NOT catch runtime widget errors, missing binaries, or visual regressions.
- `rc.lua`'s require order is **load-bearing**; the globals `user_vars`, `Theme`,
  `Theme_path`, `Hover_signal` are **intentional**. Moving a file = update every require path
  + re-run `-k`.
- Work on a git branch. Never restart the live WM on an unverified tree — test in Xephyr.
- **Decisions baked in (user-overridable):** restructure = HYBRID (§5); leaf purity invariant
  = NO BLOCKING IO, *not* "no side effects" (§3.3).

## 1. Scope & doc ownership
- **This doc:** the 5 composition levels, dependency rules, folder layout, migration plan.
- **DESIGN_SYSTEM.md:** palette/tokens, typography, component *looks*. Its §3 palette **is**
  the "atoms (tokens)" layer — never redefine tokens here. Those tokens **originate from the
  design toolkit `ferramentas_para_implementacao/`** (`_ds_manifest.json` / `colors_and_type.css`
  / `ui_kits/radical-hud/`); DESIGN_SYSTEM.md mirrors it, and `src/theme/palette.lua` is the Lua port.
- **CLAUDE.md:** entry point, load order, verify, external-command contracts.
- **AGENTS.md** overlaps ~80% with CLAUDE.md but is **kept and reconciled** (not merged) — the
  agent-facing verify/structure/gotchas digest. On conflict, **CLAUDE.md wins**.

## 2. The five levels, mapped to AwesomeWM
Side-effects are **not** the discriminator (in AwesomeWM almost every leaf owns a watch).
Classify by **composition + autonomy**:

- **Atoms** — one `wibox` primitive (`textbox`, `imagebox`, `progressbar`, …) OR a design
  token. Tokens live in `src/theme/` + `DESIGN_SYSTEM.md §3`.
- **Molecules** — a small, single-purpose composite of atoms; does **one** job (one metric,
  one control). MAY own its own `watch`/timer. e.g. `cpu_info`, `clock`, `date`, `battery`,
  `audio`, `network`, `kblayout`, `power`, `mon_module` (one telemetry module of the MonitorBar).
- **Organisms** — aggregate ≥2 molecules **OR** own popup/OSD/menu behavior **OR** are
  mounted directly by a page. e.g. `control_center`, `info_panel`, `usage_panel`,
  `process_panel`, `net_graph_panel`, `connections_panel`, `apps_panel`, `calendar_panel`,
  `ip_panel`, `status_dock`, `monitor_bar` (bottom telemetry dock — DESIGN_SYSTEM.md §7.3.1),
  `mon_rail` (its status rail), `taglist`, `tasklist`, `systray`, `tag_controls`, **and all of
  `src/modules/`** (OSDs, `powermenu`, `titlebar`, `notification-center`).
- **Templates** — composition skeletons that position organisms, parameterized by screen,
  with no concrete content. e.g. `radical_wm/radical_bar`, `right_bar`, `center_bar`;
  `src/tools/panel` (the panel-chrome mold).
- **Pages** — concrete per-screen instances of templates, with real wiring. = the
  `if resolve_primary()` branch in `radical_wm/init.lua` (primary gets bar/panels; the
  vertical secondary stays clean: tags only).

**Mechanical rule for the molecule↔organism ambiguity:** apply the three criteria above; if
still tied, **it is a molecule** (do not promote prematurely, §3.6).

## 3. Composition invariants (enforceable — reject violations)
1. **Unidirectional `require`.** A level requires only strictly-lower levels. Atoms never
   require molecules; molecules never require organisms; etc. If a "molecule" requires an
   organism, it is **misclassified** — fix the classification, not the rule.
2. **Tokens only from theme.** Colors/spacing/typography come from `src/theme/palette` +
   `DESIGN_SYSTEM.md` tokens. Never hardcode hex/size in molecules/organisms
   (mirrors `DESIGN_SYSTEM.md §0.2`).
3. **Purity = NO BLOCKING IO** (the real invariant). Never `io.popen`/`io.open`/`os.execute`
   on the main thread or in a timer — known WM freeze in this repo. Fetch via
   `awful.widget.watch`, `awful.spawn.easy_async`, or GIO async. A leaf MAY own its async
   fetch (colocated), but must expose a clean update surface.
4. **State lives where it's owned.** Per-screen state on `s.*` (never global tables keyed by
   screen index); shared signals via `src/core/signals` (`Hover_signal`, …). Molecules/atoms
   take config via constructor args, not by reaching into globals — except the sanctioned
   globals (`user_vars`, `Theme`, `Theme_path`, `Hover_signal`).
5. **One component per file**, filename = component. Non-backup files only (ignore
   `*_backup.lua` / `*.backup.lua`).
6. **No premature promotion.** Don't create an organism where a molecule suffices; don't
   abstract for reuse that doesn't exist yet.

## 4. Where Atomic Design does NOT apply
The behavioral/wiring layer stays as plain modules — **do not atomize** (adds wrappers for
no gain):
- `src/core/` — `error_handling`, `rules`, `signals`, `notifications`
- `mappings/` — keys, buttons, `bind_to_tags`
- `src/tools/` — `auto_starter`, `icon_handler`
- `rc.lua`

## 5. Target tree & migration (HYBRID) — the executable plan
Target layout:
```
src/
  theme/        # atoms (tokens)            — UNCHANGED
  atoms/        # primitive wibox wrappers, only if any genuinely emerge
  molecules/    # was: leaf widgets from src/widgets/
  organisms/    # was: panels from src/widgets/ + ALL of src/modules/  (+ new: monitor_bar/mon_rail)
  core/         # behavior                  — UNCHANGED
  tools/        # behavior                  — UNCHANGED
  scripts/      #                           — UNCHANGED
  assets/       #                           — UNCHANGED
mappings/       #                           — UNCHANGED
radical_wm/     # templates + pages         — UNCHANGED
```
Procedure — small, verifiable steps; **`awesome -k rc.lua` after each**:
1. Create `src/molecules/` and `src/organisms/`.
2. Classify each `src/widgets/*.lua` by §2 → move to `molecules/` or `organisms/`.
   ⚠️ Per-file classification happens on the live tree, file by file.
3. Move `src/modules/*` → `src/organisms/` (they are organisms).
4. After each move, update its require path **everywhere** (`rc.lua`,
   `radical_wm/init.lua`, cross-widget requires). `grep -rn "old.require.path" .` first.
   Re-run `-k`.
5. Enforce invariant #1 as you go.
6. Leave `radical_wm/`, `src/core/`, `mappings/`, `src/theme/` paths intact.

**Preserve during migration** (from CLAUDE.md / AGENTS.md):
- Load-bearing require order in `rc.lua`; the sanctioned globals.
- Tag-count coordination: `mappings/bind_to_tags.lua` binds keys 1..9 but only 4 tags exist
  (`PLANO-WEB3`, `VIBE-STUDING`, `GHOST-SIGN`, `NEW-ICHIMOKU`). Changing tag count = a
  coordinated edit across both files.
- External-command contracts: `rofi`, `pactl`, `playerctl`, `iw`, `ping`,
  `pkexec xfpm-power-backlight-helper`, ImageMagick `convert`, the user's terminal.
- `radical_bar` recolors children unless they set `_preserve_colors` / `_preserve_segment`.
- `plano_gif` caches frames under `/tmp/awesome_plano_gif_frames/`.
- `src/core/rules.lua` reads `src/assets/rules.txt` (runtime-mutable, semicolon-separated).

## 6. Known issues / debt to fix alongside the migration
- **Blocking-IO violations of §3.3:** `src/widgets/gpt.lua` (module-level `io.open`/`io.popen`,
  `/proc` reads) and `src/widgets/sysBackup.lua` (many `io.popen`). Convert to async, or
  quarantine if dead code.
- **Committed editor swap files:** `.app_launcher.lua.swp`, `.system_monitor_chart.lua.swo`.
  Remove; add `*.sw?` to `.gitignore`.
- **Leftovers** from the discarded `system_monitor_chart` (per `DESIGN_SYSTEM.md §1.2`): purge.
- **Doc sprawl (resolved):** `AGENTS.md` is **kept and reconciled** against CLAUDE.md /
  DESIGN_SYSTEM.md (CLAUDE.md wins on conflict), not merged. `ONBOARDING.md` (a team template,
  irrelevant to a solo config) was **repurposed into `README.md`** — project overview + doc map
  + boot/verify.

## 7. Acceptance checklist
- [ ] every `src/widgets/*.lua` reclassified into `molecules/` or `organisms/` per §2
- [ ] `src/modules/*` folded into `organisms/`
- [ ] `monitor_bar` organism present + mounted on the primary screen's bottom (DESIGN_SYSTEM.md §7.3.1)
- [ ] no upward `require` (verified by grep / a require-graph pass)
- [ ] no hardcoded color/size in molecules/organisms (tokens only)
- [ ] no blocking IO anywhere (`gpt.lua`, `sysBackup.lua` fixed)
- [ ] `awesome -k rc.lua` passes
- [ ] live boot in Xephyr: bar/panels on primary, clean vertical secondary
- [ ] swap files removed, `.gitignore` updated
