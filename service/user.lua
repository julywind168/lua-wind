local wind = require "lualib.wind"

--[[
{
    room: "room_1"
}
]]
local User = {}


function User:_init()
    self:log("start =====================")
end

function User:_moved()
    self:log("moved =====================")
    local room = wind.querylocal(self.room)
    room:ready()
end

function User:hello(...)
end



return User