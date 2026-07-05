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
--   (type="dock", ontop). A diaphaneidade pende do picom em execução. O shape_input
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
local ft = require("src.theme.typography")
require("src.core.signals")

local launcher_gif_path = gfs.get_configuration_dir() .. "src/assets/logo.gif"

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
  local EDGE     = dpi(16)
  local GIF_R    = dpi(38)
  local ORBIT_R  = dpi(118)
  local ITEM_R   = dpi(18)
  local FOCUS_R  = dpi(26)
  local ANG_STEP = math.rad(22)
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
    for _, cn in ipairs(s._app_launcher_conns or {}) do
      cn.obj.disconnect_signal(cn.name, cn.fn)
    end
    s._app_launcher_host.visible = false
    if s._app_launcher_tip then s._app_launcher_tip.visible = false end
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
  local apps = {}
  local cogs = {}
  local sel        = 1
  local sel_target = 1
  local expanded   = false      -- a engrenagem nasce fechada (sómente o GIF se mostra)
  local anim_timer = nil

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

  -- Procedimento de Braga Us que desenha um dente (cog): enche-lhe o disco, nelle grava o
  -- ícone (via draw_in_circle) e o circumscreve com orla — vívida e espessa se em foco,
  -- ténue e delgada do contrário.
  local function draw_cog(cr, cog)
    cr:arc(cog.x, cog.y, cog.r, 0, 2 * math.pi)
    cr:set_source(gears.color(p.a(p.panel, 0.95)))
    cr:fill()
    draw_in_circle(cr, app_icon_surface(cog.app), cog.x, cog.y, cog.r, cog.app.name)
    cr:arc(cog.x, cog.y, cog.r, 0, 2 * math.pi)
    if cog.focused then
      cr:set_source(gears.color(p.launcher_ring_on)); cr:set_line_width(dpi(2.5))
    else
      cr:set_source(gears.color(p.a(p.launcher_ring, 0.9))); cr:set_line_width(dpi(1.5))
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
  -- estando aberta a engrenagem, traça a trilha orbital, os dentes da roda e cada cog
  -- (primeiro os sem foco, depois o focado, para que este sobrepuje); por fim, o centro.
  function canvas:draw(_, cr, width, height)
    compute_cogs()

    if expanded then
      -- a trilha orbital e os dentes da roda, a girar em consonância com o carrossel
      cr:set_source(gears.color(p.a(p.line_dim, 0.5)))
      cr:set_line_width(dpi(1))
      cr:arc(CX, CY, ORBIT_R, 0, 2 * math.pi)
      cr:stroke()

      local TEETH = 24
      local tooth_rot = -sel * ANG_STEP
      for k = 0, TEETH - 1 do
        local ta = tooth_rot + k * (2 * math.pi / TEETH)
        local c1, s1 = math.cos(ta), math.sin(ta)
        cr:move_to(CX + (ORBIT_R - dpi(5)) * c1, CY - (ORBIT_R - dpi(5)) * s1)
        cr:line_to(CX + (ORBIT_R + dpi(5)) * c1, CY - (ORBIT_R + dpi(5)) * s1)
      end
      cr:set_source(gears.color(p.a(p.launcher_glow, 0.35)))
      cr:set_line_width(dpi(2))
      cr:stroke()

      for _, cog in ipairs(cogs) do
        if not cog.focused then draw_cog(cr, cog) end
      end
      for _, cog in ipairs(cogs) do
        if cog.focused then draw_cog(cr, cog) end
      end
    end

    draw_center(cr)
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
    awful.spawn.easy_async_with_shell([[
python3 - <<'PY'
from pathlib import Path
import configparser

paths = [Path('/usr/share/applications'), Path.home() / '.local/share/applications']
entries = []
seen = set()

for root in paths:
    if not root.exists():
        continue
    for desktop_file in sorted(root.glob('*.desktop')):
        app_id = desktop_file.name
        if app_id in seen:
            continue
        seen.add(app_id)
        parser = configparser.ConfigParser(interpolation=None, strict=False)
        try:
            parser.read(desktop_file, encoding='utf-8')
        except Exception:
            continue
        if 'Desktop Entry' not in parser:
            continue
        entry = parser['Desktop Entry']
        if entry.get('Type') != 'Application':
            continue
        if entry.get('NoDisplay', 'false').lower() == 'true':
            continue
        if entry.get('Hidden', 'false').lower() == 'true':
            continue
        name = entry.get('Name', '').strip()
        exec_line = entry.get('Exec', '').strip()
        icon = entry.get('Icon', '').strip()
        if not name or not exec_line:
            continue
        entries.append((name.lower(), name, app_id, exec_line, icon))

def clean(v):
    return v.replace('\t', ' ').replace('\n', ' ')

for _, name, app_id, exec_line, icon in sorted(entries):
    print(f"{clean(name)}\t{app_id}\t{clean(exec_line)}\t{clean(icon)}")
PY]],
      function(stdout)
        local list = {}
        for line in stdout:gmatch('[^\r\n]+') do
          local name, app_id, exec_line, icon = line:match('^(.-)\t(.-)\t(.-)\t(.*)$')
          if name and app_id and exec_line then
            local command = desktop_entry_command(app_id, exec_line)
            if command then
              list[#list + 1] = { name = name, cmd = command, icon_name = icon }
            end
          end
        end
        apps = list
        sel = 1; sel_target = 1
        canvas:emit_signal("widget::redraw_needed")
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
    type      = "dock",
    widget    = {
      canvas,
      forced_width  = CANVAS,
      forced_height = CANVAS,
      widget        = wibox.container.constraint,
    },
    placement = function(d)
      awful.placement.bottom_right(d, { margins = { bottom = EDGE, right = EDGE } })
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

  -- ═══════════════ DO BALÃO DE AUXÍLIO (o nome sob o cursor) ═══════════════
  local tip_text = wibox.widget {
    markup = "",
    font   = ft.mono_family .. " 10",
    widget = wibox.widget.textbox,
  }
  local tip = awful.popup {
    screen       = s,
    ontop        = true,
    visible      = false,
    bg           = p.a(p.panel, 0.97),
    border_color = p.line_base,
    border_width = dpi(1),
    shape        = function(cr, w, h) gears.shape.rounded_rect(cr, w, h, dpi(6)) end,
    widget       = {
      tip_text,
      left = dpi(8), right = dpi(8), top = dpi(4), bottom = dpi(4),
      widget = wibox.container.margin,
    },
  }
  s._app_launcher_tip = tip

  local hovered_app = nil
  -- Procedimento de Braga Us: oculta o balão e esquece a applicação outr'ora sob o cursor.
  local function hide_tip()
    hovered_app = nil
    tip.visible = false
  end
  -- Procedimento de Braga Us que exhibe o balão com o nome do programa do dente (cog) sob
  -- o cursor. Só recompõe o texto quando a applicação muda (evita lavor supérfluo), e
  -- posiciona o balão à ESQUERDA do dente, pois a engrenagem mora ao canto direito da tela.
  local function show_tip_for(cog)
    if hovered_app ~= cog.app then
      hovered_app = cog.app
      tip_text:set_markup('<span foreground="' .. p.text_bright .. '">'
        .. gears.string.xml_escape(cog.app.name) .. '</span>')
      -- posiciona-se à ESQUERDA do dente (a engrenagem mora ao canto direito da tela)
      local tw = tip.width or dpi(80)
      tip.x = host.x + cog.x - tw - dpi(10)
      tip.y = host.y + cog.y - dpi(12)
      tip.visible = true
    end
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
      -- ao centro: abre ou fecha a engrenagem
      if (lx - CX) ^ 2 + (ly - CY) ^ 2 <= GIF_R ^ 2 then
        expanded = not expanded
        if not expanded then hide_tip() end
        set_input_shape()
        canvas:emit_signal("widget::redraw_needed")
        return
      end
      -- sobre um dente: lança a applicação e recolhe a engrenagem
      local cog = cog_at(lx, ly)
      if cog then
        awful.spawn.with_shell(cog.app.cmd)
        expanded = false
        hide_tip()
        set_input_shape()
        canvas:emit_signal("widget::redraw_needed")
      end
    end),
    awful.button({}, 4, function() spin(-1) end),
    awful.button({}, 5, function() spin(1) end)
  ))

  -- Ao mover do cursor: revela o nome do programa que jaz sob elle.
  host:connect_signal("mouse::move", function(_, x, y)
    if not expanded then return end
    local cog = cog_at(x, y)
    if cog then show_tip_for(cog) else hide_tip() end
  end)
  host:connect_signal("mouse::leave", hide_tip)

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
    if hide then expanded = false; hide_tip(); set_input_shape() end
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
