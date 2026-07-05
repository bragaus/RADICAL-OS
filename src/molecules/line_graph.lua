------------------------------------------------------------------------------------------
-- src/molecules/line_graph.lua — ONE line/area renderer (VIOLET HUD §7.4.3 + §7.3.1)        --
--                                                                                        --
-- A single pure cairo renderer that serves BOTH kit graphs:                                --
--   * charts.jsx  LineGraph  — grid + area fill + halo + 2px stroke (3-pass), inset "well" --
--                              with an accent border, dynamic scale with a `floor`.        --
--   * monitorbar.jsx MonGraph — vertical `gradient_fill`, additive `blend="screen"` around --
--                               each series group, `fixed100` (0..100 %) scale.            --
-- Both share the same 3-pass core (area -> halo -> stroke) and the same midpoint-Bézier    --
-- smoothing, so this replaces net_graph_panel.make_graph AND monitor_bar.make_area_graph.  --
--                                                                                        --
-- PRESENTATIONAL / PURE: it spawns nothing and samples nothing. The OWNER pushes values    --
-- (already in %, KB/s, whatever) via :push(i,v) / :set_data(i,vals); every value is still   --
-- tonumber()-guarded here defensively (nil -> 0, matching the two live implementations).   --
-- Both mutators emit "widget::redraw_needed". Returns a base widget with those methods +    --
-- direct closure refs to its series arrays (never queries ids — R1).                       --
--                                                                                        --
-- SCALING (not 0..1-normalized — matches the live code it replaces):                       --
--   fixed100=true  -> peak = 100 (series are percentages).                                 --
--   fixed100=false -> peak = max(floor, max(values)) (dynamic; `floor` guards low noise).  --
--                                                                                        --
-- Colors are ALWAYS palette tokens (series[i].color, p.grid, p.inset). The alpha/width     --
-- multipliers below are intrinsic chart-drawing params (no DS token exists for them; the   --
-- pixel-diff acceptance gate excludes graph regions).                                      --
--                                                                                        --
-- Usage:                                                                                   --
--   local line_graph = require("src.molecules.line_graph")                                 --
--   -- net_graph style (dynamic scale, well, grid, halo):                                  --
--   local g = line_graph{ series = {{ color = p.data4, data = zeros(30) }}, floor = 64 }    --
--   g:push(1, kbps)                                                                        --
--   -- monitor_bar style (fills its box, gradient area, screen blend, %):                  --
--   local mg = line_graph{ series = {{color=p.data1},{color=p.data4}},                     --
--                          fill = true, gradient_fill = true, blend = "screen",             --
--                          fixed100 = true, grid = false, halo = false, well = false }      --
------------------------------------------------------------------------------------------

local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

-- cairo operators for the additive "screen" blend (MonGraph). lgi is the same low-level
-- rendering substrate gears/wibox sit on; guarded so blend gracefully no-ops if absent.
local OP_SCREEN, OP_OVER
do
  local ok, lgi = pcall(require, "lgi")
  if ok and lgi and lgi.cairo and lgi.cairo.Operator then
    OP_SCREEN = lgi.cairo.Operator.SCREEN
    OP_OVER   = lgi.cairo.Operator.OVER
  end
end

-- Intrinsic chart geometry / alpha (NOT design-system tokens — see header). --------------
local PAD    = 4    -- plot inset when `well` (kit LineGraph pad); dpi() at use-site
local WELL_R = 6    -- well corner radius
local HALO_W = 6    -- translucent halo stroke width
local MAIN_W = 2    -- main line stroke width
local MAIN_A = 0.95 -- main line alpha
-- grid alpha multipliers (even rows stronger; verticals fainter, on the accent color)
local GRID_A_STRONG, GRID_A_FAINT   = 0.22, 0.12
local VGRID_A_STRONG, VGRID_A_FAINT = 0.09, 0.04
-- gradient_fill vertical stops (MonGraph): top opaque -> mid -> near-transparent bottom
local GRAD_TOP, GRAD_MID, GRAD_BOT, GRAD_MID_STOP = 0.6, 0.16, 0.02, 0.62

-- palette colors decomposed once (static tokens)
local GRID_R, GRID_G, GRID_B    = p.rgb(p.grid)
local INSET_R, INSET_G, INSET_B = p.rgb(p.inset)

local function line_graph(args)
  args = args or {}

  local grid          = args.grid ~= false
  local halo          = args.halo ~= false
  local well          = args.well ~= false
  local gradient_fill = args.gradient_fill and true or false
  local blend         = args.blend
  local fixed100      = args.fixed100 and true or false
  local floor         = args.floor or mt.net_floor_kbps
  local fill          = args.fill and true or false

  -- fit sizing: caller width or available; height = explicit / graph_h / (fill -> available)
  local fw = args.width
  local fh = args.height
  if fh == nil and not fill then fh = dpi(mt.graph_h) end

  -- Series: {{ color, data = {..} }, ...}. data optional (owner seeds/pushes).
  local series = {}
  for i, sdef in ipairs(args.series or {}) do
    local d = {}
    if type(sdef.data) == "table" then
      for k = 1, #sdef.data do d[k] = tonumber(sdef.data[k]) or 0 end
    end
    series[i] = { color = sdef.color or p.v500, data = d }
  end

  local w = wibox.widget.base.make_widget()

  function w:fit(_, avail_w, avail_h)
    local rw = fw or avail_w
    local rh = fill and avail_h or (fh or avail_h)
    return rw, rh
  end

  function w:draw(_, cr, width, height)
    local pad = dpi(PAD)
    local x, y, pw, ph
    if well then
      x, y = pad, pad
      pw = math.max(1, width - pad * 2)
      ph = math.max(1, height - pad * 2)
      -- inset well + accent border (net_graph look)
      gears.shape.rounded_rect(cr, width, height, dpi(WELL_R))
      cr:set_source_rgba(INSET_R, INSET_G, INSET_B, p.alpha.well)
      cr:fill()
      if series[1] then
        local wr, wg, wb = p.rgb(series[1].color)
        gears.shape.rounded_rect(cr, width, height, dpi(WELL_R))
        cr:set_source_rgba(wr, wg, wb, p.alpha.well_border)
        cr:set_line_width(dpi(1))
        cr:stroke()
      end
    else
      x  = 0
      pw = math.max(1, width)
      y  = dpi(2)
      ph = math.max(1, height - dpi(4))
    end

    -- grid: horizontal every 25% (on p.grid), vertical every ~16% (on the accent)
    if grid then
      for i = 0, 4 do
        local gy = y + (ph / 4) * i
        cr:set_source_rgba(GRID_R, GRID_G, GRID_B, (i % 2 == 0) and GRID_A_STRONG or GRID_A_FAINT)
        cr:set_line_width(dpi(1))
        cr:move_to(x, gy); cr:line_to(x + pw, gy); cr:stroke()
      end
      local ar, ag, ab = 0.6, 0.4, 0.9
      if series[1] then ar, ag, ab = p.rgb(series[1].color) end
      for i = 0, 6 do
        local gx = x + (pw / 6) * i
        cr:set_source_rgba(ar, ag, ab, (i % 2 == 0) and VGRID_A_STRONG or VGRID_A_FAINT)
        cr:set_line_width(dpi(1))
        cr:move_to(gx, y); cr:line_to(gx, y + ph); cr:stroke()
      end
    end

    -- series (front-to-back order as passed) ----------------------------------------------
    for si = 1, #series do
      local s     = series[si]
      local vals  = s.data
      local count = #vals
      if count >= 2 then
        local sr, sg, sb = p.rgb(s.color)

        -- scale
        local peak
        if fixed100 then
          peak = 100
        else
          peak = floor
          for _, v in ipairs(vals) do
            local n = tonumber(v) or 0
            if n > peak then peak = n end
          end
        end
        if peak <= 0 then peak = 1 end

        local step = pw / math.max(count - 1, 1)
        local pts = {}
        for i = 1, count do
          local n = tonumber(vals[i]) or 0
          local frac = n / peak
          if frac < 0 then frac = 0 elseif frac > 1 then frac = 1 end
          pts[i] = { x = x + (i - 1) * step, y = y + ph - (ph * frac) }
        end

        -- midpoint-Bézier smoothing (same as the two live graphs)
        local function trace()
          cr:move_to(pts[1].x, pts[1].y)
          for i = 2, count do
            local prev, cur = pts[i - 1], pts[i]
            local mx = (prev.x + cur.x) / 2
            cr:curve_to(mx, prev.y, mx, cur.y, cur.x, cur.y)
          end
        end

        if blend == "screen" and OP_SCREEN then cr:set_operator(OP_SCREEN) end

        -- pass 1: area fill (flat, or vertical gradient for MonGraph)
        cr:new_path()
        cr:move_to(pts[1].x, y + ph)
        cr:line_to(pts[1].x, pts[1].y)
        trace()
        cr:line_to(pts[count].x, y + ph)
        cr:close_path()
        if gradient_fill then
          cr:set_source(gears.color({
            type = "linear",
            from = { pts[1].x, y },
            to   = { pts[1].x, y + ph },
            stops = {
              { 0,             p.a(s.color, GRAD_TOP) },
              { GRAD_MID_STOP, p.a(s.color, GRAD_MID) },
              { 1,             p.a(s.color, GRAD_BOT) },
            },
          }))
          cr:fill()
        else
          cr:set_source_rgba(sr, sg, sb, p.alpha.graph_area)
          cr:fill()
        end

        -- pass 2: halo (thick translucent stroke under the line)
        if halo then
          cr:new_path(); trace()
          cr:set_source_rgba(sr, sg, sb, p.alpha.graph_halo)
          cr:set_line_width(dpi(HALO_W))
          cr:stroke()
        end

        -- pass 3: main line
        cr:new_path(); trace()
        cr:set_source_rgba(sr, sg, sb, MAIN_A)
        cr:set_line_width(dpi(MAIN_W))
        cr:stroke()

        if blend == "screen" and OP_OVER then cr:set_operator(OP_OVER) end
      end
    end
  end

  -- :push(i, v) — ring-append (drop oldest, append newest) into series i. Owner seeds the
  -- desired depth; nil coerces to 0 (matches live push). Emits a redraw.
  function w:push(i, v)
    local s = series[i]
    if not s then return end
    local d = s.data
    table.remove(d, 1)
    d[#d + 1] = tonumber(v) or 0
    self:emit_signal("widget::redraw_needed")
  end

  -- :set_data(i, vals) — replace series i's history (each value tonumber-guarded).
  function w:set_data(i, vals)
    local s = series[i]
    if not s then return end
    local d = {}
    if type(vals) == "table" then
      for k = 1, #vals do d[k] = tonumber(vals[k]) or 0 end
    end
    s.data = d
    self:emit_signal("widget::redraw_needed")
  end

  return w
end

return line_graph
