-- impl for root thread

local config = require "preload"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"
local root = require "wind.root"

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


local function turn_worker_alloter()
    local id = 1
    return function ()
        id = id + 1
        if id > config.nthread - 1 then
            id = 2
        end
        return id
    end
end

M.worker_alloter = turn_worker_alloter()

-- thread_id sould been root or worker
function M._newstate(classname, t, thread_id, ...)
    assert(wind.sclass[classname], "not found preload class:"..tostring(classname))
    assert(t, "newstate need a pure data table")
    assert(not t.id, "state.id is reserved, it will been gen by framework")

    thread_id = thread_id or M.worker_alloter()
    assert(thread_id > 0 and thread_id < config.nthread)
    local id = root.newstate(thread_id)
    t.id = id

    if thread_id == wind.THREAD_ROOT then
        return wind._initstate(classname, t, ...)
    else
        wind.send(thread_id, "_newstate", classname, t, ...)
    end
end

-- 根据 worker_alloter 分配
function M.newstate(classname, t, ...)
    return M._newstate(classname, t, nil, ...)
end

function M.newstate2self(classname, t, ...)
    return M._newstate(classname, t, wind.THREAD_ROOT, ...)
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