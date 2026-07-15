-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/panel.lua — Da chancellaria geométrica do Doutor BRAGA US.
--
-- TRACTADO SOBRE A MOLDURA CANÔNICA DO "VIOLET HUD", motivo central de todo o
-- systema decorativo. Foi transladado (git mv) de src/tools/panel.lua, onde
-- permanece agora tão-sómente um shim de re-exportação, cortez ao chamador antigo.
--
-- POSTULADO DA MOLDURA — todo painel da referência participa do mesmo molde,
-- qual figura semelhante em geometria: cabeçalho em CAIXA-ALTA, seguido de linha
-- divisória em gradiente, corpo, borda subtil e bisel de dois tons, e os quatro
-- "L" de canto (corner ticks). Assim demonstrou o insigne geómetra Braga Us que
-- da invariância d'estes elementos resulta a unidade harmônica do conjuncto.
--
-- Da maneira de invocar esta obra:
--   local panel = require("src.molecules.panel")   -- ou o shim require("src.tools.panel")
--   local w = panel({ title = "INFO", body = some_widget, accent = p.v500 })
--   w:panel_set_focus(true)   -- realça a borda quando em foco ou activo
--
-- FACTO NOTÁVEL — a decoração (banda do cabeçalho, bisel, ticks) é traçada pelo
-- `bgimage`, ATRÁS dos filhos; por conseguinte os filhos ostentam fundo diáphano
-- e o influxo do rato (input) prossegue immediato e sem obstáculo.
--
-- ⚠ LEMMA R1 — da ruptura da cadeia de identificadores: `get_children_by_id()`
--   NÃO resolve ids atravez d'este `body` já montado por panel(). Segue-se, como
--   corollário, que um molecule empregado como `body` DEVE retornar o widget
--   COM seus métodos e guardar referências locaes directas aos sub-widgets;
--   JAMAIS se consultem ids de volta atravez de panel(). Este painel expõe
--   sómente :panel_set_focus (nenhum id interno). Q.E.D.
-- ══════════════════════════════════════════════════════════════════════════

local wibox   = require("wibox")
local gears   = require("gears")
local dpi     = require("beautiful.xresources").apply_dpi
local p       = require("src.theme.palette")
local mt      = require("src.theme.metrics")
local txt     = require("src.atoms.txt")
local divider = require("src.atoms.divider")

-- Auxiliar de alpha, tomado da palette (princípio do DRY — não se redefina a
-- mesma funcção a() em domínio local, pois duplicar é multiplicar o erro).
local a = p.a

-- ──────────────────────────────────────────────────────────────────────────
-- Funcção build — urdida pelo Doutor Braga Us para engendrar a moldura completa.
--   DOMÍNIO (argumento `opts`, uma taboa de opções, toda ella facultativa):
--     title        (string)  título em CAIXA-ALTA que ornará o cabeçalho.
--     body         (widget)  o conteúdo próprio do painel.
--     accent       (hex, por defeito p.v500) côr do título, da divisória e dos ticks.
--     w, h         (dpi)      dimensões, quando se queira impô-las.
--     header_height(dpi, por defeito dpi(mt.header_h)) altura do cabeçalho.
--     radius       (dpi, por defeito dpi(mt.radius_panel)) raio dos cantos.
--     pad          (dpi, por defeito dpi(mt.pad_panel)) enchimento do corpo.
--     focus        (bool)     quando verdadeiro, borda viva line_bright.
--     right_icon   (widget)   ícone opcional à direita do cabeçalho (text_muted).
--   CONTRA-DOMÍNIO: retorna o widget `outer` já decorado, dotado do método
--     :panel_set_focus. INVARIANTE: a decoração habita o bgimage, e o fundo dos
--     filhos permanece diáphano, conforme o facto notável supra-enunciado.
-- EXPERIMENTO DO HORIZONTE (decreto do operador): a banda do cabeçalho de TODO
-- painel veste, por defeito, o mesmo HORIZONTE das faixas do context_menu —
-- magenta (data4) -> laranja (data3) -> diáphano — com o título em tinta escura
-- (v975, inversão sobre paradas claras). Para reverter ao chrome clássico,
-- mude esta constante p/ "accent"; caso a caso, passe opts.header_variant.
local HEADER_VARIANT = "sunset"

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
  local sunset_hd    = (opts.header_variant or HEADER_VARIANT) == "sunset"

  -- Título em CAIXA-ALTA, papel ft.title (ExtraBold 11, == .hp__title do kit); a
  -- côr do fg confere-se pelo container (tinta escura v975 sobre o horizonte;
  -- text_heading sobre a banda clássica). O atom atoms/txt aplica o :upper() e é
  -- o único soberano do markup (aqui apenas texto puro, sem ornamento algum).
  local title_box = txt { role = "title", text = opts.title, upper = true, valign = "center" }

  local header = wibox.widget {
    {
      {
        { title_box, fg = sunset_hd and p.v975 or p.text_heading, widget = wibox.container.background },
        nil,
        opts.right_icon and { opts.right_icon, fg = sunset_hd and p.v975 or p.text_muted, widget = wibox.container.background } or nil,
        expand = "inside",
        layout = wibox.layout.align.horizontal,
      },
      left   = pad,
      right  = pad,
      widget = wibox.container.margin,
    },
    forced_height = header_h,
    bg            = p.transparent, -- a banda é traçada pelo bgimage, não aqui
    widget        = wibox.container.background,
  }

  -- Linha divisória: do accent, transitando a accent@alpha.divider_tail (a 55%),
  -- e findando no diáphano. O gradiente foi extrahido para o atom atoms/divider
  -- (o span abrange toda a largura do painel). Facultativamente, opts.divider_variant
  -- = "sunset" veste a régua com o HORIZONTE do poente (vide atoms/divider).
  local rule = divider { accent = accent, width = grad_w, variant = opts.divider_variant }

  local body_wrap = wibox.widget {
    body,
    left   = pad,
    right  = pad,
    top    = dpi(mt.body_top_pad_spec), -- 7 (spec do kit .hp__bd padding-top:7px)
    bottom = pad,
    widget = wibox.container.margin,
  }

  -- ────────────────────────────────────────────────────────────────────────
  -- Funcção decoration — pincel geométrico da penna do professor Braga Us.
  --   DOMÍNIO: (_, cr, w, h) — o contexto cairo `cr` e as dimensões w, h.
  --   EFEITO: traça, ATRÁS do conteúdo, a banda do cabeçalho, o bisel de dois
  --   tons (efeito inset) e os quatro ticks de canto. Nada retorna (contra-
  --   domínio vazio); opera sómente por seus effeitos sobre o contexto cairo.
  local function decoration(_, cr, w, h)
    -- banda do cabeçalho, recortada nos cantos superiores segundo o rectângulo
    -- de bordas arredondadas. Na variante HORIZONTE: gradiente magenta->laranja->ø
    -- (o mesmo das faixas do context_menu); na clássica: v700 em foco / panel_hi.
    cr:save()
    gears.shape.rounded_rect(cr, w, h, radius)
    cr:clip()
    if sunset_hd then
      cr:set_source(gears.color {
        type = "linear", from = { 0, 0 }, to = { w, 0 },
        stops = { { 0, p.data4 }, { 0.55, p.data3 }, { 1, p.a(p.data3, 0) } },
      })
    else
      cr:set_source(gears.color(focused and p.v700 or p.panel_hi))
    end
    cr:rectangle(0, 0, w, header_h)
    cr:fill()
    cr:restore()

    -- bisel: realce ao alto e à esquerda, sombra em baixo e à direita — d'onde
    -- se produz, ao olhar, a illusão de reintrância (efeito inset).
    cr:set_line_width(dpi(mt.border_panel))
    cr:set_source(gears.color(a(p.bevel_hi, p.alpha.bevel_hi)))
    cr:move_to(1, h); cr:line_to(1, 1); cr:line_to(w, 1); cr:stroke()
    cr:set_source(gears.color(a(p.bevel_lo, p.alpha.bevel_lo)))
    cr:move_to(w - 1, 0); cr:line_to(w - 1, h - 1); cr:line_to(0, h - 1); cr:stroke()

    -- os quatro "L" de canto, na côr accent (corner ticks), um por vértice.
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
    bg                 = a(p.panel, p.alpha.panel), -- panel@0.92 (.hp bg do kit), fundo do conjuncto
    bgimage            = decoration,
    shape              = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, radius) end,
    shape_border_width = dpi(mt.border_panel),
    shape_border_color = border_color,
    widget             = wibox.container.background,
  }

  if opts.w then outer.forced_width = opts.w end
  if opts.h then outer.forced_height = opts.h end

  -- ────────────────────────────────────────────────────────────────────────
  -- Método outer:panel_set_focus — do engenho do Doutor Braga Us.
  --   DOMÍNIO: `f` (booleano) — declara se o painel está em foco ou activo.
  --   EFEITO: permuta, em tempo de execução (runtime), a côr da borda (viva
  --   line_bright quando f, senão line_base) e a banda do cabeçalho, e emitte
  --   o signal de redesenho. INVARIANTE: `focused` reflecte sempre o último f.
  function outer:panel_set_focus(f)
    focused = f and true or false
    self.shape_border_color = f and p.line_bright or p.line_base
    self:emit_signal("widget::redraw_needed")
  end

  return outer
end

-- Exporta-se a obra como taboa com o método build, e ainda dotada de __call,
-- de sorte que panel(o) e panel.build(o) sejam idênticos em effeito. Q.E.D.
return setmetatable({ build = build }, { __call = function(_, o) return build(o) end })

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
