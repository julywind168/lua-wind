local wind = require "lualib.wind"

-- wind config
local config = {
    threads = {
        {id = 1, name = "logger", filename = "logger.lua"},
        {id = 2, name = "root", filename = "root.lua"},
        {id = 3, name = "worker", filename = "worker.lua"},
        {id = 4, name = "worker", filename = "worker.lua"},
    }
}

config.nthread = #config.threads + 1  -- add main


function config.querythread(name)
    local start
    local num = 0
    for _, thread in ipairs(config.threads) do
        if thread.name == name then
            num = num + 1
            if num == 1 then
                start = thread.id
            end
        end
    end
    return start, num
end

function config.countthread(name)
    local _, num = config.querythread(name)
    return num
end

function config.threadname(id)
    if id == 0 then
        return "main"
    end
    return config.threads[id].name
end


-- load class
local state_classes = {
    "User"
}

for _, name in ipairs(state_classes) do
    wind.sclass[name] = require(string.format("states.%s", name))
end



-- hook print (only for debug, other please use wind.log)
local self = wind.self()

if config.threadname(self.id) ~= "logger" then
    local _print = print

    function print(...)
        _print(string.format("%s[%d]:", config.threadname(self.id), self.id), ...)
    end
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
        if type(t) == "string" then
            return string.format("'%s'", t)
        else
            return tostring(t)
        end
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

function table.clone( obj )
    local function _copy( t )
        if type(t) ~= 'table' then
            return t
        else
            local tmp = {}
            for k,v in pairs(t) do
                tmp[k] = _copy(v)
            end
            return tmp
        end
    end
    return _copy(obj)
end


return config