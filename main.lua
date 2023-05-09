require "preload"
local main = require "wind.main"
local wind = require "lualib.wind"




print('hello world', dump(wind.self()))

local root = main.fork("root.lua")
local worker = main.fork("worker.lua")
assert(root == 1)
assert(worker == 2)


main.join_threads()

print("bye")