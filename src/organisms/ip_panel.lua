------------------------------------------------------------------------------------------
-- src/organisms/ip_panel.lua — Painel "IP" (VIOLET HUD §7.4.1 / §7.4.x, coluna do meio)      --
--                                                                                        --
-- Duas info-rows key/value (§7.4.1):                                                     --
--   IPv4  <addr>   |   IPv6  <addr>                                                       --
-- rótulo à esquerda (text_muted, CAIXA-ALTA) / valor à direita (text_bright, mono,        --
-- ellipsize). Endereço vazio -> "—". As linhas usam a molécula compartilhada             --
-- info_row{variant="plain", key_width} (o "plain" reproduz o antigo make_row: linha nua, --
-- largura de rótulo fixa, valor fixado à direita).                                       --
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
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)
local info_row = require("src.molecules.info_row") -- key/value HUD row (§7.4.1)

local EMPTY = "—"

return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Info-rows via molécula compartilhada (variant "plain" == look do antigo make_row).
  -- Refs diretas às linhas (:set_value); nunca consultamos ids de volta pelo panel() (R1).
  local row_v4 = info_row { key = "IPv4", value = EMPTY, variant = "plain", key_width = dpi(46) }
  local row_v6 = info_row { key = "IPv6", value = EMPTY, variant = "plain", key_width = dpi(46) }

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

  -- Define o valor de uma row, mostrando EMPTY quando vazio (info_row:set_value(nil)
  -- mantém o último valor por design — por isso passamos EMPTY explicitamente).
  local function set_value(row, addr)
    if not addr or addr == "" then
      row:set_value(EMPTY)
    else
      row:set_value(addr)
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

  local function sample()
    update_v4()
    update_v6()
  end

  local sample_timer = gears.timer {
    timeout   = args.timeout or 30,
    call_now  = false,
    autostart = false,
    callback  = sample,
  }

  local outer = panel({
    title      = "IP",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(260),
    right_icon = Icon("net", { size = dpi(14), color = p.text_muted }),
  })

  -- Sampling gated por visibilidade (control_center liga ao abrir / desliga ao fechar o
  -- dashboard): não consulta IP enquanto o popup está oculto (perf).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    sample()
    sample_timer:start()
  end
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end
