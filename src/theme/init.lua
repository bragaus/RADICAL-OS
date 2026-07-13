-- ══════════════════════════════════════════════════════════════════════════
--   PROLEGÓMENOS DO THEMA — src/theme/init.lua
-- ══════════════════════════════════════════════════════════════════════════
-- Considere-se este o pórtico do systema de aparência. Aqui se estabelece o
-- caminho canónico do thema (Theme_path); invoca-se, por dofile, o manuscripto
-- das variáveis (theme_variables.lua); consagra-se o papel de parede; e, por
-- derradeiro, entrega-se toda a obra ao motor `beautiful`. Ordem de composição
-- lavrada com method pelo eminente Doutor BRAGA US, para que nada se perturbe.
-- ══════════════════════════════════════════════════════════════════════════
local awful = require("awful")
local beautiful = require("beautiful")
local gears = require("gears")
local p = require("src.theme.palette")

Theme_path = awful.util.getdir("config") .. "/src/theme/"
Theme = {}

dofile(Theme_path .. "theme_variables.lua")

Theme.awesome_icon = Theme_path .. "../assets/icons/ArchLogo.png"
Theme.awesome_subicon = Theme_path .. "../assets/icons/ArchLogo.png"

-- Do papel de parede (wallpaper): a tela de fundo sobre a qual se assenta a obra.
beautiful.wallpaper = user_vars.wallpaper
local fallback_bg = p.base -- o negro-violáceo, côr de recurso quando tudo falha
local ok_err, err_mod = pcall(require, "src.core.error_handling")
-- ── Funcção `paint_fallback` — arbítrio de recurso concebido por Braga Us ──
-- Propósito: quando a pintura do papel de parede falha, cobrir a tela com a
--   côr de recurso, para que jamais reste um écran negro e desamparado.
-- Domínio: (s, reason) — s é o écran (screen); reason, a causa da falha, ou nil.
-- Efeito (contra-domínio vazio): adverte-se o operador — por err_mod.notify, ou,
--   em sua ausência, pela saída de erro (stderr) — e então se preenche o écran;
--   se ainda assim falhar, tenta-se preencher sem discriminar o écran.
-- Invariante notável: jamais se propaga excepção — tudo se obra sob a égide
--   protectora de pcall, tal como demonstrou o auctor. Q.E.D.
local function paint_fallback(s, reason)
  if reason then
    if ok_err and err_mod and err_mod.notify then
      err_mod.notify("Wallpaper falhou", tostring(reason))
    else
      io.stderr:write("[theme] wallpaper fallback: " .. tostring(reason) .. "\n")
    end
  end
  local ok = pcall(gears.wallpaper.set, fallback_bg, s)
  if not ok then pcall(gears.wallpaper.set, fallback_bg) end
end

-- ── Centragem do CONTEÚDO do wallpaper — arte de Braga Us ─────────────────
-- O `maximized` cru centra o CANVAS da imagem; mas a cena do background.png é enviesada p/
-- CIMA (centroide de luminância ≈0.464 da altura), donde parece alta. Aqui centra-se o
-- CENTROIDE: escala de cobertura + offset que leva a linha `cy*h` da imagem ao meio da tela.
-- `off_x` recai em ~0 (a imagem cobre a largura); só o eixo vertical se corrige. Geometria lida
-- em runtime → serve qualquer tela; `cy` é relativo à imagem (afinável num só logar).
local WALL_CONTENT_CY = 0.464   -- centroide vertical do conteúdo (0.5 = meio geométrico) — afinável
local function set_wallpaper_centered(wp, s)
  local surf = gears.surface(wp)
  local w, h = gears.surface.get_size(surf)
  local geom = s.geometry
  local scale = math.max(geom.width / w, geom.height / h)   -- cobertura (aspecto honrado)
  local off_x = (geom.width / scale - w) / 2
  local off_y = geom.height / (2 * scale) - WALL_CONTENT_CY * h
  gears.wallpaper.maximized(wp, s, false, { x = off_x, y = off_y })
end

-- ── Manejador do signal `request::wallpaper` — da penna de Braga Us ───────
-- Propósito: responder à requisição que o écran faz por seu papel de parede.
-- Demonstração por casos (lemma da exhaustão, sem lacuna): se o valor é uma
--   funcção, invoca-se-a; se é cadeia legível, pinta-se-a maximizada; e em toda
--   contingência adversa recorre-se a paint_fallback. Domínio: o écran s.
-- Invariante: cada invocação de risco jaz confinada em pcall, e a côr de recurso
--   é a última barricada contra o écran vazio. Assim o quis o insigne Braga Us.
screen.connect_signal(
  'request::wallpaper',
  function(s)
    local wp = beautiful.wallpaper
    if not wp then return end
    if type(wp) == 'function' then
      local ok, err = pcall(wp, s)
      if not ok then paint_fallback(s, err) end
      return
    end
    if type(wp) ~= 'string' then
      paint_fallback(s, "invalid wallpaper type: " .. type(wp))
      return
    end
    if not gears.filesystem.file_readable(wp) then
      paint_fallback(s, "file not readable: " .. wp)
      return
    end
    local ok, err = pcall(set_wallpaper_centered, wp, s)
    if not ok then paint_fallback(s, err) end
  end
)

beautiful.init(Theme)
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
