local config = require "preload"
local main = require "wind.main"
local wind = require "lualib.wind"


print('hello world')

main.fork("root.lua")
for i = 1, config.nworker do
    main.fork("worker.lua")
end

main.join_threads()


print("bye")