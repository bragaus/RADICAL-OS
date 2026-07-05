-- src/theme/typography.lua
-- Typography roles as READY-TO-USE Pango strings (require as:
--   local ft = require("src.theme.typography")).
--
-- dpi policy: fonts are Pango POINT strings — NEVER wrap them in dpi().
--
-- Discipline (self-documenting): every DE-FACTO role DEFAULTS to the *current
-- live* string so token adoption is pixel-identical; the kit-spec value is a
-- one-line commented upgrade for a future deliberate "ratify" pass. Kit-spec
-- roles exist alongside for anything built fresh to spec. This inoculates
-- against the mistaken panel-title 14->11 shrink.
--
-- Requires nothing but the sanctioned `user_vars` global (read defensively).

local uf   = (user_vars and user_vars.font) or {}
local mono = uf.specify or "JetBrainsMono Nerd Font"
local disp = uf.display or "Xirod"

return {
  mono_family = mono, display_family = disp,

  -- ── KIT SPEC roles (colors_and_type.css --fs-*/--fw-*; 800->ExtraBold 700->Bold 500->Medium) ──
  title = mono..", ExtraBold 11",  label = mono..", Bold 10",  value = mono..", ExtraBold 12",
  body  = mono..", Medium 11",     bar   = mono..", Bold 11",  micro = mono..", Bold 9",

  -- ── DE-FACTO roles: DEFAULT = live string; kit spec noted for a future "ratify" pass ──
  panel_title = uf.extrabold or (mono..", ExtraBold 14"), -- LIVE ExtraBold 14 (panel.lua:49); kit spec 11
  cell        = mono..", 9",            -- table/list cells (usage/process/connections/ip/calendar); kit 10
  cell_bold   = mono..", Bold 9",       -- emphasized table/list cell; kit 10
  lozenge     = mono..", Bold 18",      -- control_center MONO (dockbar); ~200% upscale, live
  readout     = mono..", ExtraBold 20", -- MonitorBar big value (monitor_bar READOUT); kit spec 16
  mon_sub     = mono..", Bold 9",       -- MonitorBar sub-label (SUB), live
  mon_micro   = mono..", Bold 8",       -- MonitorBar footer/micro (MICRO); kit spec 9
  notif_title = mono..", ExtraBold 16", notif_body = mono..", Regular 12",

  -- Xirod: wordmark / MonitorBar brand labels ONLY, never data (DS §4). Live module label = 15.
  display = function(size) return disp.." "..tostring(size or 15) end,
}
