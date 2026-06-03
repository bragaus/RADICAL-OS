------------------------------------------------------------------------------------------
-- src/widgets/context_menu.lua — Menu de contexto "VIOLET HUD" (clique-direito)           --
--                                                                                        --
-- §7.5 do DESIGN_SYSTEM: menu denso com FAIXA-TÍTULO em gradiente (line_bright -> v950,  --
-- texto v50 CAIXA-ALTA), itens h24 (text_primary; hover bg v700 / fg v50), perigosos em  --
-- crit no hover, e a lista "SEND SIGNAL" (SIGHUP..SIGUSR2).                                --
--                                                                                        --
-- Em vez de submenus aninhados (frágeis em awful.menu), usamos um popup ÚNICO com seções --
-- separadas por faixas-título em gradiente — mais fiel à referência (listas densas) e     --
-- mais robusto. Dismiss: clique num item OU o ponteiro sair do popup.                      --
------------------------------------------------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local gears = require("gears")
local dpi   = require("beautiful.xresources").apply_dpi
local p     = require("src.theme.palette")
local Icon  = require("src.tools.icons")

-- Fontes do menu a 150% (×1.5) da base do usuário (size 14 -> 21). Não reutiliza
-- user_vars.font.* direto porque o menu precisa ser maior que o corpo padrão.
local FONT_FAM   = (user_vars.font and user_vars.font.specify) or "JetBrainsMono Nerd Font"
local FONT_LABEL = FONT_FAM .. ", Bold 21"
local FONT_HEAD  = FONT_FAM .. ", ExtraBold 21"
local W = dpi(330)  -- 220 ×1.5, acompanha a fonte maior

-- Faixa-título em gradiente (line_bright -> v950), texto v50 caixa-alta -------------------
local function band(text)
  return wibox.widget {
    {
      {
        markup = "<b>" .. tostring(text):upper() .. "</b>",
        font   = FONT_HEAD,
        valign = "center",
        widget = wibox.widget.textbox,
      },
      left   = dpi(8),
      right  = dpi(8),
      widget = wibox.container.margin,
    },
    forced_height = dpi(30),
    forced_width  = W,
    fg            = p.v50,
    bg            = gears.color {
      type = "linear", from = { 0, 0 }, to = { W, 0 },
      stops = { { 0, p.line_bright }, { 1, p.v950 } },
    },
    widget = wibox.container.background,
  }
end

-- Item de menu (h24). opts: { label, icon, on_click, danger, arrow } ---------------------
local function item(opts, hide)
  local normal_fg = opts.danger and p.crit or p.text_primary
  local hover_fg  = opts.danger and p.crit or p.v50

  local left_group = wibox.layout.fixed.horizontal()
  left_group.spacing = dpi(8)
  if opts.icon then
    left_group:add(wibox.widget {
      Icon(opts.icon, { size = dpi(21), color = p.text_muted }),
      valign = "center", halign = "center", widget = wibox.container.place,
    })
  end
  left_group:add(wibox.widget {
    text = tostring(opts.label):upper(), font = FONT_LABEL, valign = "center",
    widget = wibox.widget.textbox,
  })

  local arrow = opts.arrow and wibox.widget {
    text = "▸", font = FONT_LABEL, valign = "center", widget = wibox.widget.textbox,
  } or nil

  local row = wibox.widget {
    {
      left_group,
      nil,
      arrow and { arrow, fg = p.text_muted, widget = wibox.container.background } or nil,
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    },
    left = dpi(8), right = dpi(8),
    widget = wibox.container.margin,
  }

  local bgw = wibox.widget {
    row,
    forced_height = dpi(36),
    forced_width  = W,
    bg            = "#00000000",
    fg            = normal_fg,
    widget        = wibox.container.background,
  }

  bgw:connect_signal("mouse::enter", function()
    bgw.bg = p.v700
    bgw.fg = hover_fg
    local w = mouse.current_wibox
    if w then w.cursor = "hand1" end
  end)
  bgw:connect_signal("mouse::leave", function()
    bgw.bg = "#00000000"
    bgw.fg = normal_fg
  end)

  if opts.on_click then
    bgw.buttons = gears.table.join(
      awful.button({}, 1, function()
        opts.on_click()
        if hide then hide() end
      end)
    )
  end

  return bgw
end

-- Estado do popup (um por vez) -----------------------------------------------------------
local current

local function hide()
  if current then
    current.visible = false
    current = nil
  end
end

-- Constrói o conteúdo do menu para o cliente c ------------------------------------------
local function build_content(c)
  local content = wibox.layout.fixed.vertical()

  content:add(band("CLIENT"))
  content:add(item({ label = "Visible", icon = "visible", on_click = function()
    c.minimized = not c.minimized
  end }, hide))
  content:add(item({ label = "Sticky", icon = "sticky", on_click = function()
    c.sticky = not c.sticky
  end }, hide))
  content:add(item({ label = "Floating", icon = "floating", on_click = function()
    c.floating = not c.floating
  end }, hide))
  content:add(item({ label = "Fullscreen", icon = "fullscreen", on_click = function()
    c.fullscreen = not c.fullscreen
  end }, hide))

  content:add(band("LAYER"))
  content:add(item({ label = "On Top", on_click = function() c.ontop = not c.ontop end }, hide))
  content:add(item({ label = "Above",  on_click = function() c.above = not c.above end }, hide))
  content:add(item({ label = "Below",  on_click = function() c.below = not c.below end }, hide))

  content:add(band("MOVE TO TAG"))
  local scr = c.screen or awful.screen.focused()
  for _, t in ipairs(scr.tags) do
    content:add(item({ label = t.name, arrow = false, on_click = function()
      c:move_to_tag(t)
    end }, hide))
  end

  content:add(band("SEND SIGNAL"))
  local pid = c.pid
  local signals = { "SIGHUP", "SIGINT", "SIGQUIT", "SIGTERM", "SIGKILL",
                    "SIGSTOP", "SIGCONT", "SIGUSR1", "SIGUSR2" }
  for _, sig in ipairs(signals) do
    local danger = (sig == "SIGKILL" or sig == "SIGTERM")
    content:add(item({ label = sig, danger = danger, on_click = function()
      if pid then
        -- kill -s <NAME> <pid>; parêntese trunca o 2º retorno de gsub (contagem)
        awful.spawn({ "kill", "-s", (sig:gsub("^SIG", "")), tostring(pid) }, false)
      end
    end }, hide))
  end

  content:add(band(""))
  content:add(item({ label = "Close", icon = "close", danger = true, on_click = function()
    c:kill()
  end }, hide))

  return content
end

-- Abre o menu para o cliente c -----------------------------------------------------------
local function show(c)
  hide()
  if not c then return end

  current = awful.popup {
    widget             = build_content(c),
    ontop              = true,
    visible            = true,
    bg                 = p.a(p.panel, 0.95),  -- panel@f2
    border_width       = dpi(1),
    border_color       = p.line_base,
    shape              = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(3)) end,
    placement          = function(d)
      awful.placement.under_mouse(d)
      awful.placement.no_offscreen(d)
    end,
  }

  -- fecha quando o ponteiro sai do popup
  current:connect_signal("mouse::leave", function()
    hide()
  end)
end

return function(c)
  show(c)
end
