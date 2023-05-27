local wind = require "lualib.wind"

local Logger = {}


function Logger:_init()

end

-- todo 
-- write to a singal file
function Logger:log(source, ...)
    local params = {...}
    for i, v in ipairs(params) do
        if type(v) == "table" then
            params[i] = dump(v)
        else
            params[i] = tostring(v)
        end
    end
    local text = table.concat(params, "  ")
    print(string.format("worker[%d] %s", source, text))
end

-- todo 
-- write to a singal file
function Logger:error(source, ...)
    self:log(source, ...)
end



return Logger