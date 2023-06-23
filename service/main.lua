--[[
    服务生命周期回调
    __init           : 被创建时调用
    __moved          : 被移动到新worker时调用
    __exit           : 退出时调用
]]

local wind = require "lualib.wind"


local Main = {}

function Main:__init()
    self:log("start")

    self:http_get("https://api.vvhan.com/api/joke", {token = "TOKEN"}, function (r)
        self:log("response:", r)
    end)
end


function Main:__tick_1000()
    self:log("Tick")
end


return Main