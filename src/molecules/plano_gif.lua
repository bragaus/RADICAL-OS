local awful = require("awful")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local gears = require("gears")
local gfs = require("gears.filesystem")
local wibox = require("wibox")

local M = {}

local gif_path = gfs.get_configuration_dir() .. "src/assets/logo.gif"
-- Cache PERSISTENTE (era /tmp, limpo a cada reboot → re-rodava convert no 1º boot).
-- Sufixo _v4 = invalidação manual: bump p/ _v5 se trocar logo.gif.
local cache_home = os.getenv("XDG_CACHE_HOME") or ((os.getenv("HOME") or "/tmp") .. "/.cache")
local frames_root = cache_home .. "/awesome/plano_gif_frames_v4"
local caches = {}

local DEFAULT_RADIUS = dpi(14)
local DEFAULT_FALLBACK_BG = "#00000000"

local function normalize_size(target_size)
  local size = tonumber(target_size) or dpi(400)
  return math.max(16, math.floor(size))
end

local function get_cache(target_size)
  local size = normalize_size(target_size)

  if caches[size] then
    return caches[size], size
  end

  local cache = {
    frames_dir = string.format("%s/%d/", frames_root, size),
    gif_surfaces = {},
    loading = false,
    loaded = false,
    waiting_widgets = {},
    load_timer = nil,
  }

  caches[size] = cache
  return cache, size
end

local function notify_waiters(cache)
  for _, widget in ipairs(cache.waiting_widgets) do
    widget:emit_signal("widget::redraw_needed")
  end
  cache.waiting_widgets = {}
end

local function load_surfaces_async(cache, paths)
  local index = 1
  local notified_first_frame = false

  if cache.load_timer then
    cache.load_timer:stop()
    cache.load_timer = nil
  end

  cache.load_timer = gears.timer {
    timeout = 0.001,
    autostart = true,
    call_now = false,
    callback = function()
      if index <= #paths then
        local surf = gears.surface.load_uncached(paths[index])
        if surf then
          cache.gif_surfaces[#cache.gif_surfaces + 1] = surf

          if not notified_first_frame then
            notified_first_frame = true
            notify_waiters(cache)
          end
        end
        index = index + 1
      else
        cache.load_timer:stop()
        cache.load_timer = nil
        cache.loading = false
        cache.loaded = #cache.gif_surfaces > 0
        notify_waiters(cache)
      end
    end
  }
end

local function load_gif_frames(target_size)
  local cache, size = get_cache(target_size)

  if cache.loading or cache.loaded then
    return cache, size
  end

  cache.loading = true

  local check_cmd = string.format("ls %s*.png 2>/dev/null | wc -l", cache.frames_dir)

  awful.spawn.easy_async_with_shell(check_cmd, function(stdout)
    local cached = tonumber(stdout:match("%d+")) or 0

    if cached > 0 then
      local paths = {}
      for i = 0, cached - 1 do
        paths[i + 1] = string.format("%sframe_%04d.png", cache.frames_dir, i)
      end
      load_surfaces_async(cache, paths)
    else
        local extract_cmd = string.format(
          "mkdir -p %s && convert %q -coalesce -alpha set -background none -fuzz 8%% -trim +repage -resize %dx%d -gravity center -extent %dx%d %sframe_%%04d.png 2>/dev/null; ls %s*.png 2>/dev/null | wc -l",
          cache.frames_dir, gif_path, size, size, size, size, cache.frames_dir, cache.frames_dir
        )

      awful.spawn.easy_async_with_shell(extract_cmd, function(out)
        local count = tonumber(out:match("%d+")) or 0

        if count > 0 then
          local paths = {}
          for i = 0, count - 1 do
            paths[i + 1] = string.format("%sframe_%04d.png", cache.frames_dir, i)
          end
          load_surfaces_async(cache, paths)
        else
          local surf = gears.surface.load_uncached(gif_path)
          if surf then
            cache.gif_surfaces = { surf }
            cache.loaded = true
          end
          cache.loading = false
          notify_waiters(cache)
        end
      end)
    end
  end)

  return cache, size
end

function M.preload(target_size)
  load_gif_frames(target_size)
end

function M.new(args)
  args = args or {}

  local radius = args.radius or DEFAULT_RADIUS
  local fallback_bg = args.fallback_bg or DEFAULT_FALLBACK_BG
  local anim_interval = args.anim_interval or 0.06
  local content_scale = args.content_scale or 1
  local shape = args.shape
  local cache, preload_size = get_cache(args.preload_size or dpi(400))

  local current_surface = nil
  local current_frame = 1
  local frame_timer = nil

  local widget = wibox.widget.base.make_widget()

  function widget:fit(_, width, height)
    return width, height
  end

  function widget:draw(_, cr, width, height)
    if shape then
      shape(cr, width, height)
    else
      gears.shape.rounded_rect(cr, width, height, radius)
    end

    cr:clip()

    if current_surface then
      local iw = current_surface:get_width()
      local ih = current_surface:get_height()
      local scale = math.max(width / iw, height / ih) * content_scale
      local ox = (width - iw * scale) / 2
      local oy = (height - ih * scale) / 2

      cr:save()
      cr:translate(ox, oy)
      cr:scale(scale, scale)
      cr:set_source_surface(current_surface, 0, 0)
      cr:paint()
      cr:restore()
    else
      local r, g, b, a = gears.color.parse_color(fallback_bg)
      cr:set_source_rgba(r, g, b, a)
      cr:paint()
    end
  end

  local function start_animation()
    if frame_timer or #cache.gif_surfaces == 0 then
      return
    end
    if widget._paused then return end -- honor pause() requested before the first start

    frame_timer = gears.timer {
      timeout = anim_interval,
      autostart = true,
      call_now = true,
      callback = function()
        if #cache.gif_surfaces == 0 then
          return
        end

        current_surface = cache.gif_surfaces[current_frame]
        current_frame = (current_frame % #cache.gif_surfaces) + 1
        widget:emit_signal("widget::redraw_needed")
      end
    }

    widget._gif_timer = frame_timer
  end

  if cache.loaded and #cache.gif_surfaces > 0 then
    current_surface = cache.gif_surfaces[1]
    start_animation()
  else
    table.insert(cache.waiting_widgets, widget)
    cache = load_gif_frames(preload_size) or cache

    local wait_timer
    wait_timer = gears.timer {
      timeout = 0.05,
      autostart = true,
      call_now = false,
      callback = function()
        if #cache.gif_surfaces > 0 then
          current_surface = cache.gif_surfaces[1]
          start_animation()
          widget:emit_signal("widget::redraw_needed")
          wait_timer:stop()
        elseif not cache.loading then
          wait_timer:stop()
        end
      end
    }

    widget._wait_timer = wait_timer
  end

  -- ── ADDITIVE (C11): pause/resume the frame animation without touching the
  -- shared frame cache, preload order, or the convert contract. Lets a host
  -- (e.g. status_dock) stop the GIF while hidden and resume on show — no
  -- always-on poller, no tokens, no IO. Idempotent; guards gears.timer's
  -- start/stop asserts via the .started flag.
  function widget:pause()
    self._paused = true
    if frame_timer and frame_timer.started then
      frame_timer:stop()
    end
  end

  function widget:resume()
    self._paused = false
    if frame_timer then
      if not frame_timer.started then frame_timer:start() end
    else
      start_animation() -- frames may have arrived while paused before the first start
    end
  end

  return widget
end

return M
