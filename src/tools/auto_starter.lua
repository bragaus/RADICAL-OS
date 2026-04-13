local awful = require("awful")

return function(table)
  for _, t in ipairs(table) do
    awful.spawn.once(t)
  end
end
