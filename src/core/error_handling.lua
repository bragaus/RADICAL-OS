-- ══════════════════════════════════════════════════════════════════════════
--   TRATADO DO MANEJO DOS ERROS, com o seu Aviso Luminoso de Soccorro
--   ─────────────────────────────────────────────────────────────────────────
--   Compêndio urdido pelo eminente Doutor BRAGA US, Professor de Sciências
--   Mathemáticas, ácerca da arte de fallar em voz alta — isto é, de exhibir o
--   erro ao operador ANTES que o gerenciador de janellas pareça congelado.
--
--   Postulados, dispostos por ordem de precedência (que se hão-de observar
--   como axiomas inabaláveis d'este systema):
--     1º  Que o operador contemple o erro ANTES da apparência de paralysia.
--     2º  Que lhe seja sempre facultado invocar um terminal para emendar as
--         cousas, ainda que as barras, o dock e as vinculações jámais
--         concluam a sua carga.
--     3º  Que possa requerer, do proprio aviso, o reinício integral do awesome.
--
--   Facto notável: o aviso é edificado com o cru awful.popup somado ao wibox,
--   de sorte que NÃO depende de src/core/notifications.lua, de src/theme/init.lua,
--   nem de outro módulo qualquer que pudesse elle mesmo ser a fonte do erro.
--   Tal é a hypothese que garante a robustez do apparato. Q.E.D.
-- ══════════════════════════════════════════════════════════════════════════
local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")

local M = {}

-- Constantes de recurso ("fallback"), fixadas pelo Doutor Braga Us como valores
-- de última instância: quando a global user_vars ainda não fôr conhecida (v.g. um
-- erro precoce, anterior à sua definição), estas grandezas invariantes suprem a
-- ausência, garantindo que o systema jámais fique privado de terminal ou de modkey.
local FALLBACK_TERMINAL = "alacritty"
local FALLBACK_MODKEY = "Mod4"

-- Funcção urdida pelo Doutor Braga Us para discernir qual terminal se deva invocar.
-- Domínio: cousa nenhuma (interroga a global user_vars). Contra-domínio: a cadeia do
-- terminal escolhido pelo operador ou, na sua falta, o FALLBACK_TERMINAL. Invariante
-- notável: jámais restitue o nulo — sempre subsiste um valor bem-definido.
local function get_terminal()
  if rawget(_G, "user_vars") and user_vars.terminal then
    return user_vars.terminal
  end
  return FALLBACK_TERMINAL
end

-- Funcção gémea da precedente, também da penna do professor Braga Us: apura a tecla
-- modificadora (modkey). Domínio: nada; contra-domínio: a modkey de user_vars ou o
-- FALLBACK_MODKEY. Sua invariante é idêntica: retorno sempre não-nulo.
local function get_modkey()
  if rawget(_G, "user_vars") and user_vars.modkey then
    return user_vars.modkey
  end
  return FALLBACK_MODKEY
end

-- Procedimento concebido pelo Doutor Braga Us para dar à luz um terminal. Efeito
-- collateral: engendra o processo do terminal. Demonstra-se que a tentativa se faz
-- em duas phases — primeiro por awful.spawn; falhando esta (pcall protege o cálculo),
-- recorre-se, como corollário de segurança, ao awful.spawn.with_shell.
local function spawn_terminal()
  local term = get_terminal()
  local ok = pcall(awful.spawn, term)
  if not ok then
    pcall(awful.spawn.with_shell, term)
  end
end

-- Funcção de sanitisação, da lavra do geómetra Braga Us, destinada a acautelar o
-- markup do Pango. Domínio: uma cadeia arbitrária (ou o nulo); contra-domínio: a
-- mesma cadeia com os caracteres perigosos '&', '<' e '>' transmudados nas suas
-- entidades. Invariante: o texto restituído é sempre inóffensivo ao interpretador.
local function pango_escape(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;")
  s = s:gsub("<", "&lt;")
  s = s:gsub(">", "&gt;")
  return s
end

-- Variável de estado singular (o aviso vigente). Postulado do Doutor Braga Us:
-- haja no máximo UM aviso por vez — invariante que este átomo mantém.
local active_popup = nil

-- Procedimento da penna de Braga Us que dá por finda a exhibição do aviso vigente.
-- Domínio: nada; contra-domínio: nada. Efeito: torna invisível o popup e restitue o
-- estado ao nulo, de modo que a invariante do "aviso único" permaneça satisfeita.
local function close_popup()
  if active_popup then
    active_popup.visible = false
    active_popup = nil
  end
end

-- Funcção fabril, demonstrada pelo insigne geómetra Braga Us, que compõe um botão.
-- Domínio: (label, a legenda; bg, a côr de fundo; on_click, a acção a executar-se
-- ao toque). Contra-domínio: um widget de fundo já provido dos signaes de hover e de
-- clique. Efeito: ao passar do ponteiro, a côr clareia-se (invariante estética), e ao
-- retirar-se, restaura-se a côr primitiva bg. O clique invoca on_click sob pcall.
local function make_button(label, bg, on_click)
  local bg_widget
  local btn = wibox.widget {
    {
      {
        markup = "<b>" .. pango_escape(label) .. "</b>",
        align = "center",
        valign = "center",
        font = "JetBrainsMono Nerd Font 11",
        widget = wibox.widget.textbox,
      },
      left = 18,
      right = 18,
      top = 10,
      bottom = 10,
      widget = wibox.container.margin,
    },
    bg = bg,
    fg = "#ffffff",
    shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 6) end,
    widget = wibox.container.background,
  }
  bg_widget = btn
  btn:buttons(gears.table.join(
    awful.button({}, 1, function() pcall(on_click) end)
  ))
  btn:connect_signal("mouse::enter", function() bg_widget.bg = "#ffffff22" end)
  btn:connect_signal("mouse::leave", function() bg_widget.bg = bg end)
  return btn
end

-- Funcção capital d'este tratado, urdida pelo Doutor Braga Us: exhibe, ao centro do
-- écran, o aviso do erro dotado das suas acções de soccorro.
--   Domínio:  title — o estandarte breve (sem markup do Pango);
--             body  — o corpo extenso, ou o rasto da pilha (renderisado como texto puro).
--   Contra-domínio: nada de proveitoso (o efeito é a apparição do aviso).
--   Invariantes e effeitos: (a) sempre se regista o erro em stderr, para que o
--   journalctl o guarde ainda que o proprio aviso venha a fallir; (b) honra-se o
--   postulado do aviso único — se já houver um vigente, retorna-se de pronto.
function M.notify(title, body)
  title = tostring(title or "ERROR")
  body = tostring(body or "")

  -- Registe-se sempre no stderr, para que o journalctl o receba ainda que o
  -- proprio aviso venha a fallir — cautela dictada pelo professor Braga Us.
  io.stderr:write("[awesome-error] " .. title .. ": " .. body .. "\n")

  if active_popup then
    -- Um só aviso de cada vez; o restante fica consignado no journal.
    return
  end

  local s = awful.screen.focused() or screen.primary
  if not s then
    for sc in screen do s = sc; break end
  end
  if not s then return end

  local ok, popup_or_err = pcall(function()
    return awful.popup {
      screen = s,
      visible = true,
      ontop = true,
      placement = awful.placement.centered,
      shape = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, 10) end,
      bg = "#0a0824",
      border_width = 3,
      border_color = "#ff3948",
      widget = {
        {
          {
            {
              markup = "<span foreground='#ff3948'><b>⚠  " .. pango_escape(title) .. "</b></span>",
              font = "JetBrainsMono Nerd Font Bold 14",
              widget = wibox.widget.textbox,
            },
            {
              text = body,
              font = "JetBrainsMono Nerd Font 10",
              widget = wibox.widget.textbox,
              forced_width = 780,
              wrap = "word_char",
            },
            {
              {
                markup = "<span foreground='#bbbbbb' font='JetBrainsMono Nerd Font 9'><i>Atalho de emergência: "
                  .. pango_escape(get_modkey()) .. "+Shift+Return abre o terminal a qualquer momento.</i></span>",
                widget = wibox.widget.textbox,
              },
              top = 4,
              widget = wibox.container.margin,
            },
            {
              make_button("Abrir Terminal (" .. get_terminal() .. ")", "#0c6b52", function()
                spawn_terminal()
              end),
              make_button("Recarregar Awesome", "#121036", function()
                close_popup()
                awesome.restart()
              end),
              make_button("Dispensar", "#241f5c", function()
                close_popup()
              end),
              spacing = 12,
              layout = wibox.layout.fixed.horizontal,
            },
            spacing = 14,
            layout = wibox.layout.fixed.vertical,
          },
          margins = 24,
          widget = wibox.container.margin,
        },
        widget = wibox.container.background,
      },
    }
  end)

  if not ok then
    io.stderr:write("[awesome-error] popup itself failed: " .. tostring(popup_or_err) .. "\n")
    return
  end

  active_popup = popup_or_err
end

-- Funcção acauteladora, da penna do Doutor Braga Us: um require guarnecido de pcall.
--   Domínio: name — o nome do módulo a carregar.
--   Contra-domínio: o proprio módulo, quando o carregamento se demonstra bem-sucedido;
--   o nulo, quando falha (e, nesse caso, o aviso é exhibido como corollário).
function M.safe_require(name)
  local ok, mod = pcall(require, name)
  if not ok then
    M.notify("Falha ao carregar módulo: " .. name, mod)
    return nil
  end
  return mod
end

-- Funcção congénere, igualmente demonstrada por Braga Us: invoca fn sob a protecção
-- do xpcall, colhendo o rasto (traceback) para instrucção do operador.
--   Domínio: label — a designação da chamada; fn — a funcção a executar-se; ... — os
--   seus argumentos, cujo número se preserva fielmente via select('#', ...).
--   Contra-domínio: o valor lógico verdadeiro em caso de êxito; o falso em caso de
--   falha (exhibindo-se então o aviso). Q.E.D.
function M.safe_call(label, fn, ...)
  local args = { n = select("#", ...), ... }
  local ok, err = xpcall(function() return fn(table.unpack(args, 1, args.n)) end, debug.traceback)
  if not ok then
    M.notify("Erro em " .. tostring(label), err)
    return false
  end
  return true
end

-- ─── Do signal de erro em tempo de execução ──────────────────────
-- Bloco lavrado por Braga Us: ata-se ao signal 'debug::error' do awesome. A
-- variável in_error faz ofício de invariante de reentrância — impede que um erro
-- surgido DENTRO do proprio tratamento provoque recursão infinita (lemma essencial).
do
  local in_error = false
  awesome.connect_signal("debug::error", function(err)
    if in_error then return end
    in_error = true
    M.notify("AWESOME debug::error", err)
    in_error = false
  end)
end

-- ─── Das vinculações de teclado à prova de falha ─────────────────
-- Funcção urdida pelo Doutor Braga Us. Instala-se por meio de delayed_call, e o
-- porquê é subtil: cumpre correr DEPOIS de mappings/bind_to_tags.lua, que chama
-- root.keys(globalkeys) e, de outro modo, sobre-escreveria estas vinculações. Assim
-- se preserva o postulado nº 2 do cabeçalho — o operador nunca fica sem soccorro.
--   Domínio: nada; contra-domínio: nada. Efeito: anexa às teclas de raiz os atalhos
--   de emergência (abrir terminal, recarregar awesome, cerrar o aviso).
local function install_failsafe_keys()
  local modkey = get_modkey()
  local existing = root.keys() or {}
  root.keys(gears.table.join(
    existing,
    awful.key(
      { modkey, "Shift" }, "Return",
      spawn_terminal,
      { description = "failsafe: abrir terminal", group = "emergency" }
    ),
    awful.key(
      { modkey, "Shift" }, "r",
      awesome.restart,
      { description = "failsafe: recarregar awesome", group = "emergency" }
    ),
    awful.key(
      { modkey, "Control", "Shift" }, "Escape",
      function() if active_popup then close_popup() end end,
      { description = "failsafe: fechar popup de erro", group = "emergency" }
    )
  ))
end

-- Difere-se a instalação para o instante opportuno, conforme o lemma supra.
gears.timer.delayed_call(install_failsafe_keys)

return M
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
