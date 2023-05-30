--[[
    服务生命周期回调
    _init           : 被创建时调用
    _moved          : 被移动到新worker时调用
    _exit           : 退出时调用
]]

local wind = require "lualib.wind"


local Main = {}

function Main:_init()
    self:log("test log", {a = 1, b = "ccccccc"})

    -- test tick
    self.count = 0
    self._sub._tick_1000 = true         -- sub `_tick_1000` event

    -- local && debug_console hotfix tutorial
    self.bug_fixed = false
    wind.newservice(wind.self().id, "calc")
    self:test_calc()

    -- multiple service && test move
    wind.newservice(1, "user_1", "user", {room = "room_1"})
    wind.newservice(2, "user_2", "user", {room = "room_1"})
    wind.newservice(math.random(1, 2), "room_1", "room", {players = {"user_1", "user_2"}})

    -- benchmark run in worker 2
    -- wind.newservice(2, "benchmark")
    -- wind.call("benchmark", "start", 10*10000)

    -- tcp
    wind.newservice(1, "gate")
    wind.newservice(1, "debug_console")

    -- test pub event
    self:pub("_main_hello", "world")
end

function Main:ping(from)
    wind.call(from, "pong")
end

function Main:test_calc()
    local calc = wind.querylocal("calc")
    local r = calc:add(3, 3)
    self:log("3 + 3 =", r)

    if r == 6 then
        self.bug_fixed = true
        wind.log("debug_console hotfix success!")
    end

    -- try query a not local service
    -- wind.querylocal("benchmark")
end

function Main:_tick_1000()
    self.count = self.count + 1
    if self.count%5 == 0 and not self.bug_fixed then
        self:test_calc()
    end
end

function Main:_exit()
end


return Main