------------------------------------------------------------------------------------------
-- src/organisms/tag_controls.lua — Cluster de controle de tags (VIOLET HUD)                 --
--                                                                                        --
-- Pequeno grupo de botões no FIM da barra de tags (Image #2): adiciona/remove tags e     --
-- move a tag atual entre os workspaces. Quatro botões clicáveis (icon_button), cada um    --
-- em repouso p.v200; hover -> p.v400 (cached surface swap + cursor hand1, dentro do        --
-- molecule). Cada icon_button SELF-seta _preserve_colors (R6); o container também.         --
--                                                                                        --
--   ADD   (+) : cria uma tag "NEW" nesta screen e foca nela.                             --
--   DEL   (−) : remove a tag selecionada (mantém ao menos 1).                            --
--   LEFT  (‹) : move a tag atual uma posição para a esquerda.                            --
--   RIGHT (›) : move a tag atual uma posição para a direita.                             --
------------------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local icon_button = require("src.molecules.icon_button")

-- Constrói um botão de ícone SVG clicável (repouso p.v200, hover -> p.v400). O molecule
-- cacheia as duas superfícies e cuida do cursor + _preserve_colors.
local function make_button(icon_name, action)
  return icon_button {
    icon        = icon_name,
    rest_color  = p.v200,
    hover_color = p.v400,
    on_click    = action,
  }
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

  local controls = wibox.widget {
    add_button,
    remove_button,
    move_left_button,
    move_right_button,
    spacing = dpi(4),
    layout  = wibox.layout.fixed.horizontal,
  }

  controls._preserve_colors = true

  return controls
end
