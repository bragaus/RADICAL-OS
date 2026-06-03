------------------------------------------------------------------------------------------
-- src/tools/panel.lua — Chrome de painel "VIOLET HUD" (o motivo central do design)      --
--                                                                                        --
-- Todo painel da referência usa o mesmo molde: header em caixa-alta + linha divisória   --
-- em gradiente + corpo + borda fina + bevel 2-tons + "L" de canto (corner ticks).        --
--                                                                                        --
-- Uso:                                                                                   --
--   local panel = require("src.tools.panel")                                             --
--   local w = panel({ title = "INFO", body = some_widget, accent = p.v500 })             --
--   w:panel_set_focus(true)   -- realça borda quando foco/ativo                          --
--                                                                                        --
-- A decoração (header band, bevel, ticks) é desenhada via `bgimage` (atrás dos filhos),  --
-- então os filhos usam bg transparente e o input continua funcionando normalmente.       --
------------------------------------------------------------------------------------------

local wibox = require("wibox")
local gears = require("gears")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")

-- "#RRGGBB" + alpha(0..1) -> "#RRGGBBAA"
local function a(hex, alpha)
  return string.format("%s%02x", hex, math.floor((alpha or 1) * 255 + 0.5))
end

-- Constrói um painel com chrome. Opções:
--   title        (string)            título caixa-alta no header
--   body         (widget)            conteúdo
--   accent       (hex, default v500) cor do título/divisória/ticks
--   w, h         (dpi)               forçar tamanho
--   header_height(dpi, default 20)
--   radius       (dpi, default 4)
--   focus        (bool)              borda viva line_bright
--   right_icon   (widget)            ícone opcional à direita do header (text_muted)
--   pad          (dpi, default 8)    padding do corpo
local function build(opts)
  opts = opts or {}
  local accent       = opts.accent or p.v500
  local title_text   = (opts.title or ""):upper()
  local body         = opts.body or wibox.widget.base.make_widget()
  local header_h     = opts.header_height or dpi(20)
  local radius       = opts.radius or dpi(4)
  local pad          = opts.pad or dpi(8)
  local grad_w       = opts.w or dpi(300)
  local border_color = opts.focus and p.line_bright or p.line_base
  local focused      = opts.focus and true or false

  -- Título (caixa-alta, text_heading, extrabold) centralizado verticalmente
  local title_box = wibox.widget {
    text   = title_text,
    font   = (user_vars.font and user_vars.font.extrabold) or "JetBrainsMono Nerd Font, ExtraBold 11",
    valign = "center",
    widget = wibox.widget.textbox,
  }

  local header = wibox.widget {
    {
      {
        { title_box, fg = p.text_heading, widget = wibox.container.background },
        nil,
        opts.right_icon and { opts.right_icon, fg = p.text_muted, widget = wibox.container.background } or nil,
        expand = "inside",
        layout = wibox.layout.align.horizontal,
      },
      left   = pad,
      right  = pad,
      widget = wibox.container.margin,
    },
    forced_height = header_h,
    bg            = "#00000000", -- band desenhada pelo bgimage
    widget        = wibox.container.background,
  }

  -- Linha divisória: gradiente accent -> accent@22% -> transparente
  local divider = wibox.widget {
    forced_height = dpi(2),
    bg = gears.color {
      type = "linear",
      from = { 0, 0 },
      to   = { grad_w, 0 },
      stops = {
        { 0,    accent },
        { 0.55, a(accent, 0.22) },
        { 1,    "#00000000" },
      },
    },
    shape  = gears.shape.rounded_bar,
    widget = wibox.container.background,
  }

  local body_wrap = wibox.widget {
    body,
    left   = pad,
    right  = pad,
    top    = dpi(6),
    bottom = pad,
    widget = wibox.container.margin,
  }

  -- Decoração desenhada atrás do conteúdo: header band + bevel + ticks de canto
  local function decoration(_, cr, w, h)
    -- header band (foco => v700, senão panel_hi), recortado nos cantos arredondados do topo
    cr:save()
    gears.shape.rounded_rect(cr, w, h, radius)
    cr:clip()
    cr:set_source(gears.color(focused and p.v700 or p.panel_hi))
    cr:rectangle(0, 0, w, header_h)
    cr:fill()
    cr:restore()

    -- bevel: realce topo+esquerda, sombra baixo+direita (efeito inset)
    cr:set_line_width(dpi(1))
    cr:set_source(gears.color(a(p.bevel_hi, 0.7)))
    cr:move_to(1, h); cr:line_to(1, 1); cr:line_to(w, 1); cr:stroke()
    cr:set_source(gears.color(a(p.bevel_lo, 0.9)))
    cr:move_to(w - 1, 0); cr:line_to(w - 1, h - 1); cr:line_to(0, h - 1); cr:stroke()

    -- "L" de canto em accent (corner ticks)
    local tick = dpi(10)
    cr:set_source(gears.color(a(accent, 0.9)))
    cr:set_line_width(dpi(1.4))
    cr:move_to(0, tick);     cr:line_to(0, 0);     cr:line_to(tick, 0)
    cr:move_to(w - tick, 0); cr:line_to(w, 0);     cr:line_to(w, tick)
    cr:move_to(0, h - tick); cr:line_to(0, h);     cr:line_to(tick, h)
    cr:move_to(w - tick, h); cr:line_to(w, h);     cr:line_to(w, h - tick)
    cr:stroke()
  end

  local outer = wibox.widget {
    {
      header,
      divider,
      body_wrap,
      layout = wibox.layout.fixed.vertical,
    },
    bg                 = a(p.panel, 0.9),  -- panel@e6
    bgimage            = decoration,
    shape              = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, radius) end,
    shape_border_width = dpi(1),
    shape_border_color = border_color,
    widget             = wibox.container.background,
  }

  if opts.w then outer.forced_width = opts.w end
  if opts.h then outer.forced_height = opts.h end

  -- Troca a cor da borda (normal/foco) e a header band em runtime
  function outer:panel_set_focus(f)
    focused = f and true or false
    self.shape_border_color = f and p.line_bright or p.line_base
    self:emit_signal("widget::redraw_needed")
  end

  return outer
end

return setmetatable({ build = build }, { __call = function(_, o) return build(o) end })
