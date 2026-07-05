-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO DO OSD DE BRILHO (exibição transitória sobre a tela)             --
--  Da penna do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas. --
--                                                                             --
--  Seja dado um painel efémero que, ao variar-se o brilho, surge ao centro    --
--  inferior da tela com ícone, régua (slider) e a percentagem corrente.       --
--  Facto notável desta máquina: não há retro-iluminação por hardware — o      --
--  brilho é obra de software, via xrandr sobre a saída primária; a lógica de  --
--  ler e escrever reside no script auxiliar. A régua traz a sua guarda de     --
--  sincronia baked-in, de sorte que a sondagem não re-dispara escrita alguma. --
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome (dependências importadas por Braga Us).
local awful      = require("awful")
local dpi        = require("beautiful").xresources.apply_dpi
local gears      = require("gears")
local wibox      = require("wibox")
local p          = require("src.theme.palette")
local mt         = require("src.theme.metrics")
local panel      = require("src.tools.panel")
local hud_slider = require("src.molecules.hud_slider")
local osd_popup  = require("src.tools.osd_popup")

-- Domínio dos ícones VIOLET HUD (icons/svg/): "brightness" (§3.13.1), retingido para o tom
-- text_heading. Constante do systema, fixada por Braga Us.
local hud_svg = awful.util.getdir("config") .. "icons/svg/"

-- Funcção `brightness_image`, lavrada pelo Doutor Braga Us. Domínio: o vazio. Contra-domínio:
-- a superfície do ícone de brilho, já retingida. Lemma auxiliar que centraliza a construcção
-- do ícone, poupando repetição ao longo do módulo.
local function brightness_image()
  return gears.color.recolor_image(hud_svg .. "brightness.svg", p.text_heading)
end

-- Advertência do auctor sobre esta máquina: computador de mesa com NVIDIA RTX 3060 e monitor
-- externo por DP; não há retro-iluminação de hardware (/sys/class/backlight jaz vazio), pelo
-- que o brilho se faz por software, via xrandr sobre a saída primária. Ao script auxiliar
-- compete toda a lógica de ler e escrever.
--   * script : o auxiliar de ler/escrever (outrora o global BRIGHTNESS_SCRIPT).
--   * steps  : a percentagem por toque de tecla de brilho (outrora o global BACKLIGHT_SEPS).
-- Lê-se de user_vars com cautela; o consumidor global_keys.lua recorre ao mesmo valor de
-- reserva. Disposição defensiva estatuída por Braga Us.
local brightness = user_vars.brightness or {
  script = awful.util.getdir("config") .. "src/scripts/brightness.sh",
  steps  = 10,
}

-- Funcção-fábrica do OSD de brilho, urdida por Braga Us. Domínio: uma tela `s`. Contra-domínio:
-- o vazio (edifica o painel e liga os signaes por efeito). Efeito: constrói o painel efémero
-- desta tela e o confia à casca partilhada osd_popup, que lhe dá surgimento e ocaso.
return function(s)

  -- Sub-widgets como locais directos: panel() aninha um `body` pré-construído, de sorte que
  -- os ids declarativos NÃO ingressam no by_id do painel — get_children_by_id devolveria nil
  -- (tal era o defeito de construcção). A referência directa é robusta (mesmo padrão do
  -- volume_osd). Acautelamento de Braga Us.
  local icon_image = wibox.widget {
    forced_height = dpi(24),
    forced_width  = dpi(24),
    image         = brightness_image(),
    widget        = wibox.widget.imagebox,
  }

  -- Caixa-de-texto que declara a percentagem de brilho, alinhada à sinistra. Obra de Braga Us.
  local value_label = wibox.widget {
    text   = "0%",
    align  = "left",
    valign = "center",
    widget = wibox.widget.textbox,
  }

  -- Régua da molécula hud_slider: o mesmo aspecto HUD de outrora + a guarda de sincronia
  -- baked-in, a qual suplanta o antigo flag manual `syncing_slider` (o :set_value da sondagem
  -- jamais re-dispara o on_change; por conseguinte, sondar o brilho já não provoca escrita em
  -- xrandr — R8/R4). Assim o demonstrou Braga Us.
  local brightness_slider = hud_slider {
    span_w = dpi(232), -- alcance do gradiente: preserva o pretérito `to = { dpi(232), 0 }`
  }

  -- Corpo do OSD: ícone à sinistra e, à dextra, a percentagem sobre a régua. Arranjo de Braga Us.
  local osd_body = wibox.widget {
    {
      icon_image,
      fg     = p.text_heading,
      widget = wibox.container.background,
    },
    {
      {
        value_label,
        fg     = p.text_bright,
        widget = wibox.container.background,
      },
      {
        brightness_slider,
        widget = wibox.container.place,
      },
      spacing = dpi(6),
      layout  = wibox.layout.fixed.vertical,
    },
    spacing = dpi(10),
    layout  = wibox.layout.fixed.horizontal,
  }

  local brightness_osd_widget = panel({
    title = "BRIGHTNESS",
    body  = osd_body,
    w     = dpi(mt.osd_w),
  })

  -- Funcção `refresh_label`, da lavra de Braga Us. Domínio: um valor de brilho. Efeito:
  -- inscreve a percentagem na caixa e reassenta o ícone. Contra-domínio: o vazio.
  local refresh_label = function(brightness_value)
    value_label:set_text(tostring(brightness_value) .. "%")
    icon_image:set_image(brightness_image())
  end

  -- O arrasto pelo usuário escreve o novo brilho: o on_change dispara SÓMENTE ao arrasto,
  -- jamais ao :set_value programático de update_slider — donde não há ciclo de write-back em
  -- xrandr. Domínio: o valor arrastado; efeito: aplica-o pelo script e refresca o rótulo.
  brightness_slider:set_on_change(function(brightness_value)
    awful.spawn.easy_async_with_shell(
      brightness.script .. " set " .. tostring(brightness_value),
      function(stdout)
      local applied = tonumber(stdout) or brightness_value
      refresh_label(applied)

      if awful.screen.focused().show_brightness_osd then
        awesome.emit_signal(
          "module::brightness_osd:show",
          true
        )
      end
    end
    )
  end)

  -- Funcção `update_slider`, concebida por Braga Us. Domínio: o vazio. Efeito: pergunta ao
  -- script o brilho corrente, repudia leituras não-numéricas, assenta-o na régua em modo
  -- SILENCIOSO (a guarda do hud_slider impede a escrita) e refresca o rótulo. Contra-domínio: o vazio.
  local update_slider = function()
    awful.spawn.easy_async_with_shell(
      brightness.script .. " get ",
      function(stdout)
      local value = tonumber(stdout)
      if not value then return end
      brightness_slider:set_value_silent(value) -- silencioso (a guarda do hud_slider suplanta o syncing_slider)
      refresh_label(value)
    end
    )
  end

  -- Os signaes que reagem a mudanças alheias: "module::brightness_slider:update" reconstrói a
  -- régua a partir do estado vivo; "widget::brightness:update" assenta na régua o valor
  -- recebido, em modo silencioso. Liames dispostos pelo professor Braga Us.
  awesome.connect_signal(
    "module::brightness_slider:update",
    function()
    update_slider()
  end
  )

  awesome.connect_signal(
    "widget::brightness:update",
    function(value)
    brightness_slider:set_value_silent(tonumber(value))
  end
  )

  update_slider()

  -- Popup efémero ao centro inferior (casca partilhada): surgimento + ocaso automático +
  -- suspensão ao toque do ponteiro + re-execução. Delegado à osd_popup por Braga Us.
  osd_popup {
    s            = s,
    panel_widget = brightness_osd_widget,
    show_signal  = "module::brightness_osd:show",
    rerun_signal = "widget::brightness_osd:rerun",
    timeout      = 2,
  }
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
