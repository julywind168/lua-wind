require "preload"
local config = require "config"
local main = require "wind.main"
local wind = require "lualib.wind"


for i = 1, config.nworker do
    main.fork("worker.lua")
end


wind.newservice(1, config.logservice)
wind.newservice(1, config.proxyservice)
wind.newservice(1, "main")


main.join_threads()


print("bye")