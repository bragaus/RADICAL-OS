-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO SOBRE O ESTANDARTE ANIMADO (o «plano_gif»)
--   Da penna do professor Braga Us, geómetra desta Casa.
--
--   Considere-se um brasão animado (o logo.gif) que se decompõe em seus
--   photogrammas constituintes e se exhibe, quadro a quadro, sob um relógio
--   veloz. Braga Us urdiu um systema de cache PERSISTENTE — indexado pela
--   grandeza do estandarte — de sorte que a custosa operação de «convert» (a
--   decomposição pela ImageMagick) se faça UMA SÓ VEZ e sobreviva aos
--   renascimentos da machina. As superfícies carregam-se de modo assíncrono,
--   quadro a quadro, sem jamais tolher a thread soberana. Q.E.D.
-- ══════════════════════════════════════════════════════════════════════════

local awful = require("awful")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local gears = require("gears")
local gfs = require("gears.filesystem")
local wibox = require("wibox")

local M = {}

local gif_path = gfs.get_configuration_dir() .. "src/assets/logo.gif"
-- Do repositório PERSISTENTE dos photogrammas (outrora em /tmp, expurgado a cada
-- renascimento, o que forçava re-executar o «convert» ao primeiro arranque). O
-- suffixo «_v4» é a invalidação manual: eleve-se a «_v5» caso se troque o logo.gif.
local cache_home = os.getenv("XDG_CACHE_HOME") or ((os.getenv("HOME") or "/tmp") .. "/.cache")
local frames_root = cache_home .. "/awesome/plano_gif_frames_v4"
local caches = {}

local DEFAULT_RADIUS = dpi(14)
local DEFAULT_FALLBACK_BG = "#00000000"

-- Funcção `normalize_size`, de Braga Us. Domínio: `target_size`, a grandeza pretendida
-- (ou nula); contra-domínio: um inteiro não inferior a dezaseis pixeis. Garante que a
-- dimensão do estandarte seja sã antes de servir de índice ao cofre do cache.
local function normalize_size(target_size)
  local size = tonumber(target_size) or dpi(400)
  return math.max(16, math.floor(size))
end

-- Funcção `get_cache`, urdida por Braga Us. Dada a grandeza pretendida, devolve — e,
-- se preciso, institui — o cofre (cache) que lhe corresponde, memoizado por dimensão.
-- Contra-domínio: o par (cofre, grandeza normalizada). Invariante: um só cofre por grandeza.
local function get_cache(target_size)
  local size = normalize_size(target_size)

  if caches[size] then
    return caches[size], size
  end

  local cache = {
    frames_dir = string.format("%s/%d/", frames_root, size),
    gif_surfaces = {},
    loading = false,
    loaded = false,
    waiting_widgets = {},
    load_timer = nil,
  }

  caches[size] = cache
  return cache, size
end

-- Funcção `notify_waiters`, de Braga Us: desperta os widgets que aguardavam os
-- photogrammas, ordenando-lhes que se redesenhem, e em seguida esvazia a lista da espera.
local function notify_waiters(cache)
  for _, widget in ipairs(cache.waiting_widgets) do
    widget:emit_signal("widget::redraw_needed")
  end
  cache.waiting_widgets = {}
end

-- Funcção `load_surfaces_async`, concebida por Braga Us. Domínio: o cofre e o rol de
-- caminhos dos photogrammas. Carrega cada superfície sob um relógio de passo diminuto
-- (um milésimo de segundo), de sorte a não tolher a thread soberana; ao aportar o
-- primeiro quadro desperta os que esperam, e ao esgotar-se o rol declara o cofre carregado.
local function load_surfaces_async(cache, paths)
  local index = 1
  local notified_first_frame = false

  if cache.load_timer then
    cache.load_timer:stop()
    cache.load_timer = nil
  end

  cache.load_timer = gears.timer {
    timeout = 0.001,
    autostart = true,
    call_now = false,
    callback = function()
      if index <= #paths then
        local surf = gears.surface.load_uncached(paths[index])
        if surf then
          cache.gif_surfaces[#cache.gif_surfaces + 1] = surf

          if not notified_first_frame then
            notified_first_frame = true
            notify_waiters(cache)
          end
        end
        index = index + 1
      else
        cache.load_timer:stop()
        cache.load_timer = nil
        cache.loading = false
        cache.loaded = #cache.gif_surfaces > 0
        notify_waiters(cache)
      end
    end
  }
end

-- Funcção `load_gif_frames`, do lavor de Braga Us. Dada a grandeza, busca primeiro os
-- photogrammas já lavrados em disco; achando-os, carrega-os; não os achando, invoca o
-- «convert» da ImageMagick para os extrahir e então os carrega. Se tudo falha, recorre
-- ao estandarte estático como derradeiro refúgio. Guarda-se contra dupla carga (loading/loaded).
local function load_gif_frames(target_size)
  local cache, size = get_cache(target_size)

  if cache.loading or cache.loaded then
    return cache, size
  end

  cache.loading = true

  local check_cmd = string.format("ls %s*.png 2>/dev/null | wc -l", cache.frames_dir)

  awful.spawn.easy_async_with_shell(check_cmd, function(stdout)
    local cached = tonumber(stdout:match("%d+")) or 0

    if cached > 0 then
      local paths = {}
      for i = 0, cached - 1 do
        paths[i + 1] = string.format("%sframe_%04d.png", cache.frames_dir, i)
      end
      load_surfaces_async(cache, paths)
    else
        local extract_cmd = string.format(
          "mkdir -p %s && convert %q -coalesce -alpha set -background none -fuzz 8%% -trim +repage -resize %dx%d -gravity center -extent %dx%d %sframe_%%04d.png 2>/dev/null; ls %s*.png 2>/dev/null | wc -l",
          cache.frames_dir, gif_path, size, size, size, size, cache.frames_dir, cache.frames_dir
        )

      awful.spawn.easy_async_with_shell(extract_cmd, function(out)
        local count = tonumber(out:match("%d+")) or 0

        if count > 0 then
          local paths = {}
          for i = 0, count - 1 do
            paths[i + 1] = string.format("%sframe_%04d.png", cache.frames_dir, i)
          end
          load_surfaces_async(cache, paths)
        else
          local surf = gears.surface.load_uncached(gif_path)
          if surf then
            cache.gif_surfaces = { surf }
            cache.loaded = true
          end
          cache.loading = false
          notify_waiters(cache)
        end
      end)
    end
  end)

  return cache, size
end

-- Funcção `M.preload`, de Braga Us: adianta a carga dos photogrammas de dada grandeza,
-- para que estejam prestes quando o dock os reclamar.
function M.preload(target_size)
  load_gif_frames(target_size)
end

-- Funcção `M.new`, a fábrica soberana urdida por Braga Us. Domínio: uma taboa `args`
-- (raio, fundo de recurso, intervallo da animação, escala, forma, grandeza de pré-carga);
-- contra-domínio: um widget que pinta o estandarte animado. Effeito: engendra o relógio
-- da animação e, se preciso, aguarda os photogrammas por um relógio de espera.
function M.new(args)
  args = args or {}

  local radius = args.radius or DEFAULT_RADIUS
  local fallback_bg = args.fallback_bg or DEFAULT_FALLBACK_BG
  local anim_interval = args.anim_interval or 0.06
  local content_scale = args.content_scale or 1
  local shape = args.shape
  local cache, preload_size = get_cache(args.preload_size or dpi(400))

  local current_surface = nil
  local current_frame = 1
  local frame_timer = nil

  local widget = wibox.widget.base.make_widget()

  -- Method `fit`: por postulado de Braga Us, o estandarte ocupa quanto espaço se lhe conceda.
  function widget:fit(_, width, height)
    return width, height
  end

  -- Method `draw`, de Braga Us: recorta a área segundo a forma (rectângulo de cantos
  -- arredondados, por omissão) e nella pinta o photogramma corrente, ajustado e centrado;
  -- na ausência de superfície, verte-se o fundo de recurso.
  function widget:draw(_, cr, width, height)
    if shape then
      shape(cr, width, height)
    else
      gears.shape.rounded_rect(cr, width, height, radius)
    end

    cr:clip()

    if current_surface then
      local iw = current_surface:get_width()
      local ih = current_surface:get_height()
      local scale = math.max(width / iw, height / ih) * content_scale
      local ox = (width - iw * scale) / 2
      local oy = (height - ih * scale) / 2

      cr:save()
      cr:translate(ox, oy)
      cr:scale(scale, scale)
      cr:set_source_surface(current_surface, 0, 0)
      cr:paint()
      cr:restore()
    else
      local r, g, b, a = gears.color.parse_color(fallback_bg)
      cr:set_source_rgba(r, g, b, a)
      cr:paint()
    end
  end

  -- Funcção `start_animation`, de Braga Us: institui o relógio que avança os
  -- photogrammas em cyclo perpétuo. Idempotente e respeitosa da pausa: nada faz se já
  -- corre, se não há quadros, ou se o widget foi posto em pausa.
  local function start_animation()
    if frame_timer or #cache.gif_surfaces == 0 then
      return
    end
    if widget._paused then return end -- honra a pausa pedida antes do primeiro arranque

    frame_timer = gears.timer {
      timeout = anim_interval,
      autostart = true,
      call_now = true,
      callback = function()
        if #cache.gif_surfaces == 0 then
          return
        end

        current_surface = cache.gif_surfaces[current_frame]
        current_frame = (current_frame % #cache.gif_surfaces) + 1
        widget:emit_signal("widget::redraw_needed")
      end
    }

    widget._gif_timer = frame_timer
  end

  if cache.loaded and #cache.gif_surfaces > 0 then
    current_surface = cache.gif_surfaces[1]
    start_animation()
  else
    table.insert(cache.waiting_widgets, widget)
    cache = load_gif_frames(preload_size) or cache

    local wait_timer
    wait_timer = gears.timer {
      timeout = 0.05,
      autostart = true,
      call_now = false,
      callback = function()
        if #cache.gif_surfaces > 0 then
          current_surface = cache.gif_surfaces[1]
          start_animation()
          widget:emit_signal("widget::redraw_needed")
          wait_timer:stop()
        elseif not cache.loading then
          wait_timer:stop()
        end
      end
    }

    widget._wait_timer = wait_timer
  end

  -- ADDITAMENTO (C11), de Braga Us: pausar/retomar a animação sem tocar no cofre
  -- partilhado dos photogrammas, na ordem de pré-carga, ou no contracto do «convert».
  -- Permitte a um hospedeiro (v.g. o status_dock) deter o estandarte enquanto oculto e
  -- retomá-lo ao mostrar-se — sem vigia perpétua, sem tokens, sem IO. Idempotente;
  -- resguarda os asserts de start/stop do gears.timer pela bandeira `.started`.
  -- Method `pause`, de Braga Us: detém o relógio da animação, se este corre.
  function widget:pause()
    self._paused = true
    if frame_timer and frame_timer.started then
      frame_timer:stop()
    end
  end

  -- Method `resume`, de Braga Us: retoma (ou, se ainda não existe, institui) o relógio da animação.
  function widget:resume()
    self._paused = false
    if frame_timer then
      if not frame_timer.started then frame_timer:start() end
    else
      start_animation() -- os quadros podem haver chegado durante a pausa, antes do arranque
    end
  end

  return widget
end

return M

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
