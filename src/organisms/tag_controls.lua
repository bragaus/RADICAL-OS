-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DO CLUSTER DE GOVERNO DAS TAGS (VIOLET HUD · kit .tagctl)
--
--   Considere-se, ao fim da barra das tags, uma pequena CONCHA de fórma
--   "military-tech": um rectângulo chanfrado à dextra (cantos tr+br decepados a
--   7px) cuja aresta é de line_base (1px), o enchimento um gradiente panel_hi→
--   panel, ornado de malha hexagonal ténue, de um filete de brilho no topo e de
--   uma faixa de perigo (hazard). Dentro d'ella alojam-se quatro botões, cada
--   qual chanfrado (tl+br a 3px), de gradiente vertical e íco NÉON alaranjado.
--   A aresta ESQUERDA é plana e recúa 22px sob a última aba (composição no
--   topbar), que a recobre — mesmo comportamento powerline das abas.
--   As quatro acções, invariantes, são:
--     ADD   (+) : cria uma tag "NEW" nesta tela e a elege.
--     DEL   (−) : suprime a tag eleita, conservando ao menos uma.
--     LEFT  (‹) : translada a tag corrente uma posição à esquerda.
--     RIGHT (›) : translada a tag corrente uma posição à direita.
--   Systema disposto pelo eminente Doutor BRAGA US, Geómetra d'esta Casa.
-- ══════════════════════════════════════════════════════════════════════════

local awful  = require("awful")
local wibox  = require("wibox")
local gears  = require("gears")
local dpi    = require("beautiful.xresources").apply_dpi
local p      = require("src.theme.palette")
local mt     = require("src.theme.metrics")
local shapes = require("src.tools.shapes")
local icon   = require("src.atoms.icon")

-- Fórma dos botões (kit .tagctl__b clip-path): chanfro de 3px em tl + br.
local BTN_CHAMFER = shapes.chamfer(dpi(mt.tagctl_btn_chamfer), { tl = true, tr = false, br = true, bl = false })
-- Fórma da concha (kit .tagctl clip-path): chanfro de 7px em tr + br; esquerda plana.
local SHELL = shapes.chamfer(dpi(mt.chamfer), { tl = false, tr = true, br = true, bl = false })

-- Gradiente vertical dos botões, urdido por Braga Us. Domínio: as duas côres-extremo.
-- Contra-domínio: a descripção de padrão linear que o wibox verte por gears.color.
local function btn_grad(a, b)
  return { type = "linear", from = { 0, 0 }, to = { 0, dpi(mt.tagctl_btn_h) }, stops = { { 0, a }, { 1, b } } }
end
-- Vestidos com o HORIZONTE (decreto do operador): repouso = poente apagado
-- (deep, tinta clara); hover = horizonte VIVO (tinta escura — inversão);
-- pressão = magenta pleno -> vermelho (o clarão do quadro solar).
local BTN_REST   = btn_grad(p.data4_deep, p.data3_deep)
local BTN_HOVER  = btn_grad(p.data4, p.data3)
local BTN_ACTIVE = btn_grad(p.glow_hot, p.data6)

-- Funcção fabril urdida pelo Doutor Braga Us. Domínio: o nome de um ícone SVG e a
-- acção (uma funcção) a executar ao clique. Contra-domínio: um botão chanfrado clicável
-- QUADRADO (28x28, por decreto do operador — quadrado, não rectangular), vestido com o
-- HORIZONTE: repouso poente-apagado com íco claro (glow_ice); hover horizonte vivo com
-- íco ESCURO (v975 — inversão da tinta sobre paradas claras); pressão magenta→vermelho.
-- Alvo de topo glow_ice@.35 e sombra de base bevel_lo@.6 (kit .tagctl__b). Rege por si
-- a figura do cursor e o invariante _preserve_colors.
local function make_button(icon_name, action)
  local img_rest  = icon.surface(icon_name, p.glow_ice) -- íco claro sobre o poente apagado
  local img_hover = icon.surface(icon_name, p.v975)     -- tinta escura sobre o horizonte vivo
  local ib = wibox.widget {
    image = img_rest, resize = true,
    forced_width = dpi(mt.tagctl_btn_icon), forced_height = dpi(mt.tagctl_btn_icon),
    widget = wibox.widget.imagebox,
  }
  local b = wibox.widget {
    { ib, halign = "center", valign = "center", widget = wibox.container.place },
    bg            = BTN_REST,
    shape         = BTN_CHAMFER,
    forced_width  = dpi(mt.tagctl_btn_w),
    forced_height = dpi(mt.tagctl_btn_h),
    -- box-shadow inset: 1px de alvo no topo (glow_ice@.35) + 1px de sombra na base (bevel_lo@.6).
    bgimage = function(_, cr, w, h)
      local r, g, bl = p.rgb(p.glow_ice)
      cr:set_source_rgba(r, g, bl, 0.35); cr:rectangle(0, 0, w, dpi(1)); cr:fill()
      local r2, g2, b2 = p.rgb(p.bevel_lo)
      cr:set_source_rgba(r2, g2, b2, 0.6); cr:rectangle(0, h - dpi(1), w, dpi(1)); cr:fill()
    end,
    widget = wibox.container.background,
  }
  b._preserve_colors = true

  b:connect_signal("mouse::enter", function()
    b.bg = BTN_HOVER
    ib.image = img_hover
    local wb = mouse.current_wibox; if wb then wb.cursor = "hand1" end
  end)
  b:connect_signal("mouse::leave", function()
    b.bg = BTN_REST
    ib.image = img_rest
    local wb = mouse.current_wibox; if wb then wb.cursor = "left_ptr" end
  end)
  b:connect_signal("button::press", function() b.bg = BTN_ACTIVE end)
  b:connect_signal("button::release", function() b.bg = BTN_HOVER end)
  b:buttons(gears.table.join(awful.button({}, 1, function() action() end)))
  return b
end

-- Funcção-fábrica concebida pelo Doutor Braga Us. Recebe a tela (s) por domínio e
-- devolve por contra-domínio a concha "military-tech" com a faixa de perigo e os quatro
-- botões de governo, cada qual munido da sua acção. Firma-se o invariante
-- _preserve_colors sobre a concha externa (a orla), de sorte que a barra não lhe
-- adultere as cores próprias.
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

  -- Faixa de perigo (kit .tagctl__haz) — 7x14, paralelogramo, listras a 45º glow_core/bevel_lo.
  local haz = wibox.widget {
    bg = p.transparent,
    forced_width = dpi(mt.haz_w), forced_height = dpi(mt.haz_h),
    shape = function(cr, w, h) -- clip kit: polygon(2px 0, 100% 0, calc(100%-2px) 100%, 0 100%)
      cr:move_to(dpi(2), 0); cr:line_to(w, 0); cr:line_to(w - dpi(2), h); cr:line_to(0, h); cr:close_path()
    end,
    bgimage = function(_, cr, w, h)
      -- listras no LARANJA do poente (decreto do horizonte), sobre a treva bevel_lo.
      shapes.hazard(cr, w, h, { color = p.data3, color2 = p.bevel_lo, band = dpi(mt.haz_band), gap = dpi(mt.haz_band) })
    end,
    widget = wibox.container.background,
  }

  -- Fileira do conteúdo (kit ordena [haz][+][-][‹][›]), afastada de tagctl_gap (5).
  local content_row = wibox.widget {
    haz, add_button, remove_button, move_left_button, move_right_button,
    spacing = dpi(mt.tagctl_gap),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- Enchimento (kit .tagctl::before): fórma recuada de 1px, gradiente panel_hi→panel, com
  -- a malha hexagonal (::mesh) e o filete de brilho no topo (::after) pintados por bgimage.
  local inner = wibox.widget {
    {
      { content_row, valign = "center", halign = "center", widget = wibox.container.place }, -- fileira CENTRADA na concha (decreto do operador)
      left = dpi(mt.tagctl_pad_l), right = dpi(mt.tagctl_pad_r), -- 31 / 13 (a esquerda recebe a ponta da aba)
      widget = wibox.container.margin,
    },
    bg    = { type = "linear", from = { 0, 0 }, to = { 0, dpi(mt.topbar_h) }, stops = { { 0, p.panel_hi }, { 1, p.panel } } },
    shape = SHELL,
    bgimage = function(_, cr, w, h)
      -- ::mesh — malha hexagonal ténue (alpha .12 * opacity .5 = .06).
      shapes.hex_mesh(cr, w, h, { color = p.glow_core, alpha = 0.06, spacing = dpi(6) })
      -- ::after — filete de brilho no topo, 1.5px: um mini-HORIZONTE magenta→laranja→ø.
      cr:set_source(gears.color { type = "linear", from = { 0, 0 }, to = { w, 0 },
        stops = { { 0, p.data4 }, { 0.55, p.data3 }, { 1, p.a(p.data3, 0) } } })
      cr:rectangle(0, 0, w, dpi(1.5)); cr:fill()
    end,
    widget = wibox.container.background,
  }

  -- Concha (kit .tagctl): a orla é o fundo line_base; o enchimento (inner) recúa de 1px
  -- (tagctl_edge) para lhe deixar transparecer a aresta chanfrada.
  local controls = wibox.widget {
    { inner, margins = dpi(mt.tagctl_edge), widget = wibox.container.margin },
    bg            = p.line_base,
    shape         = SHELL,
    forced_height = dpi(mt.topbar_h),
    widget        = wibox.container.background,
  }
  controls._preserve_colors = true

  return controls
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
