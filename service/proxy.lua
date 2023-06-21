local wind = require "lualib.wind"
local socket = require "wind.socket"

local proxyaddr <const> = "/tmp/windproxy.sock"


local Proxy = {}


function Proxy:__init()
    local fd = socket.unix_connect(proxyaddr)
    self:log("connect", fd)

    socket.send(fd, "hello world")

    wind.sleep(1)

    self:log("recv ...")
    self:log(socket.recv(fd))

    socket.close(fd)
end


return Proxy