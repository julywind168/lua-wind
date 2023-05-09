local _print = print

local function print(...)
    _print("worker:", ...)
end




print("i'm a worker thread, bye")