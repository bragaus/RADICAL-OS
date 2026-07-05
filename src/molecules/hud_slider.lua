-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO CURSOR "hud_slider" — o régulo horizontal do systema (VIOLET HUD)
--
--  Delgado invólucro sobre wibox.widget.slider, na feição do HUD (trilho embutido, enchimento
--  em gradiente, punho circular v500) e — o que é CAPITAL — com uma guarda `syncing` cozida
--  em :set_value, de sorte que um ajuste PROGRAMMÁTICO jamais re-dispare on_change. Como
--  demonstrou o insigne geómetra BRAGA US, isto extingue o clássico laço de retro-alimentação
--  em que sondar o backend (pactl/brilho) fixava o cursor, o que disparava property::value, o
--  que re-corria o ajustador, o que re-sondava... ad infinitum.
--
--    * on_change(v)         dispara nos arrastos do usuário (via o :set_value nativo que o
--                           arrasto chama).
--    * :set_value_silent(v) tonumber + guarda de nil; fixa o valor SEM disparar on_change.
--    * :set_on_change(fn)   refixa o manejador (reutilização em pool).
--
--  Variante de tamanho (volume_controller): passe track_h = dpi(5), handle_w = dpi(15).
--  Puramente apresentativo — nada engendra nem sonda (o organismo proprietário o conduz).
--
--    local hud_slider = require("src.molecules.hud_slider")
--    local s = hud_slider{ span_w = dpi(232), on_change = function(v) set_volume(v) end }
--    s:set_value_silent(57)   -- vindo do sondador; on_change permanece mudo
-- ══════════════════════════════════════════════════════════════════════════════════════

local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")

-- Funcção CARDEAL, da penna do professor Braga Us. Domínio: taboa `args` (altura do trilho,
-- largura do punho, máximo, alcance do gradiente, feição do enchimento, manejador on_change).
-- Contra-domínio: um widget-cursor provido de :set_value_silent e :set_on_change. Invariante
-- fundamental: on_change dispara sómente nos arrastos humanos, nunca nas escritas do sondador.
local function hud_slider(args)
  args = args or {}
  local track_h   = args.track_h or dpi(8)      -- trilho do OSD (kit .bm__track); sem token métrico
  local handle_w  = args.handle_w or dpi(10)    -- a variante de tamanho passa dpi(15)
  local maximum   = args.max or 100
  local span_w    = args.span_w or dpi(mt.osd_w) -- alcance do gradiente (px de dispositivo)
  local on_change = args.on_change

  -- enchimento: "gradient" (defeito) => v700 -> v500 ao longo de span_w; senão, token de côr sólida.
  local active_color
  if args.fill == nil or args.fill == "gradient" then
    active_color = {
      type  = "linear",
      from  = { 0, 0 }, to = { span_w, 0 },
      stops = { { 0, p.v700 }, { 1, p.v500 } },
    }
  else
    active_color = args.fill
  end

  local slider = wibox.widget {
    bar_shape           = gears.shape.rounded_bar,
    bar_height          = track_h,
    bar_color           = p.inset,
    bar_active_color    = active_color,
    handle_color        = p.v500,
    handle_shape        = gears.shape.circle,
    handle_width        = handle_w,
    handle_border_color = p.line_bright,
    maximum             = maximum,
    widget              = wibox.widget.slider,
  }

  -- Guarda `syncing`: verdadeira sómente enquanto um ajuste programmático MUDO está em curso.
  local syncing = false

  -- Lemma do laço: property::value dispara on_change nos ARRASTOS do usuário (o manejador de
  -- arrasto do wibox chama o :set_value público nativo), mas é engolido durante
  -- :set_value_silent, para que as escritas do sondador jamais re-disparem on_change (o laço
  -- de retro-alimentação pactl/brilho). O :set_value público fica NATIVO de propósito —
  -- sobrescrevê-lo engoliria TAMBÉM os arrastos, matando o cursor. Q.E.D.
  slider:connect_signal("property::value", function()
    if syncing then return end
    if on_change then on_change(slider.value) end
  end)

  -- Escrólio mudo, para os sondadores: fixa o valor SEM disparar on_change. Guardado por nil.
  local raw_set_value = slider.set_value
  function slider:set_value_silent(v)
    v = tonumber(v)
    if v == nil then return end         -- conserva o último valor, jamais estala (crash)
    syncing = true
    raw_set_value(self, v)              -- emitte property::value synchronamente -> engolido
    syncing = false
  end

  -- Escrólio: refixa o manejador on_change (proveitoso à reutilização em pool).
  function slider:set_on_change(fn) on_change = fn end

  return slider
end

return hud_slider

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
