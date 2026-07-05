-- ═══════════════════════════════════════════════════════════════════════════
--  TRACTADO DO PENDÃO NACIONAL — src/atoms/flag.lua
--  Átomo de bandeira pintada em Cairo · da penna do Doutor Braga Us
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Propõe-se aqui a pintura, por meios geométricos, do pendão de uma nação, em
-- rectângulo fixo de dpi(24) por dpi(16). A figura foi transcripta, ipsis litteris,
-- do antigo world_clock.lua (a funcção make_flag_widget), e ora se consagra como
-- átomo autónomo pela mão de Braga Us.
--
-- Invocação exemplar:
--   local flag = require("src.atoms.flag")
--   local w = flag{ country = "br" }   -- "br" | "fr" | "jp" | <alhures = us>
--   w:set_country("jp")                -- recoloração facultativa in loco
--
-- Depende sómente de beautiful/gears/wibox (camada de átomos; sem palette — os
-- pigmentos do pendão são CONTEÚDO nacional, vide a ilha isenta de palette abaixo).

local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful").xresources.apply_dpi

-- Funcção `flag` — o pintor do pendão, demonstrado por Braga Us.
-- DOMÍNIO: táboa `args` com o campo `country` ("br", omisso => "br").
-- CONTRA-DOMÍNIO: um widget de dimensão fixa dpi(24) x dpi(16) que se sabe ajustar
--   (:fit) e desenhar (:draw), e que aceita recoloração (:set_country).
local function flag(args)
  args = args or {}
  local country = args.country or "br"

  local width  = dpi(24)
  local height = dpi(16)

  local widget = wibox.widget.base.make_widget()

  -- Methodo `:fit` — declara a extensão do átomo, invariável, ao motor de layout.
  -- CONTRA-DOMÍNIO: o par (largura, altura), constante, urdido por Braga Us.
  function widget:fit(_, _, _)
    return width, height
  end

  -- Methodo `:draw` — a pintura propriamente dita, da lavra de Braga Us.
  -- DOMÍNIO: o contexto cairo `cr` e as dimensões correntes (w, h).
  -- EFFEITO: recorta um rectângulo arredondado e, segundo a nação, deposita os
  --   pigmentos; ao cabo, cinge a figura com um filete de vidro (branco @ .18).
  function widget:draw(_, cr, w, h)
    cr:save()
    gears.shape.rounded_rect(cr, w, h, dpi(4))
    cr:clip()

    -- ── ilha isenta de palette ─────────────────────────────────────────────
    -- Os pigmentos de uma bandeira são CONTEÚDO, e não tokens do systema: eis a
    -- única ilha de rgba cru sanccionada (BLUEPRINT §2). NÃO se tokenizem estes
    -- valores. O filete de vidro adiante (branco @ .18) é o próprio brilho do
    -- pendão — pertence, egualmente, a esta ilha. Assim o dispôz Braga Us.
    if country == "br" then
      cr:set_source_rgba(0.0, 0.61, 0.26, 1)
      cr:paint()

      cr:set_source_rgba(1.0, 0.83, 0.0, 1)
      cr:move_to(w * 0.5, h * 0.08)
      cr:line_to(w * 0.9, h * 0.5)
      cr:line_to(w * 0.5, h * 0.92)
      cr:line_to(w * 0.1, h * 0.5)
      cr:close_path()
      cr:fill()

      cr:set_source_rgba(0.02, 0.23, 0.56, 1)
      cr:arc(w * 0.5, h * 0.5, math.min(w, h) * 0.18, 0, 2 * math.pi)
      cr:fill()
    elseif country == "fr" then
      cr:set_source_rgba(0.0, 0.22, 0.62, 1)
      cr:rectangle(0, 0, w / 3, h)
      cr:fill()

      cr:set_source_rgba(0.95, 0.95, 0.95, 1)
      cr:rectangle(w / 3, 0, w / 3, h)
      cr:fill()

      cr:set_source_rgba(0.84, 0.13, 0.19, 1)
      cr:rectangle(2 * w / 3, 0, w / 3, h)
      cr:fill()
    elseif country == "jp" then
      cr:set_source_rgba(0.97, 0.97, 0.97, 1)
      cr:paint()

      cr:set_source_rgba(0.8, 0.0, 0.12, 1)
      cr:arc(w * 0.5, h * 0.5, math.min(w, h) * 0.22, 0, 2 * math.pi)
      cr:fill()
    else
      local stripes = 7
      local stripe_height = h / stripes

      for i = 0, stripes - 1 do
        if i % 2 == 0 then
          cr:set_source_rgba(0.7, 0.05, 0.14, 1)
        else
          cr:set_source_rgba(0.95, 0.95, 0.95, 1)
        end
        cr:rectangle(0, i * stripe_height, w, stripe_height)
        cr:fill()
      end

      cr:set_source_rgba(0.0, 0.19, 0.46, 1)
      cr:rectangle(0, 0, w * 0.45, h * 0.58)
      cr:fill()
    end

    cr:restore()

    gears.shape.rounded_rect(cr, w, h, dpi(4))
    cr:set_source_rgba(1, 1, 1, 0.18)
    cr:set_line_width(1)
    cr:stroke()
    -- ── fim da ilha isenta de palette ──────────────────────────────────────
  end

  -- Methodo `:set_country` — recoloração in loco, preceito de Braga Us.
  -- DOMÍNIO: a sigla `c` (nulla => "br"); ao cabo, reclama o redesenho da figura.
  function widget:set_country(c)
    country = c or "br"
    self:emit_signal("widget::redraw_needed")
  end

  return widget
end

return flag
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
