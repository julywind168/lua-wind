-- impl for root thread

local config = require "preload"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"

local M = {
    alive = true
}

local CMD = {}

local ready = 0

function CMD:_worker_initialized()
    ready = ready + 1
    if ready == config.nworker then
        if M._init then
            M._init()
        end
    end
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


function M.exit()
    wind.send2workers("_exit")
    M.alive = false
end


function M.start(init)
    assert(wind.is_root(), "this impl is for root thread")
    M._init = init

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