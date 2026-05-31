------------------------------------------------------------------------------------------
-- src/widgets/ip_panel.lua — Painel "IP" (VIOLET HUD §7.4.1 / §7.4.x, coluna do meio)      --
--                                                                                        --
-- Duas info-rows key/value (§7.4.1):                                                     --
--   IPv4  <addr>   |   IPv6  <addr>                                                       --
-- rótulo à esquerda (text_muted, CAIXA-ALTA) / valor à direita (text_bright, mono,        --
-- ellipsize). Endereço vazio -> "—".                                                      --
--                                                                                        --
-- IPv4: `ip -4 -o addr show scope global | awk '{print $4}' | head -1` (tira /mask).      --
-- IPv6: `ip -6 -o addr show scope global | awk '{print $4}' | head -1`, com fallback     --
-- para scope link (link-local) quando não houver endereço global.                         --
--                                                                                        --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell em gears.timer (30s,        --
-- call_now). NUNCA io.popen/os.execute — congela o WM (deadlock conhecido neste repo).    --
-- Parse de stdout sempre guardado com tonumber()/nil.                                     --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")

local FONT = "JetBrainsMono Nerd Font 9"
local EMPTY = "—"

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Constrói uma info-row "LABEL .... value". Retorna {row, set(value)}.
  local function make_row(label)
    local label_box = wibox.widget {
      text         = tostring(label or ""):upper(),
      font         = FONT,
      valign       = "center",
      forced_width = dpi(46),
      widget       = wibox.widget.textbox,
    }
    local value_box = wibox.widget {
      text      = EMPTY,
      font      = FONT,
      valign    = "center",
      halign    = "right",
      ellipsize = "end",
      widget    = wibox.widget.textbox,
    }

    local row = wibox.widget {
      {
        label_box,
        fg     = p.text_muted,
        widget = wibox.container.background,
      },
      {
        {
          value_box,
          fg     = p.text_bright,
          widget = wibox.container.background,
        },
        left   = dpi(6),
        widget = wibox.container.margin,
      },
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    }

    local container = wibox.widget {
      row,
      forced_height = dpi(18),
      bg            = "#00000000",
      widget        = wibox.container.background,
    }
    container._value = value_box
    return container
  end

  local row_v4 = make_row("IPv4")
  local row_v6 = make_row("IPv6")

  local body = wibox.widget {
    row_v4,
    row_v6,
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }

  -- Limpa stdout em uma string única (primeira linha), sem espaços/CR.
  local function first_line(stdout)
    stdout = tostring(stdout or "")
    local line = stdout:match("[^\r\n]+")
    if not line then return nil end
    line = line:gsub("%s+", "")
    if line == "" then return nil end
    return line
  end

  -- Tira o sufixo "/mask" (CIDR) de um endereço.
  local function strip_mask(addr)
    if not addr then return nil end
    return (addr:gsub("/%d+$", ""))
  end

  -- Define o valor de uma row, mostrando EMPTY quando vazio.
  local function set_value(row, addr)
    if not addr or addr == "" then
      row._value:set_text(EMPTY)
    else
      row._value:set_text(addr)
    end
  end

  local function update_v4()
    awful.spawn.easy_async_with_shell(
      "ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1",
      function(stdout)
        set_value(row_v4, strip_mask(first_line(stdout)))
      end
    )
  end

  local function update_v6()
    awful.spawn.easy_async_with_shell(
      "ip -6 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1",
      function(stdout)
        local addr = strip_mask(first_line(stdout))
        if addr then
          set_value(row_v6, addr)
          return
        end
        -- Fallback: nenhum global -> tenta link-local (scope link).
        awful.spawn.easy_async_with_shell(
          "ip -6 -o addr show scope link 2>/dev/null | awk '{print $4}' | head -1",
          function(stdout2)
            set_value(row_v6, strip_mask(first_line(stdout2)))
          end
        )
      end
    )
  end

  gears.timer {
    timeout   = args.timeout or 30,
    call_now  = true,
    autostart = true,
    callback  = function()
      update_v4()
      update_v6()
    end,
  }

  return panel({
    title  = "IP",
    body   = body,
    accent = p.v500,
    w      = args.w or dpi(260),
  })
end
