local wind = require "lualib.wind"

-- wind config
local config = {
    nworker = 2
}

config.nthread = config.nworker + 2

-- load class
local state_classes = {
    "User"
}

for _, name in ipairs(state_classes) do
    wind.sclass[name] = require(string.format("states.%s", name))
end



-- hook print
local self = wind.self()


local _print = print

function print(...)
    _print(string.format("%s[%d]:", self.name, self.id), ...)
end


-- dump
local function tab_size(t)
    local sz = 0
    local k = nil
    
    while true do
        k = next(t, k)
        if k then
            sz = sz + 1
        else
            break
        end
    end
    return sz
end

local function is_array(t)
    return #t == tab_size(t)
end


local function t2line(t)
    if type(t) ~= "table" then
        return tostring(t)
    else
        if not next(t) then
            return "{}"
        end

        if is_array(t) then
            local s = "{"
            for _,v in ipairs(t) do
                s = s..t2line(v)..", "
            end
            return s:sub(1, #s-2).."}"
        else
            local s = "{"
            local count = 0
            for k,v in pairs(t) do
                count = count + 1
                -- 混合体, 数组部分
                if type(k) == "number" and k == count then
                    s = s..t2line(v)..", "
                else
                    s = s..k..":"..t2line(v)..", "
                end
            end
            return s:sub(1, #s-2).."}"
        end
    end
end


function dump(t)
    return t2line(t)
end


return config