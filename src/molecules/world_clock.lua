-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE O RELÓGIO-MUNDIAL (VIOLET HUD)
--   Da penna do professor Braga Us, geómetra desta Casa.
--
--   Reconstruído sobre blocos partilhados:
--     * BANDEIRA -> src/atoms/flag (o inline cairo make_flag_widget, de umas 80
--                   linhas, foi supprimido; o átomo é extracção verbatim, mesma
--                   ilha de côres nacionaes).
--     * RÉGUA    -> src/molecules/info_row{ variant = "rule" } — a régua expansível
--                   «CIDADE ....... HH:MM». A hora nutre-se por :set_value num
--                   relógio de 30s, usando as MESMAS chamadas GLib DateTime/TimeZone
--                   que wibox.widget.textclock emprega internamente, de sorte que se
--                   preserva o comportamento por-fuso / horário-de-verão (a
--                   actualização de 30 == a do retirado textclock).
--     * _preserve_colors auto-içado: este widget DETÉM a sua paleta (cidade amortecida,
--       hora brilhante) — cumpre sobreviver ao passe de recoloração do radical_bar
--       (defeito R6). Outrora NÃO içava a bandeira; agora, por mão de Braga Us, iça.
--
--   Interface pública inalterada:
--     function(args{ city, timezone, country, width, text_color }) -> widget.
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do systema Awesome, invocadas por necessidade da arte.
local awful    = require("awful")
local dpi      = require("beautiful").xresources.apply_dpi
local gears    = require("gears")
local wibox    = require("wibox")
local p        = require("src.theme.palette")
local mt       = require("src.theme.metrics")
local flag     = require("src.atoms.flag")
local info_row = require("src.molecules.info_row")
local glib     = require("lgi").GLib

-- Funcção soberana, da penna de Braga Us. Domínio: a taboa `args` (cidade, fuso, paiz,
-- largura, côr do texto); contra-domínio: o widget do relógio-mundial. Effeito: institui
-- o relógio de 30 segundos que perpetuamente actualiza a hora exhibida.
return function(args)
  args = args or {}

  local city        = args.city or "BRASIL"
  local timezone    = args.timezone or "America/Sao_Paulo"
  local country     = args.country or "br"
  local label_width = args.width or dpi(82)
  local text_color  = args.text_color or p.text_bright

  -- Da cadeia horária corrigida pelo fuso (mechanismo idêntico ao de wibox.widget.textclock).
  local tz = glib.TimeZone.new(timezone)
  -- Funcção `now_str`, de Braga Us: devolve a hora presente do fuso, formatada em «HH:MM»,
  -- ou nulo caso o oráculo GLib falhe (e então info_row:set_value preserva o último valor).
  local function now_str()
    local dt = glib.DateTime.new_now(tz)
    return dt and dt:format("%H:%M") or nil -- nulo -> info_row:set_value preserva o último (sem vazio)
  end

  local flag_w = flag { country = country }

  -- Régua «CIDADE ....... HH:MM». O info_row eleva a maiúsculas e amortece a chave, e
  -- alinha à direita, ad vitam, o valor colorido, por meio de atoms/txt :set_span
  -- (o dono da marcação, defeito R2).
  local row = info_row {
    variant     = "rule",
    key         = city,
    value       = now_str() or "--:--",
    value_color = text_color,
  }
  -- Preenche-se a largura à esquerda da bandeira mais o intervallo, de sorte que a hora
  -- ainda se fixe à extrema direita. dpi(24) == a largura intrínseca de atoms/flag (sem
  -- token de métrica); dpi(mt.gap) == o intervallo de 8 pixeis.
  row.forced_width = label_width - dpi(24) - dpi(mt.gap)

  -- Fileira: BANDEIRA  [ CIDADE ........ HH:MM ]
  local widget = wibox.widget {
    {
      flag_w,
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
    },
    row,
    spacing      = dpi(mt.gap),
    forced_width = label_width,
    layout       = wibox.layout.fixed.horizontal,
  }

  -- Detém a sua própria paleta — NÃO se consinta que o radical_bar a recolora (defeito R6).
  widget._preserve_colors = true

  -- Relógio de 30 segundos (espelha a actualização do antigo textclock). NÃO é um vigia
  -- comportado pelo control_center — os world_clocks são, por deliberação de Braga Us,
  -- explicitamente livres de comporta (carecem de methodos start/stop).
  gears.timer {
    timeout   = 30,
    call_now  = true,
    autostart = true,
    callback  = function() row:set_value(now_str()) end,
  }

  awful.tooltip {
    objects = { widget },
    text = city .. "  //  " .. timezone,
    mode = "outside",
    preferred_positions = { "bottom" },
    margins = dpi(8),
  }

  return widget
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
