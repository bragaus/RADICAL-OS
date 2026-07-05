------------------------------------------------------------------------------------------
-- src/atoms/icon.lua — Recolored SVG imagebox + (name,color)->surface cache.             --
--                                                                                        --
-- The SVGs in icons/svg/ already ship in the violet palette; use them AS-IS by default   --
-- (omit color -> imagebox loads the multitone path). Recolor only by STATE (e.g. KILL    --
-- -> p.crit on hover). icon.surface(name, color) memoizes the recolored/loaded cairo     --
-- surface by name|color so hover two-state swaps never re-run recolor_image per event.   --
--                                                                                        --
-- Errors LOUDLY (with the resolved path) on a missing/unreadable file.                   --
--                                                                                        --
-- Callable two ways (src/tools/icons.lua is a permanent re-export shim of this module):   --
--   local icon = require("src.atoms.icon")                                               --
--   icon{ name = "cpu", color = p.crit, size = dpi(16) }   -- atom form; size dflt icon_md--
--   icon("cpu", { color = p.crit, size = dpi(14) })         -- legacy Icon(name, opts)    --
--   local surf = icon.surface("kill", p.crit)               -- cached surface (hover swap)--
------------------------------------------------------------------------------------------

local wibox    = require("wibox")
local gcolor   = require("gears.color")
local gsurface = require("gears.surface")
local gfs      = require("gears.filesystem")
local dpi      = require("beautiful.xresources").apply_dpi
local mt       = require("src.theme.metrics")

-- Preserved convention from the old src/tools/icons.lua.
local DIR = gfs.get_configuration_dir() .. "icons/svg/"

local function path_for(name)
  return DIR .. tostring(name) .. ".svg"
end

local function readable_path(name)
  local path = path_for(name)
  if not gfs.file_readable(path) then
    error("atoms/icon: SVG not found or unreadable -> " .. path, 2)
  end
  return path
end

-- surface cache keyed by "name|color" ("name|raw" when uncolored).
local cache = {}

local function surface(name, color)
  local key = tostring(name) .. "|" .. tostring(color or "raw")
  local hit = cache[key]
  if hit then return hit end
  local path = readable_path(name)
  local surf = color and gcolor.recolor_image(path, color) or gsurface.load(path)
  cache[key] = surf
  return surf
end

local function build(opts)
  opts = opts or {}
  local img
  if opts.color then
    img = surface(opts.name, opts.color) -- cached recolor (dedupes hover states)
  else
    img = readable_path(opts.name)       -- raw path -> imagebox keeps the multitone SVG
  end
  return wibox.widget {
    image         = img,
    resize        = true,
    forced_width  = opts.size,
    forced_height = opts.size,
    widget        = wibox.widget.imagebox,
  }
end

local M = { surface = surface }

return setmetatable(M, {
  __call = function(_, a1, a2)
    if type(a1) == "string" then
      -- Legacy Icon(name, opts): size omitted -> natural size (contract preserved).
      local o = a2 or {}
      return build({ name = a1, color = o.color, size = o.size })
    end
    -- Atom form icon{ name=, color=, size= }: size defaults to dpi(mt.icon_md).
    a1 = a1 or {}
    return build({ name = a1.name, color = a1.color, size = a1.size or dpi(mt.icon_md) })
  end,
})
