-- impl for logger thread
local config = require "preload"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"

local M = {
    alive = true
}

local CMD = {}

local exited = 0

function CMD:_thread_exited()
    exited = exited + 1
    if exited == config.countthread("root") + config.countthread("worker") then
        M.alive = false
    end
end

local function _log(id, ...)
    print(string.format("LOG %s[%d]:", config.threadname(id), id), ...)
end

local function _error(id, ...)
    print(string.format("ERR %s[%d]:", config.threadname(id), id), ...)
end


function CMD:_log(...)
    _log(self, ...)
end

function CMD:_error(...)
    _error(self, ...)
end

function M.log(...)
    _log(wind.self().id, ...)
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
    M.log("start")
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
    M.log("exit")
end


return M