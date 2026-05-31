--------------------------------------------------
--  ██████╗██████╗ ██╗   ██╗██╗     ██╗ █████╗  --
-- ██╔════╝██╔══██╗╚██╗ ██╔╝██║     ██║██╔══██╗ --
-- ██║     ██████╔╝ ╚████╔╝ ██║     ██║███████║ --
-- ██║     ██╔══██╗  ╚██╔╝  ██║     ██║██╔══██║ --
-- ╚██████╗██║  ██║   ██║   ███████╗██║██║  ██║ --
--  ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═╝╚═╝  ╚═╝ --
--------------------------------------------------
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")

Theme_path = awful.util.getdir("config") .. "/src/theme/"
Theme = {}

dofile(Theme_path .. "theme_variables.lua")

Theme.awesome_icon = Theme_path .. "../assets/icons/ArchLogo.png"
Theme.awesome_subicon = Theme_path .. "../assets/icons/ArchLogo.png"

-- Wallpaper
beautiful.wallpaper = user_vars.wallpaper
local fallback_bg = "#1a0d2e"
local ok_err, err_mod = pcall(require, "src.core.error_handling")
local function paint_fallback(s, reason)
  if reason then
    if ok_err and err_mod and err_mod.notify then
      err_mod.notify("Wallpaper falhou", tostring(reason))
    else
      io.stderr:write("[theme] wallpaper fallback: " .. tostring(reason) .. "\n")
    end
  end
  local ok = pcall(gears.wallpaper.set, fallback_bg, s)
  if not ok then pcall(gears.wallpaper.set, fallback_bg) end
end
screen.connect_signal(
  'request::wallpaper',
  function(s)
    local wp = beautiful.wallpaper
    if not wp then return end
    if type(wp) == 'function' then
      local ok, err = pcall(wp, s)
      if not ok then paint_fallback(s, err) end
      return
    end
    if type(wp) ~= 'string' then
      paint_fallback(s, "invalid wallpaper type: " .. type(wp))
      return
    end
    if not gears.filesystem.file_readable(wp) then
      paint_fallback(s, "file not readable: " .. wp)
      return
    end
    local ok, err = pcall(gears.wallpaper.maximized, wp, s)
    if not ok then paint_fallback(s, err) end
  end
)

beautiful.init(Theme)
