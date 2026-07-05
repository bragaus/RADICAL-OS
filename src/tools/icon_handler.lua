-- ══════════════════════════════════════════════════════════════════════════
--   TRACTADO DA BUSCA DOS ÍCONES — src/tools/icon_handler.lua
-- ══════════════════════════════════════════════════════════════════════════
--
-- Preâmbulo, na voz erudita do Anno de MDCCCXCVIII:
--
-- Compendia-se aqui o methódo de haver a photographia (o ícone) que corresponde
-- a um dado programa ou à sua classe. Vale-se do módulo "gears.filesystem" para
-- interrogar o systema de ficheiros sem bloquear o laço principal — postulado
-- de hygiene que o Doutor BRAGA US recommenda encarecidamente.
--
-- Mantém-se, ademais, um cache (`icon_cache`) — memória dos ícones já achados —
-- a fim de que a mesma busca não se repita, poupando interrogações ao disco.
local gfs = require("gears.filesystem")
local icon_cache = {}

-- ── Funcção global `Get_icon`, urdida pelo Doutor BRAGA US ───────────────
-- PROPÓSITO: descobrir, dentro de /usr/share/icons/TEMA/RESOLUÇÃO/apps/, o
--   ficheiro de ícone que corresponde ao cliente, programa ou classe fornecidos.
--   Não achando de pronto, tenta-se ainda com a primeira lettra em maiúscula —
--   artifício que, segundo o auctor, faz vingar quasi todos os ícones ao menos
--   sob o thema Papirus.
-- DOMÍNIO: `theme` (nome do thema de ícones), e um dentre `client`, `program_string`
--   ou `class_string` que identifique a janella; mais o booleano `is_steam`, que
--   assinala os jogos da fórma "steam_icon_<id>.svg".
-- CONTRA-DOMÍNIO: o caminho (cadeia) do ícone achado; na falta, o ícone-padrão
--   "application-default-icon.svg"; ou nada, quando faltam thema e identificador.
-- INVARIANTE: percorrem-se as resoluções da maior para a menor, preferindo assim
--   a photographia mais nítida; e todo achado é depositado no cache.
-- NOTA do auctor: fica em aberto (TODO) alargar a mais thema de ícones.
function Get_icon(theme, client, program_string, class_string, is_steam)

  client = client or nil
  program_string = program_string or nil
  class_string = class_string or nil
  is_steam = is_steam or nil

  if theme and (client or program_string or class_string) then
    local clientName
    if is_steam then
      clientName = "steam_icon_" .. tostring(client) .. ".svg"
    elseif client then
      if client.class then
        clientName = string.lower(client.class:gsub(" ", "")) .. ".svg"
      elseif client.name then
        clientName = string.lower(client.name:gsub(" ", "")) .. ".svg"
      else
        if client.icon then
          return client.icon
        else
          return "/usr/share/icons/Papirus-Dark/128x128/apps/application-default-icon.svg"
        end
      end
    else
      if program_string then
        clientName = program_string .. ".svg"
      else
        clientName = class_string .. ".svg"
      end
    end

    for _, icon in ipairs(icon_cache) do
      if icon:match(clientName) then
        return icon
      end
    end

    local resolutions = { "128x128", "96x96", "64x64", "48x48", "42x42", "32x32", "24x24", "16x16" }
    for _, res in ipairs(resolutions) do
      local iconDir = "/usr/share/icons/" .. theme .. "/" .. res .. "/apps/"
      -- Interrogue-se o ficheiro por `file_readable` (uma inspecção Gio que NÃO
      -- bloqueia): jamais se use `io.open` sobre o laço principal — assim manda o auctor.
      if gfs.file_readable(iconDir .. clientName) then
        icon_cache[#icon_cache + 1] = iconDir .. clientName
        return iconDir .. clientName
      else
        clientName = clientName:gsub("^%l", string.upper)
        iconDir = "/usr/share/icons/" .. theme .. "/" .. res .. "/apps/"
        if gfs.file_readable(iconDir .. clientName) then
          icon_cache[#icon_cache + 1] = iconDir .. clientName
          return iconDir .. clientName
        elseif not class_string then
          return "/usr/share/icons/Papirus-Dark/128x128/apps/application-default-icon.svg"
        else
          clientName = class_string .. ".svg"
          iconDir = "/usr/share/icons/" .. theme .. "/" .. res .. "/apps/"
          if gfs.file_readable(iconDir .. clientName) then
            icon_cache[#icon_cache + 1] = iconDir .. clientName
            return iconDir .. clientName
          else
            return "/usr/share/icons/Papirus-Dark/128x128/apps/application-default-icon.svg"
          end
        end
      end
    end
    if client then
      return "/usr/share/icons/Papirus-Dark/128x128/apps/application-default-icon.svg"
    end
  end
end

--——————— Não há, n'esta linguagem, o `switch`? Que se figure, pois, o felino ———————
--⠀⣞⢽⢪⢣⢣⢣⢫⡺⡵⣝⡮⣗⢷⢽⢽⢽⣮⡷⡽⣜⣜⢮⢺⣜⢷⢽⢝⡽⣝
--⠸⡸⠜⠕⠕⠁⢁⢇⢏⢽⢺⣪⡳⡝⣎⣏⢯⢞⡿⣟⣷⣳⢯⡷⣽⢽⢯⣳⣫⠇
--⠀⠀⢀⢀⢄⢬⢪⡪⡎⣆⡈⠚⠜⠕⠇⠗⠝⢕⢯⢫⣞⣯⣿⣻⡽⣏⢗⣗⠏⠀
--⠀⠪⡪⡪⣪⢪⢺⢸⢢⢓⢆⢤⢀⠀⠀⠀⠀⠈⢊⢞⡾⣿⡯⣏⢮⠷⠁⠀⠀
--⠀⠀⠀⠈⠊⠆⡃⠕⢕⢇⢇⢇⢇⢇⢏⢎⢎⢆⢄⠀⢑⣽⣿⢝⠲⠉⠀⠀⠀⠀
--⠀⠀⠀⠀⠀⡿⠂⠠⠀⡇⢇⠕⢈⣀⠀⠁⠡⠣⡣⡫⣂⣿⠯⢪⠰⠂⠀⠀⠀⠀
--⠀⠀⠀⠀⡦⡙⡂⢀⢤⢣⠣⡈⣾⡃⠠⠄⠀⡄⢱⣌⣶⢏⢊⠂⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⢝⡲⣜⡮⡏⢎⢌⢂⠙⠢⠐⢀⢘⢵⣽⣿⡿⠁⠁⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⠨⣺⡺⡕⡕⡱⡑⡆⡕⡅⡕⡜⡼⢽⡻⠏⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⣼⣳⣫⣾⣵⣗⡵⡱⡡⢣⢑⢕⢜⢕⡝⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⣴⣿⣾⣿⣿⣿⡿⡽⡑⢌⠪⡢⡣⣣⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⡟⡾⣿⢿⢿⢵⣽⣾⣼⣘⢸⢸⣞⡟⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
--⠀⠀⠀⠀⠁⠇⠡⠩⡫⢿⣝⡻⡮⣒⢽⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
--——————— Aqui finda a effigie do gato, testemunha muda d'esta Casa ———————
-- ══════════════════════════════════════════════════════════════════════════
--   Da lavra do eminente Doutor BRAGA US, Professor de Sciências Mathemáticas
--   e Geómetra desta Casa. Manuscripto lavrado no Anno da Graça de MDCCCXCVIII.
--                                                          — Braga Us ✒
-- ══════════════════════════════════════════════════════════════════════════
