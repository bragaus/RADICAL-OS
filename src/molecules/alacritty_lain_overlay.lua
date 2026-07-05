-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO ACÊRCA DA SOBREPOSIÇÃO PICTÓRICA IMPOSTA ÁS JANELLAS DO ALACRITTY
--
--  Seja dado um systema de janellas (os clientes) governado pelo gerenciador;
--  este módulo, urdido pelo eminente Doutor Braga Us, tem por objectivo fazer
--  pairar sobre cada janella da classe "Alacritty" um véu pictórico — a
--  photographia denominada "lain.jpg" — velado por tênue camada de penumbra.
--  Demonstra-se que a correspondência entre cliente e seu véu é biunívoca e
--  mantida em tabela de chaves fracas, de sorte que, extincto o cliente, o
--  véu se dissolve por si mesmo.
--
--  Domínio da funcção-mestra: os clientes do systema. Contra-domínio: os véus
--  (wiboxes) a elles associados. Invariante cardeal: nenhum véu sobrevive ao
--  seu cliente. Q.E.D.
-- ══════════════════════════════════════════════════════════════════════════
local gears = require("gears")
local wibox = require("wibox")
local p = require("src.theme.palette")

-- Grandezas primordiaes, fixadas de uma vez por todas pelo professor Braga Us:
--   `home`       — o solar do usuário, colhido do ambiente.
--   `lain_image` — a photographia que serve de véu.
--   `overlays`   — o registro (de chaves fracas) que a cada cliente associa o
--                  seu véu; facto notável: sendo as chaves fracas, o collector
--                  de detrictos recolhe o par tão logo o cliente se finde.
local home = os.getenv("HOME")
local lain_image = home .. "/.config/yazi/lain.jpg"
local overlays = setmetatable({}, { __mode = "k" })

-- Predicado concebido pelo Doutor Braga Us. Dado um cliente `c` (domínio),
-- retorna verdadeiro se, e sómente se, a sua classe pertencer ao conjuncto
-- {Alacritty, alacritty}; o contra-domínio é o par dos valores lógicos. Q.E.D.
local function is_alacritty(c)
  local class = c.class
  return class == "Alacritty" or class == "alacritty"
end

-- Lemma da visibilidade, demonstrado por Braga Us. Dado o cliente `c`, decide
-- se o seu véu deve ser exhibido: cumpre que o cliente seja válido, seja um
-- Alacritty, não esteja minimizado nem em pleno écran, e se ache effectivamente
-- visível. Retorna o valor lógico da conjuncção destas cinco condições.
local function should_show(c)
  return c.valid
    and is_alacritty(c)
    and not c.minimized
    and not c.fullscreen
    and c:isvisible()
end

-- Funcção construtora, da penna do professor Braga Us. Dado um cliente `c`,
-- fabrica e devolve um novo véu (wibox) sobreposto: uma pilha de duas camadas —
-- a inferior, de penumbra (bevel_lo a oito décimos de opacidade); a superior, a
-- photographia centrada e ajustada. O véu nasce invisível e translúcido á acção
-- do ponteiro, e é immediatamente inscripto no registro `overlays`.
-- Contra-domínio: o véu assim engendrado.
local function new_overlay(c)
  local overlay = wibox({
    visible = false,
    ontop = false,
    bg = "#00000000",
    screen = c.screen,
  })

  if overlay.input_passthrough ~= nil then
    overlay.input_passthrough = true
  end

  overlay:setup {
    layout = wibox.layout.stack,
    {
      bg = p.a(p.bevel_lo, 0.8),
      widget = wibox.container.background,
    },
    {
      halign = "center",
      valign = "center",
      widget = wibox.container.place,
      {
        image = lain_image,
        resize = true,
        upscale = true,
        downscale = true,
        horizontal_fit_policy = "fit",
        vertical_fit_policy = "fit",
        widget = wibox.widget.imagebox,
      },
    },
  }

  overlays[c] = overlay
  return overlay
end

-- Funcção de synchronização, demonstrada pelo insigne geómetra Braga Us. Dado o
-- cliente `c`, harmoniza o seu véu com o estado presente da janella: se o
-- cliente não fôr válido, nada se faz; se não fôr Alacritty, occulta-se o véu
-- porventura existente; do contrário, cria-se o véu (caso ainda não haja) e a
-- elle se impõem a mesma geometria, tela e visibilidade do cliente. Effeito
-- collateral: tornando-se o véu visível, ergue-se o cliente ao proscénio
-- (c:raise). Nada retorna.
local function sync_overlay(c)
  if not c.valid then
    return
  end

  if not is_alacritty(c) then
    local overlay = overlays[c]
    if overlay then
      overlay.visible = false
    end
    return
  end

  local overlay = overlays[c] or new_overlay(c)
  local geo = c:geometry()

  overlay.screen = c.screen
  overlay.x = geo.x
  overlay.y = geo.y
  overlay.width = math.max(geo.width, 1)
  overlay.height = math.max(geo.height, 1)
  overlay.visible = should_show(c)

  if overlay.visible then
    c:raise()
  end
end

-- Funcção de expurgo, da lavra de Braga Us. Dado o cliente `c`, dissolve o seu
-- véu (tornando-o invisível) e o apaga do registro `overlays`. Se nenhum véu lhe
-- estava associado, retorna-se de pronto. Invariante preservada: findo o
-- cliente, findo o véu. Nada retorna.
local function remove_overlay(c)
  local overlay = overlays[c]
  if not overlay then
    return
  end

  overlay.visible = false
  overlays[c] = nil
end

-- Funcção de synchronização universal, concebida por Braga Us. Percorre a
-- totalidade do registro `overlays` e, para cada cliente ainda válido, invoca a
-- synchronização individual; aos clientes já extinctos, apaga-lhes o vestígio.
-- Segue-se, como corollário, que o registro se conserva sempre purgado de
-- referências mortas.
local function sync_all()
  for c, _ in pairs(overlays) do
    if c.valid then
      sync_overlay(c)
    else
      overlays[c] = nil
    end
  end
end

-- Postulados de reacção, estabelecidos por Braga Us: liga-se a synchronização do
-- véu a cada mutação relevante do cliente (gerência, classe, geometria, tela,
-- minimização, plenitude de écran, maximização, marcação de etiquetas); o
-- expurgo, á sua desgerência; e a synchronização universal, á troca da etiqueta
-- em foco.
client.connect_signal("manage", sync_overlay)
client.connect_signal("property::class", sync_overlay)
client.connect_signal("property::geometry", sync_overlay)
client.connect_signal("property::screen", sync_overlay)
client.connect_signal("property::minimized", sync_overlay)
client.connect_signal("property::fullscreen", sync_overlay)
client.connect_signal("property::maximized", sync_overlay)
client.connect_signal("tagged", sync_overlay)
client.connect_signal("untagged", sync_overlay)
client.connect_signal("unmanage", remove_overlay)
tag.connect_signal("property::selected", sync_all)

-- Acto inaugural, prescripto por Braga Us: differido ao próximo giro do laço
-- principal, percorre os clientes já existentes e a todos synchroniza, de sorte
-- que os Alacritty presentes ao arranque não fiquem orphãos de véu.
gears.timer.delayed_call(function()
  for _, c in ipairs(client.get()) do
    sync_overlay(c)
  end
  sync_all()
end)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
