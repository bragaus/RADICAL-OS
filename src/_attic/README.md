# `src/_attic/` — quarantined dead code

Not an Atomic Design layer. Nothing here is `require`d by the live config
(verified: zero require sites). Kept out of `molecules/`/`organisms/` for one of
three reasons: **NO BLOCKING IO** violation (ARCHITECTURE.md §3.3), the file does
not even parse, or a live organism already supersedes it.

Per ARCHITECTURE.md §6 the choice for blocking-IO code was "convert to async, or
**quarantine if dead code**". Every file here is dead, so it is quarantined
rather than ported.

| file | why quarantined |
|------|-----------------|
| `gpt.lua`       | module-level `io.open`/`io.popen` + `/proc` reads; unmounted |
| `sysBackup.lua` | many synchronous `io.popen` calls; unmounted |
| `battery.lua`   | **does not parse** (`luac5.3` fails at L54: `'}' expected` to close `{` at L20); machine has no battery hardware (desktop, xrandr software brightness); zero require sites. Quarantined during the Atomic-Design refactor rather than repaired — no consumer, no hardware to feed it. |
| `status_dock.lua` | **superseded** by `src/organisms/control_center.lua`, a strict superset (its `make_lozenge` stat-lozenge strip lives on in `control_center`; the redesign's only sanctioned top strip is `control_center`). Parses cleanly but has zero require sites. Quarantined during the refactor as a dead duplicate. |

To revive either: convert all blocking IO to `awful.spawn.easy_async` /
`awful.widget.watch` / GIO async first, then move it into `molecules/` (single
job) or `organisms/` (aggregate/popup) and wire its `require`.
