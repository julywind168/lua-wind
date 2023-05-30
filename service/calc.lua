-- debug_console hotfix demo

local wind = require "lualib.wind"

local Calc = {}


function Calc:_init()
    self.on_strike = true
end

function Calc:add(a, b)
    if self.on_strike then
        return "please use debugconsole, try to new `calc_bugfix` service"
    end
    return a * b    -- it a bug here, should use `+`
end



return Calc