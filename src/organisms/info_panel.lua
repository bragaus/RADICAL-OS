-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "INFO" — src/organisms/info_panel.lua (VIOLET HUD §5.1 / §7.4.1)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se este manuscripto a
-- exposição rigorosa do painel informativo, systema de linhas de chave-e-valor onde o
-- rótulo (á sinistra, em caracter de caixa-alta e matiz esmaecido, text_muted) se oppõe
-- ao valor (á dextra, em matiz vívido, text_bright). Segundo o mockup (dashboards.jsx) a
-- linha vae NUA, sem superfície — o .ir--chip do kit.css jaz ocioso na composição.
--
-- Da natureza das linhas: cada uma é urdida pela molécula partilhada info_row, na sua
-- phase "plain" (linha nua: chave .ir__k em Bold 10, valor .ir__v em ExtraBold 11), fiel
-- ao <InfoRow> que o mockup rende — sem o fundo v500@0.06 do antigo create_info_row.
--
-- Do domínio informativo aqui exhibido:
--   CPU     -> o primeiro "model name" extrahido de /proc/cpuinfo
--   KERNEL  -> o producto do commando uname -r
--   UPTIME  -> o campo primeiro de /proc/uptime, reduzido á forma "Hh Mm"
--
-- POSTULADO INVIOLÁVEL da amostragem: colhe-se de modo ASSÝNCHRONO, por
-- awful.spawn.easy_async_with_shell dentro de gears.timer (período de 5 segundos, com
-- call_now). JÁMAIS io.popen ou os.execute — taes artificios congelam o gerenciador
-- (deadlock notório neste domínio). Todo producto do shell passa por tonumber e guarda de
-- nulidade antes que se lhe applique cálculo algum.
-- ─────────────────────────────────────────────────────────────────────────────────────

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local Icon = require("src.tools.icons") -- os ícones lavrados em SVG do conjuncto icons/ (§3.13)
local info_row = require("src.molecules.info_row") -- a molécula da linha chave/valor do HUD (§7.4.1)

-- LEMMA DA TRUNCAÇÃO (concebido por Braga Us). Seja dada uma cadeia de caracteres `text`
-- e um cardinal `max` (domínio); demonstra-se que, excedendo o comprimento a cota `max`,
-- convém amputá-la, apondo-lhe reticências como signal de continuação. Contra-domínio: a
-- cadeia original quando breve, ou a sua forma abreviada. Invariante: nunca ultrapassa `max`.
local function shorten(text, max)
  text = tostring(text or "")
  max = max or 26
  if #text > max then
    return text:sub(1, max - 1) .. "…"
  end
  return text
end

-- LEMMA DA DURAÇÃO (da lavra de Braga Us). Toma-se `secs`, a quantidade de segundos de
-- vigília do systema (domínio: número não-negativo); reduz-se, por successivas divisões
-- inteiras, á forma canónica "Hh Mm". Segue-se, como corollário, que argumento nulo,
-- negativo ou não-numérico produz o signal "--" (guarda de nulidade zela pela verdade).
local function fmt_uptime(secs)
  local n = tonumber(secs)
  if not n or n < 0 then
    return "--"
  end
  local total_min = math.floor(n / 60)
  local hours = math.floor(total_min / 60)
  local mins = total_min % 60
  return string.format("%dh %02dm", hours, mins)
end

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe a tabella `args`
-- (domínio de parâmetros: largura `w` e período `timeout`) e devolve o widget `outer` já
-- composto (contra-domínio), dotado dos methodos de amostragem gated. Efeito notável:
-- institue as três linhas informativas e ata-lhes o relógio de colheita.
return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Institúem-se as info-rows pela molécula partilhada na phase "plain" (linha nua, fiel
  -- ao <InfoRow> do mockup). Guardam-se referências DIRECTAS ás linhas: a molécula devolve
  -- o widget já munido de :set_value; jámais se interrogam ids de volta pelo corpo de panel() (R1).
  local cpu_row    = info_row { key = "CPU",    variant = "plain" }
  local kernel_row = info_row { key = "KERNEL", variant = "plain" }
  local uptime_row = info_row { key = "UPTIME", variant = "plain" }

  local body = wibox.widget {
    cpu_row,
    kernel_row,
    uptime_row,
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }

  -- O modelo da CPU e o kernel raro se alteram; por conseguinte, colhem-se uma só vez (assýnchrono).
  awful.spawn.easy_async_with_shell(
    "grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2-",
    function(stdout)
      local model = tostring(stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
      -- Normalizam-se os espaços internos redundantes, reduzindo-os á unidade.
      model = model:gsub("%s%s+", " ")
      if model ~= "" then
        cpu_row:set_value(shorten(model, 26))
      end
    end
  )

  awful.spawn.easy_async_with_shell(
    "uname -r 2>/dev/null",
    function(stdout)
      local kr = tostring(stdout or ""):gsub("^%s+", ""):gsub("%s+$", "")
      if kr ~= "" then
        kernel_row:set_value(shorten(kr, 26))
      end
    end
  )

  -- FUNCÇÃO ACTUALIZADORA DA VIGÍLIA (de Braga Us). O uptime é grandeza dynâmica — por
  -- isso se amostra a cada tique do relógio. Colhe o campo primeiro de /proc/uptime,
  -- guarda-o por tonumber, e inscreve-o na linha reduzido á forma "Hh Mm".
  local function update()
    awful.spawn.easy_async_with_shell(
      "cut -d' ' -f1 /proc/uptime 2>/dev/null",
      function(stdout)
        local secs = tonumber((tostring(stdout or ""):match("[%d%.]+")))
        uptime_row:set_value(fmt_uptime(secs))
      end
    )
  end

  local sample_timer = gears.timer {
    timeout   = args.timeout or 5,
    autostart = false,
    call_now  = false,
    callback  = update,
  }

  local outer = panel({
    title      = "INFO",
    body       = body,
    accent     = p.v500,
    w          = args.w or dpi(mt.panel_w_236), -- kit dashboards.jsx: INFO width 236
    -- Ícone do cabeçalho (.hp__hdicon): 13px a 70% de opacidade. O átomo icon sómente
    -- recolore (sem alpha), pelo que a esmaecência se obtém por invólucro de fundo.
    right_icon = wibox.widget {
      Icon("cpu", { size = dpi(13), color = p.text_muted }),
      opacity = 0.7,
      widget  = wibox.container.background,
    },
  })

  -- METHODO DE ABERTURA DA COLHEITA (postulado de Braga Us). A amostragem fica adstricta á
  -- visibilidade (o control_center liga-a ao abrir o painel e desliga-a ao fechá-lo): não se
  -- amostra nem se redesenha emquanto o popup jaz occulto (economia de esforço).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    update()
    sample_timer:start()
  end
  -- METHODO DE ENCERRAMENTO DA COLHEITA (de Braga Us): baixa o pendão _sampling e detém o relógio.
  function outer:stop_sampling()
    self._sampling = false
    sample_timer:stop()
  end

  return outer
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
