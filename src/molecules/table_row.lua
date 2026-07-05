------------------------------------------------------------------------------------------
-- src/molecules/table_row.lua — One fixed-column table row (VIOLET HUD TableRow/connrow). --
--                                                                                        --
-- Replaces the ad-hoc per-cell builders in usage_panel / process_panel / apps_panel and    --
-- connections_panel.make_row. A row is N cells laid out left-to-right, each cell described  --
-- by a {text, w, align, color} tuple:                                                      --
--   text  — initial cell text ("" for a blank pool row).                                   --
--   w     — column width in PIXELS (caller applies dpi). nil => the FLEXIBLE column: it     --
--           expands to fill and ellipsizes (connections' peer column). At most one flex     --
--           cell (the first width-less one); rigid cells before/after it pin left/right.    --
--   align — "left" (default) | "right" | "center".                                         --
--   color — cell fg; defaults to text_muted for a header, text_bright for a data row.       --
--                                                                                        --
-- header=true -> muted defaults, shorter (row_header_h), no hover.                          --
-- on_kill      -> a trailing atoms/kill_btn (SIGTERM hit-target); semantics stay in the     --
--                 caller's callback (c:kill() / awful.spawn{"kill",pid} — never os.execute). --
-- hover=true   -> whole-row highlight to panel_hi via the sanctioned Hover_signal global.    --
--                                                                                        --
-- :set_cells(new_cells) mutates the EXISTING cell textboxes IN PLACE — no widget rebuild.    --
-- Present cells update text (+ color/align/width); trailing absent cells are blanked. Every  --
-- cell renders through atoms/txt :set_span (the sole markup owner) so recoloring per update   --
-- (e.g. connections state colors) never mixes markup with .text (R2). Direct refs to the     --
-- cell boxes are held in the closure — ids are never queried back (R1).                      --
--                                                                                        --
--   local table_row = require("src.molecules.table_row")                                  --
--   local hdr = table_row{ header = true, cells = {{"", dpi(34)},{"GHz", dpi(58),"right"}} } --
--   local row = table_row{ cells = {{"", dpi(34)},{"", dpi(58),"right"}}, hover = true }     --
--   row:set_cells({ {"C1"}, {"3.40", nil, nil, p.text_bright} })                            --
--   row:set_cells({})   -- clears every cell + drops any latched hover bg (pool recycle)     --
------------------------------------------------------------------------------------------

local wibox    = require("wibox")
local dpi      = require("beautiful.xresources").apply_dpi
local p        = require("src.theme.palette")
local mt       = require("src.theme.metrics")
local txt      = require("src.atoms.txt")
local kill_btn = require("src.atoms.kill_btn")

local function build(args)
  args = args or {}
  local is_header     = args.header and true or false
  local cells_spec    = args.cells or {}
  local default_color = is_header and p.text_muted or p.text_bright
  local CELL_SPACING  = dpi(mt.row_gap)

  -- Build one cell textbox per tuple; remember the first width-less (flexible) cell.
  local boxes    = {} -- ordered DIRECT refs to the cell textboxes
  local flex_idx = nil
  for i, c in ipairs(cells_spec) do
    local color = c[4] or default_color
    local box = txt {
      role         = "cell",
      text         = c[1],
      color        = color,
      align        = c[3] or "left",
      forced_width = c[2], -- pixels (caller dpi's); nil = flexible column
    }
    box._cell_default_color = color
    boxes[i] = box
    if c[2] == nil and flex_idx == nil then
      flex_idx = i
    end
  end

  -- Trailing kill hit-target (only when the caller wants one).
  local kbtn
  if args.on_kill ~= nil then
    kbtn = kill_btn { on_kill = args.on_kill }
  end

  -- Layout: all-rigid -> a plain left-packed fixed row; a flex cell present -> partition
  -- into (rigid-before | flex | rigid-after+kill) via align.horizontal (middle expands).
  local content
  if flex_idx then
    local before = wibox.layout.fixed.horizontal()
    before.spacing = CELL_SPACING
    for i = 1, flex_idx - 1 do before:add(boxes[i]) end

    local after = wibox.layout.fixed.horizontal()
    after.spacing = CELL_SPACING
    for i = flex_idx + 1, #boxes do after:add(boxes[i]) end
    if kbtn then after:add(kbtn) end

    content = wibox.widget {
      before,
      boxes[flex_idx],
      after,
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    }
  else
    content = wibox.layout.fixed.horizontal()
    content.spacing = CELL_SPACING
    for i = 1, #boxes do content:add(boxes[i]) end
    if kbtn then content:add(kbtn) end
  end

  local row = wibox.widget {
    content,
    forced_height = is_header and dpi(mt.row_header_h) or dpi(mt.row_h),
    bg            = p.transparent,
    widget        = wibox.container.background,
  }

  -- Whole-row hover highlight (data rows only). Wired ONCE at construction — never inside
  -- a watch/timer callback (R7). Hover_signal is a sanctioned global; guarded for storybook.
  if args.hover and not is_header and Hover_signal then
    Hover_signal(row, p.panel_hi, nil)
  end

  -- ── Update surface: mutate the SAME cell textboxes in place (no rebuild) ──────────
  function row:set_cells(new_cells)
    new_cells = new_cells or {}
    for i, box in ipairs(boxes) do
      local c = new_cells[i]
      if c then
        if c[3] then box.align = c[3] end               -- optional in-place realign
        if c[2] ~= nil then box.forced_width = c[2] end  -- optional in-place rewidth
        box:set_span(tostring(c[1] or ""), c[4] or box._cell_default_color)
      else
        box:set_span("", box._cell_default_color)        -- blank trailing unused cell
      end
    end
    if #new_cells == 0 then
      self.bg = p.transparent -- pool recycle: drop any hover bg latched under the cursor
    end
  end

  -- Rebind the kill target when a pooled row is reused for a different process/window.
  function row:set_on_kill(fn)
    if kbtn then kbtn:set_on_kill(fn) end
  end

  return row
end

return build
