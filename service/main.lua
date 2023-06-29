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

    -- test http.get
    self:fetch("https://api.vvhan.com/api/joke", function (r)
        self:log("get response:", r.body)
    end)

    -- test http.post
    self:fetch(
        "https://jsonplaceholder.typicode.com/posts",
        {
            method = "POST",
            body = {useId = 1, nick = "windy"}
        },
        function (r)
            self:log("post response:", r.body)
        end
    )
end


return Main