-- impl for logger thread
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

function CMD:_log(...)
    print(string.format("LOG %s[%d]:", config.threadname(self), self), ...)
end

function CMD:_error(...)
    print(string.format("ERR %s[%d]:", config.threadname(self), self), ...)
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
    local efd = wind.self().efd
    while M.alive do
        while true do
            if handle(wind.recv()) then
                break
            end
        end
        if M.alive then
            eventfd.read(efd)
        end
    end
end


return M