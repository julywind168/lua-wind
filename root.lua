local wind = require "lualib.wind"
local root = require "lualib.root"



print("start")
root.start(function ()
    print("all worker is ready ok, to do something")
    root.exit()
end)