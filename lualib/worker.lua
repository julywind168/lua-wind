-- impl for worker thread

local config = require "preload"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"

local M = {
    alive = true
}

local CMD = {}

function CMD:_exit()
    M.alive = false
end

function CMD:_newstate(classname, t, ...)
    wind._initstate(classname, t, ...)
end


local function handle(source, cmd, ...)
    if not source then
        return true
    end
    local f = CMD[cmd]
    if f then
        f(source, ...)
    else
        print("get unknown cmd", cmd, ...)
    end
end


function M.start()
    assert(wind.is_worker(), "this impl is for root thread")

    wind.send(wind.THREAD_ROOT, "_worker_initialized")

    local efd = wind.self().efd
    while M.alive do
        eventfd.read(efd)
        while true do
            if handle(wind.recv()) then
                break
            end
        end
    end
    print("exit")
end


return M