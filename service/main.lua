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

    -- mongo service should monopolize one worker thread
    -- wind.newservice(2, "mongo")

    wind.newservice(1, "test_httpclient")
    
    self:call("test_httpclient", "joke", function (joke)
        self:log("joke:", joke)
    end)
end


return Main