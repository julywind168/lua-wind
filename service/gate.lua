local wind = require "lualib.wind"
local socket = require "wind.socket"


local Gate = {}


function Gate:_init()
    local listen_fd = assert(wind.listen(6666))
    self:log("listen on 6666")


    local socket_connect = string.format("socket_connect_%d", listen_fd)
    local socket_message = string.format("socket_message_%d", listen_fd)


    self:sub(socket_connect, function (_, fd, addr)
        self:log("connect", fd, addr)
    end)

    self:sub(socket_message, function (_, fd, msg)
        self:log("message", fd, string.trim(msg))
        socket.send(fd, msg)
    end)

end


return Gate