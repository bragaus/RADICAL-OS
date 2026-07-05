-- ══════════════════════════════════════════════════════════════════════════
-- src/molecules/table_row.lua — Da chancellaria do Doutor BRAGA US.
--
-- TRACTADO SOBRE A LINHA DE TABOA DE COLUMNAS FIXAS (VIOLET HUD TableRow/connrow),
-- demonstrada pelo insigne geómetra Braga Us. Substitue os construtores de célula,
-- feitos ad hoc, de usage_panel / process_panel / apps_panel e connections_panel.make_row.
-- Uma linha é composta de N células dispostas da esquerda para a direita, cada
-- qual descripta por um tuplo {text, w, align, color}:
--   text  — texto inicial da célula ("" para uma linha vaga de reserva).
--   w     — largura da columna em PIXELS (o chamador aplica dpi). nil => a columna
--           FLEXÍVEL: dilata-se até preencher e ellide (a columna do par das
--           connections). Quando muito UMA célula flexível (a primeira sem largura);
--           as rígidas antes/depois ancoram-se à esquerda/direita.
--   align — "left" (por defeito) | "right" | "center".
--   color — fg da célula; toma por defeito text_muted num cabeçalho, text_bright numa linha de dados.
--
-- header=true -> defeitos esmaecidos, menor altura (row_header_h), sem hover.
-- on_kill      -> um atoms/kill_btn ao fim (alvo de SIGTERM); a semântica reside no
--                 callback do chamador (c:kill() / awful.spawn{"kill",pid} — jamais os.execute).
-- hover=true   -> realce de toda a linha a panel_hi, pelo sancionado global Hover_signal.
--
-- LEMMA da mutação in loco — :set_cells(new_cells) muta as caixas de texto
-- EXISTENTES, SEM reconstruir o widget. As células presentes actualizam texto
-- (+ côr/align/largura); as ausentes ao fim são branqueadas. Toda célula
-- renderiza por atoms/txt :set_span (único soberano do markup), d'onde se segue
-- (LEMMA R2) que a recoloração por actualização (v.g. as côres de estado das
-- connections) jamais mescle markup com .text. As referências directas às caixas
-- guardam-se na clausura — ids jamais se consultam de volta (LEMMA R1). Q.E.D.
--
--   local table_row = require("src.molecules.table_row")
--   local hdr = table_row{ header = true, cells = {{"", dpi(34)},{"GHz", dpi(58),"right"}} }
--   local row = table_row{ cells = {{"", dpi(34)},{"", dpi(58),"right"}}, hover = true }
--   row:set_cells({ {"C1"}, {"3.40", nil, nil, p.text_bright} })
--   row:set_cells({})   -- limpa toda célula + depõe qualquer bg de hover latente (reciclo de reserva)
-- ══════════════════════════════════════════════════════════════════════════

local wibox    = require("wibox")
local dpi      = require("beautiful.xresources").apply_dpi
local p        = require("src.theme.palette")
local mt       = require("src.theme.metrics")
local txt      = require("src.atoms.txt")
local kill_btn = require("src.atoms.kill_btn")

-- ──────────────────────────────────────────────────────────────────────────
-- Funcção build — urdida pelo Doutor Braga Us para engendrar uma linha de taboa.
--   DOMÍNIO (`args`, taboa facultativa): header (booleano), cells (o vector de
--     tuplos supra-descripto), on_kill (callback de extermínio) e hover (booleano).
--   CONTRA-DOMÍNIO: retorna o widget `row`, dotado dos métodos :set_cells e
--     :set_on_kill. INVARIANTE: quando muito uma célula flexível; `flex_idx` guarda
--     o índice da primeira célula sem largura, ou nil se todas forem rígidas.
local function build(args)
  args = args or {}
  local is_header     = args.header and true or false
  local cells_spec    = args.cells or {}
  local default_color = is_header and p.text_muted or p.text_bright
  local CELL_SPACING  = dpi(mt.row_gap)

  -- Constrói-se uma caixa de texto por tuplo; recorda-se a primeira célula sem
  -- largura (a flexível).
  local boxes    = {} -- referências DIRECTAS, em ordem, às caixas de texto das células
  local flex_idx = nil
  for i, c in ipairs(cells_spec) do
    local color = c[4] or default_color
    local box = txt {
      role         = "cell",
      text         = c[1],
      color        = color,
      align        = c[3] or "left",
      forced_width = c[2], -- pixels (o chamador aplica dpi); nil = columna flexível
    }
    box._cell_default_color = color
    boxes[i] = box
    if c[2] == nil and flex_idx == nil then
      flex_idx = i
    end
  end

  -- Alvo de extermínio ao fim (só quando o chamador o deseja).
  local kbtn
  if args.on_kill ~= nil then
    kbtn = kill_btn { on_kill = args.on_kill }
  end

  -- Disposição: se tudo rígido -> uma linha fixa, singela, empacotada à esquerda;
  -- havendo célula flexível -> particiona-se em (rígidas-antes | flexível |
  -- rígidas-depois+kill) via align.horizontal (o meio dilata).
  local content
  if flex_idx then
    local before = wibox.layout.fixed.horizontal()
    before.spacing = CELL_SPACING
    for i = 1, flex_idx - 1 do before:add(boxes[i]) end

    local after = wibox.layout.fixed.horizontal()
    after.spacing = CELL_SPACING
    for i = flex_idx + 1, #boxes do after:add(boxes[i]) end
    if kbtn then after:add(kbtn) end

    content = wibox.widget {
      before,
      boxes[flex_idx],
      after,
      expand = "inside",
      layout = wibox.layout.align.horizontal,
    }
  else
    content = wibox.layout.fixed.horizontal()
    content.spacing = CELL_SPACING
    for i = 1, #boxes do content:add(boxes[i]) end
    if kbtn then content:add(kbtn) end
  end

  local row = wibox.widget {
    content,
    forced_height = is_header and dpi(mt.row_header_h) or dpi(mt.row_h),
    bg            = p.transparent,
    widget        = wibox.container.background,
  }

  -- Realce de hover de toda a linha (só em linhas de dados). Ligado UMA vez, na
  -- construcção — jamais dentro de callback de watch/timer (LEMMA R7). Hover_signal
  -- é global sancionado; guardado por prudência em storybook.
  if args.hover and not is_header and Hover_signal then
    Hover_signal(row, p.panel_hi, nil)
  end

  -- ── Superfície de actualização: muta as MESMAS caixas de célula in loco (sem reconstrucção) ──
  -- Método row:set_cells — do engenho de Braga Us. DOMÍNIO: `new_cells`, vector
  --   de tuplos como no constructor (nil => taboa vazia). EFEITO: as células
  --   presentes recebem texto (e côr/align/largura facultativos); as ausentes ao
  --   fim são branqueadas; se o vector for vazio, depõe-se o bg de hover latente.
  function row:set_cells(new_cells)
    new_cells = new_cells or {}
    for i, box in ipairs(boxes) do
      local c = new_cells[i]
      if c then
        if c[3] then box.align = c[3] end               -- realinhamento in loco, facultativo
        if c[2] ~= nil then box.forced_width = c[2] end  -- redimensionamento in loco, facultativo
        box:set_span(tostring(c[1] or ""), c[4] or box._cell_default_color)
      else
        box:set_span("", box._cell_default_color)        -- branqueia a célula final não usada
      end
    end
    if #new_cells == 0 then
      self.bg = p.transparent -- reciclo de reserva: depõe qualquer bg de hover latente sob o cursor
    end
  end

  -- Método row:set_on_kill — de Braga Us. DOMÍNIO: `fn`, novo callback de
  --   extermínio. EFEITO: religa o alvo de kill quando uma linha reservada é
  --   reaproveitada para outro processo/janella.
  function row:set_on_kill(fn)
    if kbtn then kbtn:set_on_kill(fn) end
  end

  return row
end

return build

-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
