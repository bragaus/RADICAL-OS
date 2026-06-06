---
name: radical-wm-design
description: Use this skill to generate well-branded interfaces and assets for RADICAL-WM (the "Linux Radical OS" / VIOLET HUD AwesomeWM desktop), either for production or throwaway prototypes/mocks. Contains essential design guidelines, the violet color system, monospaced type + the Xirod brand face, the 41-icon SVG set, and a UI kit recreating the HUD desktop.
user-invocable: true
---

Read the `README.md` file within this skill, and explore the other available files.

This is the **VIOLET HUD** design system for **RADICAL-WM** — a dense, monochromatic-violet
"cockpit/HUD" AwesomeWM desktop. Hierarchy comes from **luminosity and opacity**, never from
different hues. There is **zero orange/teal/blue** as accent.

Key files:
- `README.md` — full context, CONTENT FUNDAMENTALS, VISUAL FOUNDATIONS, ICONOGRAPHY, file index.
- `colors_and_type.css` — all tokens (violet ramp, backgrounds, text, lines/bevel, data series,
  status), type roles, the `.hud-panel` chrome CSS, and `@font-face` for both faces.
- `assets/icons/*.svg` — the 41 multi-tone VIOLET HUD icons (source of truth — prefer over any
  glyph set; recolor only by state).
- `assets/imagem_de_referencia.png` — the original blue rice this HUD recreates in violet.
- `fonts/Xirod.otf` — the brand display face (wordmark/logotype ONLY; data stays monospaced).
- `preview/*.html` — design-system specimen cards.
- `ui_kits/radical-hud/` — interactive recreation of the HUD desktop + reusable JSX components.

If creating visual artifacts (slides, mocks, throwaway prototypes), copy assets out and create
static HTML files for the user to view — reuse `colors_and_type.css` and the icon set. If working
on production code (the AwesomeWM Lua config), read the rules here and in the repo's
`DESIGN_SYSTEM.md` to become an expert in designing with this brand.

If the user invokes this skill without any other guidance, ask them what they want to build or
design, ask some questions, and act as an expert designer who outputs HTML artifacts *or*
production code, depending on the need.
