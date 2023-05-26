local wind = require "lualib.wind"

local Root = {}


function Root:_init()
    wind.log("Root start =====================")
end

function Root:hello(...)
    wind.log("Root.hello", ...)
    return table.concat({...})
end



return Root