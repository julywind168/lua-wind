local wind = require "lualib.wind"

--[[
{
    players = {uid, ...},
    nready = 0,
    status = "readying",
}
]]

local Room = {}


function Room:_init()
    self.nready = 0
    self.status = "readying"
    self:log("Room start =====================")
    for i, uid in ipairs(self.players) do
        wind.moveto(uid, wind.self().id)
    end
end

function Room:ready()
    self.nready = self.nready + 1
    if self.nready == #self.players then
        self:gamestart()
    end
end

function Room:gamestart()
    self.status = "gameing"
    self:log("Room gamestart =====================")
end



return Room