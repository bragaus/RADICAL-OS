------------------------------------------------------------------------------------------
-- src/widgets/tag_controls.lua — Cluster de controle de tags (VIOLET HUD)                 --
--                                                                                        --
-- Pequeno grupo de botões no FIM da barra de tags (Image #2): adiciona/remove tags e     --
-- move a tag atual entre os workspaces. Quatro botões clicáveis (glyphs ASCII p/ render   --
-- garantido), cada um em p.v200; hover -> p.v400 (Hover_signal), cursor hand1, bg transp. --
--                                                                                        --
--   ADD   (+) : cria uma tag "NEW" nesta screen e foca nela.                             --
--   DEL   (−) : remove a tag selecionada (mantém ao menos 1).                            --
--   LEFT  (‹) : move a tag atual uma posição para a esquerda.                            --
--   RIGHT (›) : move a tag atual uma posição para a direita.                             --
------------------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local gcolor = require("gears.color")
local gfs = require("gears.filesystem")
local p = require("src.theme.palette")
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)
require("src.core.signals")

local SVG = gfs.get_configuration_dir() .. "icons/svg/"

-- Constrói um botão de ícone SVG clicável. `icon_name` é um arquivo de icons/svg/;
-- `action` é chamado em button 1. Repouso em p.v200, hover -> p.v400 (recolor da imagem).
local function make_button(icon_name, action)
  local ib = Icon(icon_name, { size = dpi(16), color = p.v200 })
  local svg = SVG .. icon_name .. ".svg"

  local button = wibox.widget {
    { ib, widget = wibox.container.place },
    forced_width = dpi(22),
    bg           = "#00000000",
    widget       = wibox.container.background,
  }

  button:buttons(awful.util.table.join(
    awful.button({}, 1, function()
      action()
    end)
  ))

  -- hover -> p.v400: recolore a imagem (imagebox não muda cor via fg). Hover_signal
  -- mantém o cursor hand1.
  button:connect_signal("mouse::enter", function() ib.image = gcolor.recolor_image(svg, p.v400) end)
  button:connect_signal("mouse::leave", function() ib.image = gcolor.recolor_image(svg, p.v200) end)
  Hover_signal(button, nil, p.v400)

  return button
end

return function(s)
  -- ADD: nova tag "NEW" nesta screen, vira a selecionada.
  local add_button = make_button("add", function()
    awful.tag.add("NEW", {
      screen = s,
      layout = awful.layout.layouts[1] or awful.layout.suit.tile,
    }):view_only()
  end)

  -- REMOVE: deleta a tag selecionada, mantendo ao menos uma.
  local remove_button = make_button("remove", function()
    local t = s.selected_tag
    if t and #s.tags > 1 then
      t:delete()
    end
  end)

  -- MOVE LEFT: move a tag atual uma posição para a esquerda (clamp em [1, #tags]).
  local move_left_button = make_button("move_left", function()
    local t = s.selected_tag
    if t then
      local target = t.index - 1
      if target >= 1 and target <= #s.tags then
        awful.tag.move(target, t)
      end
    end
  end)

  -- MOVE RIGHT: move a tag atual uma posição para a direita (clamp em [1, #tags]).
  local move_right_button = make_button("move_right", function()
    local t = s.selected_tag
    if t then
      local target = t.index + 1
      if target >= 1 and target <= #s.tags then
        awful.tag.move(target, t)
      end
    end
  end)

  return wibox.widget {
    add_button,
    remove_button,
    move_left_button,
    move_right_button,
    spacing = dpi(4),
    layout  = wibox.layout.fixed.horizontal,
  }
end
