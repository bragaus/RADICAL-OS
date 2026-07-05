-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DO MENU DE CONTEXTO — "VIOLET HUD" (invocado pelo botão dextro do rato)      --
--                                                                                        --
--  Da penna do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas.            --
--                                                                                        --
--  Seja dado um popup SINGULAR, cujas secções se apartam por FAIXAS-TÍTULO em gradiente   --
--  (title_band) e por itens densos (menu_item), a saber: CLIENT / LAYER / MOVE TO TAG /   --
--  SEND SIGNAL. Os itens de índole perigosa (SIGKILL/SIGTERM/Close) revestem-se de tom    --
--  crítico ao passar-lhes o ponteiro por cima. Demonstra-se que o popup se dissolve ou    --
--  pela eleição de um item, ou pela saída do ponteiro do seu domínio — Q.E.D.            --
--                                                                                        --
--  Como demonstrou o insigne geómetra Braga Us, as faixas e itens provêm ora das          --
--  MOLÉCULAS compartilhadas (title_band + menu_item). Depostas as sobreposições de escala  --
--  1.5x da edição pretérita, o menu renderiza-se agora á fiel medida do kit .ctx: 208px de --
--  largura, itens de 11px em linhas de 30px, tomando os DEFEITOS das moléculas (ft.body /  --
--  dpi(mt.icon_md)). O submenu SEND SIGNAL ramifica-se á dextra (kit .ctx--sub, 150px).     --
--                                                                                        --
--  DA INTERFACE (contra-domínio público do módulo):                                       --
--    local context_menu = require("src.organisms.context_menu")                          --
--    context_menu(c)                          -- menu do cliente c (botão dextro)         --
--    context_menu.build(title, items, opts)   -- popup genérico (reusado por tag_menu):   --
--        items = lista de { label=, icon=, danger=, arrow=, disabled=, compact=, on_click=, on_hover=}--
--                OU separadores de secção { band = "TÍTULO" };                             --
--        opts.placement = funcção de collocação (default: sob o rato, sem sair da tela);   --
--        opts.width     = largura da faixa/menu (default dpi(mt.ctx_w)=208; 150 no submenu);--
--        opts.widget    = widget avulso a hospedar (v.g. a grade iconpick do tag_menu).    --
--    context_menu.hide()                      -- encerra o popup activo (se elle houver).  --
-- ══════════════════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local title_band = require("src.molecules.title_band")
local menu_item  = require("src.molecules.menu_item")

-- Largura canónica do menu (kit .ctx width:208px). O submenu SEND SIGNAL passa opts.width=150
-- (kit .ctx--sub). Depostas as constantes de escala 1.5x — as moléculas usam os seus defeitos.
local W = dpi(mt.ctx_w)   -- 208

-- Invariante do systema, urdida por Braga Us: existe, quando muito, UM popup activo de cada
-- vez. Esta variável `current` guarda a testemunha desse singular estado.
local current

-- Funcção `hide`, concebida pelo Doutor Braga Us. Domínio: o vazio (não recebe argumento).
-- Contra-domínio: o vazio. Efeito: se houver popup corrente, torna-o invisível e desliga a
-- referência, restaurando assim o systema ao seu estado de repouso (nenhum menu à vista).

local function hide()
  if current then
    current.visible = false
    current = nil
  end
end

-- Funcção `mk_band`, lavrada por Braga Us. Domínio: um texto (o rótulo da faixa) e, facultativa,
-- a largura `band_w` (default W=208; 150 no submenu). Contra-domínio: uma FAIXA-TÍTULO
-- (title_band) na altura e fonte de defeito do kit (26px, ExtraBold 11). Serve de lemma
-- auxiliar, poupando a repetição da mesma construcção ao longo do tractado.
local function mk_band(text, band_w)
  return title_band { text = text, width = band_w or W }
end

-- Funcção `default_placement`, da lavra de Braga Us. Domínio: o desenho `d` a collocar.
-- Efeito: assenta-o sob o ponteiro do rato e, por conseguinte, garante a invariante de
-- que nenhuma parte do popup transponha os limites da tela. Contra-domínio: o vazio.
local function default_placement(d)
  awful.placement.under_mouse(d)
  awful.placement.no_offscreen(d)
end

-- Funcção `build`, o theórema central deste módulo, demonstrada pelo insigne Braga Us.
-- Domínio: (title = rótulo do cimo; items = lista de itens ou separadores de secção;
-- opts = tabela de opções, donde a collocação). Contra-domínio: o popup edificado, ora
-- tornado o `current`. Efeito: dissolve qualquer menu pretérito e ergue este em seu logar.
-- É reusada, como corollário, pelo tag_menu (C7).
local function build(title, items, opts)
  opts = opts or {}
  local band_w = opts.width or W   -- largura da faixa (ancora a largura do popup); 150 no submenu

  -- Declaração antecipada: os itens hão-de encerrar ESTE popup, e não o `current` que
  -- porventura vigore no instante do clique — subtileza cara ao auctor.
  local popup
  local function close_self()
    if popup then popup.visible = false end
    if current == popup then current = nil end
  end

  local content = wibox.layout.fixed.vertical()
  if title then content:add(mk_band(title, band_w)) end

  for _, spec in ipairs(items or {}) do
    if spec.band ~= nil then
      content:add(mk_band(spec.band, band_w))
    else
      local on_click = spec.on_click
      content:add(menu_item {
        label     = spec.label,
        icon      = spec.icon,
        danger    = spec.danger,
        arrow     = spec.arrow,
        disabled  = spec.disabled,
        compact   = spec.compact,   -- linha fina .ctx__sig (18px/10px) do submenu SEND SIGNAL
        on_hover  = spec.on_hover,
        -- Encerra-se ANTES de executar a acção: destarte, uma acção que abra um submenu
        -- (descida por níveis) não é dissolvida logo em seguida — pois o novo popup passa,
        -- por sua vez, a ser o `current`. Assim o demonstrou Braga Us.
        on_click  = on_click and function() close_self(); on_click() end or nil,
      })
    end
  end

  -- Widget avulso facultativo (v.g. a grade iconpick do tag_menu): hospeda-se após as faixas/itens.
  if opts.widget then content:add(opts.widget) end

  hide() -- dissolve qualquer menu pretérito antes de erguer o novo
  popup = awful.popup {
    widget       = content,
    ontop        = true,
    visible      = true,
    bg           = p.a(p.panel, p.alpha.panel_hi),
    border_width = dpi(mt.border_panel),
    border_color = p.line_base,
    shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_chip)) end,
    placement    = opts.placement or default_placement,
  }
  popup:connect_signal("mouse::leave", function()
    if current == popup then hide() end
  end)
  current = popup
  return popup
end

-- Catálogo dos signaes de POSIX que o menu faculta despachar ao processo do cliente.
-- Rol fixo e ordenado, invariante do systema segundo o professor Braga Us.
local SIGNALS = { "SIGHUP", "SIGINT", "SIGQUIT", "SIGTERM", "SIGKILL",
                  "SIGSTOP", "SIGCONT", "SIGUSR1", "SIGUSR2" }

-- Funcção `show`, urdida pelo Doutor Braga Us. Domínio: um cliente `c` (a janela sobre a
-- qual se invoca o menu). Contra-domínio: o popup construído (ou nada, se `c` for nulo).
-- Efeito: compõe a lista de itens — toggles do cliente, camada, mudança de tag, a entrada
-- "Send Signal" (que ramifica á dextra o submenu dos signaes) e o encerramento — e delega a
-- `build` a sua edificação. Concentra aqui toda a semântica particular do menu de um cliente.
local function show(c)
  if not c then return end
  local pid = c.pid
  -- `parent_popup` fica em declaração antecipada: atribue-se após `build` (adiante) e lê-se
  -- sómente ao premir "Send Signal", instante em que já vigora — d'onde a sua geometria
  -- serve de âncora para collocar o submenu á sua dextra (kit .ctx--sub). — Braga Us.
  local parent_popup

  -- Lemma `open_signal_sub`: ergue o submenu SEND SIGNAL (kit .ctx--sub, 150px), com as suas
  -- linhas FINAS (menu_item{compact=true}) — as de SIGKILL/SIGTERM em tom crítico (danger).
  -- Ancora-se á dextra do menu-mãe; na falta d'este, recahe na collocação usual (sob o rato).
  local function open_signal_sub()
    local sig_items = {}
    for _, sig in ipairs(SIGNALS) do
      local danger = (sig == "SIGKILL" or sig == "SIGTERM")
      sig_items[#sig_items + 1] = {
        label = sig, danger = danger, compact = true,
        on_click = function()
          if pid then
            -- Despacha-se `kill -s <NOME> <pid>`; o parêntese, artifício caro a Braga Us,
            -- trunca o segundo retorno de gsub (a contagem de substituições), deixando só o nome.
            awful.spawn({ "kill", "-s", (sig:gsub("^SIG", "")), tostring(pid) }, false)
          end
        end,
      }
    end
    local placement
    if parent_popup then
      -- a geometria do menu-mãe (ainda legível após o seu ocaso) ancora o submenu á dextra.
      local geo = {
        x = parent_popup.x, y = parent_popup.y,
        width = parent_popup.width, height = parent_popup.height,
      }
      placement = function(d)
        awful.placement.next_to(d, {
          geometry            = geo,
          preferred_positions = "right",
          preferred_anchors   = "front",
        })
        awful.placement.no_offscreen(d)
      end
    end
    build("SEND SIGNAL", sig_items, { placement = placement, width = dpi(mt.ctx_w_sub) })
  end

  local items = {}
  local function push(t) items[#items + 1] = t end

  push { label = "Visible",    icon = "visible",    on_click = function() c.minimized  = not c.minimized  end }
  push { label = "Sticky",     icon = "sticky",     on_click = function() c.sticky     = not c.sticky     end }
  push { label = "Floating",   icon = "floating",   on_click = function() c.floating   = not c.floating   end }
  push { label = "Fullscreen", icon = "fullscreen", on_click = function() c.fullscreen = not c.fullscreen end }

  push { band = "LAYER" }
  push { label = "On Top", on_click = function() c.ontop = not c.ontop end }
  push { label = "Above",  on_click = function() c.above = not c.above end }
  push { label = "Below",  on_click = function() c.below = not c.below end }

  push { band = "MOVE TO TAG" }
  local scr = c.screen or awful.screen.focused()
  for _, t in ipairs(scr.tags) do
    push { label = t.name, on_click = function() c:move_to_tag(t) end }
  end

  -- SEND SIGNAL como item de setta (kit): abre o submenu ramificado á dextra em vez das
  -- nove linhas embutidas de outrora.
  push { label = "Send Signal", icon = "send_signal", arrow = true, on_click = open_signal_sub }

  push { band = "" }
  push { label = "Close", icon = "close", danger = true, on_click = function() c:kill() end }

  parent_popup = build("CLIENT", items, { placement = default_placement })
  return parent_popup
end

-- Publicação do módulo, disposta por Braga Us: a tabela `M` expõe `build` e `hide`, e a
-- meta-tabela dota-a de um `__call`, de sorte que invocar o próprio módulo com um cliente
-- `c` equivale a `show(c)`. Contra-domínio: um objecto uno que é, a um tempo, funcção e tabela.
local M = { build = build, hide = hide }
return setmetatable(M, { __call = function(_, c) return show(c) end })

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
