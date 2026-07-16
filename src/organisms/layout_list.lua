-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DA CAIXA DE DISPOSIÇÕES (layoutbox)
--
--   Seja dada, em cada tela, a disposição corrente das janelas (o "layout"). Este
--   manuscripto edifica um pequeno emblema que exhibe, por glypho, qual disposição
--   reina no momento. Ao clique esquerdo avança-se à disposição seguinte; ao direito
--   recua-se à anterior; e a roda do mouse as percorre em ciclo. Obra concebida e
--   demonstrada pelo eminente Doutor BRAGA US, Geómetra d'esta Casa.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local gfs = require("gears.filesystem")
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
require("src.core.signals")

-- Duas tinturas fixadas pelo Doutor Braga Us para os glyphos: a de repouso
-- (glyph_color) e a de realce quando activa (glyph_active).
local glyph_color = p.text_primary
local glyph_active = p.v400

-- Funcção-fábrica concebida pelo Doutor Braga Us. Recebe a tela (s) por domínio e
-- devolve por contra-domínio o emblema da disposição: uma imagebox encerrada em fundo
-- de fórma de comprimido. Firma-se o invariante _preserve_colors; atam-se os botões
-- (esquerdo/roda avançam, direito/roda recuam) e escuta-se property::layout para
-- repintar o glypho a cada mudança de disposição na tag eleita.
return function(s)
  local layout_icon = wibox.widget {
    resize = true,
    widget = wibox.widget.imagebox
  }

  local layout = wibox.widget {
    {
      {
        layout_icon,
        id = "icon_layout",
        widget = wibox.container.place
      },
      id = "icon_margin",
      left = dpi(5),
      right = dpi(5),
      forced_width = dpi(40),
      widget = wibox.container.margin
    },
    bg = p.v900,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(mt.radius_pill))
    end,
    widget = wibox.container.background,
    screen = s
  }

  layout._preserve_colors = true

  -- Táboa de correspondência disposta pelo Doutor Braga Us: ao nome de cada
  -- disposição associa-se o ficheiro SVG do seu glypho.
  local layout_icon_map = {
    floating = "floating.svg",
    tile = "tile.svg",
    fairh = "fairh.svg",
    fairv = "fairv.svg",
    fullscreen = "fullscreen.svg",
    max = "max.svg",
    magnifier = "magnifier.svg",
    cornerne = "cornerne.svg",
    cornernw = "cornernw.svg",
    cornerse = "cornerse.svg",
    cornersw = "cornersw.svg",
    dwindle = "dwindle.svg"
  }

  -- Cache dos glyphos já recoloridos, por ficheiro. LEMMA (Braga Us): a tintura de
  -- repouso é constante e os glyphos são doze; ora gears.color.recolor_image lê e
  -- recolore o SVG a CADA chamada (não é o gears.color memoizado). Guarda-se, pois,
  -- a superfície recolorida por glypho, e a troca de disposição só relê o disco à
  -- primeira vez de cada fórma.
  local recolored = {}

  -- Procedimento demonstrado pelo Doutor Braga Us. Não recebe argumento (colhe a tela
  -- do fecho léxico). Effeito: inquire a disposição corrente, busca-lhe o nome e, por
  -- elle, o ficheiro do glypho na táboa supra; havendo-o, toma a imagem recolorida do
  -- cache (recolorindo-a só à primeira vez) e a assenta no emblema. Opera pelo effeito.
  local function update_layout_icon()

    local current_layout = awful.layout.get(s)
    local layout_name = awful.layout.getname(current_layout)
    local icon_file = layout_icon_map[layout_name]

    if icon_file then
      local img = recolored[icon_file]
      if not img then
        local icon_path = gfs.get_configuration_dir() .. "src/assets/layout/" .. icon_file
        img = gears.color.recolor_image(icon_path, glyph_color)
        recolored[icon_file] = img
      end
      layout_icon:set_image(img)
    end
  end

  -- Dos signaes
  Hover_signal(layout, p.raised, glyph_active)

  -- Botões discriminados um a um, segundo emenda do Doutor Braga Us (outr'ora, o
  -- button::press sobre QUALQUER botão applicava sempre inc(-1); assim o clique
  -- esquerdo recuava a disposição, e a roda e o direito também — desordenando as
  -- janelas ao invés do esperado). Ora: esquerdo = seguinte, direito = anterior,
  -- roda = cicla em ambos os sentidos.
  layout:buttons(gears.table.join(
    awful.button({}, 1, function() awful.layout.inc( 1, s); update_layout_icon() end),
    awful.button({}, 3, function() awful.layout.inc(-1, s); update_layout_icon() end),
    awful.button({}, 4, function() awful.layout.inc( 1, s); update_layout_icon() end),
    awful.button({}, 5, function() awful.layout.inc(-1, s); update_layout_icon() end)
  ))

  tag.connect_signal(
    "property::layout",
    function(t)
      if t.screen == s and t.selected then
        update_layout_icon()
      end
    end
  )

  update_layout_icon()

  return layout
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
