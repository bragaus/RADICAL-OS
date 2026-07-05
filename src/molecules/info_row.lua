------------------------------------------------------------------------------------------
-- src/molecules/info_row.lua — Key/value HUD row (VIOLET HUD §7.4.1).                     --
--                                                                                        --
-- ONE shared molecule replacing the four ad-hoc key/value rows:                          --
--   * "chip"   -> info_panel.create_info_row  (v500@chip_bg surface + border, radius bar) --
--   * "plain"  -> ip_panel.make_row           (bare row, fixed key width, value pinned)   --
--   * "swatch" -> protocols_donut.legend_row  (legend square + label + count)             --
--   * "rule"   -> world_clock row             (expanding label ... value, no surface)     --
--                                                                                        --
-- Presentational only: data arrives via constructor args + :set_* update methods; the     --
-- molecule never samples anything (storybook-safe). It returns the widget WITH its         --
-- methods and keeps DIRECT local refs to the sub-widgets (key/value/swatch) — it NEVER     --
-- queries ids back through a pre-built body (R1: get_children_by_id can't cross panel()).  --
--                                                                                        --
-- Coloring goes exclusively through atoms/txt :set_span (the sole markup owner) so the     --
-- "markup='' alongside text=" blanking crash is structurally impossible (R2).              --
--                                                                                        --
--   local info_row = require("src.molecules.info_row")                                    --
--   local r = info_row{ key = "IPv4", value = "--", variant = "plain", key_width = dpi(46) } --
--   r:set_value("192.168.0.2")                                                            --
--   r:set_value_color(p.crit)                                                             --
--   r:set_key("IPv6")                                                                     --
--   r:set_swatch(p.data2)   -- swatch variant only; no-op otherwise                       --
------------------------------------------------------------------------------------------

local wibox  = require("wibox")
local dpi    = require("beautiful.xresources").apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local txt    = require("src.atoms.txt")
local chip   = require("src.atoms.chip")
local swatch = require("src.atoms.swatch")

-- Per-variant text roles, picked to match each replaced consumer as closely as the
-- typography token set allows (see report): plain/swatch are exact; chip is ExtraBold
-- 11->12; "rule" adopts label/value (world_clock was live 14pt — a deliberate shrink,
-- Xephyr-verified when C8 rebuilds world_clock).
local ROLE = {
  plain  = { key = "cell",  value = "cell" },
  chip   = { key = "label", value = "value" },
  swatch = { key = "cell",  value = "cell_bold" },
  rule   = { key = "label", value = "value" },
}

local function build(args)
  args = args or {}
  local variant     = args.variant or "plain"
  local roles       = ROLE[variant] or ROLE.plain
  local value_color = args.value_color or p.text_bright

  -- Track the current value text so :set_value_color can recolor without a text arg
  -- (txt:set_span(nil, c) is a no-op by design — nil text keeps the last value).
  local cur_value = tostring(args.value or "--")

  -- KEY (left, muted, UPPER) — markup-colored via txt.
  local key_box = txt {
    role         = roles.key,
    text         = args.key,
    color        = p.text_muted,
    upper        = true,
    forced_width = args.key_width, -- pixels (caller dpi's); nil = auto width
  }

  -- VALUE (right, colored) — markup-colored; owns its box for life via :set_span.
  local value_box = txt {
    role  = roles.value,
    text  = cur_value,
    color = value_color,
    align = "right",
  }

  -- SWATCH (legend square) — swatch variant only.
  local sw
  local left
  if variant == "swatch" then
    sw = swatch { color = args.swatch_color or p.data1 }
    left = wibox.widget {
      { sw, valign = "center", widget = wibox.container.place },
      key_box,
      spacing = dpi(mt.gap),
      layout  = wibox.layout.fixed.horizontal,
    }
  else
    left = key_box
  end

  -- "LEFT ....... VALUE": align.horizontal with an empty middle expands the gap so the
  -- value pins to the right edge (the shared idiom of all four originals).
  local content = wibox.widget {
    left,
    nil,
    value_box,
    expand = "inside",
    layout = wibox.layout.align.horizontal,
  }

  local row
  if variant == "chip" then
    -- Chip surface owns its own bg/border/radius/padding; the content is forced to
    -- (row_h - 2*pad_row_y) so chip total height == row_h (matches info_panel: 18).
    content.forced_height = dpi(mt.row_h - 2 * mt.pad_row_y)
    row = chip {
      child  = content,
      pad_x  = dpi(mt.pad_header_x),
      pad_y  = dpi(mt.pad_row_y),
      radius = dpi(mt.radius_bar),
      -- bg / border default to v500@chip_bg / v500@chip_border (info_panel look).
    }
  else
    row = wibox.widget {
      content,
      forced_height = dpi(mt.row_h),
      bg            = p.transparent,
      widget        = wibox.container.background,
    }
  end

  -- ── Update surface (mutates the SAME textboxes in place; no rebuild) ──────────────
  function row:set_value(s)
    if s == nil then return end -- nil -> keep last value (never blanks the box)
    cur_value = tostring(s)
    value_box:set_span(cur_value, value_color)
  end

  function row:set_value_color(c)
    if not c then return end
    value_color = c
    value_box:set_span(cur_value, value_color)
  end

  function row:set_key(s)
    key_box:set_span(s, p.text_muted) -- s nil -> :set_span no-ops (keeps last)
  end

  function row:set_swatch(c)
    if sw then sw:set_color(c) end
  end

  return row
end

return build
