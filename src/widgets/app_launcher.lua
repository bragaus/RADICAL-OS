------------------------------------------------------------------------------------------
-- src/widgets/app_launcher.lua — Launcher GIF + ENGRENAGEM de apps (canto inf-direito)      --
--                                                                                        --
-- Disco central com o logo.gif ANIMADO (fundo transparente). Clicar no centro ABRE/FECHA   --
-- a engrenagem: os programas instalados (.desktop) aparecem como "cogs" (círculos com o     --
-- ícone) numa trilha. SCROLL gira a engrenagem percorrendo TODOS os apps; o app na FRENTE   --
-- fica maior. HOVER num cog mostra o NOME do programa (tooltip). Clicar num cog LANÇA o app  --
-- e fecha a engrenagem.                                                                     --
--                                                                                        --
-- Tudo num ÚNICO widget Cairo dentro de awful.popup transparente (type="dock", ontop). O    --
-- fundo é transparente (depende do picom rodando). shape_input = só o disco do GIF quando   --
-- fechado (resto passa o clique), ou o disco inteiro da engrenagem quando aberto.           --
--                                                                                        --
-- Apps lidos 1x via Python. Ícones via menubar.utils.lookup_icon (SVG/PNG), cacheados.      --
-- Frames do GIF recortados na figura e cacheados em /tmp/awesome_launcher_gif_v2_<px>/.     --
-- Chamar:  require("src.widgets.app_launcher")(s)                                           --
------------------------------------------------------------------------------------------

local awful = require("awful")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi
local gears = require("gears")
local gfs = require("gears.filesystem")
local wibox = require("wibox")
local cairo = require("lgi").cairo
local menubar_utils = require("menubar.utils")
local p = require("src.theme.palette")
require("src.core.signals")

local launcher_gif_path = gfs.get_configuration_dir() .. "src/assets/logo.gif"

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

return function(s)
  -- ============================ GEOMETRIA ============================
  local EDGE     = dpi(16)
  local GIF_R    = dpi(38)
  local ORBIT_R  = dpi(118)
  local ITEM_R   = dpi(18)
  local FOCUS_R  = dpi(26)
  local ANG_STEP = math.rad(22)
  local ANCHOR   = math.rad(135)  -- frente do carrossel (diagonal sup-esquerda)
  local VIS_LO   = math.rad(86)
  local VIS_HI   = math.rad(184)

  local GIF_PX     = 110
  local frames_dir = string.format("/tmp/awesome_launcher_gif_v2_%d/", GIF_PX)

  local CANVAS = math.ceil(GIF_R + ORBIT_R + FOCUS_R + dpi(14))
  local CX = CANVAS - GIF_R - dpi(6)
  local CY = CANVAS - GIF_R - dpi(6)
  local RIN = ORBIT_R + FOCUS_R + dpi(4)

  local function pos(a)
    return CX + ORBIT_R * math.cos(a), CY - ORBIT_R * math.sin(a)
  end

  -- ============================ TEARDOWN instância anterior ============================
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

  local function track_conn(obj, name, fn)
    obj.connect_signal(name, fn)
    table.insert(s._app_launcher_conns, { obj = obj, name = name, fn = fn })
  end

  -- ============================ Estado ============================
  local apps = {}
  local cogs = {}
  local sel        = 1
  local sel_target = 1
  local expanded   = false      -- engrenagem fechada por padrão (só o GIF visível)
  local anim_timer = nil

  local current_surface = nil
  local gif_surfaces  = {}
  local current_frame = 1
  local frame_timer   = nil
  local load_timer    = nil
  local ANIM_INTERVAL = 0.05

  -- ============================ Ícone do app (cacheado) ============================
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

  -- ============================ Canvas Cairo ============================
  local canvas = wibox.widget.base.make_widget()
  canvas._preserve_colors  = true
  canvas._preserve_segment = true

  function canvas:fit(_, w, h)
    return math.min(w, CANVAS), math.min(h, CANVAS)
  end

  -- Só há cogs quando ABERTO. App i no ângulo ANCHOR + (i-sel)*STEP (ângulo CRU -> só vizinhos
  -- de sel caem no arco; normalizar faria apps distantes dar a volta e reaparecer).
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

  local function draw_cog(cr, cog)
    cr:arc(cog.x, cog.y, cog.r, 0, 2 * math.pi)
    cr:set_source(gears.color(p.a(p.panel, 0.95)))
    cr:fill()
    draw_in_circle(cr, app_icon_surface(cog.app), cog.x, cog.y, cog.r, cog.app.name)
    cr:arc(cog.x, cog.y, cog.r, 0, 2 * math.pi)
    if cog.focused then
      cr:set_source(gears.color(p.glow_core)); cr:set_line_width(dpi(2.5))
    else
      cr:set_source(gears.color(p.a(p.line_base, 0.9))); cr:set_line_width(dpi(1.5))
    end
    cr:stroke()
  end

  local function draw_center(cr)
    cr:arc(CX, CY, GIF_R, 0, 2 * math.pi)
    cr:set_source(gears.color(p.a(p.panel, 0.9)))
    cr:fill()
    draw_in_circle(cr, current_surface, CX, CY, GIF_R, nil)
    cr:arc(CX, CY, GIF_R, 0, 2 * math.pi)
    cr:set_source(gears.color(p.glow_soft)); cr:set_line_width(dpi(2)); cr:stroke()
  end

  function canvas:draw(_, cr, width, height)
    compute_cogs()

    if expanded then
      -- trilha + dentes girando com o carrossel
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
      cr:set_source(gears.color(p.a(p.glow_soft, 0.35)))
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

  -- ============================ Carrossel animado ============================
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

  local function spin(dir)
    if not expanded then return end
    local n = #apps
    if n == 0 then return end
    sel_target = math.max(1, math.min(n, math.floor(sel_target + 0.5) + dir))
    animate_sel()
  end

  -- ============================ GIF ============================
  local function start_animation()
    if frame_timer then frame_timer:stop() end
    frame_timer = gears.timer {
      timeout   = ANIM_INTERVAL,
      autostart = true,
      call_now  = true,
      callback  = function()
        if #gif_surfaces == 0 then return end
        if mousegrabber and mousegrabber.isrunning and mousegrabber.isrunning() then
          return -- não anima durante move/resize de janela
        end
        current_surface = gif_surfaces[current_frame]
        current_frame   = (current_frame % #gif_surfaces) + 1
        canvas:emit_signal("widget::redraw_needed")
      end,
    }
    table.insert(s._app_launcher_timers, frame_timer)
  end

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

  -- ============================ Scan dos apps ============================
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

  -- ============================ Host (popup transparente) ============================
  local host = awful.popup {
    screen    = s,
    ontop     = true,
    visible   = true,
    bg        = "#00000000",
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

  -- shape_input: fechado -> só o disco do GIF (resto passa clique); aberto -> disco da engrenagem.
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

  -- ============================ Tooltip (nome do app no hover) ============================
  local tip_text = wibox.widget {
    markup = "",
    font   = "JetBrainsMono Nerd Font 10",
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
  local function hide_tip()
    hovered_app = nil
    tip.visible = false
  end
  local function show_tip_for(cog)
    if hovered_app ~= cog.app then
      hovered_app = cog.app
      tip_text:set_markup('<span foreground="' .. p.text_bright .. '">'
        .. gears.string.xml_escape(cog.app.name) .. '</span>')
      -- posiciona à ESQUERDA do cog (engrenagem fica no canto direito da tela)
      local tw = tip.width or dpi(80)
      tip.x = host.x + cog.x - tw - dpi(10)
      tip.y = host.y + cog.y - dpi(12)
      tip.visible = true
    end
  end

  -- ============================ Hit-test / clique / scroll ============================
  local function local_coords()
    local m = mouse.coords()
    return m.x - host.x, m.y - host.y
  end

  local function cog_at(lx, ly)
    for _, cog in ipairs(cogs) do
      if (lx - cog.x) ^ 2 + (ly - cog.y) ^ 2 <= cog.r ^ 2 then return cog end
    end
    return nil
  end

  canvas:buttons(gears.table.join(
    awful.button({}, 1, function()
      local lx, ly = local_coords()
      -- centro -> abre/fecha a engrenagem
      if (lx - CX) ^ 2 + (ly - CY) ^ 2 <= GIF_R ^ 2 then
        expanded = not expanded
        if not expanded then hide_tip() end
        set_input_shape()
        canvas:emit_signal("widget::redraw_needed")
        return
      end
      -- cog -> lança e fecha
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

  -- Hover: mostra o nome do programa sob o cursor.
  host:connect_signal("mouse::move", function(_, x, y)
    if not expanded then return end
    local cog = cog_at(x, y)
    if cog then show_tip_for(cog) else hide_tip() end
  end)
  host:connect_signal("mouse::leave", hide_tip)

  Hover_signal(canvas) -- cursor hand1 no hover

  -- ============================ Visibilidade (some em fullscreen) ============================
  local function is_current() return s._app_launcher_host == host end

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
