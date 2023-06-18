local wind = require "lualib.wind"

local Logger = {}


-- todo 
-- write to date-files
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
    local msgs = {}
    local len = select('#', ...)
    local v
    for i = 1, len do
        v = args[i]
        if type(v) == "table" then
            msgs[i] = dump(v)
        else
            msgs[i] = tostring(v)
        end
    end

    -- clean `nil` on the tail
    for i = len, 1, -1 do
        if args[i] == nil then
            msgs[i] = nil
        else
            break
        end
    end

    local text = table.concat(msgs, "  ")
    return string.format("worker[%d] %s", source, text)
end


return Logger