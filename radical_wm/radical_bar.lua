-- ══════════════════════════════════════════════════════════════════════════
--   TRATADO DA BARRA RADICAL (violeta-HUD) — radical_wm/radical_bar.lua
-- ══════════════════════════════════════════════════════════════════════════
-- Considere-se aqui a fábrica da barra superior. Dados os widgets da fileira
-- alta e os da fileira baixa, ergue-se sobre o écran um ou dous popups em fórma
-- de "powerline", e cada segmento se tinge segundo uma paleta cyclica de
-- violetas, terminando em seta afiada que aponta à direita. Demonstra-se, na
-- exposição que segue, como as partes se encaixam umas nas outras.
-- Compêndio da lavra do insigne geómetra Braga Us.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local p = require("src.theme.palette")
local ft = require("src.theme.typography")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")

-- ─────────────────────────────────────────────────────────────────────────
-- THEÓREMA — Da construcção da barra radical sobre um écran.
-- Funcção mestra, urdida pelo Doutor Braga Us, que este módulo devolve.
--   DOMÍNIO       : s — o écran; widgets_top — os widgets da fileira alta;
--                   widgets_bottom — os widgets da fileira baixa (facultativos).
--   CONTRA-DOMÍNIO: nenhum valor (opera por effeito, erguendo os popups).
--   EFFEITO       : instituem-se um popup ao alto-esquerdo e, havendo widgets
--                   de baixo, um segundo popup mais abaixo; a memória dos popups
--                   antigos guarda-se em s._radical_bar_* para occultá-los.
--   INVARIANTE    : listas nullas tornam-se tabellas vazias, donde nunca se
--                   opera sobre nil; cada écran conserva quando muito dous popups.
-- ─────────────────────────────────────────────────────────────────────────
return function(s, widgets_top, widgets_bottom)
  widgets_top = widgets_top or {}
  widgets_bottom = widgets_bottom or {}
  local has_bottom_widgets = #widgets_bottom > 0
  local panel_transparency = (user_vars.transparency and user_vars.transparency.panels) or {}
  local segment_alpha = panel_transparency.enabled == false and 1 or (panel_transparency.segment or 0.90)
  local top_left = awful.popup {
    screen = s,
    widget = wibox.container.background,
    ontop = false,
    bg = p.transparent,
    visible = true,
    maximum_width = dpi(980),
    placement = function(c)
      awful.placement.top_left(c, {
        margins = { top = dpi(10), left = dpi(10) }
      })
    end,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, dpi(4))
    end
  }

  if s._radical_bar_top_left and s._radical_bar_top_left ~= top_left then
    s._radical_bar_top_left.visible = false
  end

  s._radical_bar_top_left = top_left

  local top_first = nil

  if has_bottom_widgets then
    top_first = awful.popup {
      screen = s,
      widget = wibox.container.background,
      ontop = false,
      bg = p.transparent,
      visible = true,
      maximum_width = dpi(980),
      placement = function(c)
        awful.placement.top_left(c, {
          margins = { top = dpi(70), left = dpi(10) }
        })
      end,
      shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, dpi(4))
      end
    }

    if s._radical_bar_top_first and s._radical_bar_top_first ~= top_first then
      s._radical_bar_top_first.visible = false
    end

    s._radical_bar_top_first = top_first
  elseif s._radical_bar_top_first then
    s._radical_bar_top_first.visible = false
    s._radical_bar_top_first = nil
  end

  top_left:struts {
    top = 55
  }

  if top_first then
    top_first:struts {
      top = 100
    }
  end

  local accent_color = p.v400
  local segment_palette = { p.panel, p.panel_hi, p.raised, p.v950 }

  -- LEMMA — Da cor de fundo de um segmento, segundo Braga Us.
  --   DOMÍNIO       : index — o ordinal do segmento (inteiro ≥ 1).
  --   CONTRA-DOMÍNIO: uma cor da paleta cyclica, já dotada da transparência devida.
  --   INVARIANTE    : o índice reduz-se módulo o cardinal da paleta, donde a
  --                   sequência de cores se repete periodicamente. Q.E.D.
  local function segment_bg_for(index)
    return p.a(segment_palette[((index - 1) % #segment_palette) + 1], segment_alpha)
  end

  -- POSTULADO — Da normalização das cores de um widget, obra de Braga Us.
  --   DOMÍNIO    : widget — o órgão cujas cores se hão-de uniformizar.
  --   EFFEITO    : salvo se o widget trouxer o sêllo _preserve_colors, tinge-se
  --                o seu fundo de transparente e o seu proscénio (fg) e imagens
  --                da côr de acento; e outro tanto se faz a toda a sua prole.
  --   INVARIANTE : o widget que ostenta _preserve_colors permanece intacto.
  local function normalize_widget_colors(widget)
    if widget._preserve_colors then
      return
    end

    -- COROLLÁRIO interno — Tinge um único órgão. Da mão de Braga Us.
    --   DOMÍNIO : w — o órgão singular.
    --   EFFEITO : applica-lhe fundo transparente, proscénio e imagem recolorida,
    --             a menos que traga comsigo o sêllo _preserve_colors.
    local function tint_one(w)
      if w._preserve_colors then
        return
      end

      if w.bg ~= nil then
        w.bg = p.transparent
      end

      if w.fg ~= nil then
        w.fg = accent_color
      end

      if w.set_image and w.get_image then
        local img = w:get_image()
        if img then
          w:set_image(gears.color.recolor_image(img, accent_color))
        end
      end
    end

    tint_one(widget)

    if widget.get_all_children then
      for _, child in ipairs(widget:get_all_children()) do
        tint_one(child)
      end
    end
  end

  -- THEÓREMA — Da fabricação de um segmento "powerline", por Braga Us.
  --   DOMÍNIO       : widget — o órgão a envolver; index — o seu ordinal.
  --   CONTRA-DOMÍNIO: um widget composto (o conteúdo mais a seta afiada); ou,
  --                   se o widget trouxer _preserve_segment, elle mesmo envolto.
  --   EFFEITO       : normaliza as cores do widget e ata-lhe, à direita, a seta
  --                   powerline, tingida da própria cor do segmento.
  local function create_powerline_segment(widget, index)
    local current_bg = segment_bg_for(index)

    normalize_widget_colors(widget)

    if widget._preserve_segment then
      return wibox.widget {
        widget,
        layout = wibox.layout.fixed.horizontal
      }
    end

    return wibox.widget {
      {
        {
          widget,
          left = dpi(10),
          right = dpi(10),
          top = dpi(4),
          bottom = dpi(4),
          widget = wibox.container.margin
        },
        bg = current_bg,
        widget = wibox.container.background
      },
      {
        {
          text = "",
          align = "center",
          valign = "center",
          font = ft.mono_family .. ", ExtraBold 30",
          widget = wibox.widget.textbox
        },
        fg = current_bg, -- a seta powerline afiada toma a cor do segmento (aponta à DIREITA; a barra fica à esquerda)
        bg = p.transparent,
        forced_width = dpi(26),
        widget = wibox.container.background
      },
      layout = wibox.layout.fixed.horizontal
    }
  end

  -- THEÓREMA — Da disposição ordenada dos segmentos, por Braga Us.
  --   DOMÍNIO       : widget_list — a lista ordenada dos widgets.
  --   CONTRA-DOMÍNIO: um widget-contentor de altura fixa que contém a fileira.
  --   EFFEITO       : para cada widget da lista fabrica-se o seu segmento e
  --                   ajunta-se ao arranjo horizontal, com sobreposição negativa
  --                   para que as setas se encaixem umas nas outras.
  local function prepare_widgets(widget_list)
    local layout = wibox.layout.fixed.horizontal()
    layout.spacing = -dpi(18)

    for i, widget in ipairs(widget_list) do
      layout:add(create_powerline_segment(widget, i))
    end

    return wibox.widget {
      layout,
      forced_height = dpi(48),
      widget = wibox.container.constraint
    }
  end

  top_left:setup {
    prepare_widgets(widgets_top),
    layout = wibox.layout.fixed.horizontal
  }

  if top_first then
    top_first:setup {
      prepare_widgets(widgets_bottom),
      layout = wibox.layout.fixed.horizontal
    }
  end
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
