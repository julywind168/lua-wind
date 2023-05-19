-- impl for worker thread

local config = require "preload"
local serialize = require "wind.serialize"
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

    -- init
    t._id = id
    t._classname = classname
    t._sub = {}
    t._parent = nil
    t._children = {}
    setmetatable(t, {__index = c[1]})
    M.statecache[id] = t
    try(t._init, t, ...)
    return t
end

function CMD:_callstate(id, name, ...)
    local s = M.statecache[id]
    if s then
        local f = s[name]
        f(s, ...)
    else
        -- direct to root
    end
end

function CMD:_movestate(id, new_worker, parent)
    wind.move(id, new_worker, parent)
end

function CMD:_newevent(name, ...)
    for _, state in pairs(M.statecache) do
        if state._sub[name] then
            local f = assert(state[name], name)
            f(state, ...)
        end
    end
end


local function join(t, parent)
    table.insert(parent._children, t._id)
    t._parent = parent._id
    try(parent._joined, parent, t)
end


-- state move done
function CMD:_state_moved(id, data, old_worker, parent_id)
    local t = serialize.unpack(data)
    local c = wind.stateclass[t._classname]
    assert(not M.statecache[id], string.format("state[%d] already exist", id))

    setmetatable(t, {__index = c[1]})
    M.statecache[id] = t
    try(t._moved, t, old_worker)

    if parent_id then
        local parent = assert(M.statecache[parent_id], string.format("parent state[%d] not found", parent_id))
        join(t, parent)
    end
    return t
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

function wind.newstate(...)
    wind.send(THREAD_ROOT, "_newstate", ...)
end

-- send ---- data ----> root -- data --> new_worker
-- move 之后 可能还会有相关的call, 转发给root 即可
function wind.move(id, new_worker, parent_id)
    local t = M.statecache[id]
    local parent = parent_id and M.statecache[parent_id]
    if t then
        if parent then      -- all in this thread
            join(t, parent)
        else
            local data = serialize.pack(t)
            wind.send(THREAD_ROOT, "_movestate", id, data, new_worker, wind.self().id, parent_id)
            M.statecache[id] = nil
        end
    else
        wind.send(THREAD_ROOT, "_call_movestate", id, new_worker, parent_id)
    end
end

function wind.moveto(id, parent_id)
    wind.move(id, -1, parent_id)
end

-- call service
function wind.call(name, ...)
    wind.send(THREAD_ROOT, "_callservice", name, ...)
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