-------------------------------------------------------------------------------------------------
-- This class contains rules for float exceptions or special themeing for certain applications --
-------------------------------------------------------------------------------------------------

-- Awesome Libs
local awful = require("awful")
local beautiful = require("beautiful")
local ruled = require("ruled")

awful.rules.rules = {
  {
    rule = {},
    properties = {
      border_width = beautiful.border_width,
      border_color = beautiful.border_normal,
      focus        = awful.client.focus.filter,
      raise        = true,
      keys         = require("../../mappings/client_keys"),
      buttons      = require("../../mappings/client_buttons"),
      screen       = awful.screen.preferred,
      placement    = awful.placement.no_overlap + awful.placement.no_offscreen
    }
  },
  {
    rule_any = {
      instance = {},
      class = {
        "Arandr",
        "Lxappearance",
        "kdeconnect.app",
        "zoom",
        "file-roller",
        "File-roller"
      },
      name = {},
      role = {
        "AlarmWindow",
        "ConfigManager",
        "pop-up"
      }
    },
    properties = { floating = true, titlebars_enabled = true }
  },
  {
    id = "titlebar",
    rule_any = {
      type = { "normal", "dialog", "modal", "utility" }
    },
    properties = { titlebars_enabled = true }
  }
}

awful.spawn.easy_async_with_shell(
  "cat ~/.config/awesome/src/assets/rules.txt",
  function(stdout)
    -- rules.txt = nomes de classe separados por ';' numa única linha (file-as-source-of-truth).
    -- Split por ';' (tolera espaço/newline) e match EXATO da classe: anchored + escapado.
    -- Assim um token-lixo/parcial (ex: fragmento de URL colada) NÃO casa por substring
    -- e não flutua a janela errada (correção da bug-family rules.txt). Preserva nomes com
    -- '.'/'-' (ex: "kdeconnect.app", "file-roller") que o antigo %a+ quebrava.
    for entry in stdout:gmatch("[^;]+") do
      local class = entry:gsub("%s+", "")
      if class ~= "" then
        local exact = "^" .. class:gsub("[%-%.%+%[%]%(%)%%%?%*%^%$]", "%%%1") .. "$"
        ruled.client.append_rule {
          rule = { class = exact },
          properties = {
            floating = true
          },
        }
      end
    end
  end
)
