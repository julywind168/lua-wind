local wind = require "lualib.wind"

local Root = {}


function Root:_init()
    self:log("Root start =====================")
end

function Root:hello(...)
    self:log("Root.hello", ...)
    return table.concat({...})
end



return Root