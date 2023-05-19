local wind = require "lualib.wind"


local struct = {
    matching = {},      -- pid => p
    queue = {}          -- {p1, p2, ...}
}


local MatchMgr = {}


function MatchMgr:init()
    wind.log("Service match_mgr init ====================================")
    self._sub._tick_1000 = true
    return self
end


function MatchMgr:_tick_1000()
    -- todo match
    wind.log("MatchMgr tick ===========================", wind.time())
end


function MatchMgr:start_match(p)
    if not self.matching[p.id] then
        self.matching[p.id] = p
    end
    table.insert(self.queue, p)
    if #self.queue == 2 then
        wind.newstate("Room", {id = "10001"}, nil, self.queue)
    end
end


return {MatchMgr, struct}