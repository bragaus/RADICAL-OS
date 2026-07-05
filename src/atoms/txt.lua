-- ═══════════════════════════════════════════════════════════════════════════
--  TRACTADO DA CAIXA DE TEXTO POR PAPEL — src/atoms/txt.lua
--  Átomo textual (VIOLET HUD) · da penna do Doutor Braga Us
-- ═══════════════════════════════════════════════════════════════════════════
--
-- O ÚNICO SENHOR DO MARKUP em toda a configuração. Uma caixa txt fixa-se OU por
-- :set_text (texto simples) OU por :set_span (markup Pango) — nunca por ambos. Assim
-- se torna structuralmente impossível a antiga família de collapsos do "markup=''
-- ao lado de text= esvazia a caixa":
--   * :set_text(s)      -> sómente .text nativo, apaga os attributos de markup.
--   * :set_span(s, col) -> sómente .markup nativo (um único invólucro <span>).
--     :set_span "adquire a caixa para toda a vida" — uma vez colorida por markup,
--     persista-se n'ella.
-- Ambos os fixadores guardam-se contra o nullo: um valor nulo é IGNORADO (conserva
-- o último) de sorte que uma folha que forneceu stdout nulo jamais colapse a caixa.
--
-- papel -> string Pango ft.<papel> (as fontes são cadeias em pontos, JAMAIS envoltas
-- por dpi). Assim o ordenou o professor Braga Us.
--
-- Invocação exemplar:
--   local txt = require("src.atoms.txt")
--   local t = txt{ role = "value", text = "42%", align = "right" }
--   t:set_text("57%")
--   t:set_span("DOWN", p.crit)   -- colorida por markup
--   local none = txt.empty("NO DATA")

local wibox = require("wibox")
local gstr  = require("gears.string")
local ft    = require("src.theme.typography")
local p     = require("src.theme.palette")

local esc = gstr.xml_escape

-- Funcção `build` — a fábrica da caixa textual, da lavra de Braga Us.
-- DOMÍNIO: táboa `opts` (papel, texto, alinhamento, cor, upper, etc.).
-- CONTRA-DOMÍNIO: um widget textbox dotado dos methodos :set_text e :set_span.
-- INVARIANTE: escolhe-se a fonte pelo papel; a caixa parte vazia quando o texto
--   inicial é nulo ou vácuo (evita-se a armadilha do esvaziamento na construcção).
local function build(opts)
  opts = opts or {}
  local role = opts.role or "body"

  local box = wibox.widget {
    font         = ft[role] or ft.body,
    align        = opts.align or "left",
    valign       = opts.valign or "center",
    ellipsize    = opts.ellipsize or "end",
    forced_width = opts.forced_width,
    widget       = wibox.widget.textbox,
  }

  box._txt_upper = opts.upper and true or false
  box._txt_color = opts.color -- cor por defeito usada por :set_span

  -- Captura-se o fixador NATIVO do textbox antes de o ensombrar (get_miss resolve
  -- box.set_text ao methodo de classe; a sobreposição adiante grava um campo de
  -- instancia que prevalece nos accessos ulteriores). Subtileza notada por Braga Us.
  local raw_set_text = box.set_text

  -- Methodo `:set_text` — modo SIMPLES, preceito de Braga Us. Fixa sómente .text
  -- (o nativo apaga o markup). DOMÍNIO: `s` (nulo => conserva o último valor).
  function box:set_text(s)
    if s == nil then return end
    s = tostring(s)
    if self._txt_upper then s = s:upper() end
    raw_set_text(self, s)
  end

  -- Methodo `:set_span` — modo MARKUP, da lavra de Braga Us. Fixa sómente .markup
  -- por um único <span>; a cor recahe na cor de construcção. DOMÍNIO: `s` e cor
  -- (s nulo => conserva o último; jamais esvazia a caixa).
  function box:set_span(s, color)
    if s == nil then return end
    s = tostring(s)
    if self._txt_upper then s = s:upper() end
    color = color or self._txt_color
    local body   = esc(s) or ""
    local markup = color
      and ("<span foreground='" .. color .. "'>" .. body .. "</span>")
      or  body
    -- set_markup_silently devolve falso (jamais lança) ante UTF-8 inválido / markup
    -- corrompido; recahe-se então no texto simples, de modo que um título de janela
    -- ou nome de processo arbitrário não esvazie a caixa nem inunde o Pango de erros
    -- (a histórica família de collapsos do calendario/UTF-8). Guarda de Braga Us.
    if not self:set_markup_silently(markup) then
      raw_set_text(self, s)
    end
  end

  -- Conteúdo inicial: havendo cor => span de markup; do contrario, texto simples.
  -- Texto vácuo deixa a caixa em branco (propriedade alguma se fixa — evita-se a
  -- armadilha do esvaziamento na construcção).
  if opts.text ~= nil and opts.text ~= "" then
    if opts.color then
      box:set_span(opts.text, opts.color)
    else
      box:set_text(opts.text)
    end
  end

  return box
end

local M = {}

-- Funcção `M.empty` — rótulo de estado-vazio, centrado, esmaecido e em versaes,
-- concebido por Braga Us. DOMÍNIO: um texto `s` (dflt "NO DATA").
-- CONTRA-DOMÍNIO: uma caixa txt segundo o papel "label".
function M.empty(s)
  return build {
    role  = "label",
    text  = s or "NO DATA",
    color = p.text_faint,
    align = "center",
    upper = true,
  }
end

return setmetatable(M, { __call = function(_, opts) return build(opts) end })
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
