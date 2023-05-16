local wind = require "lualib.wind"
local root = require "lualib.root"

local function benchmark()
    wind.send(3, "_ping")
end


root.start(function ()
    wind.log("----------------------------------------------------------------------------")
    wind.log("-------------------------- all worker is ready OK --------------------------")
    wind.log("----------------------------------------------------------------------------")


    local user_mgr = root.uniqueservice("UserMgr"):init()
    local match_mgr = root.uniqueservice("MatchMgr"):init()



    local windy = root.newstate("User", {id = "1001", nick = "windy", gold = 0}, nil, "your_init_params_1")
    local jack = root.newstate("User", {id = "1002", nick = "jack", gold = 200}, nil, "your_init_params_2")

    root.callstate(windy, "print")

    benchmark()
    -- root.exit()
end)