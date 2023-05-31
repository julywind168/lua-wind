-- debug_console hotfix demo

local wind = require "lualib.wind"

local Calc = {}


function Calc:_init()
    self.bug = true
end

function Calc:add(a, b)
    if self.bug then
        return "try connect debug_console, input `patch calc {bug=false}`"
    end
    return a * b    -- it a bug here, should use `+`
end



return Calc