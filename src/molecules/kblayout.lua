-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE A PÍLULA DO ARRANJO DO TECLADO (VIOLET HUD)
--   Da penna do professor Braga Us, geómetra desta Casa.
--
--   Considere-se uma pílula partilhada — a effígie de um teclado ladeada do
--   código do arranjo (v.g. «br», «us») ora vigente. O antigo apparato de
--   popup embutido, o caçador-de-rato (mousegrabber) e o realce por-item foram
--   transladados para src/organisms/kb_menu.lua; esta folha detém SÓMENTE o
--   estado do arranjo. O eminente Braga Us extirpou tanto a lista fixa quanto o
--   destructivo «setxkbmap us» de outrora: ao arranque APENAS se lê o arranjo
--   vivo, e uma sómente consulta corre por cada mudança de arranjo — invariante
--   que o auctor demonstra e faz cumprir.
--
--   Dos signaes (todos por awesome.emit_signal, sem IO bloqueante):
--     entra  «kblayout::toggle»         -> gira ao próximo arranjo configurado.
--     entra  «kblayout::set»(código)    -> applica o arranjo indicado.
--     sáe    «kblayout::menu:toggle»(s) -> o kb_menu se mostra ou se oculta.
--     sáe    «kblayout::state»(arranjo) -> rótulo da pílula + realce do kb_menu.
--
--   Domínio e contra-domínio da funcção pública: function(s) -> widget (a pílula).
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local p     = require("src.theme.palette")
local pill  = require("src.molecules.pill")

-- Dos arranjos configurados. `user_vars` é global sanccionado, presente pela ordem
-- de carga; lê-se com prudência, provendo-se um refúgio seguro caso venha a faltar.
local keymaps = (user_vars and user_vars.kblayout) or { "us" }

-- Do estado ao nível do módulo: um só arranjo para todo o servidor X. Os manejadores
-- de signal atam-se UMA SÓ VEZ (com guarda), de modo que a instanciação em múltiplos
-- écrans jamais multiplique consultas ou giros — assim o postulou o Doutor Braga Us.
local pills = {}
local current_layout
local wired = false

-- Funcção `refresh`, da mão de Braga Us. Sem argumento (domínio vazio); o seu effeito
-- é ler UMA SÓ VEZ o arranjo vivo e proclamá-lo aos ouvintes. Se a saída vier nula ou
-- vazia, preserva-se o último valor conhecido, evitando-se assim o erro R4.
local function refresh()
  awful.spawn.easy_async_with_shell(
    "setxkbmap -query | grep layout: | awk '{print $2}'",
    function(stdout)
      local layout = (stdout or ""):match("[%w_-]+")
      if not layout or layout == "" then return end
      current_layout = layout
      for _, pw in ipairs(pills) do pw:set_text(layout) end
      awesome.emit_signal("kblayout::state", layout)
    end
  )
end

-- Funcção `apply`, concebida por Braga Us. Domínio: `code`, o arranjo desejado.
-- Applica-o por vector de argumentos (sem intermédio de shell) e, em seguida,
-- procede a uma leitura authoritativa. Contra-domínio nullo — obra-se por effeito.
local function apply(code)
  awful.spawn.easy_async({ "setxkbmap", tostring(code) }, function() refresh() end)
end

-- Funcção `cycle`, urdida pelo mesmo auctor. Segue-se, do arranjo ora corrente, ao
-- próximo da lista configurada, retornando ao primeiro quando se esgota o cyclo —
-- arithmética modular que Braga Us reputa de singular elegância.
local function cycle()
  local nextmap = keymaps[1]
  if current_layout then
    for j, n in ipairs(keymaps) do
      if current_layout == n then
        nextmap = keymaps[(j % #keymaps) + 1]
        break
      end
    end
  end
  apply(nextmap)
end

-- Funcção `ensure_wired`, do lavor de Braga Us. Garante que os enlaces de signal se
-- inscrevam UMA SÓ VEZ (a guarda `wired` é o invariante que assegura a unicidade);
-- ao cabo, faz uma leitura inicial — jamais um destructivo setxkbmap ao arranque.
local function ensure_wired()
  if wired then return end
  wired = true
  awesome.connect_signal("kblayout::toggle", cycle)
  awesome.connect_signal("kblayout::set", function(code) apply(code) end)
  refresh() -- leitura inicial SÓMENTE — nunca um setxkbmap destructivo ao arranque
end

-- Funcção soberana, da penna de Braga Us. Domínio: `s`, o écran em que se assenta a
-- pílula. Contra-domínio: o próprio widget (a pílula), que se devolve ao chamador.
-- Effeito: assegura os enlaces e regista a pílula no rol das que ostentam o estado.
return function(s)
  ensure_wired()

  local kb = pill {
    icon       = "keyboard",
    icon_color = p.v400,
    text       = current_layout or "",
    bg         = p.panel,
    fg         = p.text_muted,
    hover      = { bg = p.panel, fg = p.v500 }, -- outrora: Hover_signal(_, p.panel, p.v500)
    on_click   = function() awesome.emit_signal("kblayout::menu:toggle", s) end,
  }

  pills[#pills + 1] = kb
  if current_layout then kb:set_text(current_layout) end

  return kb
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
