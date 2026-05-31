--------------------------------------------------------------------------------------------------------------
-- VIOLET HUD — coluna lateral de painéis (§5 do DESIGN_SYSTEM).                                              --
-- Recebe uma lista de widgets já construídos (cada um envolto pelo chrome de src/tools/panel.lua) e os        --
-- empilha verticalmente num awful.popup ancorado na borda. Overlay (sem struts) p/ não brigar com o tiling.   --
--------------------------------------------------------------------------------------------------------------
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")

-- side_panels(s, widgets, opts)
--   s       : screen
--   widgets : { panel_widget, ... }  (ordem de cima p/ baixo)
--   opts    : { side = "left"|"right" (default "left"), top = dpi, margin = dpi }
return function(s, widgets, opts)
  widgets = widgets or {}
  opts = opts or {}
  local side = opts.side or "left"
  local top_margin = opts.top or dpi(70)
  local edge_margin = opts.margin or dpi(10)

  local column = awful.popup {
    screen = s,
    ontop = false,
    bg = "#00000000",
    visible = true,
    placement = function(c)
      if side == "right" then
        awful.placement.top_right(c, { margins = { top = top_margin, right = edge_margin } })
      else
        awful.placement.top_left(c, { margins = { top = top_margin, left = edge_margin } })
      end
    end,
    shape = function(cr, w, h)
      gears.shape.rounded_rect(cr, w, h, dpi(4))
    end,
    widget = wibox.container.background,
  }

  -- Evita coluna duplicada ao recarregar
  local key = "_radical_side_panel_" .. side
  if s[key] and s[key] ~= column then
    s[key].visible = false
  end
  s[key] = column

  local layout = wibox.layout.fixed.vertical()
  layout.spacing = dpi(8)
  for _, w in ipairs(widgets) do
    if w then layout:add(w) end
  end

  column:setup {
    layout,
    widget = wibox.container.background,
  }

  return column
end
