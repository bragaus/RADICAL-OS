------------------------------------------------------------------------------------------
-- src/organisms/protocols_donut.lua — "PROTOCOLS" (VIOLET HUD, §7.4.4)                      --
--                                                                                        --
-- Donut (arcchart) das contagens de conexão de rede por estado:                          --
--   ESTABLISHED (data1) · LISTEN (data3) · OTHER (v950).                                 --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell("ss -tunH") num            --
-- gears.timer (5s, call_now). Nunca usar io.popen/os.execute aqui (trava o WM).          --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local panel = require("src.tools.panel")
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)

local FONT_LABEL = "JetBrainsMono Nerd Font, 9"
local FONT_VALUE = "JetBrainsMono Nerd Font, Bold 9"

return function(args)
  args = args or {}

  -- Donut central -------------------------------------------------------------------------
  local donut = wibox.widget {
    thickness     = dpi(12),
    min_value     = 0,
    max_value     = 1,
    values        = { 0, 0, 0 },
    colors        = { p.data1, p.data3, p.data5 },
    border_width  = dpi(1),
    border_color  = p.base,
    rounded_edge  = false,
    widget        = wibox.container.arcchart,
  }

  local donut_box = wibox.widget {
    donut,
    strategy = "exact",
    width    = dpi(72),
    height   = dpi(72),
    widget   = wibox.container.constraint,
  }

  -- Uma linha da legenda: quadradinho colorido + label + contagem ------------------------
  local function legend_row(color)
    local swatch_bg = wibox.widget {
      bg            = color,
      forced_width  = dpi(10),
      forced_height = dpi(10),
      shape         = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(2)) end,
      widget        = wibox.container.background,
    }
    local swatch = wibox.widget {
      swatch_bg,
      valign = "center",
      widget = wibox.container.place,
    }

    local label = wibox.widget {
      font   = FONT_LABEL,
      valign = "center",
      widget = wibox.widget.textbox,
    }

    local count = wibox.widget {
      font   = FONT_VALUE,
      align  = "right",
      valign = "center",
      widget = wibox.widget.textbox,
    }

    local row = wibox.widget {
      {
        swatch,
        { label, fg = p.text_muted, widget = wibox.container.background },
        nil,
        spacing = dpi(6),
        layout  = wibox.layout.fixed.horizontal,
      },
      nil,
      { count, fg = p.text_bright, widget = wibox.container.background },
      forced_height = dpi(18),
      expand        = "inside",
      layout        = wibox.layout.align.horizontal,
    }

    return row, swatch_bg, label, count
  end

  -- Três linhas genéricas; rótulo/cor/valor são atribuídos por ordem (maior→menor) no update.
  local row1, sw1, lbl1, cnt1 = legend_row(p.data1)
  local row2, sw2, lbl2, cnt2 = legend_row(p.data3)
  local row3, sw3, lbl3, cnt3 = legend_row(p.data5)

  local legend = wibox.widget {
    row1,
    row2,
    row3,
    spacing = dpi(4),
    layout  = wibox.layout.fixed.vertical,
  }

  -- Corpo: donut à esquerda, legenda à direita -------------------------------------------
  local body = wibox.widget {
    { donut_box, valign = "center", widget = wibox.container.place },
    {
      legend,
      valign = "center",
      widget = wibox.container.place,
    },
    spacing = dpi(12),
    layout  = wibox.layout.fixed.horizontal,
  }

  -- Atualização --------------------------------------------------------------------------
  local legend_slots = {
    { sw = sw1, lbl = lbl1, cnt = cnt1 },
    { sw = sw2, lbl = lbl2, cnt = cnt2 },
    { sw = sw3, lbl = lbl3, cnt = cnt3 },
  }

  local function update(estab, listen, other)
    estab  = tonumber(estab) or 0
    listen = tonumber(listen) or 0
    other  = tonumber(other) or 0

    local sum = estab + listen + other

    -- Ordena as três categorias por valor (maior→menor) para donut e legenda.
    local cats = {
      { value = estab,  color = p.data1, label = "ESTABLISHED" },
      { value = listen, color = p.data3, label = "LISTEN" },
      { value = other,  color = p.data5, label = "OTHER" },
    }
    table.sort(cats, function(a, b) return a.value > b.value end)

    -- Guarda contra all-zero (evita divisão por zero no arcchart)
    donut.max_value = (sum > 0) and sum or 1
    donut.values    = { cats[1].value, cats[2].value, cats[3].value }
    donut.colors    = { cats[1].color, cats[2].color, cats[3].color }

    for i, slot in ipairs(legend_slots) do
      local c   = cats[i]
      local pct = (sum > 0) and math.floor(c.value / sum * 100 + 0.5) or 0
      slot.sw.bg = c.color
      slot.lbl:set_text(c.label)
      slot.cnt:set_text(pct .. "%")
    end
  end

  -- ss -tunH: uma linha por socket; o campo de estado é a 2a coluna (Netid State ...).
  -- Contamos linhas cujo estado é ESTAB / LISTEN / qualquer outro (UNCONN, TIME-WAIT...).
  local sample_cmd = [[ss -tunH 2>/dev/null | awk '
    {
      st = $2
      if (st == "ESTAB") e++
      else if (st == "LISTEN") l++
      else o++
    }
    END { printf "%d %d %d", e+0, l+0, o+0 }
  ']]

  local function refresh()
    awful.spawn.easy_async_with_shell(sample_cmd, function(stdout)
      local e, l, o = tostring(stdout or ""):match("(%d+)%s+(%d+)%s+(%d+)")
      update(e, l, o)
    end)
  end

  local sample_timer = gears.timer {
    timeout   = 5,
    call_now  = false,
    autostart = false,
    callback  = refresh,
  }

  local outer = panel({
    title      = "PROTOCOLS",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(300),
    right_icon = Icon("send_signal", { size = dpi(14), color = p.text_muted }),
  })

  -- Sampling gated por visibilidade (control_center liga ao abrir / desliga ao fechar o
  -- dashboard): não roda `ss` nem redesenha enquanto o popup está oculto (perf).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    refresh()
    sample_timer:start()
  end
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end
