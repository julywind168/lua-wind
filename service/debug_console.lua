local wind = require "lualib.wind"
local socket = require "wind.socket"


local DebugConsole = {}


-- api start --------------------------------------------------------

-- reload a service class, or use `reload *` to reload all
function DebugConsole:reload(calssname)
    if not calssname then
        return "need a calssname"
    end
    wind.reload(calssname)
end

function DebugConsole:new(worker, name, calssname, s)
    wind.newservice(worker, name, calssname, s)
end

-- api end ----------------------------------------------------------

function DebugConsole:_init()

    local handle = {}

    function handle.connect(fd, addr)
        self:log("connect", fd, addr)
        socket.send(fd, "Welcome to wind console\n")
    end

    function handle.message(fd, msg)
        self:log("message", fd, msg:trim())

        local t = self:parse_msg(msg:trim())
        local cmd = assert(t[1])
        local f = self[cmd]
        if not f then
            socket.send(string.format("Invalid command %s\n", cmd))
            return
        end
        local r = f(self, table.unpack(t, 2)) or "done"
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


function DebugConsole:parse_msg(msg)
    local t = msg:split(" ")
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



return DebugConsole