local wind = require "lualib.wind"

local Benchmark = {}


function Benchmark:_init()
    
end

function Benchmark:start(times)
    self.count = 0
    self.times = times or 10000
    self.start_time = wind.time()
    self:log("start =====================", times)
    wind.call("main", "ping", self._name)
end

function Benchmark:pong()
    self.count = self.count + 1
    if self.count == self.times then
        self:log(string.format("ping-pong %d times, use time:%dms", self.count, wind.time() - self.start_time))
    else
        wind.call("main", "ping", self._name)
    end
end



return Benchmark