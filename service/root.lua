local wind = require "lualib.wind"

local Root = {}


function Root:_init()

end

function Root:hello(...)
    return table.concat({...})
end



return Root