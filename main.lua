require "preload"
local config = require "config"
local main = require "wind.main"
local wind = require "lualib.wind"


print('hello world')

for i = 1, config.nworker do
    main.fork("worker.lua")
end



-- let worker1 run main service
wind.send(1, "uniqueservice", "main")


main.join_threads()


print("bye")