------------------------------------------------------------------------------------------
-- src/molecules/scroll_list.lua — Generic ROW-POOL scroll engine (VIOLET HUD §7.4.7/§7.4.8) --
--                                                                                        --
-- The one scrolling primitive that replaces the per-panel scroll assemblies (the verbatim  --
-- connections_panel / process_panel `make_scrollbar` + window logic). A fixed window of    --
-- `visible` reusable rows of fixed height — the widget NEVER grows. The full item list is  --
-- held internally; the mouse wheel (buttons 4/5) slides a 0-based `offset` and re-renders   --
-- ONLY the visible slice into the pooled rows. A thin rail (track + v500 thumb) on the      --
-- right shows position/proportion and is shown ONLY when #items > visible.                 --
--                                                                                        --
-- PRESENTATIONAL: the row look is 100% the caller's. `make_row()` builds one reusable row  --
-- widget; `set_row(row, item_or_nil)` populates it (item) or clears+hides it (nil). This   --
-- molecule spawns nothing and parses nothing — a storybook mount with a mock item list     --
-- renders with no backend (R-purity). Returns the widget WITH :set_data/:scroll METHODS +  --
-- keeps direct local refs to every pooled row / the rail (never queries ids — R1).         --
--                                                                                        --
-- Usage:                                                                                   --
--   local scroll_list = require("src.molecules.scroll_list")                               --
--   local sl = scroll_list{                                                                --
--     header    = header_row,             -- optional; sits above the pool, never scrolls   --
--     empty_text = "NO CONNECTIONS",                                                        --
--     make_row  = function() return my_row_widget() end,                                   --
--     set_row   = function(row, item) --[[ populate or clear if item==nil ]] end,           --
--   }                                                                                       --
--   sl:set_data(items)   -- keeps the current offset (re-clamped to the new total)          --
--   sl:scroll(1)         -- programmatic scroll (wheel 4/5 wired internally)                --
------------------------------------------------------------------------------------------

local gears = require("gears")
local wibox = require("wibox")
local awful = require("awful")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local txt   = require("src.atoms.txt")

local function scroll_list(args)
  args = args or {}

  local VISIBLE = args.visible or mt.visible_rows
  local ROW_H   = dpi(args.row_height or mt.row_h)
  local ROW_GAP = dpi(args.spacing or mt.row_gap)
  local GUTTER  = dpi(mt.gutter)
  local SB_W    = dpi(mt.sb_w)
  local AREA_H  = VISIBLE * ROW_H + (VISIBLE - 1) * ROW_GAP -- fixed row-area height

  local make_row = args.make_row or function()
    return wibox.widget { forced_height = ROW_H, widget = wibox.container.background }
  end
  local set_row = args.set_row or function() end

  -- Rail (track + thumb). Thumb height % = max(visible/total*100, mt.thumb_min_pct)%.
  local function make_scrollbar()
    local sb = wibox.widget.base.make_widget()
    sb._total, sb._offset, sb._visible = 0, 0, VISIBLE

    function sb:fit(_, _, height) return SB_W, height end

    function sb:draw(_, cr, width, height)
      cr:set_source(gears.color(p.a(p.line_base, p.alpha.rail)))
      gears.shape.rounded_bar(cr, width, height)
      cr:fill()
      if self._total <= self._visible then return end
      local thumb_frac = math.max(self._visible / self._total, mt.thumb_min_pct / 100)
      local thumb_h    = height * thumb_frac
      local max_off    = self._total - self._visible
      local t          = max_off > 0 and (self._offset / max_off) or 0
      local y          = t * (height - thumb_h)
      cr:set_source(gears.color(p.v500))
      cr:translate(0, y)
      gears.shape.rounded_bar(cr, width, thumb_h)
      cr:fill()
    end

    function sb:update(total, offset, visible)
      self._total, self._offset, self._visible = total, offset, visible
      self:emit_signal("widget::redraw_needed")
    end

    return sb
  end

  -- Pool of reusable rows.
  local rows = {}
  local list = wibox.layout.fixed.vertical()
  list.spacing = ROW_GAP
  for i = 1, VISIBLE do
    rows[i] = make_row()
    list:add(rows[i])
  end

  local scrollbar = make_scrollbar()

  -- Scroll state: full item list + window offset.
  local data   = {}
  local offset = 0
  local function max_offset() return math.max(0, #data - VISIBLE) end

  -- Empty-state label filling the fixed area (centered faint uppercase).
  local empty_widget = wibox.widget {
    {
      txt.empty(args.empty_text or "NO DATA"),
      valign = "center",
      halign = "center",
      widget = wibox.container.place,
    },
    forced_height = AREA_H,
    widget        = wibox.container.background,
  }

  -- Row area: fixed height. List (with a right gutter) + rail overlaid in the gutter.
  local list_area = wibox.widget {
    {
      { list, right = GUTTER, widget = wibox.container.margin },
      {
        nil, nil,
        { scrollbar, right = (GUTTER - SB_W) / 2, widget = wibox.container.margin },
        layout = wibox.layout.align.horizontal,
      },
      layout = wibox.layout.stack,
    },
    forced_height = AREA_H,
    bg            = p.transparent,
    widget        = wibox.container.background,
  }

  -- Body container that swaps between the row area and the empty label.
  local body = wibox.widget { layout = wibox.layout.fixed.vertical }
  local showing_empty = nil
  local function show_empty()
    if showing_empty ~= true then
      body:reset(); body:add(empty_widget); showing_empty = true
    end
  end
  local function show_list()
    if showing_empty ~= false then
      body:reset(); body:add(list_area); showing_empty = false
    end
  end

  -- Render only the VISIBLE items from `offset` into the pooled rows.
  local function render_window()
    if offset > max_offset() then offset = max_offset() end
    if offset < 0 then offset = 0 end
    if #data == 0 then
      show_empty()
      scrollbar:update(0, 0, VISIBLE)
      scrollbar.visible = false
      return
    end
    show_list()
    for i = 1, VISIBLE do
      set_row(rows[i], data[offset + i]) -- nil past the end -> caller clears the row
    end
    scrollbar:update(#data, offset, VISIBLE)
    scrollbar.visible = (#data > VISIBLE) -- rail only when it overflows
  end

  -- Slide the window (delta in rows) and re-render.
  local function scroll(delta)
    local new_off = offset + delta
    if new_off < 0 then new_off = 0 end
    if new_off > max_offset() then new_off = max_offset() end
    if new_off ~= offset then
      offset = new_off
      render_window()
    end
  end

  -- Wheel over the row area slides the window (1 row per notch).
  list_area:buttons(awful.util.table.join(
    awful.button({}, 4, function() scroll(-1) end),
    awful.button({}, 5, function() scroll(1) end)
  ))

  -- Root: [header?] + swap-body. Header never scrolls, always visible.
  local root = wibox.widget { layout = wibox.layout.fixed.vertical }
  if args.header then root:add(args.header) end
  root:add(body)

  render_window() -- coherent first frame (empty) before any :set_data

  -- :set_data(items) — replace the item list; keep the current offset (re-clamped).
  function root:set_data(items)
    data = items or {}
    render_window()
  end

  -- :scroll(delta) — programmatic scroll (wheel is wired internally).
  function root:scroll(delta) scroll(tonumber(delta) or 0) end

  return root
end

return scroll_list
