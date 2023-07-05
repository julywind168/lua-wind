local wind = require "lualib.wind"


local TestWsClient = {}

function TestWsClient:__init()
    local handle = {}

    function handle.connect()
        self:log("connected")
        self._sub.tick_1000 = true
    end

    function handle.message(msg)
        self:log("message", msg:trim())
    end

    function handle.close(errmsg)
        self:log("closed", errmsg)
    end

    self.tick = 0
    self.ws = self:connect({protocol = "websockt", url = "ws://127.0.0.1:8888/"}, handle)
end

function TestWsClient:__tick_1000()
    self.tick = self.tick + 1

    if self.tick%3 == 0 then
        self.ws.send(string.format("hello_%d", self.tick))
    end
end


return TestWsClient