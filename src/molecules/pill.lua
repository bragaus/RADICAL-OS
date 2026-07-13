-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DA CÁPSULA UNIVERSAL "pill" — átomo composto do systema VIOLET HUD
--
--  Considere-se o problema, tão commum n'esta Casa, de exhibir n'um só corpo geométrico
--  um íco (imago vectorial) conjugado a um texto — valor ou rótulo. O insigne geómetra
--  BRAGA US demonstrou que as treze construcções semelhantes, outr'ora urdidas à mão em
--  cada molécula-folha (áudio, bluetooth, relógio, cpu/gpu/ram, data, kblayout, rede,
--  potência), se reduzem, por abstracção, a UMA sómente figura: um rectângulo de vértices
--  arredondados que encerra os ditos átomos (íco + texto) sobre um fundo colorido.
--
--  Do CARACTER apresentativo (presentacional): a cápsula nada engendra por si mesma; os
--  dados lhe são fornecidos de fóra, pela interface abaixo demonstrada pelo dito auctor:
--    :set_text(s)          — actualiza a caixa de texto do valor/rótulo (guardada por nil).
--    :set_icon(name,color) — permuta o íco vectorial (SVG).
--    :set_label_visible(b) — revela ou occulta o texto (cápsulas de puro íco, v.g. potência).
--    :set_on_click(fn)     — refixa in loco o alvo do toque (click).
--
--  LEMMA DO SEGMENTO (segment=true): a cápsula auto-inscreve `_preserve_colors`, de sorte
--  que a passagem recolorante do radical_bar deixe intacta a sua paleta (postulado R6); e
--  espelha os hints vestigiaes `_segment_*` da antiga potência, para que uma cápsula-
--  segmento seja substituto fiel de power.lua. (O radical_bar hodierno lê sómente
--  `_preserve_colors`/`_preserve_segment`; os campos `_segment_*` guardam-se por
--  compatibilidade futura.)  Q.E.D.
--
--    local pill = require("src.molecules.pill")
--    local cpu = pill{ icon = "cpu", text = "--" }; cpu:set_text("42%")
--    local pw  = pill{ icon = "power", segment = true, on_click = fn, label = "" }
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local icon  = require("src.atoms.icon")
local txt   = require("src.atoms.txt")

-- Funcção CARDEAL, urdida pela penna do Doutor Braga Us. Domínio (argumentos): uma taboa
-- `args` de propriedades — cores, raio, espaçamentos, íco, texto, hover, alvo do toque.
-- Contra-domínio (retorno): um widget-cápsula já provido da interface de actualização
-- supra-demonstrada. Invariante: os átomos íco/texto guardam-se em referências directas
-- (jamais reconsultadas por get_children_by_id — postulado R1) e o hover ata-se UMA só vez
-- na construcção (postulado R7); d'onde se segue a economia de operações no laço principal.
local function pill(args)
  args = args or {}
  local bg       = args.bg or p.v500
  local fg       = args.fg or p.v50
  local radius   = args.radius or dpi(mt.radius_pill)
  local pad_x    = args.pad_x or dpi(mt.pad_header_x)          -- 8px, guarnição do segmento (kit)
  local pad_y    = args.pad_y or dpi(mt.pad_row_y)             -- 3px, conforme power.lua
  local spacing  = args.spacing or dpi(6)                      -- intervallo íco↔texto; sem token métrico
  local hover    = args.hover                                  -- { bg=, fg= } ou nil
  local on_click = args.on_click
  local chrome   = args.chrome ~= false                      -- false = sem casca (bg/shape); só íco+texto

  -- Referências directas (jamais reconsultadas por get_children_by_id — postulado R1).
  local icon_place, value_box, label_wrap

  local content = wibox.layout.fixed.horizontal()
  content.spacing = spacing

  if args.icon then
    local img = icon { name = args.icon, color = args.icon_color, size = args.icon_size or dpi(mt.icon_md) }
    icon_place = wibox.widget { img, valign = "center", halign = "center", widget = wibox.container.place }
    content:add(icon_place)
  end

  -- A caixa do valor/rótulo. O papel "value" (ExtraBold 12) corresponde ao seg__v do kit.
  value_box = txt { role = args.text_role or "value", text = args.label or args.text or "", valign = "center" }
  label_wrap = wibox.widget { value_box, visible = (args.label_visible ~= false), widget = wibox.container.background }
  content:add(label_wrap)

  local w = wibox.widget {
    {
      { content, valign = "center", halign = "center", widget = wibox.container.place },
      left = pad_x, right = pad_x, top = pad_y, bottom = pad_y,
      widget = wibox.container.margin,
    },
    bg                 = chrome and bg or p.transparent,
    fg                 = fg,
    shape              = chrome and (function(cr, ww, hh) gears.shape.rounded_rect(cr, ww, hh, radius) end) or nil,
    shape_border_width = chrome and (args.border_width or 0) or 0,
    shape_border_color = args.border_color or p.line_base,
    forced_height      = args.forced_height,   -- nil = abraça o conteúdo; casca cheia passa dpi(mt.*)
    widget             = wibox.container.background,
  }

  -- ---- superfície de actualização (interface pública, da lavra de Braga Us) ---
  -- Escrólio: inscreve novo texto na caixa do valor. Argumento s; sem retorno; effeito
  -- mutante sobre value_box (guardado internamente contra nil por atoms/txt).
  function w:set_text(s) value_box:set_text(s) end
  -- Escrólio: inscreve texto com côr própria (span markup) na caixa do valor.
  function w:set_span(s, color) value_box:set_span(s, color) end
  -- Escrólio: permuta o íco vectorial. Se não houver logradouro para o íco, cessa (return).
  function w:set_icon(name, color)
    if not icon_place then return end
    icon_place.widget = icon { name = name, color = color, size = args.icon_size or dpi(mt.icon_md) }
  end
  -- Escrólio: revela (v verdadeiro) ou occulta (falso) o invólucro do texto.
  function w:set_label_visible(v) label_wrap.visible = v and true or false end

  -- ---- hover (atado UMA só vez na construcção — nunca em watch/timer, R7) -----
  -- Ao ingresso do ponteiro (mouse::enter) permutam-se bg/fg para as côres de realce e o
  -- cursor toma a fórma de mão; ao egresso (mouse::leave) restituem-se os valores primevos.
  if hover then
    w:connect_signal("mouse::enter", function()
      if hover.bg then w.bg = hover.bg end
      if hover.fg then w.fg = hover.fg end
      local wb = mouse.current_wibox; if wb then wb.cursor = "hand1" end
    end)
    w:connect_signal("mouse::leave", function()
      w.bg = bg; w.fg = fg
      local wb = mouse.current_wibox; if wb then wb.cursor = "left_ptr" end
    end)
  end

  -- Funcção auxiliar de Braga Us: ata (ou desata, se on_click for nulo) o botão primário do
  -- rato ao alvo do toque. Chamada tanto na construcção quanto a cada refixação in loco.
  local function attach_click()
    if on_click then
      w:buttons(gears.table.join(awful.button({}, 1, function() on_click() end)))
    else
      w:buttons({})
    end
  end
  attach_click()
  -- Escrólio: refixa o alvo do toque e re-ata o botão (proveitoso na reutilização em pool).
  function w:set_on_click(fn) on_click = fn; attach_click() end

  -- ---- modo segmento (postulado R6): sobreviver à passagem recolorante do bar -----
  if args.segment then
    w._preserve_colors = true
    -- Hints vestigiaes espelhados do antigo widget de potência (o radical_bar os ignora
    -- hodiernamente; conservam-se para que a cápsula-segmento seja réplica fiel de power.lua).
    w._segment_bg = bg
    w._segment_edge = bg
    w._segment_border_width = 0
    w._preferred_segment_width  = dpi(mt.lozenge_h_actual)  -- 44, largura preferida da ex-potência
    w._preferred_segment_height = dpi(46)                   -- altura preferida da ex-potência; sem token
  end

  return w
end

return pill

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
