-- impl for root thread

local config = require "preload"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"

local THREAD_MAIN <const> = 0
local THREAD_LOGGER <const> = 1
local THREAD_ROOT <const> = 2

local M = {
    alive = true
}

local CMD = {}

local ready = 0

function CMD:_worker_initialized()
    ready = ready + 1
    if ready == config.countthread('worker') then
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
-- function M._newstate(classname, t, thread_id, ...)
--     assert(wind.sclass[classname], "not found preload class:"..tostring(classname))
--     assert(t, "newstate need a pure data table")
--     assert(not t.id, "state.id is reserved, it will been gen by framework")

--     thread_id = thread_id or M.worker_alloter()
--     assert(thread_id > 0 and thread_id < config.nthread)
--     local id = root.newstate(thread_id)
--     t.id = id

--     if thread_id == wind.THREAD_ROOT then
--         return wind._initstate(classname, t, ...)
--     else
--         wind.send(thread_id, "_newstate", classname, t, ...)
--     end
-- end

-- 根据 worker_alloter 分配
-- function M.newstate(classname, t, ...)
--     return M._newstate(classname, t, nil, ...)
-- end

-- function M.newstate2self(classname, t, ...)
--     return M._newstate(classname, t, wind.THREAD_ROOT, ...)
-- end

function M.send2workers(...)
    local id, num = config.querythread('worker')
    for i = id, id+num-1 do
        wind.send(i, ...)
    end
end

function M.send2other(...)
    for _, t in ipairs(config.threads) do
        if t.id ~= THREAD_ROOT then
            wind.send(t.id, ...)
        end
    end
end


function M.exit()
    M.send2other("_exit")
    M.alive = false
end


function M.start(init)
    M._init = init

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