local wind = require "lualib.wind"
local util = require "lualib.util"

local Struct = {
    id = util.required("string"),       -- required a string
    players = {}
}

--[[
    newstate("Room", {}, {p1, p2, p3})
    moveto(p1, self)            
    moveto(p2, self)
    moveto(p3, self)

    -- p1._parent = room
    -- p2._parent = room
    -- p3._parent = room

    -- room._children = {p1, p2, p3}

]]
local Room = {}

function Room:_init(users)
    wind.log("Room._init", dump(self), users)

    for i, u in ipairs(users) do
        wind.moveto(u._id, self._id)
    end
end

function Room:_joined(user)
    wind.log("Room._joined =================", dump(user))
    if #self._children == 2 then
        self:gamestart()
    end
end

function Room:gamestart()
    wind.log("Room.gamestart =================")
end



return {Room, Struct}