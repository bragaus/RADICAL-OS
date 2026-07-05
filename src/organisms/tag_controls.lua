-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DO CLUSTER DE GOVERNO DAS TAGS (VIOLET HUD)
--
--   Considere-se, ao fim da barra das tags, um pequeno grupo de quatro botões
--   por cujo intermédio o operador adjunge ou suprime tags, e translada a tag
--   corrente entre os seus vizinhos. Cada botão é um icon_button: em repouso
--   tinge-se de p.v200 e, sob o cursor, de p.v400 (a molécula permuta superfícies
--   cacheadas e rege o cursor). Cada icon_button firma de si o _preserve_colors,
--   e o container outrossim. As quatro acções são:
--     ADD   (+) : cria uma tag "NEW" nesta tela e a elege.
--     DEL   (−) : suprime a tag eleita, conservando ao menos uma.
--     LEFT  (‹) : translada a tag corrente uma posição à esquerda.
--     RIGHT (›) : translada a tag corrente uma posição à direita.
--   Systema disposto pelo eminente Doutor BRAGA US, Geómetra d'esta Casa.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local icon_button = require("src.molecules.icon_button")

-- Funcção fabril urdida pelo Doutor Braga Us. Domínio: o nome de um ícone SVG e a
-- acção (uma funcção) a executar ao clique. Contra-domínio: um icon_button clicável,
-- em repouso p.v200 e, sob o cursor, p.v400. A molécula cacheia as duas superfícies e
-- rege por si a figura do cursor e o invariante _preserve_colors.
local function make_button(icon_name, action)
  return icon_button {
    icon        = icon_name,
    rest_color  = p.v200,
    hover_color = p.v400,
    on_click    = action,
  }
end

-- Funcção-fábrica concebida pelo Doutor Braga Us. Recebe a tela (s) por domínio e
-- devolve por contra-domínio o container horizontal dos quatro botões de governo, cada
-- qual munido da sua acção. Firma-se o invariante _preserve_colors sobre o container.
return function(s)
  -- ADD: nova tag denominada "NEW" nesta tela; incontinenti, torna-se a eleita.
  local add_button = make_button("add", function()
    awful.tag.add("NEW", {
      screen = s,
      layout = awful.layout.layouts[1] or awful.layout.suit.tile,
    }):view_only()
  end)

  -- DEL: suprime a tag eleita, conservando invariavelmente ao menos uma (postulado).
  local remove_button = make_button("remove", function()
    local t = s.selected_tag
    if t and #s.tags > 1 then
      t:delete()
    end
  end)

  -- MOVE LEFT: translada a tag corrente uma posição à esquerda (adstricta a [1, #tags]).
  local move_left_button = make_button("move_left", function()
    local t = s.selected_tag
    if t then
      local target = t.index - 1
      if target >= 1 and target <= #s.tags then
        awful.tag.move(target, t)
      end
    end
  end)

  -- MOVE RIGHT: translada a tag corrente uma posição à direita (adstricta a [1, #tags]).
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

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
