local wind = require "lualib.wind"
local root = require "lualib.root"




root.start(function ()
    wind.log("----------------------------------------------------------------------------")
    wind.log("-------------------------- all worker is ready OK --------------------------")
    wind.log("----------------------------------------------------------------------------")


    local user_mgr = root.uniqueservice("UserMgr"):init()
    local match_mgr = root.uniqueservice("MatchMgr"):init()
    local benchmark = root.uniqueservice("Benchmark")



    local windy = wind.newstate("User", {id = "1001", nick = "windy", gold = 0}, nil, "your_init_params_1")
    local jack = wind.newstate("User", {id = "1002", nick = "jack", gold = 200}, nil, "your_init_params_2")


    wind.call(windy, "print")


    -- benchmark:start(root.newstate("Benchmark", {}), 10*10000)
    -- wind.exit()
end)