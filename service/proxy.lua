local wind = require "lualib.wind"
local socket = require "wind.socket"

local SOCKPATH <const> = "/tmp/windproxy.sock"


local Proxy = {}


function Proxy:__init()
    local handle = {}

    function handle.message(msg)
        self:log("recv", msg)
    end

    function handle.error(errmsg)
        self:log("connect error", errmsg)
    end

    function handle.close()
        self:log("connect closed")
    end

    local fd = self:connect({protocol = "unix", sockpath = SOCKPATH}, handle)
    if fd then
        socket.send(fd, "hello world")
    end
end


return Proxy