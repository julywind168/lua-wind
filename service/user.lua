local wind = require "lualib.wind"

--[[
{
    room: "room_1"
}
]]
local User = {}


function User:__init()
end

function User:__moved()
    self:log("moved")
    wind.querylocal(self.room):ready()
end


return User