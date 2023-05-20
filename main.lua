require "preload"
local config = require "config"
local main = require "wind.main"


print('hello world')

for i = 1, config.nworker do
    main.fork("worker.lua")
end


main.join_threads()


print("bye")