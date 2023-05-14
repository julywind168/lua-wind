local wind = require "lualib.wind"
local root = require "lualib.root"



print("start")
root.start(function ()
    wind.log("----------------------------------------------------------------------------")
    wind.log("-------------------------- all worker is ready OK --------------------------")
    wind.log("----------------------------------------------------------------------------")

    root.newstate("User", {id = "1001", nick = "windy", gold = 0}, nil, "your_init_params_1")
    root.newstate("User", {id = "1002", nick = "jack", gold = 200}, nil, "your_init_params_2")
    root.exit()
end)