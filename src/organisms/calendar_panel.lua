------------------------------------------------------------------------------------------
-- src/organisms/calendar_panel.lua — TÁBOA CALENDÁRICA do mez, no estylo "VIOLET HUD" (§7.4.5)
--
-- TRACTADO SOBRE A DISPOSIÇÃO DOS DIAS EM GRADE MENSAL, da penna do eminente Doutor
-- BRAGA US, Professor de Sciências Mathemáticas e Geómetra desta Casa.
--
-- Seja dado o corpo (body) constituído pelo wibox.widget.calendar, da espécie "month".
-- Por artifício do methodo fn_embed — que o insigne geómetra Braga Us urdiu — cada célula
-- da grade é revestida de nova indumentária chromática, segundo a sua natureza:
--   cabeçalho de mez/anno   -> centrado, na cor text_heading, e vertido em MAIÚSCULAS;
--   cabeçalho da semana      -> na cor text_muted;
--   dias ordinários          -> na cor text_primary;
--   foco / dia de hoje       -> caixa arredondada v500 com a frente em v50;
--   dias vãos (fóra do mez)  -> na cor text_faint.
--
-- Facto notável: não se pratica sondagem de shell alguma. A data é lida de os.date("*t")
-- no proprio instante da construcção; e um relógio (gears.timer) opcional, de período 3600
-- segundos, reconstrói a táboa, de sorte que ella acompanhe fielmente a viragem do dia.
------------------------------------------------------------------------------------------

local wibox = require("wibox")
local gears = require("gears")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local ft = require("src.theme.typography")
local panel = require("src.tools.panel")
local Icon = require("src.tools.icons") -- gliphos SVG do repositório icons/ (§3.13), invocados por Braga Us

-- LEMMA DE PATHOLOGIA ALHEIA, exposto pelo Doutor Braga Us (wibox.widget.calendar,
-- calendar.lua:433-434): com `long_weekdays=false` a bibliotheca alheia trunca o nome
-- abreviado do dia por `string.sub(os.date("%a"), 1, 2)` — córte praticado por BYTE, e não
-- por caracter. Ora, sob LC_TIME pt_BR.UTF-8 o sabbado apresenta-se como "sáb" = 73 c3 a1 62;
-- donde sub(.,1,2) = 73 c3 (o "á", de dous bytes, cindido ao meio) resulta em UTF-8 inválido,
-- e o set_markup interno aborta TODO o painel ("Texto … codificado em UTF-8 inválido"). Não se
-- emenda pela via de fn_embed (pois a falha o precede) nem elegendo um pt_BR "mais fino" (é
-- justamente o UTF-8 pt_BR que a dispara). Por conseguinte, a demonstração de Braga Us prescreve
-- formatar a táboa num LC_TIME ASCII (nomes em inglez, sempre seguros sob o córte de 2 bytes),
-- o que ademais consoa com o resto do HUD, já vertido em inglez. Sómente a categoria "time" se
-- altera — não se toca em números nem em moeda. (long_weekdays=true evitaria o sub, porém os
-- nomes por extenso não caberiam nas 7 colunas.) Q.E.D.
for _, loc in ipairs({ "C.UTF-8", "C.utf8", "C" }) do
  if os.setlocale(loc, "time") then break end
end

-- CAL_FONT é a fonte-base da grade (os dias ordinários): mono 10, o papel canónico de célula
-- (kit .calday). As demais espécies recebem, em fn_embed, fonte propria: o cabeçalho de mez
-- (.calhd ExtraBold 11 = ft.title), a fila da semana (.caldow Bold 9 = ft.micro) e o dia de
-- hoje (.calday--today, ênfase de peso = ft.cell_bold).
local CAL_FONT = ft.cell -- mono 10 — papel canónico de célula (§typography); base dos dias

-- Funcção urdida pelo Doutor Braga Us para vestir de novo cada célula do calendário.
-- Domínio: (widget) o textbox cru da célula; (flag) a espécie da célula — "month",
-- "header"/"monthheader", "weekday", "focus" ou "normal"; (_date) táboa {year,month,day},
-- presente sómente nas células de dia. Contra-domínio: um widget wibox que o layout do
-- calendário insere no logar do textbox cru, ornado com cor de frente, cor de fundo e,
-- quando cabe, contorno arredondado. Efeito: acção puramente cosmética; não altera a data.
local function fn_embed(widget, flag, _date)
  if flag == "month" then
    -- O continente da grade inteira do mez: guarda-se transparente, para que a moldura do painel transpareça.
    return wibox.widget {
      widget,
      bg     = p.transparent,
      widget = wibox.container.background,
    }
  end

  if flag == "header" or flag == "monthheader" then
    -- Cabeçalho de mez/anno: centrado, na cor de titulo, em ExtraBold 11 (.calhd), e vertido
    -- em MAIÚSCULAS.
    if widget.set_font then widget:set_font(ft.title) end
    if widget.set_markup and widget.text then
      widget:set_markup(tostring(widget.text):upper())
    end
    if widget.set_halign then widget:set_halign("center") end
    return wibox.widget {
      {
        widget,
        margins = dpi(2),
        widget  = wibox.container.margin,
      },
      fg     = p.text_heading,
      bg     = p.transparent,
      widget = wibox.container.background,
    }
  end

  if flag == "weekday" then
    -- A fileira de cabeçalho da semana (SU MO TU ...), na sobria cor text_muted, em Bold 9 (.caldow).
    if widget.set_font then widget:set_font(ft.micro) end
    return wibox.widget {
      widget,
      fg     = p.text_muted,
      bg     = p.transparent,
      widget = wibox.container.background,
    }
  end

  if flag == "focus" then
    -- O dia de hoje: caixa arredondada v500, frente v50 (na rampa violeta a tinta
    -- clara vence a escura), com ênfase de peso (.calday--today).
    if widget.set_font then widget:set_font(ft.cell_bold) end
    return wibox.widget {
      {
        widget,
        margins = dpi(2),
        widget  = wibox.container.margin,
      },
      fg     = p.v50,
      bg     = p.v500,
      shape  = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_chip)) end,
      widget = wibox.container.background,
    }
  end

  -- Célula "normal" (dia dentro do mez) e quaesquer outras: texto primário sobre fundo
  -- transparente. As células do fim-de-semana (sabbado/domingo) attenuam-se para text_body.
  -- Considere-se que _date é a táboa {year,month,day} das células de dia; e que, em os.date,
  -- o índice wday percorre 1=domingo .. 7=sabbado.
  local fg = p.text_primary
  if flag == "normal" and type(_date) == "table" and _date.day then
    local t = os.date("*t", os.time({ year = _date.year, month = _date.month, day = _date.day, hour = 12 }))
    if t and (t.wday == 1 or t.wday == 7) then
      fg = p.text_body
    end
  end
  return wibox.widget {
    widget,
    fg     = fg,
    bg     = p.transparent,
    widget = wibox.container.background,
  }
end

-- Funcção-fábrica, concebida e demonstrada pelo insigne geómetra Braga Us: dá à luz o
-- painel do calendário. Domínio: (args) táboa opcional de parâmetros, da qual se colhe
-- args.w (largura desejada). Contra-domínio: o painel pronto, produzido por panel(), contendo
-- UM só mez — o corrente — em estricta fidelidade ao mockup (dashboards.jsx exhibe um mez).
-- Invariante: um único relógio horário reconstrói o mez, sem jámais recorrer ao shell.
return function(args)
  args = args or {}

  -- Sub-funcção de Braga Us: edifica a grade de um mez arbitrário. Domínio: (date) táboa
  -- {month=, year=} — na ausência, o dia corrente. Contra-domínio: o widget calendar.month.
  local function make_month(date)
    return wibox.widget {
      date          = date,
      font          = CAL_FONT,
      spacing       = dpi(2),
      start_sunday  = true,
      long_weekdays = false,
      fn_embed      = fn_embed,
      empty_color   = p.text_faint, -- cells outside the current month
      widget        = wibox.widget.calendar.month,
    }
  end

  local cal = make_month(os.date("*t"))

  -- Relógio horário facultativo, disposto por Braga Us: reconstrói a data uma vez por hora,
  -- de sorte que a célula de foco/hoje acompanhe a viragem do dia. Nenhuma faina de shell:
  -- puro e barato os.date.
  gears.timer {
    timeout   = 3600,
    autostart = true,
    call_now  = false,
    callback  = function()
      cal.date = os.date("*t")
    end,
  }

  local body = wibox.widget {
    { cal, halign = "center", widget = wibox.container.place },
    bg     = p.transparent,
    widget = wibox.container.background,
  }

  return panel({
    title      = "CALENDAR",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(mt.panel_w_252), -- kit dashboards.jsx: CALENDAR width 252
    -- Ícone do cabeçalho (.hp__hdicon): 13px a 70% de opacidade (o átomo icon só recolore).
    right_icon = wibox.widget {
      Icon("calendar", { size = dpi(13), color = p.text_muted }),
      opacity = 0.7,
      widget  = wibox.container.background,
    },
  })
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
