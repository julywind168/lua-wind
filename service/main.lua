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



    wind.newservice(1, "test_wsserver")
    wind.sleep(1)
    wind.newservice(1, "test_wsclient")
end


return Main