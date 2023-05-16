-- impl for worker thread

local config = require "preload"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"

local THREAD_MAIN <const> = 0
local THREAD_LOGGER <const> = 1
local THREAD_ROOT <const> = 2

local M = {
    alive = true,
    statecache = {}
}

local CMD = {}

function CMD:_exit()
    M.alive = false
end

-- state ---------------------------------------
local function try(f, self, ...)
    if f then
        f(self, ...)
    end
end

function CMD:_newstate(classname, id, t, ...)
    local c = wind.stateclass[classname]
    assert(not M.statecache[id], string.format("state[%d] already exist", id))
    t._id = id
    setmetatable(t, {__index = c[1]})
    M.statecache[id] = t
    try(t._init, t, ...)
    return t
end

function CMD:_callstate(id, name, ...)
    local s = M.statecache[id]
    local f = s[name]
    f(s, ...)
end

function CMD:_ping()
    -- wind.log("PING ==================", self)
    wind.send(self, "_pong")
end

-- end


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

-- send ---- data ----> root -- data --> new_worker
-- move 之后 可能还会有相关的call, 转发给root 即可
function M.move(id, worker)

end


function M.start()
    wind.log("start")
    wind.send(THREAD_ROOT, "_worker_initialized")

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
    wind.log("exit")
    wind.send(THREAD_LOGGER, "_thread_exited")
end


return M