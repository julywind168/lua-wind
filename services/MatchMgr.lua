local wind = require "lualib.wind"


local struct = {
    matching = {},      -- pid => p
    queue = {}          -- {p1, p2, ...}
}


local MatchMgr = {}


function MatchMgr:init()
    wind.log("Service match_mgr init ====================================")
    return self
end


function MatchMgr:_tick_1000()
    -- todo match
end


function MatchMgr:join(p)
    if not self.matching[p.id] then
        self.matching[p.id] = p
    end
    table.insert(self.queue, p)
end


return {MatchMgr, struct}