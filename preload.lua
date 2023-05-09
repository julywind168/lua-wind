local wind = require "wind"


local state_classes = {
    "User"
}

for _, name in ipairs(state_classes) do
    wind.sclass[name] = require(string.format("states.%s", name))
end