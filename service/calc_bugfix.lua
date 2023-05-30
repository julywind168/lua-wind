-- debug_console hotfix demo

local wind = require "lualib.wind"

local CalcBugFix = {}

--[[
    1. 先获取 calc 所处的 worker, 并将自己移动过去
    2. querylocal, 然后修改 calc 的状态
]]
function CalcBugFix:_init()
    self:moveto(wind.queryworker("calc"))
end


function CalcBugFix:_moved()
    local calc = wind.querylocal("calc")

    -- fix the bug
    calc.on_strike = false
end



return CalcBugFix