local wind = require "lualib.wind"

local Logger = {}


function Logger:_init()

end

-- todo 
-- write to a singal file
function Logger:log(source, ...)
    local text = self:concat(source, ...)
    print(text)
end

-- todo 
-- write to a singal file
function Logger:error(source, ...)
    local text = self:concat(source, ...)
    print(string.format("%s%s%s", "\27[33;38;2;200;100;50m", text, "\27[0m"))
end

function Logger:concat(source, ...)
    local args = {...}
    local v
    for i = 1, select('#', ...) do
        v = args[i]
        if type(v) == "table" then
            args[i] = dump(v)
        else
            args[i] = tostring(v)
        end
    end
    local text = table.concat(args, "  ")
    return string.format("worker[%d] %s", source, text)
end


return Logger