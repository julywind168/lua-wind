local wind = require "lualib.wind"
local root = require "lualib.root"



print("start")
root.start(function ()
    print("----------------------------------------------------------------------------")
    print("-------------------------- all worker is ready OK --------------------------")
    print("----------------------------------------------------------------------------")
    
    root.newstate2self("User", {nick = "windy", gold = 0, loginc = 0}, "your_init_params_1")
    root.newstate("User", {nick = "tom", gold = 100, loginc = 0}, "your_init_params_2")
    root.newstate("User", {nick = "jack", gold = 200, loginc = 0}, "your_init_params_3")
    root.exit()
end)