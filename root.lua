local _print = print

local function print(...)
    _print("root:", ...)
end


print("i'm a root thread, bye")