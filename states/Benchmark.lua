local wind = require "lualib.wind"
local util = require "lualib.util"

local Struct = {}


local Benchmark = {}



function Benchmark:ping()
    wind.call("Benchmark", "pong")
end



return {Benchmark, Struct}