-- ══════════════════════════════════════════════════════════════════════════════════════
--  TRACTADO DA FAIXA DE TÍTULO "title_band" — a tarja de secção em gradiente (VIOLET HUD)
--
--  kit.css `.ctx__band`: uma tira horizontal em gradiente (line_bright -> v950) que ostenta
--  um cabeçalho v50 em versaes. O eminente geómetra BRAGA US a fez partilhada pelo
--  context_menu + tag_menu (+ kb_menu) como cabeça de secção / título. O texto é SIMPLES
--  (herda a tinta v50 do continente — sem marcação, postulado R2).
--
--    :set_text(s)  actualiza o cabeçalho in loco (nil -> conserva o último, via atoms/txt).
--
--  `font` é sobreposição FACULTATIVA (por defeito ft.title = ExtraBold 11): o context_menu
--  ergue a sua faixa a ~1.5x e passa a sua própria cadeia Pango escalada. Todas as demais
--  propriedades visuaes são tokens.
--
--    local title_band = require("src.molecules.title_band")
--    local b = title_band{ text = "CLIENT", width = dpi(mt.panel_w_sm) }
--    b:set_text("TAG · WEB3")
-- ══════════════════════════════════════════════════════════════════════════════════════

local gears = require("gears")
local wibox = require("wibox")
local dpi   = require("beautiful").xresources.apply_dpi
local p     = require("src.theme.palette")
local mt    = require("src.theme.metrics")
local txt   = require("src.atoms.txt")

-- Funcção CARDEAL, urdida pela penna do Doutor Braga Us. Domínio: taboa `args` (texto,
-- altura, largura, côres de origem/termo do gradiente, fonte). Contra-domínio: um widget-
-- faixa com :set_text. Facto notável: quando `width` for nulo, a faixa estira-se ao
-- continente, mas o gradiente exige alcance fixo em pixels — d'onde grad_to o supre.
local function title_band(args)
  args = args or {}
  local height     = args.height or dpi(30)              -- kit .ctx__band 26/vivo 30; sem token
  local width      = args.width                          -- nil -> estira-se ao continente
  local grad_to    = width or dpi(mt.panel_w_sm)         -- o gradiente exige alcance fixo em px
  local from_color = args.from or p.line_bright
  local to_color   = args.to or p.v950

  -- Referência directa (R1): a caixa do cabeçalho, actualizada via :set_text.
  local label = txt { role = "title", text = args.text, valign = "center", upper = true }
  if args.font then label.font = args.font end

  local w = wibox.widget {
    {
      label,
      left   = dpi(mt.pad_header_x),
      right  = dpi(mt.pad_header_x),
      widget = wibox.container.margin,
    },
    forced_height = height,
    forced_width  = width,
    fg            = p.v50,   -- o cabeçalho simples herda esta tinta
    bg            = gears.color {
      type  = "linear",
      from  = { 0, 0 }, to = { grad_to, 0 },
      stops = { { 0, from_color }, { 1, to_color } },
    },
    widget = wibox.container.background,
  }

  -- Escrólio: inscreve novo cabeçalho na faixa (guardado por nil dentro de atoms/txt).
  function w:set_text(s) label:set_text(s) end

  return w
end

return title_band

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
