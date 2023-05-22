local wind = require "lualib.wind"

local Root = {}


function Root:_init()
    print("Root start =====================")
end

function Root:hello(...)
    print("Root.hello", ...)
    return table.concat({...})
end



return Root