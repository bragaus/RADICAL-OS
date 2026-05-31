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
local p = require("src.theme.palette")
require("src.core.signals")

local MONO = "JetBrainsMono Nerd Font"

-- Constrói um botão glyph clicável. `action` é chamado em button 1.
local function make_button(glyph, action)
  local button = wibox.widget {
    {
      {
        markup = string.format("<b>%s</b>", glyph),
        font   = MONO .. " 13",
        align  = "center",
        valign = "center",
        widget = wibox.widget.textbox,
      },
      widget = wibox.container.place,
    },
    forced_width = dpi(22),
    fg           = p.v200,
    bg           = "#00000000",
    widget       = wibox.container.background,
  }

  button:buttons(awful.util.table.join(
    awful.button({}, 1, function()
      action()
    end)
  ))

  -- hover -> p.v400 (bg permanece transparente; Hover_signal guarda nil bg)
  Hover_signal(button, nil, p.v400)

  return button
end

return function(s)
  -- ADD: nova tag "NEW" nesta screen, vira a selecionada.
  local add_button = make_button("+", function()
    awful.tag.add("NEW", {
      screen = s,
      layout = awful.layout.layouts[1] or awful.layout.suit.tile,
    }):view_only()
  end)

  -- REMOVE: deleta a tag selecionada, mantendo ao menos uma.
  local remove_button = make_button("−", function()
    local t = s.selected_tag
    if t and #s.tags > 1 then
      t:delete()
    end
  end)

  -- MOVE LEFT: move a tag atual uma posição para a esquerda (clamp em [1, #tags]).
  local move_left_button = make_button("‹", function()
    local t = s.selected_tag
    if t then
      local target = t.index - 1
      if target >= 1 and target <= #s.tags then
        awful.tag.move(target, t)
      end
    end
  end)

  -- MOVE RIGHT: move a tag atual uma posição para a direita (clamp em [1, #tags]).
  local move_right_button = make_button("›", function()
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
