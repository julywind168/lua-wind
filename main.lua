require "preload"
local config = require "config"
local main = require "wind.main"
local wind = require "lualib.wind"


print('hello world')

for i = 1, config.nworker do
    main.fork("worker.lua")
end



-- let worker 1 run main service
wind.newservice(1, "main")


main.join_threads()


print("bye")