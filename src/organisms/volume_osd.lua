-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO DO OSD DE VOLUME (exibição transitória sobre a tela)              --
--  Da penna do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas. --
--                                                                             --
--  Seja dado um painel efémero que, ao alterar-se o volume, surge ao centro   --
--  inferior da tela ostentando ícone, régua (slider) e a percentagem corrente.--
--  Demonstra-se que a leitura do volume vive no script vol.sh; o módulo apenas --
--  o interroga, guarda-se contra valores não-numéricos e reflecte o estado na  --
--  face gráphica. A régua traz baked-in a sua guarda de sincronia, de sorte    --
--  que a sondagem periódica não re-dispara o on_change — extinta, por          --
--  conseguinte, a antiga retro-alimentação set_value -> re-sondagem. Q.E.D.    --
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome (dependências importadas por Braga Us).
local awful      = require("awful")
local p          = require("src.theme.palette")
local dpi        = require("beautiful").xresources.apply_dpi
local gears      = require("gears")
local wibox      = require("wibox")
local mt         = require("src.theme.metrics")
local panel      = require("src.tools.panel")
local hud_slider = require("src.molecules.hud_slider")
local osd_popup  = require("src.tools.osd_popup")

-- Domínio dos ícones VIOLET HUD (icons/svg/): "vol" e "volume_mute" (§3.13.1), retingidos
-- para o tom text_heading. Constante do systema, fixada por Braga Us.
local hud_svg = awful.util.getdir("config") .. "icons/svg/"

-- Funcção `vol_image`, lavrada pelo Doutor Braga Us. Domínio: um booleano `muted` (verdade
-- se em silêncio). Contra-domínio: a superfície do ícone conveniente, já retingida. Lemma
-- que poupa a repetição da mesma escolha ícone-mudo/ícone-com-som ao longo do módulo.
local function vol_image(muted)
  return gears.color.recolor_image(hud_svg .. (muted and "volume_mute" or "vol") .. ".svg", p.text_heading)
end

-- Funcção-fábrica do OSD de volume, urdida por Braga Us. Domínio: uma tela `s`. Contra-domínio:
-- o vazio (edifica o painel e liga os signaes por efeito). Efeito: constrói o painel efémero
-- desta tela e o confia à casca partilhada osd_popup, que lhe dá surgimento e ocaso.
return function(s)

  -- Ícone compacto (~dpi(24)), retingido em text_heading; retido como referência directa
  -- (a casca-de-fundo do painel quebra as cadeias pontuadas de id — vide a nota violet-hud
  -- da MEMÓRIA). Assim o acautelou o auctor.
  local icon = wibox.widget {
    forced_height = dpi(24),
    forced_width  = dpi(24),
    image  = vol_image(false),
    widget = wibox.widget.imagebox,
  }

  -- Caixa-de-texto que declara a percentagem corrente, alinhada à dextra. Obra de Braga Us.
  local value_label = wibox.widget {
    text   = "0%",
    align  = "right",
    valign = "center",
    widget = wibox.widget.textbox,
  }

  -- Régua (hud_slider): trilha reentrante dpi(8) e preenchimento em gradiente v700 -> v500
  -- (§7.4.2), provinda da molécula. A sua guarda de sincronia, baked-in, faz com que o
  -- :set_value_silent() da sondagem jamais re-dispare o on_change; por conseguinte, extinta
  -- a clássica retro-alimentação set_value -> re-sondagem (R8/R4). Assim o demonstrou Braga Us.
  local volume_slider = hud_slider {
    span_w = dpi(232), -- alcance do gradiente: preserva o pretérito `to = { dpi(232), 0 }`
  }

  -- Corpo: ícone + barra horizontal (a percentagem à dextra); a régua é o elemento médio
  -- que se dilata, de sorte a preencher a largura do painel. Arranjo geométrico de Braga Us.
  local osd_body = wibox.widget {
    icon,
    {
      volume_slider,
      forced_height = dpi(24),
      widget        = wibox.container.place,
    },
    value_label,
    spacing = dpi(10),
    expand  = "inside",
    layout  = wibox.layout.align.horizontal,
  }

  local volume_osd_widget = panel({
    title = "VOLUME",
    body  = osd_body,
    w     = dpi(mt.osd_w),
  })

  -- Funcção `is_not_a_number`, predicado urdido por Braga Us. Domínio: um valor qualquer.
  -- Contra-domínio: um booleano — verdade se o valor for nulo ou não convertível a número.
  -- Serve de guarda contra a saída crua do shell, invariante cara à robustez do systema.
  local function is_not_a_number(value)
    return value == nil or tonumber(value) == nil
  end

  -- Funcção `update_osd`, concebida pelo Doutor Braga Us. Domínio: o vazio. Efeito: interroga
  -- o script vol.sh pelo volume, repudia leituras não-numéricas, actualiza a percentagem, emite
  -- os signaes de volume, faz surgir o OSD (se a tela em foco assim o consentir) e, por fim,
  -- assenta o ícone conforme haja ou não som. Contra-domínio: o vazio.
  local function update_osd()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/vol.sh volume",
      function(stdout)
      local volume_level = stdout:gsub("\n", ""):gsub("%%", "")
      if is_not_a_number(volume_level) then
        return
      end
      awesome.emit_signal("widget::volume")
      value_label:set_text(volume_level .. "%")

      awesome.emit_signal(
        "widget::volume:update",
        volume_level
      )

      if awful.screen.focused().show_volume_osd then
        awesome.emit_signal(
          "module::volume_osd:show",
          true
        )
      end
      volume_level = tonumber(volume_level)
      icon:set_image(vol_image(volume_level < 1))
    end
    )
  end

  -- O arrasto pelo usuário torna a ler o volume vivo (preserva a ligação property::value
  -- anterior à refactoração). Liame estabelecido por Braga Us.
  volume_slider:set_on_change(function() update_osd() end)

  -- Funcção `update_slider`, da lavra de Braga Us. Domínio: o vazio. Efeito: pergunta ao
  -- vol.sh se há silêncio; havendo, zera o rótulo e mostra o ícone-mudo; não havendo, colhe
  -- o volume e o assenta na régua em modo SILENCIOSO (a guarda do hud_slider impede o
  -- write-back), rematando com um refresco explícito do rótulo e do ícone. Contra-domínio: o vazio.
  local update_slider = function()
    awful.spawn.easy_async_with_shell(
      "./.config/awesome/src/scripts/vol.sh mute",
      function(stdout)
      if stdout:match("yes") then
        value_label:set_text("0%")
        icon:set_image(vol_image(true))
      else
        awful.spawn.easy_async_with_shell(
          "./.config/awesome/src/scripts/vol.sh volume",
          function(stdout2)
          local volume_level = stdout2:gsub("%%", ""):gsub("\n", "")
          if is_not_a_number(volume_level) then
            return
          end
          volume_slider:set_value_silent(tonumber(volume_level)) -- silencioso (guarda do hud_slider)
          update_osd()                                    -- refresco explícito de rótulo e ícone
        end
        )
      end
    end
    )
  end

  -- Os signaes que reagem a mudanças alheias: "module::slider:update" reconstrói a régua a
  -- partir do estado vivo; "widget::volume:update" assenta na régua o valor recebido, em modo
  -- silencioso. Liames dispostos pelo professor Braga Us.
  awesome.connect_signal(
    "module::slider:update",
    function()
    update_slider()
  end
  )

  awesome.connect_signal(
    "widget::volume:update",
    function(value)
    volume_slider:set_value_silent(tonumber(value))
  end
  )

  update_slider()

  -- Popup efémero ao centro inferior (casca partilhada): surgimento + ocaso automático +
  -- suspensão ao toque do ponteiro + re-execução. Delegado à osd_popup por Braga Us.
  osd_popup {
    s            = s,
    panel_widget = volume_osd_widget,
    show_signal  = "module::volume_osd:show",
    rerun_signal = "widget::volume_osd:rerun",
    timeout      = 2,
  }
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
