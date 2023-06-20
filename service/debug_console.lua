local wind = require "lualib.wind"
local socket = require "wind.socket"


local DebugConsole = {}


-- command start --------------------------------------------------------
local CMD = {}

function CMD.shutdown()
    wind.shutdown()
end

function CMD.reload(calssname)
    wind.reload(calssname or "*")
end

function CMD.patch(service_name, patch)
    wind.patch(service_name, patch)
end

function CMD.mpatch(classname, patch)
    wind.mpatch(classname, patch)
end

function CMD.new(worker, name, calssname, s)
    wind.newservice(worker, name, calssname, s)
end

function CMD.kill(service_name)
    wind.kill(service_name)
end
-- command end ----------------------------------------------------------

function DebugConsole:__init()

    local handle = {}

    function handle.connect(fd, addr)
        self:log("connect", fd, addr)
        socket.send(fd, "Welcome to wind console\n")
    end

    function handle.message(fd, msg)
        if msg:trim() == "" then
            return
        end
        self:log("message", fd, msg:trim())
        local t = self:_parse_msg(msg:trim())
        local cmd = assert(t[1])
        local f = CMD[cmd]
        if not f then
            socket.send(fd, string.format("Invalid command %s\n", cmd))
            return
        end
        local r = f(table.unpack(t, 2)) or "done"
        socket.send(fd, r.."\n")
    end

    function handle.error(fd, errmsg)
        self:log("error", fd, errmsg)
    end

    function handle.close(fd)
        self:log("closed", fd)
    end

    self:listen(8000, handle)
    self:log("listen on 8000")
end


function DebugConsole:_parse_msg(msg)
    local t = self:_split_msg(msg)
    for i, v in ipairs(t) do
        if tonumber(v) then
            t[i] = tonumber(v)
        elseif v == "true" then
            t[i] = true
        elseif v == "false" then
            t[i] = false
        elseif v:sub(1, 1) == '{' and v:sub(#v, #v) == '}' then
            t[i] = load("return "..v)()
        end
    end
    return t
end


function DebugConsole:_split_msg(msg)
    local function count(str, token)
        return select(2, str:gsub(token, ""))
    end

    local function calc_level(token)
        return count(token, "{") - count(token, "}")
    end

    local function split(str)
        local t = str:split(" ")
        local r = {}

        local inside_table = false
        local level = 0
        local tmp

        for _, token in ipairs(t) do
            if inside_table then
                table.insert(tmp, token)
                level = level + calc_level(token)
                if level == 0 then
                    table.insert(r, table.concat(tmp, " "))
                    inside_table = false
                end
            else
                level = calc_level(token)
                if level > 0 then
                    inside_table = true
                    tmp = {token}
                else
                    assert(level == 0)
                    table.insert(r, token)
                end
            end
        end
        return r
    end

    return split(msg)
end


return DebugConsole