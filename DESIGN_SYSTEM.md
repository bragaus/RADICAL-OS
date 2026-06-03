# DESIGN_SYSTEM.md — RADICAL-WM · **VIOLET HUD EDITION**

> Sistema de design para **redesenhar do zero** a interface do AwesomeWM (Lua) deste
> repositório, copiando a linguagem visual da **imagem_de_referencia.png** Localizada nesse repositorio (o "rice" azul,
> denso, em painéis com cabeçalho e gráficos) e **traduzindo a paleta azul para roxo**.
>
> **Diretriz primária:** o alvo é a imagem de referência. **NÃO** preserve o visual atual
> (chart laranja, dockbars powerline, titlebar estilo macOS, dock inferior). Reaproveite
> apenas a **lógica** (coleta de métricas, timezones, bindings) — descarte a apresentação.

---

## 0. Como o Claude Code deve usar este documento

1. **Fonte da verdade visual:** a imagem de referência (HUD azul). Este doc descreve cada
   elemento dela e como recriá-lo em AwesomeWM/`wibox`.
2. **Cor:** use **exclusivamente** os tokens da seção [3. Paleta](#3-paleta-de-cores-o-núcleo).
   Nenhum laranja (`#ff7a00`, `#ff8c00`, `#ff9a1f`), nenhum azul/teal como acento primário.
3. **Ordem de trabalho sugerida:** Paleta → Chrome de painel → Barra superior → Widgets de
   dado → Menus → Janelas/Terminais → Notificações/OSDs. Cada um tem spec própria abaixo.
4. **Critério de pronto:** seção [11. Checklist de aceite](#11-checklist-de-aceite).
5. **Validação técnica:** `awesome -k rc.lua` a partir da raiz (checa sintaxe/carga). Não
   valida visual — para isso compare com a referência.

---

## 1. Visão geral da estética

A referência é um desktop **tiling, ultra-denso, estilo "cockpit/HUD militar"**: fundo
quase preto coberto por uma malha de **painéis retangulares**, cada um com **cabeçalho
titulado em caixa-alta**, **borda fina com bevel** (canto superior-esquerdo mais claro,
inferior-direito mais escuro) e **conteúdo de dados** (gráficos de linha, pizza/rosca,
barras, calendário, relógios, listas de processo). Tudo em **monoespaçado**, com leve
transparência, e uma única família de cor (azul → no nosso caso, **roxo/violeta**)
construindo toda a hierarquia por **luminosidade e opacidade**.

### 1.1 O que COPIAR da referência

- Densidade alta: muitos painéis pequenos, colados às bordas da tela, centro livre p/ apps.
- **Chrome de painel** com header em caixa-alta + linha divisória + corpo + borda bevel + ticks de canto.
- Variedade de **visualizações**: linha, área, rosca/pizza, barras horizontais, EQ vertical, calendário, relógios, listas.
- **Menus de contexto** com **faixa-título em gradiente** e itens densos (inclusive submenu "Send Signal" com SIG\*).
- **Menu de apps** estilo lista com ícone + label.
- Tudo monoespaçado, caixa-alta nos títulos, valores numéricos alinhados à direita.
- Transparência sutil nos painéis e terminais.
- **Ícones SVG próprios** (pasta `icons/`, §3.13) nos monitores de hardware e controles — já na
  paleta violeta; **preferidos sobre glyphs Nerd-Font** (que ficam só como fallback).

### 1.2 O que DESCARTAR do estado atual (não usar como referência)

| Descartar (visual) | Por quê | Reaproveitar (lógica) |
|---|---|---|
| `system_monitor_chart.lua` — paleta laranja, layout monolítico, fotos grandes, texto japonês | Não parece a referência | Coletores `sample_cpu/mem/gpu/net/wifi/battery/audio` |
| Segmentos **powerline** (`radical_bar/left_bar/right_bar`) e o tint `#ff8c00` | Referência não usa powerline nem laranja | Mecânica de composição por `awful.popup` |
| **Dock** inferior (`dock.lua`) | Referência não tem dock macOS | — (substituir por barra/painel) |
| **Titlebar** lateral estilo "semáforo" macOS (Red/Yellow/Green) | Referência é tiling minimalista | Lógica de botões close/max/min se quiser titlebar |
| `border_width = 11`, fundos `Grey900`, fg `White` | Bordas grossas cinzas destoam | — |

> Resumo: **mantenha os dados, jogue fora a aparência.**

---

## 2. Princípios de design

1. **Monocromático roxo + hierarquia por luz/alpha.** Quase tudo é violeta; o que mostra
   importância é *mais claro/opaco*, o que é secundário é *mais escuro/transparente*.
2. **Densidade informacional.** Padding apertado, fontes pequenas, caixa-alta nos rótulos.
3. **Chrome consistente.** Todo painel usa o mesmo "molde" (header + bevel + ticks).
4. **Glow contido.** Acentos neon (lilás claro) só em foco/título/picos — nunca no fundo todo.
5. **Alinhamento técnico.** Números à direita, rótulos à esquerda, grid de gráfico visível.
6. **Sem gradientes coloridos arco-íris.** Gradientes só dentro da família violeta.

---

## 3. Paleta de cores (o núcleo)

> **Filosofia:** uma rampa violeta única (`v50`→`v975`) + neutros "violet-black" para
> fundos + neon para glow + séries de dados (variações de violeta) + status sutis.
> A referência é praticamente monocromática: **a hierarquia vem da luminosidade e da
> opacidade**, não de matizes diferentes.

Formato de cor do AwesomeWM: `#RRGGBB` ou **`#RRGGBBAA`** (8 dígitos com alpha). Use o alpha
para "mais opaco / mais transparente" (ver [3.10](#310-escada-de-opacidade-alpha)).

### 3.1 Backgrounds — *violet-blacks* (do mais escuro ao mais claro)

| Token | Hex | Uso |
|---|---|---|
| `void` | `#000000` | preto absoluto / fundo de tela base |
| `abyss` | `#070310` | wallpaper sólido / trás de tudo |
| `base` | `#0c0617` | fundo de tela útil, sob os painéis |
| `inset` | `#0a0514` | "poços" de gráfico, campos, trilhas de barra (mais fundo que o painel) |
| `panel` | `#130a24` | **fundo padrão de painel** |
| `panel_hi` | `#1b1030` | header do painel / linha selecionada |
| `raised` | `#241640` | elemento elevado (hover, chip ativo) |

### 3.2 Rampa violeta `v50`–`v975` (estrutura + acento)

| Token | Hex | Papel típico |
|---|---|---|
| `v50` | `#f4effe` | texto sobre violeta saturado / brilho máximo |
| `v100` | `#e7dafd` | texto muito claro |
| `v200` | `#cbb2fb` | texto primário claro |
| `v300` | `#b491f9` | acento claro / heading |
| `v400` | `#9d6ff6` | **acento de texto / linha de gráfico** |
| `v500` | `#8b5cf6` | **ACENTO PRIMÁRIO** (foco, título, seleção) |
| `v600` | `#7c3aed` | preenchimento forte / borda viva |
| `v700` | `#6d28d9` | preenchimento médio |
| `v800` | `#5b21b6` | borda padrão de painel |
| `v900` | `#4c1d95` | preenchimento profundo |
| `v950` | `#2e1065` | borda dim / fundo de chip |
| `v975` | `#2b0c45` | quase-fundo (tag inativa, trilha) |

### 3.3 Neon / Glow (mais saturado e claro — só para destaque)

| Token | Hex | Uso |
|---|---|---|
| `glow_ice` | `#d6c2ff` | texto-destaque máximo (equivale ao ciano claro da referência) |
| `glow_soft` | `#b794ff` | glow de header/foco |
| `glow_core` | `#a855f7` | acento neon / borda de foco viva |
| `glow_hot` | `#c026d3` | pico de gráfico / alerta magenta-violeta |

### 3.4 Texto

| Token | Hex | Uso |
|---|---|---|
| `text_bright` | `#e9dcff` | valores em destaque, números importantes |
| `text_primary` | `#cbb6ff` | corpo de texto padrão sobre painel |
| `text_heading` | `#b794ff` | títulos de painel (caixa-alta) |
| `text_body` | `#9a82c4` | texto secundário |
| `text_muted` | `#6f5a96` | rótulos, legendas, unidades |
| `text_faint` | `#463566` | placeholders, dias fora do mês no calendário |
| `text_disabled` | `#2f2348` | desabilitado |

### 3.5 Bordas / linhas / bevel

| Token | Hex | Uso |
|---|---|---|
| `line_faint` | `#241640` | divisórias internas sutis |
| `line_dim` | `#3a1f63` | **grid de gráfico** / separadores |
| `line_base` | `#5b21b6` | borda padrão de painel |
| `line_bright` | `#7c3aed` | borda de painel em foco/ativo |
| `bevel_hi` | `#9d6ff6` | **realce do bevel** (topo + esquerda) |
| `bevel_lo` | `#160c28` | **sombra do bevel** (baixo + direita) |
| `grid` | `#3a1f63` | linhas de grade (use com alpha baixo) |

### 3.6 Séries de dados (para gráficos com várias linhas/fatias)

> Mesmo num tema monocromático, gráficos multi-série precisam se distinguir. Use estas
> variações **dentro da família violeta** (ordene da mais "quente" à mais "fria").

| Token | Hex | Sugestão de série |
|---|---|---|
| `data1` | `#a855f7` | CPU |
| `data2` | `#c084fc` | MEM |
| `data3` | `#7c3aed` | GPU |
| `data4` | `#d946ef` | NET (pico/magenta) |
| `data5` | `#8b5cf6` | extra |
| `data6` | `#6d28d9` | extra |

### 3.7 Status (sutis — use com parcimônia, como na referência)

| Token | Hex | Uso |
|---|---|---|
| `ok` | `#5ad1a0` | online / saudável |
| `warn` | `#f0c44c` | atenção / temperatura alta |
| `crit` | `#fb5e8a` | urgente (combina com violeta) |
| `info` | `#8b5cf6` | informativo (= acento) |

> Para um look 100% monocromático, troque `ok/warn/crit` por `v300 / glow_soft / glow_hot`.

### 3.8 Eixos de variação (o que você pediu: mais claro/escuro/opaco/saturado…)

Exemplo aplicado ao **acento primário `v500 #8b5cf6`** (HSL ≈ 258°, 90%, 66%). Use a mesma
lógica para qualquer outra cor da rampa.

| Eixo | Passo 1 | Passo 2 | Passo 3 | Passo 4 |
|---|---|---|---|---|
| **+ Claro** (tint → branco) | `#9d75f7` | `#b194f9` | `#c6b3fb` | `#dbd1fc` |
| **+ Escuro** (shade → preto) | `#7a45ec` | `#6831d0` | `#5223a6` | `#3c1a78` |
| **+ Saturado** (neon) | `#8c4bff` | `#8a3bff` | `#7d20ff` | `#7512ff` |
| **− Saturado** (dessaturado/cinza) | `#8970b0` | `#7e6c98` | `#736780` | `#695f6e` |
| **+ Opaco / − Opaco** (alpha) | `#8b5cf6ff` | `#8b5cf6cc` | `#8b5cf680` | `#8b5cf61a` |

E para o **fundo de painel `panel #130a24`**:

| Eixo | Resultado |
|---|---|
| + Claro (elevações) | `#1b1030` → `#241640` → `#2e1c4e` |
| + Escuro (poços) | `#0c0617` → `#070310` → `#000000` |
| Translúcido (vidro) | `#130a24e6` (90%) · `#130a24cc` (80%) · `#130a2499` (60%) |

### 3.9 Mapa **azul → roxo** (de-para com a referência)

Para cada cor azul percebida na imagem, este é o equivalente roxo a usar:

| Papel na referência | Azul aprox. (origem) | **Roxo (usar)** | Token |
|---|---|---|---|
| Texto/destaque mais brilhante (ciano claro) | `#5fd0ff` | `#d6c2ff` | `glow_ice` |
| Acento de texto / heading | `#3aa0ff` | `#9d6ff6` | `v400` |
| Acento primário (foco/seleção) | `#1e8aff` | `#8b5cf6` | `v500` |
| Preenchimento de barra/linha | `#1f6fb2` | `#7c3aed` | `v600` |
| Preenchimento médio | `#155a93` | `#6d28d9` | `v700` |
| Borda de painel | `#1a4a7a` | `#5b21b6` | `v800` |
| Preenchimento profundo / fatia escura | `#0d3b66` | `#4c1d95` | `v900` |
| Fundo de painel | `#02060f` | `#130a24` | `panel` |
| Fundo de tela | `#000000` | `#0c0617` | `base` |
| Faixa-título de menu (gradiente claro→escuro) | `#2a6fb0 → #0d2c4a` | `#7c3aed → #2e1065` | `line_bright → v950` |
| Grade de gráfico | `#16334d` | `#3a1f63` | `grid` |

### 3.10 Escada de opacidade (alpha)

Sufixos de 8 dígitos (`#RRGGBB` + `AA`):

| % | AA | | % | AA | | % | AA |
|---|---|---|---|---|---|---|---|
| 100 | `ff` | | 70 | `b3` | | 30 | `4d` |
| 95 | `f2` | | 60 | `99` | | 25 | `40` |
| 90 | `e6` | | 50 | `80` | | 20 | `33` |
| 85 | `d9` | | 45 | `73` | | 15 | `26` |
| 80 | `cc` | | 40 | `66` | | 10 | `1a` |
| 75 | `bf` | | 35 | `59` | | 5 | `0d` |

Helper já existente no repo (reutilize): em `system_monitor_chart.lua` há
`with_alpha(hex, alpha)` e `hex_with_alpha_string(hex, alpha)` — promova para um util
compartilhado se for usar em vários widgets.

### 3.11 Tokens em Lua (arquivo pronto)

Crie **`src/theme/palette.lua`** (novo) e faça os widgets consumirem dele. Mantenha
`src/theme/colors.lua` (Material) para compatibilidade, mas **novos widgets usam `palette`**.

```lua
-- src/theme/palette.lua
-- Paleta "VIOLET HUD" derivada da referência azul (traduzida para roxo).
-- Hierarquia por luminosidade + opacidade. Acento primário = v500.
return {
  -- BACKGROUNDS (violet-blacks)
  void = "#000000", abyss = "#070310", base = "#0c0617",
  inset = "#0a0514", panel = "#130a24", panel_hi = "#1b1030", raised = "#241640",

  -- RAMPA VIOLETA
  v50  = "#f4effe", v100 = "#e7dafd", v200 = "#cbb2fb", v300 = "#b491f9",
  v400 = "#9d6ff6", v500 = "#8b5cf6", v600 = "#7c3aed", v700 = "#6d28d9",
  v800 = "#5b21b6", v900 = "#4c1d95", v950 = "#2e1065", v975 = "#2b0c45",

  -- NEON / GLOW
  glow_ice = "#d6c2ff", glow_soft = "#b794ff", glow_core = "#a855f7", glow_hot = "#c026d3",

  -- TEXTO
  text_bright = "#e9dcff", text_primary = "#cbb6ff", text_heading = "#b794ff",
  text_body = "#9a82c4", text_muted = "#6f5a96", text_faint = "#463566",
  text_disabled = "#2f2348",

  -- LINHAS / BORDAS / BEVEL
  line_faint = "#241640", line_dim = "#3a1f63", line_base = "#5b21b6",
  line_bright = "#7c3aed", bevel_hi = "#9d6ff6", bevel_lo = "#160c28", grid = "#3a1f63",

  -- SÉRIES DE DADOS
  data1 = "#a855f7", data2 = "#c084fc", data3 = "#7c3aed",
  data4 = "#d946ef", data5 = "#8b5cf6", data6 = "#6d28d9",

  -- STATUS (sutis)
  ok = "#5ad1a0", warn = "#f0c44c", crit = "#fb5e8a", info = "#8b5cf6",
}
```

### 3.12 Reescrita de `theme_variables.lua` (beautiful)

Reaponte as variáveis globais do `beautiful`/`Theme` para os tokens roxos. Valores-alvo:

```lua
local p = require("src.theme.palette")

Theme.bg_normal   = p.base
Theme.bg_focus    = p.panel_hi
Theme.bg_urgent   = p.glow_hot
Theme.bg_minimize = p.v950
Theme.bg_systray  = p.panel

Theme.fg_normal   = p.text_primary
Theme.fg_focus    = p.text_bright
Theme.fg_urgent   = p.v50
Theme.fg_minimize = p.text_muted

Theme.useless_gap   = dpi(6)
Theme.border_width  = dpi(2)        -- referência tem borda FINA (não 11px)
Theme.border_normal = p.v950
Theme.border_focus  = p.glow_core   -- ver workaround em signals.lua (focus)
Theme.border_marked = p.glow_hot

-- Menus (ver §7.6)
Theme.menu_height       = dpi(26)
Theme.menu_width        = dpi(220)
Theme.menu_bg_normal    = p.panel .. "f2"
Theme.menu_bg_focus     = p.v700
Theme.menu_fg_normal    = p.text_primary
Theme.menu_fg_focus     = p.v50
Theme.menu_border_color = p.line_base
Theme.menu_border_width = dpi(1)

-- Taglist
Theme.taglist_bg_focus = p.v500
Theme.taglist_fg_focus = p.v50

-- Tooltip
Theme.tooltip_bg           = p.panel .. "f2"
Theme.tooltip_fg           = p.text_bright
Theme.tooltip_border_color = p.line_base
Theme.tooltip_border_width = dpi(1)

-- Hotkeys popup
Theme.hotkeys_bg = p.panel .. "f2"
Theme.hotkeys_fg = p.text_primary
```

E em `src/core/signals.lua`, o workaround de foco passa de `#9C27B0` para `p.glow_core`
(`#a855f7`); o `unfocus` usa `p.v950`.

---

## 3.13 Icon set — pasta `icons/` (ícones SVG do sistema)

> O repo tem um set próprio de ícones em **`icons/`** (raiz da config), **já desenhados na paleta
> VIOLET HUD**. São a fonte de verdade para ícones dos **monitores de hardware** e dos controles —
> **preferidos sobre os glyphs Nerd-Font**, que ficam só como fallback onde faltar SVG.
>
> **Status de integração:** o set **já está conectado** aos widgets via `src/tools/icons.lua`
> (`Icon("<n>")`). **36 dos 41** ícones têm consumidor no código; os 5 restantes
> (`battery` `dnd` `gpu_temp` `wifi` `doc`) ficam **reservados** por falta de hardware/UI
> correspondente — ver tabela de integração em [§3.13.1](#3131-mapeamento-elemento--ícone-onde-cada-ícone-entra--status-wired).

**Estrutura:**
- `icons/svg/<nome>.svg` — **41 vetoriais** (use estes; escalam sem perda).
- `icons/png/{16,24,32,48,64}/<nome>.png` — rasterizados (fallback p/ tamanho fixo).
- `icons/icondata.json` — metadados + categorias.

**Cor:** os SVGs já vêm na paleta — **7 tokens** (inventário completo + ocorrências em
[§3.13.2](#3132-formato-de-dados-icondatajson--geometria-svg--inventário-de-cor)):
`text_primary #cbb6ff` (todo o traço/contorno), `v400 #9d6ff6` e `v500 #8b5cf6` (fills de
acento/primário), `bevel_lo #160c28` (espaço negativo: olhos do skull, furo do cadeado,
janela de trás do `floating`), `glow_ice #d6c2ff` (realce/LED: ponto do `wifi`, núcleo do
`send_signal`), `text_muted #6f5a96` (células inativas do `calendar`) e `v800 #5b21b6` (fill
profundo: corpo da pasta `files`, pino do `sticky`). **Use como estão por padrão.** Recolorir
**só por estado**: `gears.color.recolor_image("icons/svg/<n>.svg", p.<token>)` — ex.: KILL →
`crit` no hover; valor de stat ≥ 90% → `glow_hot`; ≥ 80 °C → `crit`. (Não fazer monocromático
global; recolor pinta o SVG inteiro de uma cor só — perde a composição multitom.)

**Helper — `src/tools/icons.lua` (JÁ EXISTE no repo).** Reusa o padrão `recolor_image`+`imagebox`
de `clock.lua`/`network.lua`/`battery.lua`. Assinatura `Icon(name, opts)` → `wibox.widget.imagebox`:
`opts.color` recolore o SVG inteiro (omita p/ manter o multitom nativo); `opts.size` força
largura/altura em px. Conteúdo atual:
```lua
-- local Icon = require("src.tools.icons")
-- Icon("cpu")                                   -- imagebox multitom, tamanho natural
-- Icon("kill", { color = p.crit, size = dpi(14) })  -- recolorido + tamanho fixo
local gfs    = require("gears.filesystem")
local gcolor = require("gears.color")
local wibox  = require("wibox")
local DIR = gfs.get_configuration_dir() .. "icons/svg/"
local function Icon(name, opts)
  opts = opts or {}
  local path  = DIR .. tostring(name) .. ".svg"
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
```
> **Consumo:** `require("src.tools.icons")` retorna a função `Icon` direto (não uma tabela). A
> migração dos consumidores **já foi feita** — cada arquivo e o ícone que ele usa estão na tabela
> de [§3.13.1](#3131-mapeamento-elemento--ícone-onde-cada-ícone-entra--status-wired).
>
> **Hover/estado em `imagebox`:** a cor de um `imagebox` **não** muda por `fg` — para recolorir no
> hover/estado, troque a imagem: `ib.image = gcolor.recolor_image(SVG.."<n>.svg", p.<token>)` nos
> sinais `mouse::enter`/`mouse::leave` (padrão usado em `tag_controls`/`process_panel`/`titlebar`).

**Lista (41), por categoria — exatamente como em `icondata.json` (8 categorias):**
- **stats (11):** `cpu` `cpu_temp` `mem` `gpu` `gpu_temp` `net` `net_up` `net_down` `wifi` `vol` `battery`
- **power (5):** `shutdown` `reboot` `logout` `lock` `suspend`
- **proc (2):** `kill` `kill_all`
- **osd (4):** `notification` `dnd` `brightness` `volume_mute`
- **menu (6):** `visible` `sticky` `floating` `fullscreen` `send_signal` `close`
- **tagctl (4):** `add` `remove` `move_left` `move_right`
- **tags (7):** `term` `internet` `files` `develop` `edit` `media` `doc`
- **time (2):** `clock` `calendar`

> **Atenção:** `volume_mute` vive em **`osd`** (não em `stats`) no `icondata.json` — mesmo sendo o
> par mudo do `vol` (que é `stats`). A lozenge VOL (§7.2.1) usa `vol`/`volume_mute`; o OSD de volume
> (§7.10) também. `cpu_temp`/`gpu_temp` ficam em `stats` junto dos demais sensores.

> Cobertura completa dos monitores: temperatura (`cpu_temp`/`gpu_temp`), relógio (`clock`),
> calendário (`calendar`). Sem ícone de disco/storage — não há painel DISK no HUD (reservar
> `disk.svg` caso um dia exista).

### 3.13.1 Mapeamento `elemento → ícone` (onde cada ícone entra) — **status wired**

Tabela de integração **real** (o que está conectado hoje). `✓` = wired no código; tamanho em
`dpi`; "as-is" = multitom nativo (sem recolor).

| Elemento | Ícone | Arquivo · tamanho · cor/estado |
|---|---|:--:|
| Lozenges **CPU·MEM·GPU·NET·VOL** | `cpu` `mem` `gpu` `net` `vol` | ✓ `control_center.lua` · **dpi(30)** centralizado (`ICON_SZ`) · as-is · valor ≥90% → `glow_hot` |
| Fita de status (barra fina) **CPU·MEM·NET·VOL** | `cpu` `mem` `net` `vol` | ✓ `status_dock.lua` · dpi(16) · as-is |
| **Trigger relógio/calendário** (canto sup-dir.) | `calendar` | ✓ `control_center.lua` · **dpi(30)** centralizado · `text_heading` |
| **PROCESS** — KILL por linha | `kill` | ✓ `process_panel.lua` · dpi(14) · `text_muted` → `crit` (swap no hover) |
| **PROCESS** — header | `kill_all` | ✓ `process_panel.lua` (`right_icon`) · dpi(14) · `text_muted` |
| **APPLICATIONS** — KILL por linha | `kill` | ✓ `apps_panel.lua` · dpi(14) · `text_muted` → `crit` |
| **tag_controls** `+ − ‹ ›` | `add` `remove` `move_left` `move_right` | ✓ `tag_controls.lua` · dpi(16) · `v200` → `v400` (swap) |
| **Tags** (ícone do tipo, à esq. do índice) | `internet` `edit` `develop` `media` (+`term`/`files` default) | ✓ `taglist.lua` · dpi(16) · cor = `fg` do estado (foco → `v50`) |
| **USAGE** — header / thermal | `cpu_temp` | ✓ `usage_panel.lua` (`right_icon`) · dpi(14) · coluna TEMP ≥80 °C → `crit` |
| **GRAPH** — séries ↑/↓ | `net_up` / `net_down` | ✓ `net_graph_panel.lua` · dpi(12) · `data4` / `v400` |
| **GRAPH** — header | `net` | ✓ `net_graph_panel.lua` (`right_icon`) · dpi(14) · `text_muted` |
| **IP** — header | `net` | ✓ `ip_panel.lua` (`right_icon`) · dpi(14) · `text_muted` |
| **CONNECTIONS** — header (recon/scan) | `send_signal` | ✓ `connections_panel.lua` (`right_icon`) · dpi(14) · `text_muted` |
| **PROTOCOLS** — header | `send_signal` | ✓ `protocols_donut.lua` (`right_icon`) · dpi(14) · `text_muted` |
| **INFO** — header | `cpu` | ✓ `info_panel.lua` (`right_icon`) · dpi(14) · `text_muted` |
| **CALENDAR** — header | `calendar` | ✓ `calendar_panel.lua` (`right_icon`) · dpi(14) · `text_muted` |
| **powermenu** | `shutdown` `reboot` `logout` `lock` `suspend` | ✓ `powermenu.lua` · recolor `v50` em chip `v700` |
| **OSD volume** | `vol` / `volume_mute` | ✓ `volume_osd.lua` · recolor `text_heading` (mudo → `volume_mute`) |
| **OSD brilho** | `brightness` | ✓ `brightness_osd.lua` · recolor `text_heading` |
| **Clock** (widget de barra) | `clock` | ✓ `clock.lua` · recolor `v400` |
| **Notificações** (naughty) | `notification` | ✓ `core/notifications.lua` · recolor `text_muted` |
| **Titlebar** (janela flutuante) | `sticky` `visible` `fullscreen` `close` | ✓ `modules/titlebar.lua` · dpi(14) · hover: close → `crit`, resto → `v400` (minimize segue glyph `_`, sem SVG) |

**Headers de painel:** todos via `panel.lua → opts.right_icon = Icon("<n>", { size = dpi(14), color = p.text_muted })`.

**Reservados (sem consumidor por ora — não forçar):**

| Ícone | Por que não está wired |
|---|---|
| `battery` | `battery.lua` é **dead code** (não é `require`d) e a máquina é desktop **sem bateria** (ver perfil de hardware). |
| `wifi` | máquina **sem wifi** (só `eno1`); não há indicador de wifi. |
| `gpu_temp` | não há painel/linha de **temperatura de GPU** no HUD atual. |
| `dnd` | `notifications.lua` não tem toggle de **Do-Not-Disturb**. |
| `doc` | faz parte do **vocabulário de ícone de tag** (`TAG_ICON` em `taglist.lua`); fica disponível como fallback, não atribuído às 4 tags atuais. |

> **Regra:** monitores de hardware e controles usam **ícone SVG** (este set). Glyph Nerd-Font só
> como fallback onde não houver SVG equivalente (hoje: só o `_` de minimizar na titlebar).
> Para dar casa aos reservados, crie o consumidor (ex.: painel GPU-temp → `gpu_temp`; toggle DND
> → `dnd`) e siga o mesmo padrão `Icon("<n>")`.

### 3.13.2 Formato de dados (`icondata.json`) · geometria SVG · inventário de cor

**Estrutura de `icons/icondata.json`** — array com **41** objetos (1 por ícone). Cada objeto é a
fonte declarativa do SVG: o set foi gerado a partir deste JSON, então **os `.svg` e o JSON estão
1:1** (mesmos nomes, mesmas cores — verificado).

```json
[
  {
    "name": "cpu",                 // = nome do arquivo (icons/svg/<name>.svg, sem extensão)
    "cat": "stats",                // 1 de 8: stats power proc osd menu tagctl tags time
    "shapes": [                    // ordem = ordem de desenho / ordem dos <path> no SVG
      { "op": "stroke", "d": "M6 6 H18 V18 H6 Z",   "c": "#cbb6ff", "w": 2 },
      { "op": "fill",   "d": "M10 10 H14 V14 H10 Z", "c": "#9d6ff6", "rule": "nonzero" }
    ]
  }
]
```

Campos de `shapes[]`:

| Campo | Em | Valores | Significado |
|---|---|---|---|
| `op` | sempre | `"stroke"` \| `"fill"` | traço (contorno) ou preenchimento |
| `d` | sempre | path SVG | geometria no grid **24×24** (mesmos comandos `M/H/V/L/a/A/C/Z`) |
| `c` | sempre | hex 6 díg. | cor = **um token da paleta** (nunca cor solta — ver inventário abaixo) |
| `w` | só `stroke` | `1.4` `1.6` `2` `2.6` | `stroke-width` |
| `rule` | só `fill` | sempre `"nonzero"` | `fill-rule` |

**Geometria canônica de TODO `.svg`** (constante no set — preserve ao editar/gerar):
- `viewBox="0 0 24 24"`, `width="24" height="24"`; raiz `<svg … fill="none">`.
- 1 `<path>` por shape, na ordem do array `shapes`.
- Strokes sempre `stroke-linecap="round" stroke-linejoin="round"`.
- **PNG:** `icons/png/{16,24,32,48,64}/<name>.png` — os 41 ícones rasterizados em 5 tamanhos
  (= **205 PNGs**), fallback p/ tamanho fixo. SVG é a fonte; prefira-o (escala sem perda).

**Inventário de cor (todo o set usa só estes 7 tokens — contagem real de ocorrências):**

| Token | Hex | Ocorr. | Papel nos ícones |
|---|---|---:|---|
| `text_primary` | `#cbb6ff` | 119 | **todo o traço/contorno** (presente em ~todos os ícones) |
| `v400` | `#9d6ff6` | 19 | fill de acento: núcleo do `cpu`, ponteiro do `clock`, raio do `suspend`, capô do `kill` |
| `v500` | `#8b5cf6` | 14 | fill primário: blocos de `mem`, chip do `lock`, faixa do `calendar`, `kill_all` |
| `bevel_lo` | `#160c28` | 12 | espaço negativo: olhos/dentes do skull, furo do cadeado, janela de trás do `floating` |
| `glow_ice` | `#d6c2ff` | 5 | realce/LED: ponto do `wifi`, núcleo do `send_signal`, glint do `gpu`/`gpu_temp`, sino do `notification` |
| `text_muted` | `#6f5a96` | 4 | células inativas do `calendar` |
| `v800` | `#5b21b6` | 2 | fill profundo: corpo da pasta `files`, pino do `sticky` |

> **Implicação p/ recolor:** como os ícones são **multitom** (até 7 tokens num só arquivo),
> `recolor_image` achata tudo numa cor — use **só por estado** (§3.13). P/ um realce que respeite a
> composição, troque o **token de origem** no `.svg`/JSON e regenere, não recolore em runtime.

---

## 4. Tipografia

A referência usa um **monoespaçado bitmap** apertado. Mantemos `JetBrainsMono Nerd Font`
(já no repo), mas você **pode** trocar por um bitmap p/ máxima fidelidade.

| Papel | Família | Tamanho | Peso | Caso |
|---|---|---|---|---|
| Título de painel | JetBrainsMono Nerd Font | 11 | ExtraBold | **CAIXA-ALTA**, tracking +1 |
| Rótulo (label) | JetBrainsMono Nerd Font | 10 | Bold | CAIXA-ALTA |
| Valor/número | JetBrainsMono Nerd Font | 11–12 | ExtraBold | — |
| Corpo | JetBrainsMono Nerd Font | 11 | Regular/Medium | — |
| Barra superior | JetBrainsMono Nerd Font | 11 | Bold | CAIXA-ALTA |
| Micro (legendas) | JetBrainsMono Nerd Font | 9 | Bold | CAIXA-ALTA |

- **Títulos sempre em caixa-alta** e em `text_heading` (`#b794ff`).
- **Números à direita**, rótulos à esquerda.
- Para fidelidade total à referência, fontes bitmap recomendadas (opcional):
  `Terminus`, `Tamzen`, `Cozette`, `Spleen`, `ProggyTiny`.

Defina em `user_variables.lua`:

```lua
font = {
  regular   = "JetBrainsMono Nerd Font, Medium 11",
  bold      = "JetBrainsMono Nerd Font, Bold 11",
  extrabold = "JetBrainsMono Nerd Font, ExtraBold 11",
  label     = "JetBrainsMono Nerd Font, Bold 10",
  micro     = "JetBrainsMono Nerd Font, Bold 9",
  specify   = "JetBrainsMono Nerd Font",
}
```

---

## 5. Layout & composição — **barra superior + DASHBOARDS ON-CLICK (Image #6/#8/#12)**

> **MODELO DE INTERAÇÃO (ATUALIZADO — substitui o grid de 3 colunas estáticas).**
> **NÃO** há colunas de painéis ocupando a tela o tempo todo. A única coisa sempre visível é
> uma **barra superior fina** com widgets clicáveis. Cada grupo de painéis de dado **só aparece
> num popup (dropdown) quando o usuário CLICA** no widget correspondente da barra, e some ao
> clicar de novo / abrir outro. Os popups são **GRANDES (≈2× o tamanho dos painéis antigos)** e
> ancorados logo abaixo da barra. Sem `system_monitor_chart` monolítico, sem dock, sem colunas estáticas.

### 5.1 Barra superior (única coisa sempre visível)

Da esquerda p/ a direita:
- **Tags** — abas com **seta afiada de UMA direção** (Image #11; ver §7.2) + cluster `+ − ‹ ›` (`tag_controls`).
- **STATUS DO MEIO** — lozenges **clicáveis** (§7.2.1): `〈 cpu% 〉〈 mem% 〉〈 gpu% 〉〈 net ↑↓ 〉〈 vol% 〉`
  + **relógio** `HH:MM  Mês DD`. É o miolo da barra.
- **Power** à direita.

### 5.2 Dashboards on-click (dropdown popups, ≈2×) — Image #6

Clicar num widget da barra **abre/fecha** um `awful.popup` (ontop) com os painéis daquele grupo,
ancorado abaixo da barra. **Só um aberto por vez** (abrir um fecha os outros); clicar de novo fecha.

| Clique em (widget da barra) | Abre o popup |
|---|---|
| **CPU / MEM / GPU** (lozenge) | **SYSTEM** → INFO + USAGE (tabela de núcleos GHz/Temp/Used%) + PROCESS (com Kill) |
| **NET** (lozenge) | **NETWORK** → GRAPH (↑/↓) + IP + CONNECTIONS (clique→nmap) + PROTOCOLS + APPLICATIONS (Kill) |
| **VOL** (lozenge) | controlador de volume (`volume_controller`, já existe) |
| **relógio / data** | **TIME** (Image #12) → CALENDAR (mês atual **+ próximo**) + INTERNATIONAL (fusos Europe/America/Japan) + SATELLITE |

- Painéis dentro dos popups têm largura **≈`dpi(520)`** (2× os `dpi(260)` antigos) — o usuário
  reclamou que estavam pequenos demais.
- Cada painel (§7.4) é instanciado **uma vez** (widget tem pai único) e vive em **um** popup.

### 5.3 Técnico

- **Barra superior:** tags (`radical_bar`, top-left) · **`control_center.lua`** (popup fino top-center
  com os lozenges clicáveis) · power (top-right).
- **`src/widgets/control_center.lua`** constrói a fita de lozenges clicáveis (com amostragem async
  de cpu/mem/gpu/net/vol) **e** os popups de dashboard, e faz o toggle. Recebe de `init.lua` os
  painéis já criados, agrupados por dashboard (system / network / time).
- **Popups:** `awful.popup { ontop = true, visible = false, ... }`; toggle no `button::press` do
  lozenge; `placement` abaixo da barra (`awful.placement.top`, margin ~`dpi(40)`); ao abrir um,
  esconder os demais. Opcional: fechar ao focar um cliente.
- **APOSENTADOS** da composição: `side_panels` estático, `system_monitor_chart` monolítico, `dock`.
  Reaproveite os **coletores** nos painéis (sempre **async**).

---

## 6. Espaçamento, raios, bordas, sombras

| Token | Valor | Uso |
|---|---|---|
| `radius_panel` | `dpi(4)` | cantos de painel (a referência é quase reta — raio pequeno) |
| `radius_chip` | `dpi(3)` | tags, chips, botões |
| `radius_bar` | `dpi(2)` | trilhas/preenchimentos de barra |
| `pad_panel` | `dpi(8)` | padding interno do corpo |
| `pad_header_x` | `dpi(8)` | padding horizontal do header |
| `pad_row_y` | `dpi(3)` | altura de respiro de linha de dado |
| `gap` | `dpi(8)` | entre painéis |
| `border_panel` | `dpi(1)` | borda de painel |
| `border_focus` | `dpi(2)` | borda de janela em foco |
| `corner_tick` | `dpi(10)` | comprimento do "L" de canto |

- **Raios pequenos** (referência é angular). Nada de `radius` 10–15px.
- **Sem drop-shadow colorido**; profundidade vem do **bevel 2-tons** (`bevel_hi`/`bevel_lo`).
- Picom: opacidade de painel ~0.90, terminais ~0.85, **blur leve** opcional.

---

## 7. Componentes (specs detalhadas)

### 7.1 Chrome de painel — *o motivo central*

Todo painel da referência segue o mesmo molde. Crie um **factory** reutilizável,
ex. `src/tools/panel.lua`, com a assinatura `panel({ title=, body=, accent=, w=, h= })`.

**Anatomia (de cima p/ baixo):**

1. **Header** (`panel_hi`, altura `dpi(20)`):
   - Título à esquerda, caixa-alta, fonte `extrabold 11`, cor `text_heading`.
   - (Opcional) micro-ícone à direita (`text_muted`, glyph Nerd Font como `` `` `` ou `` `` ``).
2. **Linha divisória:** 1px, gradiente horizontal `accent → accent@22% → transparente`
   (igual ao `section_line` que já existe no chart — reaproveite a ideia).
3. **Corpo** (`panel` com alpha `e6`): padding `pad_panel`, conteúdo do widget.
4. **Borda:** 1px `line_base` (ou `line_bright` se foco/ativo).
5. **Bevel:** linha extra `bevel_hi` no topo+esquerda, `bevel_lo` no baixo+direita (desenhada
   no `:draw` via `cr:move_to/line_to`), para o efeito inset da referência.
6. **Ticks de canto:** "L" de `corner_tick` px nos 4 cantos em `accent@0.9` (já há código
   desse efeito em `create_monitor_canvas` — reaproveitar).

**Estados:** normal = borda `line_base`; foco/hover = borda `line_bright` + header
`v700`; alerta = borda `glow_hot`.

```
┌[ INFO ]───────────────────────────⟳┐  ← header panel_hi, título text_heading
│────────────────────────────────────│  ← divisória gradiente accent→0
│ kernel        6.18.5                │  ← rótulo text_muted · valor text_bright
│ uptime        04:21:55              │
│ packages      1487                  │
└──────────────────────────────────── ┘  ← borda line_base + bevel
   ▏ticks de canto em accent nos 4 cantos
```

### 7.2 Barra superior (wibar)

- **Fundo:** `base .. "cc"`, altura `dpi(26)`, baseline 1px `line_base` embaixo.
- **Esquerda — Taglist (idêntico à Image #11):** cada tag é uma **aba em forma de SETA AFIADA
  de UMA direção** (`tab_shape`: borda esquerda RETA, ponta afiada à DIREITA → ; **NÃO** um
  lozângulo/hexágono com pontas dos dois lados — erro recorrente) contendo `[índice] [ícone] LABEL`
  em CAIXA-ALTA, e as abas são ligadas por **setas afiadas** (separador powerline `` em
  `line_dim`). Fonte `bold 10`. Cada tag pode exibir um **ícone** à esquerda do número
  (como na Image #2: Term/Internet/Files/Develop…).
  - inativa/vazia: bg `v975` (`#2b0c45`), fg `text_muted`
  - ocupada (tem clientes): bg `v975`, fg `text_primary`
  - foco/selecionada: bg `v500`, fg `v50`
  - urgente: bg `glow_hot`, fg `v50`
  - hover: clarear bg (selecionada `v400@dd`, outra `v900@dd`) — mecânica já no `taglist.lua`; **ajuste só as cores p/ tokens**.
- **Centro — Tasklist:** título da janela focada em `text_primary`; inativas `text_muted`.
- **Separadores — setas powerline AFIADAS, direcionais (idêntico à Image #1):** o dockbar
  de cima imita a barra de tags da referência (Image #1) — um *breadcrumb* de segmentos
  (ícone + label em CAIXA-ALTA) ligados por **setas afiadas (sharp)**. A direção da seta
  depende de **qual canto superior** a barra ocupa:
  - barra do **canto superior-ESQUERDO** (tags) → seta aponta para a **DIREITA** (``, glyph Nerd Font powerline U+E0B0).
  - barra do **canto superior-DIREITO** (relógios/status) → seta aponta para a **ESQUERDA** (``, U+E0B2).
  Efeito powerline contínuo: a **cor da seta = cor do segmento que ela segue**, sobrepondo o
  segmento vizinho (`spacing` negativo, ~`-dpi(18)`). Segmentos em sombras violeta da paleta
  (`panel` → `panel_hi` → `raised` → `v950`), texto/ícone em `text_bright`/`v400`.
  *(Esta diretriz substitui — só para a barra superior — a antiga nota de "sem powerline / chevron sutil".)*
- **Cluster de controle de tags (fim da taglist, idêntico à Image #2):** logo após as abas,
  um grupo de botões-glyph (`src/widgets/tag_controls.lua`) para **gerenciar áreas de trabalho**:
  - `` **adicionar** tag (`awful.tag.add(...):view_only()`)
  - `` **remover** a tag atual (`s.selected_tag:delete()`, protegido p/ não zerar `#s.tags`)
  - `` / `` **mover** a tag atual p/ a esquerda/direita entre as áreas (`awful.tag.move`)
  Glyphs em `text_muted`, hover `v400`, cursor `hand1`. (Equivale ao grupo `+ - ⊕ ▣` do canto
  direito da barra de tags da Image #2.)
- **Centro — STATUS DO MEIO (lozenges, idêntico à Image #7):** ver **§7.2.1**. Uma fita de
  **cápsulas com ponta de seta côncava** `〈 valor 〉`, cada uma com um stat do sistema
  (CPU/MEM/NET/VOL) + relógio à direita, ocupando o **miolo** da barra superior, **entre** a
  taglist (esquerda) e o relógio/systray (direita). Arquivo `src/widgets/status_dock.lua`.
- **Direita:** systray (`bg_systray = panel`, `systray_icon_spacing = dpi(6)`), mini-relógio
  `%H:%M` em `text_bright`, e indicadores compactos (layoutbox, kb layout) em `text_muted`.

> **Ícones da taglist e do cluster (set `icons/`, §3.13.1):** cada tag pode usar o ícone do seu tipo
> (`term`/`internet`/`files`/`develop`/`edit`/`media`/`doc`) à esquerda do índice; o `tag_controls`
> usa `add`/`remove`/`move_left`/`move_right` (recolor `v400` no hover) no lugar dos `+ − ‹ ›` ASCII.

### 7.2.1 STATUS DO MEIO — lozenges de estatística (Image #7) — *o "status do meio"*

A fita central da barra superior (a que está apontada na **Image #7**) é uma sequência de
**lozenges (pílulas) com cápsulas de seta côncava** — o estilo clássico "blind/arrow" do
AwesomeWM. Cada lozenge mostra UM stat; o conjunto fica **entre as tags e o relógio**.

Anatomia de UMA lozenge `〈  NN% 〉`:
- **Forma:** retângulo arredondado/hexagonal com as duas pontas em **seta côncava** (chevron
  apontando p/ DENTRO da pílula). Implementar com `shape` custom (`cr:move_to/line_to`) — um
  hexágono achatado tipo `tab_shape` do taglist; alternativa simples = `rounded_rect` raio
  `radius_chip` ladeado por cápsulas `‹` `›` em `line_dim`.
- **Fundo:** `panel .. "cc"`; **borda:** 1px `line_base`; altura `dpi(20)`, padding-x `dpi(8)`.
- **Conteúdo:** **ícone SVG** de `icons/svg/` (cpu/mem/gpu/net/vol — via `src/tools/icons.lua`)
  + valor `text_bright`, monoespaçado, número à direita. (Substitui o glyph Nerd-Font; ver §3.13.1.)
- **ÍCONE GRANDE + CENTRALIZADO (obrigatório):** o ícone deve ser **grande** — ~`dpi(28–30)` no
  dockbar do meio (`control_center.lua`, pílula `PILL_H = dpi(44)`), nunca os antigos `dpi(18-20)`,
  que ficam pequenos demais perto do valor (fonte `Bold 18`). E **centralizado nos DOIS eixos**:
  envolva o grupo `{ ícone, valor }` num `wibox.container.place` (`halign="center"`,
  `valign="center"`) — sem isso o conteúdo cola no TOPO da pílula (um `container.margin` só com
  `left/right` não centraliza vertical) e fica desalinhado. O ícone também vai dentro do seu
  próprio `place` (center/center). Tamanho via constante `ICON_SZ` no topo do arquivo.
  - Na barra fina alternativa (`status_dock.lua`, `PILL_H = dpi(20)`) escale junto: ícone ~`dpi(16)`.
- **Fita contínua:** as lozenges encostam (gap pequeno `dpi(2)`) formando a tira da Image #7.
- **SEMPRE no MEIO (centragem do dockbar):** o popup do dockbar do meio é `placement = top`
  (centrado na tela). Como os valores chegam **assíncronos** (`"--"` → `"3%"`/`"↑0 ↓1"`/`"98%"`),
  a largura **cresce após** o placement inicial e o bar escorrega para a direita (entrando por
  cima do dockbar do relógio). **Obrigatório re-centrar a cada mudança de largura:**
  `bar:connect_signal("property::width", function() awful.placement.top(bar, {margins={top=dpi(8)}}) end)`.

Os stats, na ordem da Image #7:

| Lozenge | Glyph | Valor | Fonte (assíncrona) |
|---|---|---|---|
| **CPU** | `` | `NN%` | `/proc/stat` (delta busy/idle entre ticks) |
| **MEM** | `` | `NN%` | `/proc/meminfo` (`1 − MemAvailable/MemTotal`) |
| **NET** | `` `` | `↑NN ↓NN` (KB/s) | `/proc/net/dev` (delta rx/tx entre ticks) |
| **VOL** | `` | `NN%` | `pactl get-sink-volume @DEFAULT_SINK@` |

- **Ícones (não glyphs):** a coluna "Glyph" da tabela acima é, na implementação, um **ícone SVG**
  do set `icons/` (§3.13.1): CPU=`cpu`, MEM=`mem`, **GPU=`gpu`**, NET=`net`, VOL=`vol` (mudo=`volume_mute`).
- À direita do grupo (na barra, fora das lozenges): **relógio** `HH:MM` + **data** `Mês DD`
  em `text_bright`/`text_muted` (como o `01:42  Jan 02` da Image #7).
- Alerta opcional: valor ≥ 90% → `glow_hot`; caso contrário sempre violeta.
- Arquivo: `src/widgets/status_dock.lua`. **Amostragem sempre assíncrona** (nunca `io.popen`/sync).
- **Posição:** miolo da barra superior; nunca à direita junto dos relógios mundiais. Se o centro
  estiver ocupado por outra coisa, essa outra coisa cede o centro — o status do meio tem prioridade.
- **CLICÁVEIS (dashboards on-click, §5.2):** cada lozenge é um botão. Clique abre/fecha o popup
  do grupo: CPU/MEM/GPU → SYSTEM, NET → NETWORK, VOL → controlador de volume, relógio → TIME
  (calendário+fusos, Image #12). Só um popup aberto por vez; cursor `hand1` no hover.

### 7.3 Barra inferior / colunas laterais

- **Colunas:** `awful.popup` vertical com painéis (§7.1). Largura sugerida `dpi(260)`.
- **Barra inferior:** mesma estética da superior; pode hospedar `CONNECTIONS`, now-playing,
  status de rede. Substitui o dock atual.

### 7.4 Widgets de dado

Todos vivem **dentro** do chrome de painel (§7.1). Cores sempre dos tokens.

#### 7.4.1 Info rows (key/value) — `INFO`, `STATE`, `USERS`
- Linha: rótulo à esquerda (`text_muted`, CAIXA-ALTA), valor à direita (`text_bright`).
- Opcional: fundo da linha `v500@0.06`, borda `v500@0.20`, raio `radius_bar` (estilo
  `create_info_row` do chart — reaproveite e recolora).
- Altura de linha `dpi(18)`, `pad_row_y` vertical.

#### 7.4.2 Bar meter horizontal — `USAGE` (CPU/MEM/…)
```
CPU  ▕████████████░░░░░░░░░▏ 58%
```
- Trilha: `inset`, raio `radius_bar`, altura `dpi(8)`.
- Preenchimento: gradiente horizontal `v700 → v500` (saturar levemente perto do fim).
- ≥ limiar de alerta: preenchimento vira `glow_hot`.
- Valor `%` à direita em `text_bright`.

#### 7.4.3 Line graph + grid + área — `GRAPH`
- Poço: `inset`, raio `radius_panel`.
- **Grid:** linhas horizontais a cada 25% em `grid@0.22/0.12` (alterna), verticais em
  `accent@0.09/0.04` (já há essa lógica no `graph_widget:draw` — reaproveite, recolorindo).
- **Área:** sob a linha, fill da série em alpha 0.20–0.34.
- **Linha:** 2px na cor da série (`data1..n`), com "halo" 6px em alpha 0.22 por baixo.
- Multi-série: empilhar `mem` (data2) → `gpu` (data3) → `net` (data4) → `cpu` (data1).
- Picos altos podem usar `glow_hot`.

#### 7.4.4 Pie / Donut — `PROTOCOLS`
- Fatias em `data1..6` (ordem da maior p/ menor). Rosca (donut) com furo `inset`.
- Legenda à direita: quadradinho da cor + label `text_muted` + `%` `text_bright`.
- Borda de cada fatia 1px `base` para separar.

#### 7.4.5 Calendar — `CALENDAR`
- Cabeçalho do mês em `text_heading` CAIXA-ALTA, centralizado.
- Cabeçalho de dias da semana (`SU MO TU …`) em `text_muted`.
- Dias do mês em `text_primary`; **hoje** em caixa `v500` com fg `v50` (raio `radius_chip`).
- Fim de semana levemente `text_body`; dias fora do mês `text_faint`.
- Pode usar `wibox.widget.calendar` reestilizado via `fn_embed`.

#### 7.4.6 World clocks / `INTERNATIONAL`
- Lista de linhas `CIDADE ──── HH:MM` (monoespaçado, alinhado).
- Reaproveite `world_clock.lua` (lógica de timezone + bandeira), mas **troque** o
  `segment_bg` por chrome de painel: bandeira pequena à esquerda, label `text_muted`,
  hora `text_bright`. Mantenha o desenho de bandeira (é cultural, não é o acento do tema).
- Zonas como na referência: UTC / CET / EST / JST — ou as suas (BR/FR/JP/US).

#### 7.4.7 Process list — `PROCESS`
- **Todos** os processos por CPU/MEM: `PID  NOME            CPU%  MEM%  [KILL]`.
- Nome `text_primary`, números `text_bright`, mini-barra inline opcional (`v600`).
- **Scroll por roda do mouse (altura FIXA — o painel NÃO cresce):** a lista mostra `VISIBLE`
  linhas de altura fixa (`AREA_H = VISIBLE × ROW_H + (VISIBLE-1) × ROW_GAP = 6 × dpi(18) +
  5 × dpi(2) = dpi(118)`); a amostra (`ps … --sort=-pcpu`, **sem `head`**)
  guarda a lista inteira, e a roda do mouse (botões 4/5) desliza um `offset` por linha,
  re-renderizando só a fatia visível. O `offset` é preservado entre ticks de amostragem
  (reclampado ao novo total). Barra fina à direita numa calha de `dpi(10)`: track
  `line_base@50%` + thumb `v500` cuja altura ∝ `VISIBLE/total` e cuja posição ∝ `offset`
  (some quando não há overflow). Cabeçalho e linhas compartilham a mesma calha → colunas
  alinhadas. **Padrão reusável:** qualquer lista densa (PROCESS, CONNECTIONS, sinais, …)
  deve usar esta janela de rolagem — janela de altura fixa + windowing por wheel + thumb
  na calha direita — **nunca** crescer o widget para caber todos os itens. Sem
  `wibox.layout.overflow` neste build do awesome → o windowing manual é a forma canônica.
- **Botão KILL por linha (interativo, igual à Image #4):** à direita de cada processo, um
  controle `` (skull) / "KILL" em `text_muted` (hover `crit`); clique esquerdo →
  `awful.spawn({"kill", pid})` (SIGTERM). O PID é guardado por linha; cursor `hand1` no hover.
- Coluna de **sinais** (estilo referência): lista `SIGHUP SIGINT SIGKILL …` em
  `text_muted`, item ativo `v400` (ver também submenu Send Signal §7.5).

> **Ícone do KILL (set `icons/`):** o botão usa `icons/svg/kill.svg` (matar todos = `kill_all.svg`)
> via `src/tools/icons.lua`, recolorido p/ `crit` no hover — substitui o skull Nerd-Font. Mesmo
> ícone no APPLICATIONS (§5.2). USAGE/thermal usam `cpu_temp.svg`/`gpu_temp.svg` (≥80 °C → `crit`).

#### 7.4.8 Connections — `CONNECTIONS`
- Lista **todas** as conexões de rede: `PROTO  LOCAL → REMOTO  ESTADO` (via `ss -tunH`, **sem
  `head`** — a lista inteira fica disponível pelo scroll).
- Estado `ESTABLISHED` em `ok`, `LISTEN` em `text_muted`, `TIME_WAIT` em `warn`.
- **Scroll por roda do mouse (altura FIXA — o painel NÃO cresce):** mesmo padrão reusável do
  PROCESS (§7.4.7). A área tem altura fixa de `VISIBLE × ROW_H + (VISIBLE-1) × ROW_GAP =
  6 × dpi(18) + 5 × dpi(2) = dpi(118)`; a roda (botões 4/5) desliza um `offset` por linha,
  re-renderizando a fatia visível nas `VISIBLE = 6` linhas reusáveis (cada `set_row` reaproveita
  os textboxes existentes). `offset` preservado entre ticks (5 s), reclampado ao novo total.
  Barra fina na calha de `dpi(10)` à direita: track `line_base@50%` + thumb `v500` (some quando
  não há overflow). Quando não há conexões, mostra a linha única `NO CONNECTIONS`.
- **Clique = scan (interativo / dinâmico):** cada linha é clicável. Clique esquerdo → abre o
  terminal do usuário numa **nova sessão tmux** nomeada com o **endereço do serviço** e roda um
  **nmap de serviço** sobre o `host:porta` daquela conexão, mantendo o terminal aberto:
  `<terminal> -e tmux new-session -A -s <addr-sanitizado> "nmap -Pn -sV -sC -p <porta> <host>; exec zsh"`.
  - O nome da sessão = `host[:porta]` com `.` `:` `%` `/` → `-` (tmux **proíbe** `.`/`:` em nomes).
  - `-A` anexa se a sessão já existir (clicar 2× no mesmo serviço não duplica/erra).
  - `exec zsh` deixa o terminal **aberto** após o scan; como roda **dentro do tmux** (`$TMUX`
    setado), o menu inicial de sessões do `~/.zshrc` NÃO dispara (guarda em `~/.zshrc:341`).
  - Forma de **tabela** em `awful.spawn{}` (sem shell) → sem inferno de aspas; `nmap -Pn -sV -sC`
    não exige root (connect scan). Faz parse de IPv4 (`host:porta`) e IPv6 (`[host]:porta`).
  - **Contexto:** recon das **próprias** conexões abertas, na **própria** máquina (uso
    administrativo/defensivo legítimo). Cursor `hand1` no hover.

#### 7.4.9 Audio levels / EQ vertical — `USAGE` (áudio)
- Barras verticais (EQ) ou rows de canais (`Master`, `Capture`, `Front`, `Rear Mic`…).
- Barra cheia gradiente vertical `v700 → v400`; mudo em `text_faint`.

#### 7.4.10 Sparkline / mini-histograma
- Versão compacta do line graph p/ caber no header de outro painel; só linha `v400`, sem grid.

### 7.5 Menus de contexto (clique-direito)

A referência tem menus densos com **faixa-título em gradiente**.

> **Gatilho (sem conflito com apps):** o menu abre pelo **clique do SCROLL (botão do meio /
> botão 2)** sobre o cliente (`mappings/client_buttons.lua`). O botão-DIREITO fica livre p/ o
> app usar o próprio menu (tmux, terminais, navegadores) sem o menu do awesome por cima. Resize
> de janela = `modkey` + clique-direito; mover = `modkey` + clique-esquerdo.
> ⚠️ Em terminais o botão-do-meio normalmente cola a seleção primária — aqui ele é capturado p/
> o menu (trade-off escolhido). `src/widgets/context_menu.lua` é um popup ÚNICO (sem submenus
> aninhados) com `current` global (um por vez); dismiss ao sair do ponteiro ou clicar num item.

- **Faixa-título** (cabeçalho da seção): gradiente horizontal `line_bright (#7c3aed) → v950
  (#2e1065)`, texto `v50` CAIXA-ALTA. Altura `dpi(30)`.
- **Item:** altura `dpi(36)`, fg `text_primary`, padding `dpi(8)`, ícone `dpi(21)`.
  - hover/foco: bg `v700`, fg `v50`.
- **Tipografia (FONTE A 150% — ×1.5 sobre a base do usuário):** itens `Bold 21`, faixa-título
  `ExtraBold 21` (= base `14` × 1.5). **Não** herdar `user_vars.font.bold/extrabold` direto (size
  14, pequeno demais p/ o menu); o `context_menu.lua` deriva `FONT_FAM = user_vars.font.specify`
  e fixa o size 21. Largura do popup `dpi(330)` (= 220 × 1.5) e alturas/ícone escalados juntos
  para a fonte maior não cortar.
- **Seta de submenu** `▸` em `text_muted`.
- **Borda do menu:** 1px `line_base`, bg `panel@f2`, raio `radius_chip`.
- **Submenu "Send Signal":** replicar a lista (`SIGHUP, SIGINT, SIGQUIT, SIGKILL, SIGTERM,
  SIGSTOP, SIGCONT, SIGUSR1, SIGUSR2 …`) — itens em `text_primary`, perigosos
  (`SIGKILL`/`SIGTERM`) em `crit` no hover.
- Itens do menu principal a recriar: `Visible · Sticky · Floating · Fullscreen ·
  Move to tag ▸ · Send Signal ▸ · Layer ▸ · Close`.

### 7.6 Menu de apps (launcher)

> **Launcher GIF (canto inferior-direito):** `src/widgets/app_launcher.lua` — botão circular
> `dpi(72)` com o `src/assets/logo.gif` ANIMADO, fixado no canto inferior-direito
> (`awful.placement.bottom_right`, margem `dpi(16)`). GIF desenhado direto em Cairo recortado
> num círculo; disco escuro `panel@d9` + anel `line_base` p/ visibilidade sobre o wallpaper.
> Frames extraídos 1× via ImageMagick e cacheados em `/tmp/awesome_launcher_frames/`. Clique
> esquerdo abre/fecha um popup (bottom-right, acima do botão) com TODOS os `.desktop` instalados
> (scrollável). Some quando há cliente fullscreen na tag. Montado em `radical_wm/init.lua`
> (tela primária); guarda contra duplicata em reload via `s._app_launcher_host`.

- Lista com **ícone (recolorido) + label**, categorias como na referência (Internet,
  Develop, Edit, Media, Doc…).
- bg `panel@f2`, item hover `v700`, label `text_primary`/`v50`.
- Ícones via `icon_handler.lua`; recolorir traços para `text_primary` quando monocromático.
- Se usar `rofi` (já é dependência), forneça um `.rasi` com os mesmos tokens (bg `#130a24`,
  selected `#7c3aed`, fg `#cbb6ff`, border `#5b21b6`).

### 7.7 Janelas: bordas + titlebar

- **Borda:** `border_width = dpi(2)`. Foco: `glow_core` (`#a855f7`). Sem foco: `v950`.
  (Aplicar via signal de `focus`/`unfocus` como já é feito em `signals.lua`.)
- **Cantos:** `gears.shape.rounded_rect` com raio pequeno (`dpi(6)`) p/ flutuantes;
  retangular p/ maximizado/fullscreen (já implementado em `signals.lua` — manter).
- **Titlebar:** a referência é tiling minimalista. **Descartar** o titlebar lateral
  estilo semáforo. Opções:
  - **(Preferido)** Sem titlebar em janelas tiled; título aparece na tasklist da barra.
  - **(Alternativo)** Titlebar superior fina (`dpi(22)`) com o mesmo chrome de painel:
    título `text_primary` à esquerda, e botões textuais `[ _ ][ □ ][ x ]` em
    `text_muted` (hover: `_`→`v400`, `□`→`v400`, `x`→`crit`).

### 7.8 Terminais (Alacritty) — paleta 16 cores

A referência é cheia de terminais translúcidos azuis. Forneça um `alacritty.toml` violeta
(fora do Lua, mas parte do sistema). Alvo:

```toml
[colors.primary]
background = "#0c0617"
foreground = "#cbb6ff"

[colors.normal]
black   = "#160c28"
red     = "#fb5e8a"
green   = "#5ad1a0"
yellow  = "#f0c44c"
blue    = "#7c3aed"
magenta = "#a855f7"
cyan    = "#b794ff"
white   = "#cbb6ff"

[colors.bright]
black   = "#463566"
red     = "#ff7da3"
green   = "#7fe6bd"
yellow  = "#ffd970"
blue    = "#9d6ff6"
magenta = "#c084fc"
cyan    = "#d6c2ff"
white   = "#e9dcff"

# transparência (compositor)
[window]
opacity = 0.85
```

### 7.9 Notificações (naughty)

- bg `panel@f2`, borda 1px `line_base`, raio `radius_panel`.
- **Faixa de acento** vertical de 3px à esquerda em `v500` (ou `crit` p/ urgente).
- Título `text_heading` CAIXA-ALTA; corpo `text_primary`; app-name `text_muted`.
- Ações = chips `v700`/hover `v600`.

### 7.10 OSDs (volume / brilho)

- Mini-painel central-inferior, chrome de §7.1, largura `dpi(280)`.
- Ícone `text_heading` + barra horizontal (§7.4.2). Mantenha a lógica de
  `volume_osd.lua`/`brightness_osd.lua`; recolora.

### 7.11 Calculadora & apps externos (GTK/Qt)

- A "Calc" da referência é um app nativo, não Lua. Para combinar:
  - GTK: tema escuro + accent roxo (ou um `gtk.css` custom com `#130a24`/`#7c3aed`).
  - Qt: `Kvantum` com tema violeta, ou `QT_STYLE_OVERRIDE`.
  - O WM só controla **borda + titlebar** (§7.7) desses apps.

---

## 8. Estados & interação

| Estado | Borda | Fundo | Texto |
|---|---|---|---|
| Normal | `line_base` | `panel@e6` | `text_primary` |
| Hover | `line_bright` | clarear +1 (`raised`) | `text_bright` |
| Foco/ativo | `glow_core` | `v700` (em itens) | `v50` |
| Pressionado | `line_bright` | `v600` | `v50` |
| Urgente | `glow_hot` | `glow_hot@0.15` | `v50` |
| Desabilitado | `line_faint` | `panel@cc` | `text_disabled` |

- **Hover** usa o `Hover_signal` já existente (`signals.lua`) — ele anexa `dd`/`bb` de alpha;
  passe cores roxas (`v500`, `v700`) como argumento.
- Cursor em elementos clicáveis: `hand1` (já feito).
- Animações: mínimas; no máximo transição de cor instantânea (estilo terminal).

---

## 9. Mapeamento no código (arquivo por arquivo)

| Arquivo | Ação |
|---|---|
| `src/theme/palette.lua` | **CRIAR** com os tokens de [3.11](#311-tokens-em-lua-arquivo-pronto). |
| `src/theme/theme_variables.lua` | **REESCREVER** vars do `beautiful` p/ tokens ([3.12](#312-reescrita-de-theme_variableslua-beautiful)); `border_width` 11→2. |
| `src/theme/colors.lua` | Manter (Material) p/ legado; novos widgets usam `palette`. |
| `src/core/signals.lua` | Trocar `#9C27B0`→`glow_core` no `focus`; `unfocus`→`v950`. |
| `src/tools/panel.lua` | **CRIAR** factory de chrome de painel (§7.1). |
| `radical_wm/init.lua` | **REORGANIZAR** composição p/ o grid da §5 (colunas de painéis + barras finas). Manter padrão por-tela. |
| `radical_wm/radical_bar.lua` `left_bar.lua` `right_bar.lua` | **SUBSTITUIR** powerline por barras/colunas com chrome de painel. Remover tint `#ff8c00`. |
| `radical_wm/center_bar.lua` | Re-skin ou aposentar; centro fica livre p/ janelas. |
| `radical_wm/dock.lua` | **APOSENTAR** (referência não tem dock). |
| `src/widgets/system_monitor_chart.lua` | **DECOMPOR** em painéis menores (INFO/USAGE/GRAPH/…) OU re-skinar p/ violeta. **Trocar a `palette` interna laranja** por: `accent=#8b5cf6, cpu=#a855f7, mem=#c084fc, gpu=#7c3aed, net=#d946ef, grid=#3a1f63, text=#cbb6ff, overlay=#0c0617, glow=#b794ff`. Remover título japonês/fotos se quiser fidelidade à referência. **Manter coletores.** |
| `src/widgets/taglist.lua` | Trocar hexes hardcoded por tokens (`v975`, `v500`, `glow_hot`, `v50`, hovers). |
| `src/widgets/world_clock.lua` | Reusar lógica; trocar `segment_bg` por chrome de painel. |
| `src/widgets/cpu_info.lua` `gpu_info.lua` `ram_info.lua` `network.lua` `audio.lua` `battery.lua` | Re-skin como info-rows/bar-meters (§7.4). |
| `src/modules/titlebar.lua` | **REESCREVER** conforme §7.7 (sem semáforo macOS). |
| `src/modules/volume_osd.lua` `brightness_osd.lua` | Re-skin (§7.10). |
| `src/modules/notification-center/init.lua`, `src/core/notifications.lua` | Re-skin (§7.9). |
| `src/modules/powermenu.lua` | Re-skin: botões chip `v700`, ícones recoloridos. |
| `src/assets/icons/**` | Recolorir SVGs p/ `text_primary`/`v400` quando aplicável (via `gears.color.recolor_image`). |
| `~/.config/alacritty/alacritty.toml` | Aplicar paleta §7.8 (fora do repo, documentar). |
| `src/tools/icons.lua` | **EXISTE + EM USO** — helper `Icon(name, {color, size})` carrega `icons/svg/<name>.svg` (recolor opcional) → `imagebox` (§3.13). Retorna a função direto. |
| `icons/` (svg + png + icondata.json) | **ASSETS presentes** (set VIOLET HUD): 41 SVG + 41×5 PNG + `icondata.json` (§3.13.2). Fonte de ícones de hardware/controles; **preferir** sobre glyphs Nerd-Font (§3.13.1). |
| consumidores de ícone | **MIGRAÇÃO FEITA** (36/41 wired). Arquivos tocados: `control_center.lua` `status_dock.lua` `tag_controls.lua` `taglist.lua` `process_panel.lua` `apps_panel.lua` `usage_panel.lua` `net_graph_panel.lua` `ip_panel.lua` `connections_panel.lua` `protocols_donut.lua` `info_panel.lua` `calendar_panel.lua` `clock.lua` `powermenu.lua` `volume_osd.lua` `brightness_osd.lua` `core/notifications.lua` `modules/titlebar.lua`. Detalhe por elemento em §3.13.1. **Reservados:** `battery` `dnd` `gpu_temp` `wifi` `doc`. |

> **Nota de globais:** `user_vars`, `Theme`, `Theme_path`, `Hover_signal` são globais por
> design (ver AGENTS.md). Não os transforme em locals.

### 9.1 Plano de implementação (ordem)

1. `palette.lua` + `theme_variables.lua` + `signals.lua` (base de cor).
2. `panel.lua` (chrome) — valida o motivo central isolado.
3. Barra superior (tags/tasklist/systray) — primeiro contato visual.
4. Colunas de painéis com 2–3 widgets reais (INFO, USAGE, GRAPH).
5. Demais widgets de dado (rosca, calendário, relógios, processos, conexões).
6. Menus de contexto + launcher.
7. Janelas/titlebar + terminais + notificações/OSDs.
8. Aposentar dock/powerline e limpar tints laranja.
9. `awesome -k rc.lua` e comparação visual com a referência.

---

## 10. Snippets de referência rápida

**Bevel 2-tons (no `:draw` de um widget):**
```lua
-- realce topo+esquerda
cr:set_source(gears.color(p.bevel_hi)); cr:set_line_width(dpi(1))
cr:move_to(0, h); cr:line_to(0, 0); cr:line_to(w, 0); cr:stroke()
-- sombra baixo+direita
cr:set_source(gears.color(p.bevel_lo))
cr:move_to(w, 0); cr:line_to(w, h); cr:line_to(0, h); cr:stroke()
```

**Linha divisória de header (gradiente):**
```lua
bg = gears.color {
  type = "linear", from = { 0, 0 }, to = { width, 0 },
  stops = { {0, accent}, {0.55, accent.."38"}, {1, "#00000000"} },
}
```

**Alpha em runtime:**
```lua
local function a(hex, alpha) -- alpha 0..1
  return string.format("%s%02x", hex, math.floor(alpha*255 + 0.5))
end
-- a(p.v500, 0.20) -> "#8b5cf633"
```

---

## 11. Checklist de aceite

- [ ] Fundo quase-preto violáceo; nenhuma superfície grande cinza/laranja.
- [ ] **Zero** laranja/teal como acento (sem `#ff7a00/#ff8c00/#ff9a1f`).
- [ ] Todos os painéis usam o **mesmo chrome** (header caixa-alta + divisória + bevel + ticks).
- [ ] Hierarquia vem de **luminosidade/alpha** roxos, não de matizes diferentes.
- [ ] Existe pelo menos: line graph, bar meters, rosca/pizza, calendário, relógios, lista de processos — todos roxos.
- [ ] Tags: inativa `v975`, foco `v500`, urgente `glow_hot`.
- [ ] Foco de janela: borda fina `glow_core`.
- [ ] Menus com faixa-título em gradiente violeta + submenu Send Signal.
- [ ] Terminais translúcidos com a paleta 16-cores violeta.
- [ ] Sem dock macOS, sem powerline, sem titlebar semáforo.
- [ ] Densidade alta, monoespaçado, números à direita.
- [x] **Ícones do set `icons/` wired** via `Icon("<n>")` (36/41; reservados: `battery` `dnd` `gpu_temp` `wifi` `doc`) — tabela §3.13.1.
- [x] `awesome -k rc.lua` passa sem erros.
- [ ] Lado a lado com a referência: **mesma vibe, cor roxa**.

---

*Documento vivo. Atualize tokens/medidas aqui antes de propagar mudanças de cor pelo código.*
