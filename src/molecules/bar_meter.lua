------------------------------------------------------------------------------------------
-- src/molecules/bar_meter.lua — Labelled progress meter (VIOLET HUD BarMeter).            --
--                                                                                        --
-- Layout: a header line "LABEL ...... NN%" over a full-width progress bar.                --
--   LABEL — text_muted, UPPER, left.                                                      --
--   NN%   — right; text_bright normally, p.crit when hot.                                 --
--   bar   — v500 fill normally, p.crit fill when hot; dim violet track + thin HUD border. --
--                                                                                        --
-- "hot" := alert OR pct >= mt.pct_hot (the >=90 rule). No sampling here — the owner feeds  --
-- values via :set_value (presentational purity / storybook-safe).                          --
--                                                                                        --
-- :set_value(pct, alert) tonumber-guards pct FIRST: a nil/garbage stdout value keeps the   --
-- last reading instead of crashing (R4 shell-stdout math-crash backstop). Values are        --
-- clamped to 0..100 for display; the hot test uses the raw (post-tonumber) pct per spec.    --
--                                                                                        --
-- Returns the widget WITH methods + DIRECT refs to label/value/bar (no ids — R1).          --
--                                                                                        --
--   local bar_meter = require("src.molecules.bar_meter")                                  --
--   local m = bar_meter{ label = "MASTER", pct = 42 }                                     --
--   m:set_value(97)          -- hot (>= pct_hot): crit fill + crit text                   --
--   m:set_value(30, true)    -- forced alert: hot regardless of pct                       --
--   m:set_value(nil)         -- ignored: keeps last reading                               --
------------------------------------------------------------------------------------------

local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local txt   = require("src.atoms.txt")

local function build(args)
  args = args or {}

  local init_pct  = tonumber(args.pct) or 0
  local init_hot  = (args.alert and true or false) or init_pct >= mt.pct_hot
  local init_disp = math.max(0, math.min(100, init_pct))

  -- LABEL (muted, UPPER) + VALUE (%). Both markup-colored via txt (sole markup owner).
  local label_box = txt {
    role  = "label",
    text  = args.label,
    color = p.text_muted,
    upper = true,
  }
  local value_box = txt {
    role  = "bar",
    text  = string.format("%d%%", math.floor(init_disp + 0.5)),
    color = init_hot and p.crit or p.text_bright,
    align = "right",
  }

  -- Header line: LABEL ...... NN%  (empty align middle pins the value right).
  local header = wibox.widget {
    label_box,
    nil,
    value_box,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  -- Progress bar. No dedicated meter-thickness token exists; the 8px pad_panel value
  -- is reused as the bar height (a clean HUD meter). Rounded track + fill + thin border.
  local bar = wibox.widget {
    max_value          = 100,
    value              = init_disp,
    forced_height      = dpi(mt.pad_panel),
    color              = init_hot and p.crit or p.v500,
    background_color   = p.a(p.v500, p.alpha.chip_bg),
    border_width       = dpi(mt.border_panel),
    border_color       = p.a(p.v500, p.alpha.chip_border),
    shape              = gears.shape.rounded_bar,
    bar_shape          = gears.shape.rounded_bar,
    widget             = wibox.widget.progressbar,
  }

  local w = wibox.widget {
    header,
    bar,
    spacing = dpi(mt.row_gap),
    layout  = wibox.layout.fixed.vertical,
  }

  -- ── Update surface (mutates the SAME sub-widgets in place; no rebuild) ────────────
  function w:set_value(pct, alert)
    pct = tonumber(pct)
    if not pct then return end -- nil/garbage -> keep last reading (don't crash)
    local hot  = (alert and true or false) or pct >= mt.pct_hot
    local disp = math.max(0, math.min(100, pct))
    bar.value = disp
    bar.color = hot and p.crit or p.v500
    value_box:set_span(string.format("%d%%", math.floor(disp + 0.5)), hot and p.crit or p.text_bright)
  end

  -- Additive convenience (label rarely changes; keeps the markup-owner contract).
  function w:set_label(s)
    label_box:set_span(s, p.text_muted)
  end

  return w
end

return build
