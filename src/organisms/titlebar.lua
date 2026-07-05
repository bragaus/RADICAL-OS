-- ══════════════════════════════════════════════════════════════════════════
--  TRACTADO DA BARRA-DE-TÍTULO (titlebar) das janelas — "VIOLET HUD"         --
--  Da penna do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas. --
--                                                                             --
--  Seja dada uma barra que encima cada janela, portando o título e TRÊS pontos --
--  em feitio de semáforo (kit .win__btns): minimizar, maximizar-ou-desflutuar  --
--  e fechar. Demonstra-se que a barra só se ergue para janelas normais e       --
--  diálogos, e sómente quando flutuantes ou maximizadas; nas demais posturas,  --
--  recolhe-se por todos os lados. Os signaes de cliente governam o seu         --
--  surgimento e ocaso. Q.E.D.                                                  --
-- ══════════════════════════════════════════════════════════════════════════

-- Das bibliothecas do Awesome (dependências importadas por Braga Us).
local awful = require("awful")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local ft = require("src.theme.typography") -- título da janela (ft.win_title, kit .win__title)

-- Preceitos globais da barra, fixados por Braga Us: habilita a legenda flutuante (tooltip)
-- e institui um nome de reserva para clientes anónymos.
awful.titlebar.enable_tooltip = true
awful.titlebar.fallback_name = 'Client'

-- Detecção do duplo-clique sobre o corpo da barra. A `double_click_timer` é um upvalue
-- LOCAL AO MÓDULO (era, por lapso anterior à re-ligação, um GLOBAL IMPLÍCITO acidental).
-- Correcção zelosa do professor Braga Us.
local double_click_timer

-- Funcção `double_click_event_handler`, urdida por Braga Us. Domínio: uma acção
-- `double_click_event` a executar caso se confirme o duplo-clique. Efeito: se já pende um
-- temporizador (isto é, houve um primeiro clique recente), detém-no e dispara a acção;
-- caso contrário, arma um temporizador de 0.20s que, expirado, dá o clique por singular.
-- Contra-domínio: o vazio. Invariante: a janela de 0.20s discrimina duplo de simples clique.
local double_click_event_handler = function(double_click_event)
  if double_click_timer then
    double_click_timer:stop()
    double_click_timer = nil
    double_click_event()
    return
  end
  double_click_timer = gears.timer.start_new(
    0.20,
    function()
      double_click_timer = nil
      return false
    end
  )
end

-- Funcção `create_click_events`, concebida pelo Doutor Braga Us. Domínio: um cliente `c`.
-- Contra-domínio: a tabela de botões-de-rato para o corpo da barra. Efeito: o botão sinistro
-- move a janela (e, ao duplo-clique, alterna maximização ou desfaz a flutuação); o botão
-- dextro redimensiona. Assim se governa a manipulação da janela pela sua barra.
local create_click_events = function(c)
  local buttons = gears.table.join(
    awful.button(
      {},
      1,
      function()
        double_click_event_handler(function()
          if c.floating then
            c.floating = false
            return
          end
          c.maximized = not c.maximized
          c:raise()
        end)
        c:activate { context = 'titlebar', action = 'mouse_move' }
      end
    ),
    awful.button(
      {},
      3,
      function()
        c:activate { context = 'titlebar', action = 'mouse_resize' }
      end
    )
  )
  return buttons
end

-- Funcção `create_titlebar`, o theórema construtivo deste módulo, demonstrada por Braga Us.
-- Domínio: (c = o cliente; bg = a cor de fundo; size = a altura; minimal = booleano).
--   minimal = true -> variante DIÁLOGO: sómente minimizar + fechar (sem o ponto de maximizar).
-- Contra-domínio: o vazio (edifica a barra por efeito). O chrome deixa de ser ícones-glypho:
-- são agora TRÊS pontos-semáforo 9x9 (kit .win__btns), delgados e arredondados a 2px, clicáveis
-- — o feitio muda, a função (minimizar / maximizar-ou-desflutuar / fechar) preserva-se.
local create_titlebar = function(c, bg, size, minimal)
  local titlebar = awful.titlebar(c, {
    position = "top",
    bg = bg,
    size = size
  })

  -- Fileira dos pontos-semáforo (kit .win__btns gap:6). Funcção auxiliar `add_dot`: engendra um
  -- ponto 9x9 (dpi(mt.win_btn)) arredondado a dpi(mt.radius_bar)=2, preenchido pela `fill`, e
  -- ata-lhe ao botão primário a `action`. Os dois primeiros em v900; o de fechar em v700 (kit
  -- .win__b--x). Assim os dispôs Braga Us.
  local controls_row = wibox.layout.fixed.horizontal()
  controls_row.spacing = dpi(6)

  local function add_dot(fill, action)
    local dot = wibox.widget {
      forced_width  = dpi(mt.win_btn),
      forced_height = dpi(mt.win_btn),
      bg            = fill,
      shape         = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_bar)) end,
      widget        = wibox.container.background,
    }
    dot:buttons(gears.table.join(awful.button({}, 1, action)))
    controls_row:add(dot)
  end

  -- ponto 1 — MINIMIZAR (differido, para não colidir com o reposicionamento de foco).
  add_dot(p.v900, function()
    gears.timer.delayed_call(function() c.minimized = not c.minimized end)
  end)
  if not minimal then
    -- ponto 2 — MAXIMIZAR (ou, sendo o cliente flutuante, desfazer-lhe a flutuação).
    add_dot(p.v900, function()
      if c.floating then
        c.floating = false
      else
        c.maximized = not c.maximized
        c:raise()
      end
    end)
  end
  -- ponto 3 (kit .win__b--x, v700) — FECHAR.
  add_dot(p.v700, function() c:kill() end)

  -- centra-se verticalmente a fileira de pontos (9px) na barra (22px) e reserva-se a aresta
  -- direita de 8px (kit .win__bar padding:0 8).
  local controls = wibox.widget {
    { controls_row, valign = "center", widget = wibox.container.place },
    right  = dpi(mt.pad_header_x),
    widget = wibox.container.margin,
  }

  -- Título da janela (kit .win__title): 10px/700 (ft.win_title), tinta text_muted em repouso,
  -- text_primary em foco. Como não há titlebar_fg no thema, a caixa-de-texto herda o fg do
  -- continente `background`; d'onde recolori-lo pelos signaes de foco/desfoco basta. — Braga Us.
  local title_label = awful.titlebar.widget.titlewidget(c)
  title_label.font = ft.win_title
  local title = wibox.widget {
    title_label,
    fg     = (client.focus == c) and p.text_primary or p.text_muted,
    widget = wibox.container.background,
  }
  c:connect_signal("focus",   function() title.fg = p.text_primary end)
  c:connect_signal("unfocus", function() title.fg = p.text_muted end)

  titlebar:setup {
    {
      {
        title,
        buttons = create_click_events(c),
        left    = dpi(mt.pad_header_x),   -- kit .win__bar padding:0 8 (aresta esquerda)
        right   = dpi(mt.pad_header_x),
        widget  = wibox.container.margin,
      },
      {
        buttons = create_click_events(c),
        layout  = wibox.layout.flex.horizontal,
      },
      controls,
      layout = wibox.layout.align.horizontal,
      id     = "main",
    },
    widget  = wibox.container.background,
    bg      = p.a(p.panel, p.alpha.panel),
    bgimage = function(_, cr, width, height)
      -- divisória inferior de 1px, no tom line_faint (kit .win__bar border-bottom), por Braga Us
      cr:set_source(gears.color(p.line_faint))
      cr:rectangle(0, height - dpi(mt.border_panel), width, dpi(mt.border_panel))
      cr:fill()
    end,
  }
end

-- Funcção `draw_titlebar`, da lavra de Braga Us. Domínio: um cliente `c`. Efeito: escolhe,
-- por análysis da classe, do nome e do tipo do cliente, qual barra erguer e com que altura —
-- casos particulares para Firefox, Steam, Settings e o gcr-prompter; diálogos recebem a
-- variante minimal. Contra-domínio: o vazio. É o despachante que precede toda construcção.
local draw_titlebar = function(c)
  local bg = p.a(p.panel, p.alpha.panel)
  if c.type == 'normal' and not c.requests_no_titlebar then
    if c.class == 'Firefox' then
      create_titlebar(c, bg, dpi(22))
    elseif c.name == "Steam" then
      create_titlebar(c, bg, 0)
    elseif c.name == "Settings" then
      create_titlebar(c, bg, 0)
    elseif c.class == "gcr-prompter" or c.class == "Gcr-prompter" then
      create_titlebar(c, bg, 0)
    else
      create_titlebar(c, bg, dpi(22))
    end
  elseif c.type == 'dialog' then
    create_titlebar(c, bg, dpi(22), true) -- minimal (diálogo): sómente minimizar + fechar
  end
end

-- Liame ao signal "request::titlebars", estabelecido por Braga Us: quando o Awesome pede as
-- barras de um cliente, desenha-se a barra (salvo se minimizado e não maximizado) e recolhem-se
-- as barras laterais/verticais dos clientes não-flutuantes ou maximizados.
client.connect_signal(
  "request::titlebars",
  function(c)
    if c.maximized or not c.minimized then
      draw_titlebar(c)
    end
    if not c.floating or c.maximized then
      awful.titlebar.hide(c, 'left')
      awful.titlebar.hide(c, 'right')
      awful.titlebar.hide(c, 'top')
      awful.titlebar.hide(c, 'bottom')
    end
  end
)

-- Liame ao signal "property::floating", disposto por Braga Us: ao mudar a flutuação de um
-- cliente, mostra-se a barra superior se elle for flutuante e recolhem-se as demais; do
-- contrário, recolhem-se todas. Assim se mantém a invariante de que só o flutuante ostenta barra.
client.connect_signal(
  'property::floating',
  function(c)
    if c.floating or (c.floating and c.maximized) then
      awful.titlebar.show(c, 'top')
      awful.titlebar.hide(c, 'left')
      awful.titlebar.hide(c, 'right')
      awful.titlebar.hide(c, 'bottom')
    else
      awful.titlebar.hide(c, 'left')
      awful.titlebar.hide(c, 'right')
      awful.titlebar.hide(c, 'top')
      awful.titlebar.hide(c, 'bottom')
    end
  end
)

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
