local wind = require "lualib.wind"

--[[
{
    players = {uid, ...},
    nready = 0,
    status = "readying",
}
]]

local Room = {}


function Room:__init()
    self.nready = 0
    self.status = "readying"
    self:log("start")
    for i, uid in ipairs(self.players) do
        wind.moveto(uid, wind.id)
    end
end

function Room:ready()
    self.nready = self.nready + 1
    if self.nready == #self.players then
        self:_gamestart()
    end
end

function Room:_gamestart()
    self.status = "gameing"
    self:log("gamestart")
end



return Room