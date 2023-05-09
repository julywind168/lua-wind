local main = require "wind.main"

local _print = print

local function print(...)
    _print("main:", ...)
end


-- test
print('hello world')

local root = main.fork("root.lua")
local worker = main.fork("worker.lua")

print("root:", root, "worker:", worker)

main.join_threads()

print("bye")