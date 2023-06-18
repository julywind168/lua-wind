local wind = require "lualib.wind"
local socket = require "wind.socket"


local Gate = {}


function Gate:__init()

    local handle = {}

    function handle.connect(fd, addr)
        self:log("connect", fd, addr)
    end

    function handle.message(fd, msg)
        self:log("message", fd, msg:trim())
        socket.send(fd, msg)
    end

    function handle.error(fd, errmsg)
        self:log("error", fd, errmsg)
    end

    function handle.close(fd)
        self:log("closed", fd)
    end

    self:listen(6666, handle)
    self:log("listen on 6666")
end


return Gate