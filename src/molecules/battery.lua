--------------------------------
-- This is the battery widget --
--------------------------------
-- Awesome Libs
local awful = require("awful")
local color = require("src.theme.colors")
local p = require("src.theme.palette")
local dpi = require("beautiful").xresources.apply_dpi
local gears = require("gears")
local naughty = require("naughty")
local watch = awful.widget.watch
local wibox = require("wibox")
require("src.core.signals")

-- Icon directory path
local icondir = awful.util.getdir("config") .. "src/assets/icons/battery/"

-- Returns the battery widget
return function()
  local battery_widget = wibox.widget {
    {
      {
        {
          {
            visible = false,
            align = 'center',
            valign = 'center',
            id = "charging_indicator",
            widget = wibox.widget.textbox
          },
        spacing = dpi(6),
        {
          align = 'center',
          valign = 'center',
          id = "label",
          widget = wibox.widget.textbox
        },
        id = "battery_layout",
        layout = wibox.layout.fixed.horizontal
      },
      id = "container",
      left = dpi(8),
      right = dpi(8),
      widget = wibox.container.margin
    },
    bg = p.panel,
    fg = p.text_bright,
    shape = function(cr, width, height)
      gears.shape.rounded_rect(cr, width, height, 5)
    end,
    widget = wibox.container.background
  }

  local battery_tooltip = awful.tooltip {
    objects = { battery_widget },
    text = "",
    mode = "inside",
    preferred_alignments = "middle",
    margins = dpi(10)
  }

  local get_battery_info = function()
    awful.spawn.easy_async_with_shell(
      [[ upower -i $(upower -e | grep BAT) | grep "time to " ]],
      function(stdout)
        if stdout == nil or stdout == '' then
          battery_tooltip:set_text('No Battery Found')
          return
        end
        local rem_time = ""
        if stdout:match("hour") then
          rem_time = "Hours"
        else
          rem_time = "Minutes"
        end
        local bat_time = stdout:match("%d+,%d") or stdout:match("%d+.%d") or ""
        if stdout:match("empty") then
          battery_tooltip:set_text("Remaining battery time: " .. bat_time .. " " .. rem_time)
        elseif stdout:match("time to full") then
          battery_tooltip:set_text("Battery fully charged in: " .. bat_time .. " " .. rem_time)
        end
      end
    )
  end
  get_battery_info()

  local last_battery_check = os.time()
  local notify_critical_battery = true


  local set_battery_text = function(text, text_color, charging)
    local battery_layout = battery_widget.container.battery_layout
    battery_layout.label:set_markup('<span foreground="' .. text_color .. '⚡' .. text .. '%</span>')

  local set_battery_icon = function(icon_name, icon_color)
    battery_widget.container.battery_layout.icon_margin.icon_layout.icon:set_image(gears.surface.load_uncached(
      gears.color.recolor_image(icondir .. icon_name .. '.svg', icon_color)
    ))
  end

  local battery_warning = function()
    naughty.notification {
      icon = gears.color.recolor_image(icondir .. "battery-alert.svg", p.text_bright),
      app_name = "System notification",
      title = "Battery is low",
      message = "Battery is almost empty",
      urgency = "critical"
    }
  end

   local battery_colors = {
    charged = p.v500,
    charging = p.v500,
    discharging = p.v700,
    critical = p.crit,
    unavailable = p.text_faint
  }

  local set_battery_icon = function(icon_name, icon_color)
    battery_widget.container.battery_layout.icon_margin.icon_layout.icon:set_image(gears.surface.load_uncached(
      gears.color.recolor_image(icondir .. icon_name .. '.svg', icon_color)
    ))
  end

  local update_battery = function(status)
    awful.spawn.easy_async_with_shell(
      [[sh -c "upower -i $(upower -e | grep BAT) | grep percentage | awk '{print \$2}' |tr -d '\n%'"]],
      function(stdout)
        local battery_percentage = tonumber(stdout)

        if not battery_percentage then
          return
        end

          local normalized_status = status
        if normalized_status == 'pending-charge' then
          normalized_status = 'charging'
        elseif normalized_status == 'pending-discharge' then
          normalized_status = 'discharging'
        end

        --battery_widget.container.battery_layout.spacing = dpi(5)
        --battery_widget.container.battery_layout.label.visible = true
        --battery_widget.container.battery_layout.label:set_text(battery_percentage .. '% ')

        local normalized_status = status
        if normalized_status == 'pending-charge' then
          normalized_status = 'charging'
        elseif normalized_status == 'pending-discharge' then
          normalized_status = 'discharging'
        end

        battery_widget.container.battery_layout.spacing = dpi(6)

        if normalized_status == 'fully-charged' then
          notify_critical_battery = true
          set_battery_text(battery_percentage, battery_colors.charged, true)
          return
        end
 
        if status == 'charging' then
          set_battery_icon('battery-charging', battery_colors.charging)
              return
        end
       
        if battery_percentage <= 10 and status == 'discharging' then
          icon = icon .. '-' .. 'alert'
          if (os.difftime(os.time(), last_battery_check) > 300 or notify_critical_battery) then
            last_battery_check = os.time()
            notify_critical_battery = false
            battery_warning()
          end
          --battery_widget.container.battery_layout.icon_margin.icon_layout.icon:set_image(gears.surface.load_uncached(
            --gears.color.recolor_image(icondir .. icon .. '.svg', p.v500)))
            i--set_battery_icon(icon, battery_colors.critical)
            set_battery_text(battery_percentage, battery_colors.critical, false)
          return
        end

        notify_critical_battery = true

--[[
         if battery_percentage > 0 and battery_percentage < 10 then
          icon = icon .. '-discharging-outline'
        elseif battery_percentage >= 10 and battery_percentage < 20 then
          icon = icon .. '-discharging-10'
        elseif battery_percentage >= 20 and battery_percentage < 30 then
          icon = icon .. '-discharging-20'
        elseif battery_percentage >= 30 and battery_percentage < 40 then
          icon = icon .. '-discharging-30'
        elseif battery_percentage >= 40 and battery_percentage < 50 then
          icon = icon .. '-discharging-40'
        elseif battery_percentage >= 50 and battery_percentage < 60 then
          icon = icon .. '-discharging-50'
        elseif battery_percentage >= 60 and battery_percentage < 70 then
          icon = icon .. '-discharging-60'
        elseif battery_percentage >= 70 and battery_percentage < 80 then
          icon = icon .. '-discharging-70'
        elseif battery_percentage >= 80 and battery_percentage < 90 then
          icon = icon .. '-discharging-80'
        elseif battery_percentage >= 90 and battery_percentage < 100 then
          icon = icon .. '-discharging-90'
        else
          icon = 'battery-outline'
        end--]]

        --battery_widget.container.battery_layout.icon_margin.icon_layout.icon:set_image(gears.surface.load_uncached(
          --gears.color.recolor_image(icondir .. icon .. '.svg', p.v500)))
        local min_opacity = 0.45
        local max_opacity = 1
        local opacity = min_opacity + ((100 - battery_percentage) / 100) * (max_opacity - min_opacity)
        local discharging_color = gears.color.change_opacity(battery_colors.discharging, opacity)

        set_battery_icon(icon, discharging_color)

      end
    )
  end

  Hover_signal(battery_widget, p.v500, p.text_bright)

  battery_widget:connect_signal(
    'button::press',
    function()
      awful.spawn("xfce4-power-manager-settings")
    end
  )

  battery_widget:connect_signal(
    "mouse::enter",
    function()
      get_battery_info()
    end
  )

  watch(
    [[sh -c "upower -i $(upower -e | grep BAT) | grep state | awk '{print \$2}' | tr -d '\n'"]],
    5,
    function(widget, stdout)
      local status = stdout:gsub('%\n', '')
      if status == nil or status == '' then
        battery_widget.container.battery_layout.spacing = dpi(0)
        battery_widget.container.battery_layout.label.visible = false
        battery_tooltip:set_text('No battery found')
                battery_widget.container.battery_layout.charging_indicator.visible = false
        battery_widget.container.battery_layout.label:set_markup('<span foreground="' .. battery_colors.unavailable .. '">N/A</span>')

        --battery_widget.container.battery_layout.icon_margin.icon_layout.icon:set_image(gears.surface.load_uncached(
          --gears.color.recolor_image(icondir .. 'battery-off' .. '.svg', p.text_faint)))
           --set_battery_icon('battery-off', battery_colors.unavailable)
      end
      update_battery(status)
    end
  )

  return battery_widget
end
