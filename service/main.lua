--[[
    服务生命周期回调
    __init           : 被创建时调用
    __moved          : 被移动到新worker时调用
    __exit           : 退出时调用
]]

local wind = require "lualib.wind"


local Main = {}

function Main:__init()
    -- sub example
    -- self._sub.tick_1000 = true

    -- proxy
    wind.newservice(1, "proxy")

    -- move example
    wind.newservice(1, "user_1", "user", {room = "room_1"})
    wind.newservice(2, "user_2", "user", {room = "room_1"})
    wind.newservice(math.random(1, 2), "room_1", "room", {players = {"user_1", "user_2"}})

    -- tcp
    wind.newservice(1, "gate")
    wind.newservice(1, "debug_console")
end


function Main:__tick_1000()
    self:log("Tick")
end


return Main