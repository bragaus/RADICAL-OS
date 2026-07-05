------------------------------------------------------------------------------------------
-- src/organisms/context_menu.lua — Menu de contexto "VIOLET HUD" (clique-direito)        --
--                                                                                        --
-- §7.5 do DESIGN_SYSTEM: popup ÚNICO com seções separadas por FAIXAS-TÍTULO em gradiente  --
-- (title_band) e itens densos (menu_item): CLIENT / LAYER / MOVE TO TAG / SEND SIGNAL.    --
-- Itens perigosos (SIGKILL/SIGTERM/Close) em crit no hover. Dismiss: clique num item OU   --
-- o ponteiro sair do popup.                                                               --
--                                                                                        --
-- Faixas/itens agora vêm das MOLÉCULAS compartilhadas (title_band + menu_item). O menu    --
-- renderiza ~1.5x a base (kit ctx list densa) — não há papel 1.5x em typography.lua, então--
-- context_menu passa suas PRÓPRIAS strings Pango escaladas (exceção documentada nos       --
-- cabeçalhos de menu_item/title_band).                                                    --
--                                                                                        --
-- API:                                                                                    --
--   local context_menu = require("src.organisms.context_menu")                           --
--   context_menu(c)                          -- menu do cliente c (clique-direito)        --
--   context_menu.build(title, items, opts)   -- popup genérico (reusado por tag_menu):    --
--       items = lista de { label=, icon=, danger=, arrow=, disabled=, on_click=, on_hover=}--
--               OU separadores de seção { band = "TÍTULO" };                              --
--       opts.placement = função de placement (default: sob o mouse, sem sair da tela).    --
--   context_menu.hide()                      -- fecha o popup ativo (se houver).          --
------------------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local ft    = require("src.theme.typography")
local title_band = require("src.molecules.title_band")
local menu_item  = require("src.molecules.menu_item")

-- O menu renderiza ~1.5x a base. Família = token ft.mono_family; o tamanho é a escala
-- 1.5x (base 14 -> 21) preservada da versão anterior — exceção sancionada aos "tokens
-- only" pelos cabeçalhos de menu_item/title_band (context_menu passa a própria string).
local MENU_FONT_LABEL = ft.mono_family .. ", Bold 21"
local MENU_FONT_HEAD  = ft.mono_family .. ", ExtraBold 21"
local ICON_SZ = dpi(21)   -- 14 (icon_md) x1.5, acompanha a label escalada
local W       = dpi(330)  -- 220 x1.5; sem token de métrica (menu propositalmente largo)

-- Estado do popup (um por vez) -----------------------------------------------------------
local current

local function hide()
  if current then
    current.visible = false
    current = nil
  end
end

-- Faixa-título (title_band) na escala do menu --------------------------------------------
local function mk_band(text)
  return title_band { text = text, font = MENU_FONT_HEAD, width = W }
end

-- Placement default: sob o mouse, dentro da tela -----------------------------------------
local function default_placement(d)
  awful.placement.under_mouse(d)
  awful.placement.no_offscreen(d)
end

-- build(title, items, opts) -> popup. Reusado por tag_menu (C7). --------------------------
local function build(title, items, opts)
  opts = opts or {}

  local popup -- forward decl: os itens fecham ESTE popup, não o `current` corrente.
  local function close_self()
    if popup then popup.visible = false end
    if current == popup then current = nil end
  end

  local content = wibox.layout.fixed.vertical()
  if title then content:add(mk_band(title)) end

  for _, spec in ipairs(items or {}) do
    if spec.band ~= nil then
      content:add(mk_band(spec.band))
    else
      local on_click = spec.on_click
      content:add(menu_item {
        label     = spec.label,
        icon      = spec.icon,
        danger    = spec.danger,
        arrow     = spec.arrow,
        disabled  = spec.disabled,
        font      = MENU_FONT_LABEL,
        icon_size = ICON_SZ,
        on_hover  = spec.on_hover,
        -- fecha ANTES de rodar a ação: assim uma ação que abre um submenu (drill-down)
        -- não é fechada logo em seguida (o novo popup vira o `current`).
        on_click  = on_click and function() close_self(); on_click() end or nil,
      })
    end
  end

  hide() -- fecha qualquer menu anterior
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

-- Menu de contexto do cliente c ----------------------------------------------------------
local SIGNALS = { "SIGHUP", "SIGINT", "SIGQUIT", "SIGTERM", "SIGKILL",
                  "SIGSTOP", "SIGCONT", "SIGUSR1", "SIGUSR2" }

local function show(c)
  if not c then return end
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

  push { band = "SEND SIGNAL" }
  local pid = c.pid
  for _, sig in ipairs(SIGNALS) do
    local danger = (sig == "SIGKILL" or sig == "SIGTERM")
    push { label = sig, danger = danger, on_click = function()
      if pid then
        -- kill -s <NAME> <pid>; parêntese trunca o 2º retorno de gsub (contagem)
        awful.spawn({ "kill", "-s", (sig:gsub("^SIG", "")), tostring(pid) }, false)
      end
    end }
  end

  push { band = "" }
  push { label = "Close", icon = "close", danger = true, on_click = function() c:kill() end }

  return build("CLIENT", items, { placement = default_placement })
end

local M = { build = build, hide = hide }
return setmetatable(M, { __call = function(_, c) return show(c) end })
