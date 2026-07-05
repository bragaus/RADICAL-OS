------------------------------------------------------------------------------------------
-- src/atoms/txt.lua — Role-based textbox factory (VIOLET HUD).                           --
--                                                                                        --
-- THE SOLE MARKUP OWNER of the whole config. A txt box is set EITHER via :set_text       --
-- (plain) OR via :set_span (Pango markup) — never both. This makes the historic          --
-- "markup='' alongside text= blanks the box" crash-family structurally impossible:       --
--   * :set_text(s)      -> native .text only, clears any markup attributes.              --
--   * :set_span(s, col) -> native .markup only (a single <span> wrapper).                --
--     :set_span "owns the box for life" — once you colorize via markup, keep using it.   --
-- Both setters nil-guard: a nil value is IGNORED (keeps the last value) so a leaf that    --
-- fed nil parsed stdout never crashes the textbox.                                        --
--                                                                                        --
-- role -> ft.<role> Pango string (fonts are point strings, NEVER dpi-wrapped).           --
--                                                                                        --
-- Usage:                                                                                  --
--   local txt = require("src.atoms.txt")                                                 --
--   local t = txt{ role = "value", text = "42%", align = "right" }                       --
--   t:set_text("57%")                                                                    --
--   t:set_span("DOWN", p.crit)   -- colored via markup                                   --
--   local none = txt.empty("NO DATA")                                                    --
------------------------------------------------------------------------------------------

local wibox = require("wibox")
local gstr  = require("gears.string")
local ft    = require("src.theme.typography")
local p     = require("src.theme.palette")

local esc = gstr.xml_escape

local function build(opts)
  opts = opts or {}
  local role = opts.role or "body"

  local box = wibox.widget {
    font         = ft[role] or ft.body,
    align        = opts.align or "left",
    valign       = opts.valign or "center",
    ellipsize    = opts.ellipsize or "end",
    forced_width = opts.forced_width,
    widget       = wibox.widget.textbox,
  }

  box._txt_upper = opts.upper and true or false
  box._txt_color = opts.color -- default color used by :set_span

  -- Capture the NATIVE textbox setter before shadowing it (get_miss resolves
  -- box.set_text to the class method here; the override below rawsets an
  -- instance field that wins on later access).
  local raw_set_text = box.set_text

  -- PLAIN mode. Sets .text only (native clears markup attributes). nil -> keep last.
  function box:set_text(s)
    if s == nil then return end
    s = tostring(s)
    if self._txt_upper then s = s:upper() end
    raw_set_text(self, s)
  end

  -- MARKUP mode. Sets .markup only via a single <span>. color defaults to the
  -- constructor color. nil text -> keep last (never blanks the box).
  function box:set_span(s, color)
    if s == nil then return end
    s = tostring(s)
    if self._txt_upper then s = s:upper() end
    color = color or self._txt_color
    local body   = esc(s) or ""
    local markup = color
      and ("<span foreground='" .. color .. "'>" .. body .. "</span>")
      or  body
    self:set_markup(markup) -- native set_markup (never overridden)
  end

  -- Initial content: color present => markup span; else plain text. Empty text
  -- leaves the box blank (no property set — avoids the constructor blank trap).
  if opts.text ~= nil and opts.text ~= "" then
    if opts.color then
      box:set_span(opts.text, opts.color)
    else
      box:set_text(opts.text)
    end
  end

  return box
end

local M = {}

-- Centered faint uppercase empty-state label (default "NO DATA").
function M.empty(s)
  return build {
    role  = "label",
    text  = s or "NO DATA",
    color = p.text_faint,
    align = "center",
    upper = true,
  }
end

return setmetatable(M, { __call = function(_, opts) return build(opts) end })
