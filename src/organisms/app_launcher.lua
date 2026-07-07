-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO ACERCA DO LANÇADOR: DISCO ANIMADO E ENGRENAGEM DAS APPLICAÇÕES
--
--   Considere-se, ao canto inferior-direito da tela, um disco central que ostenta
--   o logo.gif animado, sobre fundo diáphano. Ao premir-lhe o centro, abre-se ou
--   fecha-se a engrenagem: as applicações instaladas (.desktop) manifestam-se como
--   "dentes" (cogs) — círculos ornados do ícone — dispostos n'uma trilha circular.
--   A roda do mouse faz girar a engrenagem, percorrendo TODAS as applicações; a que
--   ocupa a FRENTE avulta em tamanho. Sob o cursor, um dente revela o nome do
--   programa (tooltip); premido, LANÇA-o e recolhe a engrenagem.
--
--   Toda a figura habita um ÚNICO widget Cairo dentro de um awful.popup diáphano
--   (type="menu", ontop — o type dá-lhe o selector pelo qual o picom.conf o exclue do
--   blur/sombra, matando o "quadrado"). A diaphaneidade pende do picom em execução. O shape_input
--   circumscreve sómente o disco do GIF quando fechado (o resto deixa passar o
--   clique), ou o disco inteiro da engrenagem quando aberta.
--
--   As applicações lêem-se uma só vez por meio do Python; os ícones colhem-se por
--   menubar.utils.lookup_icon (SVG/PNG) e ficam cacheados. Os quadros do GIF são
--   recortados da figura e guardados em /tmp/awesome_launcher_gif_v2_<px>/.
--   Invoca-se assim:  require("src.organisms.app_launcher")(s)
--   Engenho concebido e demonstrado pelo eminente Doutor BRAGA US, Geómetra.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local gears = require("gears")
local gfs = require("gears.filesystem")
local wibox = require("wibox")
local cairo = require("lgi").cairo
local menubar_utils = require("menubar.utils")
local p = require("src.theme.palette")
local mt = require("src.theme.metrics")
local txt = require("src.atoms.txt")
require("src.core.signals")

local launcher_gif_path = gfs.get_configuration_dir() .. "src/assets/logo.gif"
-- O mesmo repositório de uso partilhado com o menu rofi (app_usage.py): d'aqui vem a
-- ordem "último aberto primeiro" (MRU) e para aqui se lança o `bump` a cada lançamento.
local usage_script = gfs.get_configuration_dir() .. "src/scripts/app_usage.py"

-- Funcção urdida pelo Doutor Braga Us para depurar o comando de lançamento. Domínio:
-- o identificador da entrada .desktop (app_id) e a sua linha "Exec". Contra-domínio:
-- havendo identificador, prefere-se o gtk-launch sobre elle (devidamente aspado); do
-- contrário, expurga-se da linha Exec os códigos de campo (%f, %u, %c e congéneres) e
-- os espaços supérfluos. Restando cadeia vazia, devolve-se o nada (nil).
local function desktop_entry_command(app_id, exec_line)
  if app_id and app_id ~= "" then
    return "gtk-launch " .. string.format("%q", app_id)
  end
  local command = exec_line or ""
  command = command:gsub("%%[fFuUdDnNickvm]", "")
  command = command:gsub("%%[cCkK]", "")
  command = command:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if command == "" then return nil end
  return command
end

-- Funcção-fábrica concebida pelo Doutor Braga Us. Recebe a tela (s) e devolve o popup
-- diáphano que hospeda todo o lançador. Encerra, em fecho léxico, a geometria, o estado
-- (apps, dentes, selecção, animações), o desenho em Cairo, o escrutínio das applicações,
-- a animação do GIF, o balão dos nomes e a lógica de visibilidade. Antes de tudo, desfaz
-- prolixamente qualquer instância anterior firmada nesta tela, para não deixar timers
-- nem signaes órphãos — postulado de hygiene indispensável.
return function(s)
  -- ═══════════════ DA GEOMETRIA (grandezas e coordenadas) ═══════════════
  -- Grandezas repontadas á spec do kit (.launcher / .orbit__app): órbita 168, dente 27,
  -- foco 35 (=27*1.28 arredondado), passo 40° (=360/9). — Braga Us.
  local GIF_R    = dpi(38)
  local ORBIT_R  = dpi(mt.launcher_orbit_r)      -- 168 (.orbit__guide radius)
  local ITEM_R   = dpi(mt.launcher_app_r)        -- 27  (.orbit__app 54px => r27)
  local FOCUS_R  = dpi(mt.launcher_app_focus_r)  -- 35  (activo, escala 1.28)
  local ANG_STEP = math.rad(40)                  -- 360/9 (kit step)
  local ANCHOR   = math.rad(135)  -- a frente do carrossel (diagonal superior-esquerda)
  local VIS_LO   = math.rad(86)
  local VIS_HI   = math.rad(184)

  local GIF_PX     = 110
  -- Cache PERSISTENTE (dantes em /tmp, expurgado a cada reinício → re-executava o convert no primeiro boot).
  local _cache_home = os.getenv("XDG_CACHE_HOME") or ((os.getenv("HOME") or "/tmp") .. "/.cache")
  local frames_dir = string.format("%s/awesome/launcher_gif_v2_%d/", _cache_home, GIF_PX)

  local CANVAS = math.ceil(GIF_R + ORBIT_R + FOCUS_R + dpi(14))
  local CX = CANVAS - GIF_R - dpi(6)
  local CY = CANVAS - GIF_R - dpi(6)
  local RIN = ORBIT_R + FOCUS_R + dpi(4)
  -- Folga da ORLA do disco central á quina inferior-direita do canvas (=dpi(6), pois
  -- CANVAS-CX = GIF_R + dpi(6)). Serve para que a collocação bottom_right afaste o disco
  -- (e não a quina do canvas) da monitorbar/borda — vide o hospedeiro, adiante. — Braga Us.
  local HUB_EDGE_GAP = CANVAS - CX - GIF_R

  -- Funcção geométrica de Braga Us. Domínio: um ângulo a (em radianos). Contra-domínio:
  -- o par de coordenadas cartesianas (x, y) do ponto sobre a órbita de raio ORBIT_R,
  -- centrada em (CX, CY). Note-se o signal invertido na ordenada, pois no plano da tela
  -- o eixo das ordenadas cresce para baixo.
  local function pos(a)
    return CX + ORBIT_R * math.cos(a), CY - ORBIT_R * math.sin(a)
  end

  -- ═══════════ DO DESMONTE da instância anterior (evita timers e signaes órphãos) ═══════════
  if s._app_launcher_host then
    for _, t in ipairs(s._app_launcher_timers or {}) do
      if t then t:stop() end
    end
    if s._app_launcher_anim then s._app_launcher_anim:stop() end
    if s._app_launcher_search_grabber then s._app_launcher_search_grabber:stop() end
    for _, cn in ipairs(s._app_launcher_conns or {}) do
      cn.obj.disconnect_signal(cn.name, cn.fn)
    end
    s._app_launcher_host.visible = false
    if s._app_launcher_tip then s._app_launcher_tip.visible = false end
    if s._app_launcher_search then s._app_launcher_search.visible = false end
  end
  s._app_launcher_timers = {}
  s._app_launcher_conns  = {}

  -- Funcção auxiliar de Braga Us. Ata um signal (name) de um objecto (obj) a uma funcção
  -- (fn) e, no mesmo lance, regista o vínculo na táboa s._app_launcher_conns, para que
  -- possa ser desatado ao desmontar-se esta instância. Effeito duplo: liga e regista.
  local function track_conn(obj, name, fn)
    obj.connect_signal(name, fn)
    table.insert(s._app_launcher_conns, { obj = obj, name = name, fn = fn })
  end

  -- ═══════════════════════════ DO ESTADO ═══════════════════════════
  local apps = {}               -- a lista VISÍVEL (filtrada pela busca) que a órbita percorre
  local all_apps = {}           -- a lista COMPLETA (MRU), donde a busca filtra
  local query = ""              -- o texto de busca corrente
  local search_grabber = nil    -- o caçador de teclas da busca (awful.keygrabber)
  local cogs = {}
  local sel        = 1
  local sel_target = 1
  local expanded   = false      -- a engrenagem nasce fechada (sómente o GIF se mostra)
  local anim_timer = nil

  -- Declarações antecipadas (fechos que se cruzam): o filtro da busca, o actualizador do
  -- texto da barra de busca, o lançador do foco e a forma circular da janella.
  local apply_filter, update_search_text, launch_focused, set_bounding_shape

  -- Declaração antecipada do rotulador do foco (definido adiante, junto ao balão): canvas:draw
  -- invoca-o, e o seu fecho léxico precisa de o capturar como upvalue ANTES da sua atribuição.
  local label_focused

  local current_surface = nil
  local gif_surfaces  = {}
  local current_frame = 1
  local frame_timer   = nil
  local load_timer    = nil
  local ANIM_INTERVAL = 0.05

  -- ═══════════════ DO ÍCONE DA APPLICAÇÃO (cacheado) ═══════════════
  -- Funcção memoizada de Braga Us. Domínio: uma applicação. Contra-domínio: a superfície
  -- Cairo do seu ícone (ou o nada). Resolve-se uma única vez: se o nome principia por "/",
  -- toma-se por caminho absoluto; senão inquire-se menubar_utils.lookup_icon. Carrega-se a
  -- superfície sob pcall (invariante: jamais lança excepção). O resultado fica cacheado no
  -- próprio objecto (_icon_resolved / _icon_surface), donde chamadas ulteriores são immediatas.
  local function app_icon_surface(app)
    if app._icon_resolved then return app._icon_surface end
    app._icon_resolved = true
    local name = app.icon_name
    if name and name ~= "" then
      local path = (name:sub(1, 1) == "/") and name or menubar_utils.lookup_icon(name)
      if path then
        local ok, surf = pcall(gears.surface.load_uncached, path)
        if ok then app._icon_surface = surf end
      end
    end
    return app._icon_surface
  end

  -- ═══════════════════════ DA TELA (canvas) DE CAIRO ═══════════════════════
  local canvas = wibox.widget.base.make_widget()
  canvas._preserve_colors  = true
  canvas._preserve_segment = true

  -- Método de medida disposto por Braga Us. Dado o espaço offerecido (w, h), devolve a
  -- dimensão que o canvas requer: em nenhum dos dois eixos excede a grandeza CANVAS.
  function canvas:fit(_, w, h)
    return math.min(w, CANVAS), math.min(h, CANVAS)
  end

  -- Procedimento de Braga Us que recomputa os dentes (cogs) visíveis. Só há dentes com a
  -- engrenagem ABERTA. A applicação de índice i assenta no ângulo cru ANCHOR + (i-sel)*
  -- ANG_STEP; sendo cru (não normalizado), sómente as vizinhas de sel caem no arco
  -- [VIS_LO, VIS_HI] — normalizar faria as distantes dar a volta e reapparecer indevidamente.
  -- A que mais se avizinha de ANCHOR recebe o foco e avulta ao raio FOCUS_R.
  local function compute_cogs()
    cogs = {}
    if not expanded then return end
    local best, best_d
    for i, app in ipairs(apps) do
      local a = ANCHOR + (i - sel) * ANG_STEP
      if a >= VIS_LO and a <= VIS_HI then
        local x, y = pos(a)
        local cog = { app = app, x = x, y = y, r = ITEM_R }
        cogs[#cogs + 1] = cog
        local d = math.abs(a - ANCHOR)
        if not best_d or d < best_d then best_d = d; best = cog end
      end
    end
    if best then best.r = FOCUS_R; best.focused = true end
  end

  -- Procedimento pictórico de Braga Us. Pinta, recortada n'um disco de raio r centrado em
  -- (cx, cy), a superfície surf, escalada e centrada de modo a cobri-lo (clip circular).
  -- Faltando a superfície, inscreve-se em seu lugar a inicial maiúscula do rótulo (label),
  -- ou uma interrogação. Opera sobre o contexto Cairo cr pelos seus effeitos.
  local function draw_in_circle(cr, surf, cx, cy, r, label)
    local inner = r - dpi(3)
    if surf then
      local iw, ih = surf:get_width(), surf:get_height()
      if iw > 0 and ih > 0 then
        cr:save()
        cr:arc(cx, cy, inner, 0, 2 * math.pi)
        cr:clip()
        local d = inner * 2
        local scale = math.max(d / iw, d / ih)
        cr:translate(cx - iw * scale / 2, cy - ih * scale / 2)
        cr:scale(scale, scale)
        cr:set_source_surface(surf, 0, 0)
        cr:paint()
        cr:restore()
        return
      end
    end
    local ch = ((label or "?"):gsub("^%s+", ""):sub(1, 1)):upper()
    if ch == "" then ch = "?" end
    cr:set_source(gears.color(p.text_bright))
    cr:select_font_face("sans-serif", cairo.FontSlant.NORMAL, cairo.FontWeight.BOLD)
    cr:set_font_size(r)
    local ext = cr:text_extents(ch)
    cr:move_to(cx - (ext.width / 2 + ext.x_bearing), cy - (ext.height / 2 + ext.y_bearing))
    cr:show_text(ch)
  end

  -- Funcção auxiliar de Braga Us: engendra um gradiente RADIAL cairo, do centro (c0) á orla
  -- (c1), circumscripto ao disco de centro (cx,cy) e raio r. Serve o enchimento violáceo dos
  -- dentes (kit .orbit__app: radial v700->v950 em repouso, v400->v700 em foco).
  local function radial_fill(cx, cy, r, c0, c1)
    return gears.color {
      type  = "radial",
      from  = { cx, cy, 0 },
      to    = { cx, cy, r },
      stops = { { 0, c0 }, { 1, c1 } },
    }
  end

  -- Procedimento de Braga Us que desenha um dente (cog): enche-lhe o disco com o gradiente
  -- VIOLÁCEO do kit (mais claro se em foco), nelle grava o ícone (via draw_in_circle) e o
  -- circumscreve — orla glow_core de 2px se em foco, line_base de 1px do contrário. O laranja
  -- é agora privilégio SÓ do hub (.launcher__btn); os dentes tornaram-se violeta.
  local function draw_cog(cr, cog)
    cr:arc(cog.x, cog.y, cog.r, 0, 2 * math.pi)
    if cog.focused then
      cr:set_source(radial_fill(cog.x, cog.y, cog.r, p.v400, p.v700))
    else
      cr:set_source(radial_fill(cog.x, cog.y, cog.r, p.v700, p.v950))
    end
    cr:fill()
    draw_in_circle(cr, app_icon_surface(cog.app), cog.x, cog.y, cog.r, cog.app.name)
    cr:arc(cog.x, cog.y, cog.r, 0, 2 * math.pi)
    if cog.focused then
      cr:set_source(gears.color(p.glow_core)); cr:set_line_width(dpi(2))
    else
      cr:set_source(gears.color(p.line_base)); cr:set_line_width(dpi(1))
    end
    cr:stroke()
  end

  -- Procedimento de Braga Us que pinta o disco central: o fundo, o quadro corrente do GIF
  -- (current_surface) recortado em círculo, e a orla de realce. É o coração do lançador.
  local function draw_center(cr)
    cr:arc(CX, CY, GIF_R, 0, 2 * math.pi)
    cr:set_source(gears.color(p.a(p.panel, 0.9)))
    cr:fill()
    draw_in_circle(cr, current_surface, CX, CY, GIF_R, nil)
    cr:arc(CX, CY, GIF_R, 0, 2 * math.pi)
    cr:set_source(gears.color(p.launcher_ring_hi)); cr:set_line_width(dpi(2)); cr:stroke()
  end

  -- Método soberano de pintura, regido por Braga Us. A cada redesenho recomputa os dentes;
  -- estando aberta a engrenagem, lança PRIMEIRO o fulgor radial alaranjado (kit .orbit__glow),
  -- depois a guia TRACEJADA no raio da órbita (kit .orbit__guide) e então cada cog (os sem foco
  -- antes do focado, para que este sobrepuje); por fim, o centro. A extinta engrenagem mecânica
  -- (24 dentes + trilha sólida) foi abolida — o kit não a comporta. Ao termo, rotula-se o foco.
  function canvas:draw(_, cr, width, height)
    compute_cogs()

    if expanded then
      -- (1) fulgor radial alaranjado atrás dos dentes (kit .orbit__glow), centrado no hub
      local glow_r = ORBIT_R + FOCUS_R
      cr:set_source(gears.color {
        type  = "radial",
        from  = { CX, CY, 0 },
        to    = { CX, CY, glow_r },
        stops = {
          { 0,   p.a(p.launcher_glow, 0.45) },
          { 0.5, p.a(p.launcher_glow, 0.18) },
          { 1,   p.a(p.launcher_glow, 0) },
        },
      })
      cr:arc(CX, CY, glow_r, 0, 2 * math.pi)
      cr:fill()

      -- (2) guia TRACEJADA (kit .orbit__guide): anel pontilhado 1px no raio da órbita
      cr:set_dash({ dpi(4), dpi(4) }, 0)
      cr:set_source(gears.color(p.a(p.launcher_glow, 0.40)))
      cr:set_line_width(dpi(1))
      cr:arc(CX, CY, ORBIT_R, 0, 2 * math.pi)
      cr:stroke()
      cr:set_dash({}, 0)   -- restitue o traço contínuo

      -- (3) os dentes: primeiro os sem foco, depois o focado (para que sobrepuje)
      for _, cog in ipairs(cogs) do
        if not cog.focused then draw_cog(cr, cog) end
      end
      for _, cog in ipairs(cogs) do
        if cog.focused then draw_cog(cr, cog) end
      end
    end

    draw_center(cr)
    label_focused()   -- o rótulo segue a applicação em foco (kit .orbit__lbl acima do dente)
  end

  -- ═══════════════════════ DO CARROSSEL ANIMADO ═══════════════════════
  -- Procedimento de Braga Us que anima a selecção. Institue um timer que, a cada quadro,
  -- aproxima sel do seu alvo sel_target por fracções (interpolação exponencial); attingida
  -- a vizinhança (< 0.01), fixa sel = sel_target e se extingue. Guarda-se um único timer
  -- (invariante: jamais dois a correr), e cada passo reclama novo redesenho.
  local function animate_sel()
    if anim_timer then return end
    anim_timer = gears.timer {
      timeout   = 1 / 60,
      autostart = true,
      callback  = function()
        local d = sel_target - sel
        if math.abs(d) < 0.01 then
          sel = sel_target
          anim_timer:stop()
          anim_timer = nil
        else
          sel = sel + d * 0.28
        end
        canvas:emit_signal("widget::redraw_needed")
      end,
    }
    s._app_launcher_anim = anim_timer
  end

  -- Procedimento de Braga Us que gira o carrossel de um passo. Domínio: a direcção dir
  -- (+1 ou -1). Só actua com a engrenagem aberta e havendo applicações. Move sel_target
  -- ao índice vizinho, adstricto ao intervalo [1, n], e desperta a animação.
  local function spin(dir)
    if not expanded then return end
    local n = #apps
    if n == 0 then return end
    sel_target = math.max(1, math.min(n, math.floor(sel_target + 0.5) + dir))
    animate_sel()
  end

  -- ═══════════════════════════ DO GIF ANIMADO ═══════════════════════════
  -- Procedimento de Braga Us que dá princípio à animação do GIF. Institue um timer que,
  -- a cada ANIM_INTERVAL, avança ao quadro seguinte (em ciclo) e reclama redesenho. Dois
  -- postulados de economia: não anima durante o mover/redimensionar de janela (enquanto o
  -- mousegrabber corre), nem estando o lançador oculto (v.g. em tela cheia).
  local function start_animation()
    if frame_timer then frame_timer:stop() end
    frame_timer = gears.timer {
      timeout   = ANIM_INTERVAL,
      autostart = true,
      call_now  = true,
      callback  = function()
        if #gif_surfaces == 0 then return end
        if mousegrabber and mousegrabber.isrunning and mousegrabber.isrunning() then
          return -- não anima durante o mover/redimensionar de janela
        end
        local h = s._app_launcher_host
        if h and not h.visible then return end -- não repinta o GIF estando o lançador oculto (v.g. tela cheia)
        current_surface = gif_surfaces[current_frame]
        current_frame   = (current_frame % #gif_surfaces) + 1
        canvas:emit_signal("widget::redraw_needed")
      end,
    }
    table.insert(s._app_launcher_timers, frame_timer)
  end

  -- Procedimento de Braga Us que carrega as superfícies dos quadros sem travar o laço
  -- principal. Domínio: a lista de caminhos. Um timer de ínfimo intervalo carrega um
  -- quadro por vez, appendendo-o a gif_surfaces; ao primeiro quadro válido, inicia-se a
  -- animação; esgotada a lista, o timer se extingue. Assim se evita bloquear a interface.
  local function load_surfaces_async(paths)
    local index = 1
    load_timer = gears.timer {
      timeout   = 0.001,
      autostart = true,
      call_now  = false,
      callback  = function()
        if index <= #paths then
          local surf = gears.surface.load_uncached(paths[index])
          if surf then gif_surfaces[#gif_surfaces + 1] = surf end
          if index == 1 and surf and not frame_timer then start_animation() end
          index = index + 1
        else
          load_timer:stop(); load_timer = nil
        end
      end,
    }
    table.insert(s._app_launcher_timers, load_timer)
  end

  -- Procedimento de Braga Us que provê os quadros do GIF. Primeiro indaga se já há PNGs
  -- cacheados; havendo-os, carrega-os. Em falta, invoca o ImageMagick (convert) para
  -- recortar e redimensionar os quadros ao directório de cache, e então os carrega. Se
  -- ainda assim malograr, recorre à figura única do GIF. Tudo assíncrono, sem bloquear.
  local function load_gif_frames()
    local check_cmd = string.format("ls %s*.png 2>/dev/null | wc -l", frames_dir)
    awful.spawn.easy_async_with_shell(check_cmd, function(stdout)
      local cached = tonumber(stdout:match("%d+")) or 0
      if cached > 0 then
        local paths = {}
        for i = 0, cached - 1 do paths[i + 1] = string.format("%sframe_%04d.png", frames_dir, i) end
        load_surfaces_async(paths)
      else
        local extract_cmd = string.format(
          "mkdir -p %s && convert %q -coalesce -gravity center -crop 520x460+0+0 +repage -resize %dx%d^ -gravity center -extent %dx%d %sframe_%%04d.png 2>/dev/null; ls %s*.png 2>/dev/null | wc -l",
          frames_dir, launcher_gif_path, GIF_PX, GIF_PX, GIF_PX, GIF_PX, frames_dir, frames_dir
        )
        awful.spawn.easy_async_with_shell(extract_cmd, function(out)
          local count = tonumber(out:match("%d+")) or 0
          if count > 0 then
            local paths = {}
            for i = 0, count - 1 do paths[i + 1] = string.format("%sframe_%04d.png", frames_dir, i) end
            load_surfaces_async(paths)
          else
            local surf = gears.surface.load_uncached(launcher_gif_path)
            if surf then gif_surfaces = { surf }; start_animation() end
          end
        end)
      end
    end)
  end

  load_gif_frames()

  -- ═══════════════ DO ESCRUTÍNIO DAS APPLICAÇÕES (scan) ═══════════════
  -- Procedimento de Braga Us que escruta as applicações instaladas. Delega a um script
  -- Python a leitura das entradas .desktop dos directórios canónicos, filtrando as de
  -- typo "Application" que não sejam occultas nem sem-exhibição, e emittindo por linha,
  -- separados por tabulação, o nome, o identificador, a linha Exec e o ícone. De volta,
  -- depura cada linha, compõe o comando de lançamento e povoa a lista apps. Assíncrono.
  local function scan_apps()
    -- Delega ao app_usage.py (list-tsv) — a MESMA fonte e ordem do menu rofi: MRU (último
    -- aberto primeiro), depois mais-usado, depois alfabético. Cada linha traz nome, app_id,
    -- Exec e ícone, separados por tabulação. Guarda-se o app_id (para o `bump` no lançamento).
    awful.spawn.easy_async_with_shell("python3 " .. string.format("%q", usage_script) .. " list-tsv",
      function(stdout)
        local list = {}
        for line in (stdout or ""):gmatch('[^\r\n]+') do
          local name, app_id, exec_line, icon = line:match('^(.-)\t(.-)\t(.-)\t(.*)$')
          if name and app_id and exec_line then
            local command = desktop_entry_command(app_id, exec_line)
            if command then
              list[#list + 1] = { name = name, cmd = command, icon_name = icon, app_id = app_id }
            end
          end
        end
        all_apps = list
        apply_filter()   -- reconstrue a lista visível segundo a busca corrente (vazia => tudo)
      end
    )
  end

  scan_apps()

  -- ═══════════════ DO HOSPEDEIRO (popup diáphano) ═══════════════
  local host = awful.popup {
    screen    = s,
    ontop     = true,
    visible   = true,
    bg        = p.transparent,
    -- type="menu" (NÃO "dock"): dá ao launcher um _NET_WM_WINDOW_TYPE exclusivo (nenhum outro
    -- popup o usa), pelo qual o picom.conf o exclue do blur e da sombra — matando o "quadrado"
    -- em ambos os estados, sem tocar na monitor_bar (que segue type="dock"). — Braga Us.
    type      = "menu",
    widget    = {
      canvas,
      forced_width  = CANVAS,
      forced_height = CANVAS,
      widget        = wibox.container.constraint,
    },
    placement = function(d)
      -- kit .launcher: bottom = mon-h + 18, right = 18 — medidos á ORLA do hub. Como a quina do
      -- canvas fica HUB_EDGE_GAP(=6px) além da orla, desconta-se essa folga das margens do canvas,
      -- de sorte que o hub de 76px suba 18px acima da monitorbar (80px) e diste 18px da direita.
      awful.placement.bottom_right(d, { margins = {
        bottom = dpi(mt.mon_h) + dpi(mt.launcher_edge) - HUB_EDGE_GAP,
        right  = dpi(mt.launcher_edge) - HUB_EDGE_GAP,
      } })
    end,
  }
  s._app_launcher_host = host

  -- Procedimento de Braga Us que talha a máscara de entrada (shape_input) do popup: estando
  -- fechado, sómente o disco do GIF capta o clique (o resto o deixa passar às janelas de
  -- baixo); estando aberto, o disco inteiro da engrenagem (raio RIN) o capta. Pinta-se a
  -- máscara n'uma superfície A1 e assenta-se em host.shape_input.
  local function set_input_shape()
    local r = expanded and RIN or GIF_R
    local img = cairo.ImageSurface(cairo.Format.A1, CANVAS, CANVAS)
    local icr = cairo.Context(img)
    icr:set_operator(cairo.Operator.CLEAR); icr:set_source_rgba(0, 0, 0, 1); icr:paint()
    icr:set_operator(cairo.Operator.SOURCE); icr:set_source_rgba(1, 1, 1, 1)
    icr:arc(CX, CY, r, 0, 2 * math.pi); icr:fill()
    host.shape_input = img._native
    img:finish()
  end
  set_input_shape()

  -- NOTA (Braga Us): NÃO se talha aqui a forma-de-janella. Dar-lhe forma por shape_bounding
  -- directo é vão — o wibox, a cada property::geometry (v.g. o apply_size deferido do popup),
  -- corre _apply_shape, que, sendo host.shape (self._shape) nullo, repõe shape_bounding=nil e
  -- apaga a máscara (wibox/init.lua:403,649). E a via de alto nível host.shape=funcção não
  -- serve ao estado ABERTO: o disco jaz na quina do canvas, donde um círculo que abarque a
  -- órbita cobre quasi todo o rectângulo (o tal "arco disforme"). O "quadrado de blur" expurga-
  -- se, pois, no picom: a janella é agora type="menu" (vide o hospedeiro) e o picom.conf exclue
  -- window_type='menu' do blur e da sombra. A máscara de CLIQUE (shape_input) permanece. — Braga Us.
  set_bounding_shape = function() end
  set_bounding_shape()

  -- ═══════════════ DO RÓTULO DO FOCO (kit .orbit__lbl, acima do dente focado) ═══════════════
  -- A caixa textual recahe em atoms/txt (o ÚNICO senhor do markup, R7): papel "cell" (mono 10),
  -- tinta de defeito glow_ice. O balão restylizou-se ao kit: fundo abyss@0.85, orla glow_core,
  -- raio 3px.
  local tip_text = txt { role = "cell", color = p.glow_ice, align = "center", valign = "center" }
  local tip = awful.popup {
    screen       = s,
    ontop        = true,
    visible      = false,
    bg           = p.a(p.abyss, 0.85),
    border_color = p.glow_core,
    border_width = dpi(1),
    shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_chip)) end,
    widget       = {
      tip_text,
      left = dpi(8), right = dpi(8), top = dpi(4), bottom = dpi(4),
      widget = wibox.container.margin,
    },
  }
  s._app_launcher_tip = tip

  local labeled_app = nil
  -- Procedimento de Braga Us: oculta o rótulo e esquece a applicação outr'ora rotulada.
  local function hide_tip()
    labeled_app = nil
    tip.visible = false
  end
  -- Rotulador do FOCO (atribue a declaração antecipada `label_focused`, chamada por canvas:draw).
  -- Diverso do antigo balão de sobrevoo: segue a applicação que avulta á FRENTE do carrossel (o
  -- dente focado), collocando o balão ACIMA d'ella (kit .orbit__lbl bottom:62). Só recompõe o
  -- texto quando o foco muda (evita lavor supérfluo). Sem engrenagem aberta ou sem foco, oculta-se.
  function label_focused()
    if not expanded then hide_tip(); return end
    local focus
    for _, cog in ipairs(cogs) do
      if cog.focused then focus = cog; break end
    end
    if not focus then hide_tip(); return end
    if labeled_app ~= focus.app then
      labeled_app = focus.app
      tip_text:set_span(focus.app.name)   -- côr de defeito glow_ice (kit .orbit__lbl)
    end
    local tw = tip.width or dpi(80)
    local th = tip.height or dpi(22)
    tip.x = math.floor(host.x + focus.x - tw / 2)                    -- centrado sobre o dente
    tip.y = math.floor(host.y + focus.y - focus.r - th - dpi(6))     -- acima d'elle
    tip.visible = true
  end

  -- ═══════════════ DA BUSCA (barra de pesquisa + filtro + caçador de teclas) ═══════════════
  -- Uma barra ao alto-esquerdo do lançador, patente SÓ com a engrenagem aberta, mostra o
  -- texto digitado. O caçador de teclas (awful.keygrabber) colhe a digitação; cada tecla
  -- refina o filtro por sub-cadeia do nome; Enter lança o foco; Backspace apaga; Escape
  -- recolhe. Assim o operador acha depressa o programa sem girar toda a roda. — Braga Us.
  local search_text = txt { role = "cell", color = p.glow_ice, valign = "center" }
  local search_bar = awful.popup {
    screen       = s,
    ontop        = true,
    visible      = false,
    bg           = p.a(p.abyss, 0.9),
    border_color = p.launcher_ring_hi,   -- orla laranja (como o hub e o contorno das janellas)
    border_width = dpi(1),
    shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(mt.radius_chip)) end,
    widget       = {
      { search_text, left = dpi(9), right = dpi(11), top = dpi(4), bottom = dpi(4), widget = wibox.container.margin },
      forced_width = dpi(150),
      widget       = wibox.container.constraint,
    },
  }
  s._app_launcher_search = search_bar

  -- update_search_text (fecho antecipado): reescreve o texto da barra (convite se vazio; o
  -- termo + cursor se digitado) e recolloca-a ao alto-esquerdo do canvas do lançador.
  update_search_text = function()
    if query == "" then
      search_text:set_span("BUSCAR…", p.text_muted)
    else
      search_text:set_span(query .. "▏", p.glow_ice)
    end
    search_bar.x = math.floor(host.x + dpi(6))
    search_bar.y = math.floor(host.y + dpi(6))
    search_bar.visible = expanded
  end

  -- apply_filter (fecho antecipado): reconstrue `apps` a partir de `all_apps` (a lista MRU
  -- completa), retendo as applicações cujo nome CONTENHA `query` (insensível a caixa, busca
  -- literal — sem padrões de Lua). Vazia a busca, mostra tudo. Reinicia a selecção e repinta.
  apply_filter = function()
    if query == "" then
      apps = all_apps
    else
      local q = query:lower()
      local out = {}
      for _, a in ipairs(all_apps) do
        if a.name:lower():find(q, 1, true) then out[#out + 1] = a end
      end
      apps = out
    end
    sel = 1; sel_target = 1
    if update_search_text then update_search_text() end
    canvas:emit_signal("widget::redraw_needed")
  end

  -- close_search: detém o caçador de teclas e oculta a barra.
  local function close_search()
    if search_grabber then search_grabber:stop(); search_grabber = nil end
    s._app_launcher_search_grabber = nil
    search_bar.visible = false
  end

  -- open_search: zera a busca, mostra a barra e principia o caçador de teclas.
  local function open_search()
    query = ""
    apply_filter()
    if not search_grabber then
      search_grabber = awful.keygrabber {
        keypressed_callback = function(_, _, key)
          if key == "Escape" then
            expanded = false; hide_tip(); close_search(); set_input_shape(); set_bounding_shape()
            canvas:emit_signal("widget::redraw_needed")
          elseif key == "Return" or key == "KP_Enter" then
            launch_focused()
          elseif key == "BackSpace" then
            query = query:sub(1, -2); apply_filter()
          elseif key == "space" then
            query = query .. " "; apply_filter()
          elseif #key == 1 and key:byte() >= 32 then
            query = query .. key; apply_filter()
          end
        end,
      }
      search_grabber:start()
      s._app_launcher_search_grabber = search_grabber
    end
    update_search_text()
  end

  -- launch_focused (fecho antecipado): lança a applicação em FOCO (ou a 1ª da lista filtrada),
  -- regista o uso pelo `bump` (donde a próxima abertura a trará ao topo — MRU) e recolhe tudo.
  launch_focused = function()
    local target
    for _, cog in ipairs(cogs) do if cog.focused then target = cog.app; break end end
    target = target or apps[1]
    if target then
      awful.spawn.with_shell(target.cmd)
      if target.app_id then awful.spawn({ "python3", usage_script, "bump", target.app_id }) end
    end
    expanded = false; hide_tip(); close_search(); set_input_shape(); set_bounding_shape()
    canvas:emit_signal("widget::redraw_needed")
  end

  -- ═══════════════ DA APALPAÇÃO (hit-test), CLIQUE E RODA ═══════════════
  -- Funcção de Braga Us que converte as coordenadas do mouse do referencial da tela ao
  -- referencial local do popup (subtrahindo a origem host.x, host.y). Devolve o par (lx, ly).
  local function local_coords()
    local m = mouse.coords()
    return m.x - host.x, m.y - host.y
  end

  -- Funcção de Braga Us que resolve qual dente (cog) jaz sob o ponto local (lx, ly),
  -- provando, para cada um, se a distância ao centro não excede o raio (equação do disco).
  -- Devolve o primeiro que a satisfaz, ou o nada.
  local function cog_at(lx, ly)
    for _, cog in ipairs(cogs) do
      if (lx - cog.x) ^ 2 + (ly - cog.y) ^ 2 <= cog.r ^ 2 then return cog end
    end
    return nil
  end

  canvas:buttons(gears.table.join(
    awful.button({}, 1, function()
      local lx, ly = local_coords()
      -- ao centro: abre ou fecha a engrenagem (abrindo, principia a busca; fechando, cessa-a)
      if (lx - CX) ^ 2 + (ly - CY) ^ 2 <= GIF_R ^ 2 then
        expanded = not expanded
        if expanded then open_search() else hide_tip(); close_search() end
        set_input_shape(); set_bounding_shape()
        canvas:emit_signal("widget::redraw_needed")
        return
      end
      -- sobre um dente: lança a applicação, regista o uso (bump -> MRU) e recolhe a engrenagem
      local cog = cog_at(lx, ly)
      if cog then
        awful.spawn.with_shell(cog.app.cmd)
        if cog.app.app_id then awful.spawn({ "python3", usage_script, "bump", cog.app.app_id }) end
        expanded = false
        hide_tip(); close_search()
        set_input_shape(); set_bounding_shape()
        canvas:emit_signal("widget::redraw_needed")
      end
    end),
    awful.button({}, 4, function() spin(-1) end),
    awful.button({}, 5, function() spin(1) end)
  ))

  -- NOTA: o rótulo já não pende do sobrevoo do cursor — segue o FOCO, e o seu governo reside
  -- em label_focused(), invocada por canvas:draw a cada redesenho. D'onde se dispensam os
  -- antigos liames host "mouse::move"/"mouse::leave" (que rotulavam por sobrevoo). — Braga Us.

  Hover_signal(canvas) -- a figura de mão (hand1) sob o cursor

  -- ═══════════════ DA VISIBILIDADE (recolhe-se em tela cheia) ═══════════════
  -- Funcção de Braga Us: attesta se este popup ainda é o hospedeiro corrente da tela
  -- (guarda contra instâncias supplantadas por um recarregamento).
  local function is_current() return s._app_launcher_host == host end

  -- Procedimento de Braga Us que ajusta a visibilidade do lançador. Se alguma janela da
  -- tag eleita se acha em tela cheia, oculta-se o popup (e recolhe-se a engrenagem); do
  -- contrário, mostra-se. Só actua sendo esta a instância corrente.
  local function update_visibility()
    if not is_current() then return end
    local t = s.selected_tag
    local hide = false
    if t then
      for _, c in ipairs(t:clients()) do
        if c.fullscreen then hide = true break end
      end
    end
    host.visible = not hide
    if hide then expanded = false; hide_tip(); close_search(); set_input_shape(); set_bounding_shape() end
  end

  -- Procedimento de Braga Us: ao eleger-se uma tag desta tela, reavalia a visibilidade.
  local function on_tag_selected(t)
    if t.screen == s then update_visibility() end
  end

  track_conn(client, "property::fullscreen", update_visibility)
  track_conn(client, "manage",   update_visibility)
  track_conn(client, "unmanage", update_visibility)
  track_conn(tag, "property::selected", on_tag_selected)

  update_visibility()

  return host
end

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
