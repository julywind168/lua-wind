--[[
    服务生命周期回调
    _init           : 被创建时调用
    _moved          : 被移动到新worker时调用
    _joind          : 子service加入时调用
    _exit           : 退出时调用
]]

local wind = require "lualib.wind"


local Main = {}

function Main:_init()
    print("Main start =====================")

    -- test tick
    self.count = 0
    self._sub._tick_1000 = true         -- sub `_tick_1000` event

    -- benchmark run in worker 2
    wind.uniqueservice(2, "benchmark")
    wind.call("benchmark", "start", 10*10000)

    -- local
    wind.uniqueservice(wind.self().id, "root")
    self:test_root_hello()
end

function Main:ping(from)
    wind.call(from, "pong")
end

function Main:test_root_hello()
    local root = wind.querylocal("root")
    print("Main:", root:hello("W", "O", "R", "L", "D"))

    -- try query a not local service
    -- wind.querylocal("benchmark")

end

function Main:_tick_1000()
    self.count = self.count + 1
    if self.count%5 == 0 then
        print("Main Tick", self.count)
    end
end

function Main:_exit()
end


return Main