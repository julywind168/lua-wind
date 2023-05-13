local wind = require "lualib.wind"
local root = require "lualib.root"



print("start")
root.start(function ()
    wind.log("----------------------------------------------------------------------------")
    wind.log("-------------------------- all worker is ready OK --------------------------")
    wind.log("----------------------------------------------------------------------------")
    
    -- root.newstate("User", {nick = "windy", gold = 0, loginc = 0}, "your_init_params_1")
    -- root.newstate("User", {nick = "jack", gold = 200, loginc = 0}, "your_init_params_2")
    root.exit()
end)