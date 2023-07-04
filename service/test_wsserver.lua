

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

    function handle.error(id, errmsg)
        self:log("error", id, errmsg)
    end

    function handle.close(id)
        self:log("closed", id)
    end

    ws = self:listen({protocol = "websockt", port = 8888}, handle)
end


return TestWsServer