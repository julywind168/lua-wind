

local wind = require "lualib.wind"


local TestWsServer = {}

function TestWsServer:__init()
    local ws
    local handle = {}

    function handle.connect(id, addr)
        self:log("connect", id, addr)
    end

    function handle.message(id, msg)
        self:log("message", id, msg:trim())
        ws.send(id, msg)
    end

    function handle.close(id, errmsg)
        self:log("closed", id, errmsg)
    end

    ws = self:listen({protocol = "websockt", port = 8888}, handle)
end


return TestWsServer