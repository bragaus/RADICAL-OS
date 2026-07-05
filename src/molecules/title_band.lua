------------------------------------------------------------------------------------------
-- src/molecules/title_band.lua — Gradient section title band (VIOLET HUD).               --
--                                                                                        --
-- kit.css `.ctx__band`: a horizontal gradient strip (line_bright -> v950) carrying an      --
-- uppercase v50 heading. Shared by context_menu + tag_menu (+ kb_menu) as their section    --
-- header / title. Text is PLAIN (inherits the container's v50 fg — no markup, R2).         --
--                                                                                        --
--   :set_text(s)  update the heading in place (nil -> keep last, via atoms/txt).           --
--                                                                                        --
-- `font` is an OPTIONAL override (default ft.title = ExtraBold 11): context_menu builds     --
-- its band at ~1.5x, so it passes its own scaled Pango string. All other visual props are   --
-- tokens.                                                                                  --
--                                                                                        --
--   local title_band = require("src.molecules.title_band")                               --
--   local b = title_band{ text = "CLIENT", width = dpi(mt.panel_w_sm) }                    --
--   b:set_text("TAG · WEB3")                                                              --
------------------------------------------------------------------------------------------

local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local txt   = require("src.atoms.txt")

local function title_band(args)
  args = args or {}
  local height     = args.height or dpi(30)              -- kit .ctx__band 26/live 30; no token
  local width      = args.width                          -- nil -> stretch to container
  local grad_to    = width or dpi(mt.panel_w_sm)         -- gradient needs a fixed pixel reach
  local from_color = args.from or p.line_bright
  local to_color   = args.to or p.v950

  -- Direct ref (R1): the heading textbox, updated via :set_text.
  local label = txt { role = "title", text = args.text, valign = "center", upper = true }
  if args.font then label.font = args.font end

  local w = wibox.widget {
    {
      label,
      left   = dpi(mt.pad_header_x),
      right  = dpi(mt.pad_header_x),
      widget = wibox.container.margin,
    },
    forced_height = height,
    forced_width  = width,
    fg            = p.v50,   -- the plain heading inherits this
    bg            = gears.color {
      type  = "linear",
      from  = { 0, 0 }, to = { grad_to, 0 },
      stops = { { 0, from_color }, { 1, to_color } },
    },
    widget = wibox.container.background,
  }

  function w:set_text(s) label:set_text(s) end

  return w
end

return title_band
