local gears = require("gears")
local wibox = require("wibox")

local home = os.getenv("HOME")
local lain_image = home .. "/.config/yazi/lain.jpg"
local overlays = setmetatable({}, { __mode = "k" })

local function is_alacritty(c)
  local class = c.class
  return class == "Alacritty" or class == "alacritty"
end

local function should_show(c)
  return c.valid
    and is_alacritty(c)
    and not c.minimized
    and not c.fullscreen
    and c:isvisible()
end

local function new_overlay(c)
  local overlay = wibox({
    visible = false,
    ontop = false,
    bg = "#00000000",
    screen = c.screen,
  })

  if overlay.input_passthrough ~= nil then
    overlay.input_passthrough = true
  end

  overlay:setup {
    layout = wibox.layout.stack,
    {
      bg = "#160b2ecc",
      widget = wibox.container.background,
    },
    {
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
      {
        image = lain_image,
        resize = true,
        upscale = true,
        downscale = true,
        horizontal_fit_policy = "fit",
        vertical_fit_policy = "fit",
        widget = wibox.widget.imagebox,
      },
    },
  }

  overlays[c] = overlay
  return overlay
end

local function sync_overlay(c)
  if not c.valid then
    return
  end

  if not is_alacritty(c) then
    local overlay = overlays[c]
    if overlay then
      overlay.visible = false
    end
    return
  end

  local overlay = overlays[c] or new_overlay(c)
  local geo = c:geometry()

  overlay.screen = c.screen
  overlay.x = geo.x
  overlay.y = geo.y
  overlay.width = math.max(geo.width, 1)
  overlay.height = math.max(geo.height, 1)
  overlay.visible = should_show(c)

  if overlay.visible then
    c:raise()
  end
end

local function remove_overlay(c)
  local overlay = overlays[c]
  if not overlay then
    return
  end

  overlay.visible = false
  overlays[c] = nil
end

local function sync_all()
  for c, _ in pairs(overlays) do
    if c.valid then
      sync_overlay(c)
    else
      overlays[c] = nil
    end
  end
end

client.connect_signal("manage", sync_overlay)
client.connect_signal("property::class", sync_overlay)
client.connect_signal("property::geometry", sync_overlay)
client.connect_signal("property::screen", sync_overlay)
client.connect_signal("property::minimized", sync_overlay)
client.connect_signal("property::fullscreen", sync_overlay)
client.connect_signal("property::maximized", sync_overlay)
client.connect_signal("tagged", sync_overlay)
client.connect_signal("untagged", sync_overlay)
client.connect_signal("unmanage", remove_overlay)
tag.connect_signal("property::selected", sync_all)

gears.timer.delayed_call(function()
  for _, c in ipairs(client.get()) do
    sync_overlay(c)
  end
  sync_all()
end)
