------------------------------
-- This is the audio widget --
------------------------------

-- Awesome Libs
local awful = require("awful")
local color = require("src.theme.colors")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local wibox = require("wibox")
require("src.core.signals")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/kblayout/"
local active_keymaps = { "us", "fr", "jp" }

local xkeyboard_country_code = {
  us = { "English (United States)", "USA" },
  fr = { "Francais (France)", "FRA" },
  jp = { "Japanese", "JPN" },
}

return function(s)
  local kblayout_widget = wibox.widget {
    {
      {
        {
          {
            {
              id = "icon",
              widget = wibox.widget.imagebox,
              resize = false,
              image = gears.color.recolor_image(icondir .. "keyboard.svg", "#ff8c00")
            },
            id = "icon_layout",
            widget = wibox.container.place
          },
          top = dpi(2),
          widget = wibox.container.margin,
          id = "icon_margin"
        },
        spacing = dpi(10),
        {
          id = "label",
          align = "center",
          valign = "center",
          widget = wibox.widget.textbox
        },
        id = "kblayout_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = color["Green200"],
    fg = color["#ff8c00"],
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  local function get_kblayout()
    awful.spawn.easy_async_with_shell(
      [[ setxkbmap -query | grep layout | awk '{print $2}' ]],
      function(stdout)
        local layout = stdout:gsub("\n", "")
        kblayout_widget.container.kblayout_layout.label.text = layout
        awesome.emit_signal("update::background:kblayout")
      end
    )
  end

  local function create_kb_layout_item(keymap)
    local keymap_meta = xkeyboard_country_code[keymap] or { keymap:upper(), keymap:upper() }
    local longname = keymap_meta[1]
    local shortname = keymap_meta[2]

    local kb_layout_item = wibox.widget {
      {
        {
          -- Short name e.g. GER, ENG, RUS
          {
            {
              text = shortname,
              widget = wibox.widget.textbox,
              font = user_vars.font.extrabold,
              id = "shortname"
            },
            fg = color["Red200"],
            widget = wibox.container.background,
            id = "background2"
          },
          {
            {
              text = longname,
              widget = wibox.widget.textbox,
              font = user_vars.font.bold,
              id = "longname",
            },
            fg = color["Purple200"],
            widget = wibox.container.background,
            id = "background1"
          },
          spacing = dpi(15),
          layout = wibox.layout.fixed.horizontal,
          id = "container"
        },
        margins = dpi(10),
        widget = wibox.container.margin,
        id = "margin"
      },
      shape = function(cr, width, height)
        gears.shape.rounded_rect(cr, width, height, 8)
      end,
      bg = color["Grey800"],
      fg = color["White"],
      widget = wibox.container.background,
      id = "background",
      keymap = keymap
    }

    -- TODO: Hover effects, this is more pain than I'm willing to take for now
    awesome.connect_signal(
      "update::background:kblayout",
      function()
        awful.spawn.easy_async_with_shell(
          [[ setxkbmap -query | grep layout | awk '{print $2}' ]],
          function(stdout)
            local layout = stdout:gsub("\n", "")
            if kb_layout_item.keymap == layout then
              kb_layout_item.bg = color["DeepPurple200"]
              kb_layout_item:get_children_by_id("background2")[1].fg = "#ff8c00"
              kb_layout_item:get_children_by_id("background1")[1].fg = "#ff8c00" 
            else
              kb_layout_item.bg = color["Grey800"]
              kb_layout_item:get_children_by_id("background2")[1].fg = color["Red200"]
              kb_layout_item:get_children_by_id("background1")[1].fg = color["Purple200"]
            end
          end
        )
      end
    )

    get_kblayout()

    kb_layout_item:connect_signal(
      "button::press",
      function()
        awful.spawn.easy_async_with_shell(
          "setxkbmap " .. keymap,
          function()
            awesome.emit_signal("kblayout::hide:kbmenu")
            mousegrabber.stop()
            get_kblayout()
          end
        )
      end
    )
    return kb_layout_item
  end

  local function get_kblist()
    local kb_layout_items = {
      layout = wibox.layout.fixed.vertical,
      spacing = dpi(10)
    }
    for i, keymap in ipairs(active_keymaps) do
      kb_layout_items[i] = create_kb_layout_item(keymap)
    end
    local cont = {
      {
        kb_layout_items,
        margins = dpi(10),
        widget = wibox.container.margin
      },
      layout = wibox.layout.fixed.vertical,
    }
    return cont
  end

  local kb_menu_widget = awful.popup {
    screen = s,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 12)
    end,
    widget = wibox.container.background,
    bg = color["Grey900"],
    fg = color["White"],
    border_width = dpi(4),
    border_color = color["Grey800"],
    width = dpi(100),
    max_height = dpi(600),
    visible = false,
    ontop = true,
    placement = function(c) awful.placement.align(c, { position = "top_right", margins = { right = dpi(255), top = dpi(60) } }) end
  }

  kb_menu_widget:connect_signal(
    "mouse::leave",
    function()
      mousegrabber.run(
        function()
          kblayout_widget.bg = color["Green200"]
          awesome.emit_signal("kblayout::hide:kbmenu")
          mousegrabber.stop()
          return true
        end,
        "arrow"
      )
    end
  )

  kb_menu_widget:connect_signal(
    "mouse::enter",
    function()
      mousegrabber.stop()
    end
  )

  kb_menu_widget:setup(
    get_kblist()
  )

  local function toggle_kb_layout()
    awful.spawn.easy_async_with_shell(
      "setxkbmap -query | grep layout: | awk '{print $2}'",
      function(stdout)
        for j, n in ipairs(active_keymaps) do
          if stdout:match(n) then
            if j == #active_keymaps then
              awful.spawn.easy_async_with_shell(
                "setxkbmap " .. active_keymaps[1],
                function()
                  get_kblayout()
                end
              )
            else
              awful.spawn.easy_async_with_shell(
                "setxkbmap " .. active_keymaps[j + 1],
                function()
                  get_kblayout()
                end
              )
            end
          end
        end
      end
    )
  end

  awesome.connect_signal(
    "kblayout::toggle",
    function()
      toggle_kb_layout()
    end
  )

  -- Signals
  Hover_signal(kblayout_widget, color["Green200"], "#ff8c00")

  local kblayout_keygrabber = awful.keygrabber {
    autostart = false,
    stop_event = 'release',
    keypressed_callback = function(self, mod, key, command)
      awesome.emit_signal("kblayout::hide:kbmenu")
      mousegrabber.stop()
    end
  }

  kblayout_widget:connect_signal(
    "button::press",
    function()
      mousegrabber.stop()
      if kb_menu_widget.visible then
        kb_menu_widget.visible = false
        kblayout_keygrabber:stop()
      else
        kb_menu_widget.visible = true
        kblayout_keygrabber:start()
      end
    end
  )

  awesome.connect_signal(
    "kblayout::hide:kbmenu",
    function()
      kb_menu_widget.visible = false
      kblayout_keygrabber:stop()
    end
  )

  awful.spawn.easy_async_with_shell(
    "setxkbmap " .. active_keymaps[1],
    function()
      get_kblayout()
    end
  )
  kb_menu_widget.visible = false
  return kblayout_widget
end
