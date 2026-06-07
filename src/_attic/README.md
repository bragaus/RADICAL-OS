# `src/_attic/` — quarantined dead code

Not an Atomic Design layer. Nothing here is `require`d by the live config
(verified: zero require sites). Kept out of `molecules/`/`organisms/` because
each violates ARCHITECTURE.md §3.3 (**NO BLOCKING IO** on the main thread).

Per ARCHITECTURE.md §6 the choice was "convert to async, or **quarantine if dead
code**". Both files are dead, so they are quarantined here rather than ported.

| file | why quarantined |
|------|-----------------|
| `gpt.lua`       | module-level `io.open`/`io.popen` + `/proc` reads; unmounted |
| `sysBackup.lua` | many synchronous `io.popen` calls; unmounted |

To revive either: convert all blocking IO to `awful.spawn.easy_async` /
`awful.widget.watch` / GIO async first, then move it into `molecules/` (single
job) or `organisms/` (aggregate/popup) and wire its `require`.
