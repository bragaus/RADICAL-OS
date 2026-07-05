------------------------------------------------------------------------------------------
-- src/organisms/protocols_donut.lua — "PROTOCOLS" (VIOLET HUD, §7.4.4)                      --
--                                                                                        --
-- Donut (molécula donut = anel + legenda) das contagens de conexão de rede por estado:   --
--   ESTABLISHED (data1) · LISTEN (data3) · OTHER (data5).                                --
-- Amostragem ASSÍNCRONA via awful.spawn.easy_async_with_shell("ss -tunH") num            --
-- gears.timer (5s, call_now). Nunca usar io.popen/os.execute aqui (trava o WM).          --
------------------------------------------------------------------------------------------

local awful = require("awful")
local gears = require("gears")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local panel = require("src.tools.panel")
local donut = require("src.molecules.donut")
local Icon = require("src.tools.icons") -- ícones SVG do set icons/ (§3.13)

return function(args)
  args = args or {}

  -- Corpo = molécula donut (anel cairo + legenda swatch/label/%). Semeada com as três
  -- categorias em zero; o update reordena maior→menor e repopula via :set_slices.
  local chart = donut {
    slices = {
      { label = "ESTABLISHED", pct = 0, color = p.data1 },
      { label = "LISTEN",      pct = 0, color = p.data3 },
      { label = "OTHER",       pct = 0, color = p.data5 },
    },
  }

  -- Atualização: guarda com tonumber, ordena as três categorias por valor (maior→menor)
  -- e entrega ao donut (que normaliza pela soma dos pct — all-zero vira 1 internamente).
  local function update(estab, listen, other)
    estab = tonumber(estab) or 0
    listen = tonumber(listen) or 0
    other = tonumber(other) or 0

    local cats = {
      { label = "ESTABLISHED", pct = estab,  color = p.data1 },
      { label = "LISTEN",      pct = listen, color = p.data3 },
      { label = "OTHER",       pct = other,  color = p.data5 },
    }
    table.sort(cats, function(a, b) return a.pct > b.pct end)

    chart:set_slices(cats)
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
    timeout = 5,
    call_now = false,
    autostart = false,
    callback = refresh,
  }

  local outer = panel({
    title      = "PROTOCOLS",
    body       = chart,
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
