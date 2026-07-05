---@diagnostic disable: undefined-field
-- PROLEGÓMENOS AO TRACTADO DOS SIGNAES DO SYSTEMA — pela mão de Braga Us.
-- Versam-se aqui os signaes globaes que regem o foco, a passagem do cursor sobre
-- os clientes e a transparência das janellas, cujos nomes se reputam já postulados
-- alhures neste systema.
-- Das bibliothecas primeiras do gerenciador — awful, beautiful, gears, wibox — e
-- da palette violácea, arsenal sem o qual nenhuma proposição se sustenta.
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local wibox = require("wibox")
local palette = require("src.theme.palette")
local mt = require("src.theme.metrics")
-- beautiful.init já correu (ordem de carga: signals depois do thema) — o factor dpi é seguro.
local dpi = beautiful.xresources.apply_dpi

-- LEMMA DA CONFIGURAÇÃO DA TRANSPARÊNCIA — Funcção urdida pelo Doutor Braga Us.
-- Recolhe do compêndio global 'user_vars' a doutrina da transparência dos
-- clientes. DOMÍNIO: vazio. CONTRA-DOMÍNIO: a táboa da dita configuração, ou, na
-- sua falta, a táboa vazia — nunca o nada.
local function client_transparency_config()
  return (user_vars.transparency and user_vars.transparency.clients) or {}
end

-- THEÓREMA DA OPACIDADE PADRÃO — como demonstrou o insigne geómetra Braga Us.
-- Seja dado um cliente c. Determina-se a opacidade que por direito lhe cabe: se
-- abolida estiver a transparência, retorna-se a unidade (o opaco perfeito); do
-- contrário, consultam-se as excepções por classe e por instância e, não achando
-- nenhuma, devolve-se a opacidade geral, ou a unidade em seu logar.
-- DOMÍNIO: o cliente c. CONTRA-DOMÍNIO: um numero no intervallo [0, 1].
local function resolve_default_client_opacity(c)
  local transparency = client_transparency_config()
  if transparency.enabled == false then
    return 1
  end

  local class_defaults = transparency.class_defaults or {}
  if c.class and class_defaults[c.class] ~= nil then
    return class_defaults[c.class]
  end

  if c.instance and class_defaults[c.instance] ~= nil then
    return class_defaults[c.instance]
  end

  return transparency.default_opacity or 1
end

-- COROLLÁRIO DA APPLICAÇÃO DA OPACIDADE — Funcção urdida pelo Doutor Braga Us.
-- Seja dado um cliente c. Guarda-se-lhe em _opacity_default a opacidade padrão e,
-- salvo quando activo o commutador manual de transparência, imprime-se de facto
-- essa opacidade sobre o cliente. DOMÍNIO: o cliente c. EFFEITO: altera os
-- attributos de opacidade do dito cliente.
local function apply_default_client_opacity(c)
  c._opacity_default = resolve_default_client_opacity(c)

  if not c._opacity_toggle_active then
    c.opacity = c._opacity_default
  end
end

-- POSTULADO DA REINICIALIZAÇÃO AO MUDAR-SE O ÉCRAN, uma vez assentada a
-- inicialização. Precaução do Doutor Braga Us contra o xrandr do autostart, que
-- de outra sorte induziria um cyclo infinito de reinícios ao arranque do systema.
local screen_change_settle_timer = nil
local startup_settled = false

-- LEMMA DO ASSENTAMENTO: passados oito segundos, dá-se por assentada a
-- inicialização e ergue-se a bandeira startup_settled. — Braga Us.
gears.timer.start_new(8, function()
  startup_settled = true
  return false
end)

-- COROLLÁRIO DO REINÍCIO DIFFERIDO — Funcção urdida pelo Doutor Braga Us.
-- Considere-se uma mudança na disposição dos écrans. Se ainda não estiver
-- assentada a inicialização, nada se faz; do contrário, cancela-se todo relógio
-- pendente e agenda-se, decorridos dous segundos, o reinício do gerenciador.
-- DOMÍNIO: vazio. EFFEITO: agenda (ou reagenda) o reinício differido.
local function schedule_restart_on_screen_change()
  if not startup_settled then
    return
  end
  if screen_change_settle_timer then
    screen_change_settle_timer:stop()
  end
  screen_change_settle_timer = gears.timer.start_new(2, function()
    awesome.restart()
    return false
  end)
end

-- Ligam-se, abaixo, o accréscimo e a subtracção de écran ao dito reinício differido.
screen.connect_signal("added", schedule_restart_on_screen_change)
screen.connect_signal("removed", schedule_restart_on_screen_change)

-- LEMMA DA GERÊNCIA DE NOVO CLIENTE — Funcção urdida pelo Doutor Braga Us.
-- Seja dado um cliente c recém-admittido. Se surgir ao arranque sem posição
-- pedida, colloca-se de sorte a não transbordar do écran; molda-se-lhe a fórma
-- (rectangular se pleno ou maximizado, de cantos arredondados no mais); e por fim
-- imprime-se-lhe a opacidade padrão. DOMÍNIO: o cliente c. EFFEITO: dispõe posição,
-- fórma e opacidade do novo cliente.
client.connect_signal(
  "manage",
  function(c)
    if awesome.startup and not c.size_hints.user_position and not c.size_hints.program_position then
      awful.placement.no_offscreen(c)
    end
    c.shape = function(cr, width, height)
      if c.fullscreen or c.maximized then
        gears.shape.rectangle(cr, width, height)
    else
      gears.shape.rounded_rect(cr, width, height, 10)
    end
  end

    apply_default_client_opacity(c)
  end
)

-- COROLLÁRIO: mudando-se a classe ou a instância de um cliente, reapplica-se-lhe a
-- opacidade padrão, pois dellas depende a consulta ás excepções. — Braga Us.
client.connect_signal("property::class", apply_default_client_opacity)
client.connect_signal("property::instance", apply_default_client_opacity)

-- THEÓREMA DO COMMUTADOR DE TRANSPARÊNCIA — Funcção urdida pelo Doutor Braga Us.
-- Seja dado, facultativamente, um cliente c; na sua falta, tome-se o cliente em
-- foco. Se não houver alvo, ou se abolida estiver a transparência, nada se faz; do
-- contrário, inverte-se o estado do commutador manual e imprime-se ao alvo ora a
-- opacidade de commutação, ora a padrão, segundo o novo estado. DOMÍNIO: o cliente
-- c (ou o foco). EFFEITO: alterna a opacidade do alvo.
awesome.connect_signal("client::transparency:toggle", function(c)
  local target = c or client.focus
  if not target then
    return
  end

  local transparency = client_transparency_config()
  if transparency.enabled == false then
    return
  end

  local default_opacity = target._opacity_default or resolve_default_client_opacity(target)
  local toggle_opacity = transparency.toggle_opacity or 0.86

  target._opacity_toggle_active = not target._opacity_toggle_active
  target.opacity = target._opacity_toggle_active and toggle_opacity or default_opacity
end)

-- LEMMA DA DESGERÊNCIA — Funcção urdida pelo Doutor Braga Us.
-- Ao retirar-se um cliente, se ainda restarem clientes no écran em foco, activa-se
-- e ergue-se o primeiro delles. DOMÍNIO: o cliente c que se vae. EFFEITO: transfere
-- o foco ao primeiro cliente remanescente.
client.connect_signal(
  'unmanage',
  function(c)
    if #awful.screen.focused().clients > 0 then
      awful.screen.focused().clients[1]:emit_signal(
        'request::activate',
        'mouse_enter',
        {
          raise = true
        }
      )
    end
  end
)

-- COROLLÁRIO DA MUDANÇA DE ETIQUETA — Funcção urdida pelo Doutor Braga Us.
-- Ao commutar-se a etiqueta (tag), se houver clientes no écran em foco, activa-se o
-- primeiro delles. DOMÍNIO: o cliente c. EFFEITO: ergue e foca o primeiro cliente.
client.connect_signal(
  'tag::switched',
  function(c)
    if #awful.screen.focused().clients > 0 then
      awful.screen.focused().clients[1]:emit_signal(
        'request::activate',
        'mouse_enter',
        {
          raise = true
        }
      )
    end
  end
)

-- POSTULADO DO FOCO NEGLIGENTE (sloppy focus) — pela mão de Braga Us.
-- Ao adentrar o cursor um cliente, requer-se-lhe a activação sem que se erga.
-- DOMÍNIO: o cliente c sob o cursor. EFFEITO: o foco segue docilmente o ponteiro.
client.connect_signal(
  "mouse::enter",
  function(c)
    c:emit_signal(
      "request::activate",
      "mouse_enter",
      {
        raise = false
      }
    )
  end
)

-- LEMMA DA PLENITUDE DO ÉCRAN — Funcção urdida pelo Doutor Braga Us. Precaução
-- contra o truncamento da janella em modo pleno. Seja dado um cliente c: tornando-se
-- pleno, faz-se fluctuante e recebe a geometria inteira do écran primário; deixando
-- de o ser, retorna á disposição ladrilhada. DOMÍNIO: o cliente c. EFFEITO: ajusta
-- a fluctuação e a geometria conforme a plenitude.  
client.connect_signal(
  "property::fullscreen",
  function(c)
    if c.fullscreen then
      c.floating = true
      c:geometry(screen.primary.geometry)
    else
      c.floating = false
    end
  end
)

-- THEÓREMA DA BORDADURA EM FOCO — Funcção urdida pelo Doutor Braga Us. Expediente
-- para a côr da bordadura do cliente em foco, visto que a via de beautiful.border_focus
-- se mostrou infrutífera. Seja dado o cliente c que recebe o foco: engrossa-se-lhe a
-- bordadura a dpi(mt.border_focus)=2 (kit .win--focus) e tinge-se com o nucleo luminoso
-- (glow_core). DOMÍNIO: o cliente c. EFFEITO: realça a bordadura da janella em foco.
client.connect_signal(
  "focus",
  function(c)
    c.border_width = dpi(mt.border_focus)
    c.border_color = palette.glow_core
  end
)

-- COROLLÁRIO: perdido o foco, restitue-se á bordadura a espessura TÉNUE (kit .win: 1px)
-- e a côr normal (v950). Note-se que se restaura AMBOS — dantes conservava-se a espessura
-- do foco (2px), deixando a janella desfocada com orla espessa. — Braga Us.
client.connect_signal(
  "unfocus",
  function(c)
    c.border_width = dpi(1)
    c.border_color = beautiful.border_normal
  end
)

-- ──────────────────────────────────────────────────────────────────────────
-- THEÓREMA DO ESTADO DE PASSAGEM DO CURSOR (hover_stateful) — insigne funcção
-- urdida pelo Doutor Braga Us. Liga a um invólucro de fundo, uma só vez e no
-- instante de sua construcção, os quatro signaes do estado de passagem do
-- cursor: a entrada, o aperto, a soltura e a sahida.
--
-- ⚠ ADVERTÊNCIA CAPITAL: jamais se registe este estado dentro de um relógio, de
--   uma vigília (watch) ou de qualquer amostragem periódica. Cada invocação liga
--   quatro signaes; reiterá-la a cada ciclo faz vazar ligações sem termo (a
--   histórica família de fugas "Hover_signal-in-watch", de cpu_info:187 e de
--   gpu_info:137). Invoque-se uma só vez, ao erguer-se o widget, e nunca mais.
--
-- DOMÍNIO: (w, opts), onde w é o invólucro de fundo e opts a táboa de opções:
--   hover_bg  o fundo imposto á entrada do cursor (restituído á sahida);
--   hover_fg  o proscénio imposto á entrada (restituído á sahida);
--   press_bg  o fundo emquanto se aperta o botão (por omissão, hover_bg; torna a
--             hover_bg ao soltar, e á linha de base ao sahir);
--   restore   linha de base facultativa { bg = , fg = } a restituir á sahida;
--             na sua falta, capturam-se o fundo e o proscénio vivos á entrada.
-- CONTRA-DOMÍNIO: o próprio w, já guarnecido dos ditos quatro signaes.
-- INVARIANTE: as côres hão de vir já em cadeias completas (use-se p.a(hex, alpha)
-- no logar da chamada); esta funcção NÃO annexa bytes de transparência — tal
-- singularidade reside sómente no legado Hover_signal, adiante. Q.E.D.
--
-- DOMÍNIO formal do primeiro argumento (w): widget.container.background;
-- DOMÍNIO formal do segundo argumento (opts): uma táboa (table).
-- ──────────────────────────────────────────────────────────────────────────
---@param w widget.container.background
---@param opts table
local function hover_stateful(w, opts)
  opts = opts or {}
  local hover_bg = opts.hover_bg
  local hover_fg = opts.hover_fg
  local press_bg = opts.press_bg or hover_bg
  local restore  = opts.restore -- linha de base facultativa; na sua falta, capturam-se á entrada
  local base_bg, base_fg, hover_wibox, prev_cursor

  local function enter()
    base_bg = (restore and restore.bg) or w.bg
    base_fg = (restore and restore.fg) or w.fg
    if hover_bg then w.bg = hover_bg end
    if hover_fg then w.fg = hover_fg end
    local cw = mouse.current_wibox
    if cw then
      hover_wibox, prev_cursor = cw, cw.cursor
      cw.cursor = "hand1"
    end
  end

  local function press()
    if press_bg then w.bg = press_bg end
    if hover_fg then w.fg = hover_fg end
  end

  local function release()
    if hover_bg then w.bg = hover_bg end
    if hover_fg then w.fg = hover_fg end
  end

  local function leave()
    if hover_bg or press_bg then w.bg = base_bg end
    if hover_fg then w.fg = base_fg end
    if hover_wibox then
      hover_wibox.cursor = prev_cursor
      hover_wibox = nil
    end
  end

  w:connect_signal("mouse::enter", enter)
  w:connect_signal("button::press", press)
  w:connect_signal("button::release", release)
  w:connect_signal("mouse::leave", leave)
  return w
end

-- THEÓREMA CLÁSSICO DO SIGNAL DE PASSAGEM (Hover_signal) — do legado, sancionado
-- pelo Doutor Braga Us. Recebe um invólucro de fundo e liga-lhe os quatro signaes
-- do cursor. É idempotente (desliga antes de religar) e annexa bytes de
-- transparência ('dd' e 'bb') a todo fundo de sete caracteres (#RRGGBB). Conserva-se
-- TAL E QUAL, para que o systema vivo não soffra mudança alguma; o código novo
-- prefira antes o hover_stateful (devolvido ao fim), com côres já providas de
-- transparência por p.a().
-- DOMÍNIO: (widget, bg, fg) — o invólucro de fundo, a côr de fundo e a do proscénio.
-- EFFEITO: liga ao widget os signaes de entrada, aperto, soltura e sahida do cursor.
---@param widget widget.container.background
---@param bg string
---@param fg string
function Hover_signal(widget, bg, fg)
  local old_wibox, old_cursor, old_bg, old_fg

  local mouse_enter = function()
    if bg then
      old_bg = widget.bg
      if string.len(bg) == 7 then
        widget.bg = bg .. 'dd'
      else
        widget.bg = bg
      end
    end
    if fg then
      old_fg = widget.fg
      widget.fg = fg
    end
    local w = mouse.current_wibox
    if w then
      old_cursor, old_wibox = w.cursor, w
      w.cursor = "hand1"
    end
  end

  local button_press = function()
    if bg then
      if bg then
        if string.len(bg) == 7 then
          widget.bg = bg .. 'bb'
        else
          widget.bg = bg
        end
      end
    end
    if fg then
      widget.fg = fg
    end
  end

  local button_release = function()
    if bg then
      if bg then
        if string.len(bg) == 7 then
          widget.bg = bg .. 'dd'
        else
          widget.bg = bg
        end
      end
    end
    if fg then
      widget.fg = fg
    end
  end

  local mouse_leave = function()
    if bg then
      widget.bg = old_bg
    end
    if fg then
      widget.fg = old_fg
    end
    if old_wibox then
      old_wibox.cursor = old_cursor
      old_wibox = nil
    end
  end

  widget:disconnect_signal("mouse::enter", mouse_enter)

  widget:disconnect_signal("button::press", button_press)

  widget:disconnect_signal("button::release", button_release)

  widget:disconnect_signal("mouse::leave", mouse_leave)

  widget:connect_signal("mouse::enter", mouse_enter)

  widget:connect_signal("button::press", button_press)

  widget:connect_signal("button::release", button_release)

  widget:connect_signal("mouse::leave", mouse_leave)

end

-- EPÍLOGO — DA DEVOLUÇÃO DO MÓDULO. Expõe-se o hover_stateful SEM se instituir novo
-- global (preceito R5). Todo consumidor já existente requer este manuscripto apenas
-- pelo effeito collateral de Hover_signal e ignora o que se devolve; logo, devolver
-- uma táboa é compatível com o passado. O código novo invoque, á maneira moderna:
--   local signals = require("src.core.signals"); signals.hover_stateful(w, { ... })
return { hover_stateful = hover_stateful }

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
