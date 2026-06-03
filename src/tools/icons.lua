------------------------------------------------------------------------------------------
-- src/tools/icons.lua — Carregador dos ícones SVG do set VIOLET HUD (pasta icons/).        --
--                                                                                        --
-- Os SVGs em icons/svg/ já vêm na paleta violeta. Use COMO ESTÃO por padrão; recolorir    --
-- só por ESTADO (ex.: KILL -> crit no hover, alerta -> glow_hot).                         --
--                                                                                        --
--   local Icon = require("src.tools.icons")                                              --
--   Icon("cpu")                                  -- imagebox multitom, tamanho natural    --
--   Icon("kill", { color = p.crit, size = dpi(14) })  -- recolorido + tamanho fixo        --
------------------------------------------------------------------------------------------

local gfs    = require("gears.filesystem")
local gcolor = require("gears.color")
local wibox  = require("wibox")

local DIR = gfs.get_configuration_dir() .. "icons/svg/"

-- Icon(name, opts) -> wibox.widget.imagebox
--   name  : nome do arquivo sem extensão (ex.: "cpu", "net_up", "kill")
--   opts.color : token de cor p/ recolorir o SVG inteiro (opcional; omita p/ manter multitom)
--   opts.size  : largura/altura forçada em px (opcional)
local function Icon(name, opts)
  opts = opts or {}
  local path = DIR .. tostring(name) .. ".svg"
  local image = opts.color and gcolor.recolor_image(path, opts.color) or path
  return wibox.widget {
    image         = image,
    resize        = true,
    forced_width  = opts.size,
    forced_height = opts.size,
    widget        = wibox.widget.imagebox,
  }
end

return Icon
