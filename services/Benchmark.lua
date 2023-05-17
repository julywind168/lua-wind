local wind = require "lualib.wind"


local struct = {
    count = 0
}


local Benchmark = {}


function Benchmark:start(state, times)
    self.target = state
    self.starttime = wind.time()
    self.testtimes = times or 10000
    wind.call(self.target, "ping")
end

function Benchmark:pong()
    self.count = self.count + 1
    if self.count == self.testtimes then
        wind.log(string.format("Benchmark ping-pong %d times, use time:%dms", self.count, wind.time() - self.starttime))
        wind.exit()
    else
        wind.call(self.target, "ping")
    end
end



return {Benchmark, struct}