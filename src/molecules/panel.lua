------------------------------------------------------------------------------------------
-- src/molecules/panel.lua — Chrome de painel "VIOLET HUD" (o motivo central do design).   --
-- (git mv de src/tools/panel.lua; src/tools/panel.lua permanece como shim de re-export.)  --
--                                                                                        --
-- Todo painel da referência usa o mesmo molde: header em CAIXA-ALTA + linha divisória    --
-- em gradiente + corpo + borda fina + bevel 2-tons + "L" de canto (corner ticks).         --
--                                                                                        --
-- Uso:                                                                                    --
--   local panel = require("src.molecules.panel")   -- ou o shim require("src.tools.panel")--
--   local w = panel({ title = "INFO", body = some_widget, accent = p.v500 })              --
--   w:panel_set_focus(true)   -- realça a borda quando em foco/ativo                       --
--                                                                                        --
-- A decoração (header band, bevel, ticks) é desenhada via `bgimage` (ATRÁS dos filhos),   --
-- então os filhos usam bg transparente e o input continua funcionando normalmente.        --
--                                                                                        --
-- ⚠ R1 — id-chain break: `get_children_by_id()` NÃO resolve ids através deste `body` já   --
--   montado pelo panel(). Um molecule usado como `body` DEVE retornar o widget COM seus    --
--   métodos + guardar refs locais diretas aos sub-widgets; NUNCA consulte ids de volta     --
--   através de panel(). Este painel expõe apenas :panel_set_focus (nenhum id interno).     --
------------------------------------------------------------------------------------------

local wibox   = require("wibox")
local gears   = require("gears")
local dpi     = require("beautiful.xresources").apply_dpi
local p       = require("src.theme.palette")
local mt      = require("src.theme.metrics")
local txt     = require("src.atoms.txt")
local divider = require("src.atoms.divider")

-- alpha helper da palette (DRY — não redefinir a mesma a() local)
local a = p.a

-- Constrói um painel com chrome. Opções:
--   title        (string)  título CAIXA-ALTA no header
--   body         (widget)  conteúdo
--   accent       (hex, default p.v500) cor do título/divisória/ticks
--   w, h         (dpi)      forçar tamanho
--   header_height(dpi, default dpi(mt.header_h))
--   radius       (dpi, default dpi(mt.radius_panel))
--   pad          (dpi, default dpi(mt.pad_panel)) padding do corpo
--   focus        (bool)     borda viva line_bright
--   right_icon   (widget)   ícone opcional à direita do header (text_muted)
local function build(opts)
  opts = opts or {}
  local accent       = opts.accent or p.v500
  local body         = opts.body or wibox.widget.base.make_widget()
  local header_h     = opts.header_height or dpi(mt.header_h)
  local radius       = opts.radius or dpi(mt.radius_panel)
  local pad          = opts.pad or dpi(mt.pad_panel)
  local grad_w       = opts.w or dpi(mt.panel_w_md)
  local border_color = opts.focus and p.line_bright or p.line_base
  local focused      = opts.focus and true or false

  -- Título CAIXA-ALTA, papel ft.panel_title (ExtraBold live); fg via container.
  -- atoms/txt aplica o :upper() e é o único dono de markup (aqui só texto puro).
  local title_box = txt { role = "panel_title", text = opts.title, upper = true, valign = "center" }

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
    bg            = p.transparent, -- band desenhada pelo bgimage
    widget        = wibox.container.background,
  }

  -- Linha divisória: accent -> accent@alpha.divider_tail (@55%) -> transparente.
  -- Gradiente extraído para o atom atoms/divider (span = largura do painel).
  local rule = divider { accent = accent, width = grad_w }

  local body_wrap = wibox.widget {
    body,
    left   = pad,
    right  = pad,
    top    = dpi(mt.body_top_pad), -- 6 (ratificado; kit spec = 7 via mt.body_top_pad_spec)
    bottom = pad,
    widget = wibox.container.margin,
  }

  -- Decoração desenhada ATRÁS do conteúdo: header band + bevel + ticks de canto.
  local function decoration(_, cr, w, h)
    -- header band (foco => v700, senão panel_hi), recortada nos cantos do topo
    cr:save()
    gears.shape.rounded_rect(cr, w, h, radius)
    cr:clip()
    cr:set_source(gears.color(focused and p.v700 or p.panel_hi))
    cr:rectangle(0, 0, w, header_h)
    cr:fill()
    cr:restore()

    -- bevel: realce topo+esquerda, sombra baixo+direita (efeito inset)
    cr:set_line_width(dpi(mt.border_panel))
    cr:set_source(gears.color(a(p.bevel_hi, p.alpha.bevel_hi)))
    cr:move_to(1, h); cr:line_to(1, 1); cr:line_to(w, 1); cr:stroke()
    cr:set_source(gears.color(a(p.bevel_lo, p.alpha.bevel_lo)))
    cr:move_to(w - 1, 0); cr:line_to(w - 1, h - 1); cr:line_to(0, h - 1); cr:stroke()

    -- "L" de canto em accent (corner ticks)
    local tick = dpi(mt.corner_tick)
    cr:set_source(gears.color(a(accent, p.alpha.tick)))
    cr:set_line_width(dpi(mt.tick_stroke))
    cr:move_to(0, tick);     cr:line_to(0, 0);     cr:line_to(tick, 0)
    cr:move_to(w - tick, 0); cr:line_to(w, 0);     cr:line_to(w, tick)
    cr:move_to(0, h - tick); cr:line_to(0, h);     cr:line_to(tick, h)
    cr:move_to(w - tick, h); cr:line_to(w, h);     cr:line_to(w, h - tick)
    cr:stroke()
  end

  local outer = wibox.widget {
    {
      header,
      rule,
      body_wrap,
      layout = wibox.layout.fixed.vertical,
    },
    bg                 = a(p.panel, p.alpha.panel), -- panel@0.9
    bgimage            = decoration,
    shape              = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, radius) end,
    shape_border_width = dpi(mt.border_panel),
    shape_border_color = border_color,
    widget             = wibox.container.background,
  }

  if opts.w then outer.forced_width = opts.w end
  if opts.h then outer.forced_height = opts.h end

  -- Troca a cor da borda (normal/foco) e a header band em runtime.
  function outer:panel_set_focus(f)
    focused = f and true or false
    self.shape_border_color = f and p.line_bright or p.line_base
    self:emit_signal("widget::redraw_needed")
  end

  return outer
end

return setmetatable({ build = build }, { __call = function(_, o) return build(o) end })
