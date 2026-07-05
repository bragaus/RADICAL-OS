------------------------------------------------------------------------------------------
-- src/molecules/hud_slider.lua — Themed horizontal slider (VIOLET HUD).                   --
--                                                                                        --
-- Thin wrapper over wibox.widget.slider with the HUD look (inset track, gradient fill,    --
-- v500 circle handle) and — critically — a `syncing` guard baked into :set_value so a      --
-- PROGRAMMATIC set never re-fires on_change. This kills the classic feedback loop where    --
-- polling the backend (pactl/brightness) set the slider, which fired property::value,      --
-- which re-ran the setter, which re-polled...                                             --
--                                                                                        --
--   * on_change(v)         fires on user drags (via the native :set_value the drag calls).  --
--   * :set_value_silent(v) tonumber + nil-guard; sets value WITHOUT firing on_change.       --
--   * :set_on_change(fn)   rebind the handler (pooled reuse).                                --
--                                                                                        --
-- Size variant (volume_controller): pass track_h = dpi(5), handle_w = dpi(15).             --
-- Presentational only — never spawns/polls (the owning organism drives it).               --
--                                                                                        --
--   local hud_slider = require("src.molecules.hud_slider")                               --
--   local s = hud_slider{ span_w = dpi(232), on_change = function(v) set_volume(v) end }   --
--   s:set_value_silent(57)   -- from the poller; on_change stays silent                     --
------------------------------------------------------------------------------------------

local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

local function hud_slider(args)
  args = args or {}
  local track_h   = args.track_h or dpi(8)      -- OSD track (kit .bm__track); no metric token
  local handle_w  = args.handle_w or dpi(10)    -- size variant passes dpi(15)
  local maximum   = args.max or 100
  local span_w    = args.span_w or dpi(mt.osd_w) -- gradient reach (device px)
  local on_change = args.on_change

  -- fill: "gradient" (default) => v700 -> v500 across span_w; else a solid colour token.
  local active_color
  if args.fill == nil or args.fill == "gradient" then
    active_color = {
      type  = "linear",
      from  = { 0, 0 }, to = { span_w, 0 },
      stops = { { 0, p.v700 }, { 1, p.v500 } },
    }
  else
    active_color = args.fill
  end

  local slider = wibox.widget {
    bar_shape           = gears.shape.rounded_bar,
    bar_height          = track_h,
    bar_color           = p.inset,
    bar_active_color    = active_color,
    handle_color        = p.v500,
    handle_shape        = gears.shape.circle,
    handle_width        = handle_w,
    handle_border_color = p.line_bright,
    maximum             = maximum,
    widget              = wibox.widget.slider,
  }

  -- syncing guard: true only while a SILENT programmatic set is in flight.
  local syncing = false

  -- property::value fires on_change on user DRAGS (wibox's drag handler calls the native
  -- public :set_value), but is swallowed during :set_value_silent so poller write-backs
  -- never re-fire on_change (the pactl/brightness feedback loop). The public :set_value is
  -- left NATIVE on purpose — overriding it would ALSO swallow drags and kill the slider.
  slider:connect_signal("property::value", function()
    if syncing then return end
    if on_change then on_change(slider.value) end
  end)

  -- Silent setter for pollers: set the value WITHOUT firing on_change. nil-guarded.
  local raw_set_value = slider.set_value
  function slider:set_value_silent(v)
    v = tonumber(v)
    if v == nil then return end         -- keep the last value, never crash
    syncing = true
    raw_set_value(self, v)              -- emits property::value synchronously -> swallowed
    syncing = false
  end

  function slider:set_on_change(fn) on_change = fn end

  return slider
end

return hud_slider
