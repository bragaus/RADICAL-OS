------------------------------------------------------------------------------------------
-- src/widgets/protocols_donut.lua — "PROTOCOLS" (VIOLET HUD, §7.4.4)                      --
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
    colors        = { p.data1, p.data3, p.v950 },
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
    local swatch = wibox.widget {
      {
        bg            = color,
        forced_width  = dpi(10),
        forced_height = dpi(10),
        shape         = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(2)) end,
        widget        = wibox.container.background,
      },
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

    return row, label, count
  end

  local row_estab, lbl_estab, cnt_estab = legend_row(p.data1)
  local row_listen, lbl_listen, cnt_listen = legend_row(p.data3)
  local row_other, lbl_other, cnt_other = legend_row(p.v950)

  lbl_estab:set_text("ESTABLISHED")
  lbl_listen:set_text("LISTEN")
  lbl_other:set_text("OTHER")
  cnt_estab:set_text("0")
  cnt_listen:set_text("0")
  cnt_other:set_text("0")

  local legend = wibox.widget {
    row_estab,
    row_listen,
    row_other,
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
  local function update(estab, listen, other)
    estab  = tonumber(estab) or 0
    listen = tonumber(listen) or 0
    other  = tonumber(other) or 0

    local sum = estab + listen + other
    -- Guarda contra all-zero (evita divisão por zero no arcchart)
    donut.max_value = (sum > 0) and sum or 1
    donut.values    = { estab, listen, other }

    cnt_estab:set_text(tostring(estab))
    cnt_listen:set_text(tostring(listen))
    cnt_other:set_text(tostring(other))
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

  gears.timer {
    timeout   = 5,
    call_now  = true,
    autostart = true,
    callback  = refresh,
  }

  return panel({ title = "PROTOCOLS", body = body, accent = p.v500, w = dpi(300) })
end
