local wind = require "lualib.wind"

--[[
{
    room: "room_1"
}
]]
local User = {}


function User:_init()
    self._sub._main_hello = true
end

function User:_moved()
    self:log("moved")
    local room = wind.querylocal(self.room)
    room:ready()
end

function User:_main_hello(...)
    self:log("main_hello", ...)
end


return User