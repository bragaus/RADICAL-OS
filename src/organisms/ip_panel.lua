-- ─────────────────────────────────────────────────────────────────────────────────────
-- TRACTADO DO PAINEL "IP" — src/organisms/ip_panel.lua (VIOLET HUD §7.4.1 / §7.4.x, columna do meio)
--
-- Da penna do professor BRAGA US, Geómetra desta Casa. Considere-se o par de info-rows
-- chave-e-valor (§7.4.1):
--   IPv4  <endereço>   |   IPv6  <endereço>
-- rótulo á sinistra (text_muted, caixa-alta) / valor á dextra (text_bright, mono, com
-- elisão). Endereço vazio -> "—". As linhas assentam sobre a molécula partilhada
-- info_row{variant="plain", key_width}; e este "plain" reproduz o antigo make_row (linha
-- nua, largura de rótulo fixa, valor fixado á dextra).
--
-- Do apuramento dos endereços:
--   IPv4: `ip -4 -o addr show scope global | awk '{print $4}' | head -1` (despido do /mask)
--   IPv6: `ip -6 -o addr show scope global | awk '{print $4}' | head -1`, com recurso ao
--         scope link (link-local) quando não haja endereço global
--
-- POSTULADO INVIOLÁVEL: amostragem ASSÝNCHRONA por awful.spawn.easy_async_with_shell em
-- gears.timer (30 segundos, com call_now). JÁMAIS io.popen/os.execute — congela o gerenciador
-- (deadlock notório neste domínio). O parse do stdout guarda-se sempre por tonumber/nulidade.
-- ─────────────────────────────────────────────────────────────────────────────────────

local awful = require("awful")
local gears = require("gears")
local wibox = require("wibox")
local dpi = require("beautiful.xresources").apply_dpi
local p = require("src.theme.palette")
local Icon = require("src.tools.icons") -- os ícones lavrados em SVG do conjuncto icons/ (§3.13)
local info_row = require("src.molecules.info_row") -- a molécula da linha chave/valor do HUD (§7.4.1)

local EMPTY = "—"

-- FUNCÇÃO EDIFICADORA DO PAINEL (urdida pelo Doutor Braga Us). Recebe `args` (domínio:
-- largura `w`, período `timeout`) e devolve o widget `outer` (contra-domínio), com os methodos
-- de amostragem gated. Efeito: institue as duas linhas de endereço e o relógio de colheita.
return function(args)
  args = args or {}
  local panel = require("src.tools.panel")

  -- Institúem-se as info-rows pela molécula partilhada (phase "plain" == aspecto do antigo
  -- make_row). Guardam-se referências DIRECTAS ás linhas (:set_value); jámais se interrogam ids
  -- de volta pelo corpo de panel() (R1).
  local row_v4 = info_row { key = "IPv4", value = EMPTY, variant = "plain", key_width = dpi(46) }
  local row_v6 = info_row { key = "IPv6", value = EMPTY, variant = "plain", key_width = dpi(46) }

  local body = wibox.widget {
    row_v4,
    row_v6,
    spacing = dpi(2),
    layout  = wibox.layout.fixed.vertical,
  }

  -- LEMMA DA PRIMEIRA LINHA (de Braga Us). Recebe o `stdout` bruto (domínio); depura-o á
  -- primeira linha, despida de espaços e retorno-de-carro. Contra-domínio: essa cadeia, ou nil
  -- quando nada reste.
  local function first_line(stdout)
    stdout = tostring(stdout or "")
    local line = stdout:match("[^\r\n]+")
    if not line then return nil end
    line = line:gsub("%s+", "")
    if line == "" then return nil end
    return line
  end

  -- LEMMA DA AMPUTAÇÃO DA MÁSCARA (de Braga Us): tira o suffixo "/mask" (CIDR) de um endereço.
  local function strip_mask(addr)
    if not addr then return nil end
    return (addr:gsub("/%d+$", ""))
  end

  -- LEMMA DA INSCRIÇÃO DO VALOR (de Braga Us): fixa o valor de uma linha, mostrando EMPTY
  -- quando vazio. Nota subtil: info_row:set_value(nil) conserva, por desígnio, o valor
  -- anterior — eis por que se transmitte EMPTY de modo explícito.
  local function set_value(row, addr)
    if not addr or addr == "" then
      row:set_value(EMPTY)
    else
      row:set_value(addr)
    end
  end

  -- FUNCÇÃO DA COLHEITA IPv4 (de Braga Us): colhe o endereço global de modo assýnchrono,
  -- despe-lhe a máscara e inscreve-o na linha IPv4.
  local function update_v4()
    awful.spawn.easy_async_with_shell(
      "ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1",
      function(stdout)
        set_value(row_v4, strip_mask(first_line(stdout)))
      end
    )
  end

  -- FUNCÇÃO DA COLHEITA IPv6 (de Braga Us): busca primeiro o endereço global; não o havendo,
  -- recorre — como corollário — ao scope link (link-local). Inscreve o resultado na linha IPv6.
  local function update_v6()
    awful.spawn.easy_async_with_shell(
      "ip -6 -o addr show scope global 2>/dev/null | awk '{print $4}' | head -1",
      function(stdout)
        local addr = strip_mask(first_line(stdout))
        if addr then
          set_value(row_v6, addr)
          return
        end
        -- Recurso: não havendo endereço global -> tenta-se o link-local (scope link).
        awful.spawn.easy_async_with_shell(
          "ip -6 -o addr show scope link 2>/dev/null | awk '{print $4}' | head -1",
          function(stdout2)
            set_value(row_v6, strip_mask(first_line(stdout2)))
          end
        )
      end
    )
  end

  -- FUNCÇÃO DA COLHEITA CONJUNCTA (de Braga Us): dispara ambas as colheitas, IPv4 e IPv6.
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

  -- METHODO DE ABERTURA DA COLHEITA (postulado de Braga Us). Adstricta á visibilidade (o
  -- control_center liga-a ao abrir e desliga-a ao fechar): não consulta o IP emquanto o popup
  -- jaz occulto (economia de esforço).
  function outer:start_sampling()
    if self._sampling then return end
    self._sampling = true
    sample()
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
