-- impl for root thread

local config = require "preload"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"

local THREAD_MAIN <const> = 0
local THREAD_LOGGER <const> = 1
local THREAD_ROOT <const> = 2

local M = {
    alive = true,
    statecache = {},        -- id => worker (thread_id)
    service = {},           -- name => service
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


function CMD:_ping()
    wind.send(self, "_pong")
end

local count = 0
local t1, t2
function CMD:_pong()
    -- wind.log("PONG =====================", self)
    count = count + 1
    if count == 1 then
        t1 = wind.time()
    end

    if count == 10*10000 then
        t2 = wind.time()
        print(string.format("benchmark ping-pong %d times, use time:%dms", count, t2-t1))
        M.exit()
    else
        wind.send(self, "_ping")
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
    local start, num = config.querythread("worker")
    local id = start - 1

    return function ()
        id = id + 1
        if id > start + num - 1 then
            id = start
        end
        return id
    end
end

local function sample_stateid_alloter()
    local id = 0
    return function()
        id = id + 1
        return id
    end
end

M.worker_alloter = turn_worker_alloter()
M.stateid_alloter = sample_stateid_alloter()

-- thread_id sould been worker
function M.newstate(classname, t, thread_id, ...)
    local c = assert(wind.stateclass[classname], "not found preload class:"..tostring(classname))
    local struct = c[2]
    assert(t)
    -- check t struct
    if struct then
        for k,v in pairs(struct) do
            if type(v) == "function" then
                v(t[k])
            else
                if t[k] == nil then
                    t[k] = table.clone(v)
                else
                    assert(type(v) == type(t[k]), string.format("invalid struct key:%s, want:%s, get:%s", k, type(v), type(t[k])))
                end
            end
        end
    end

    local worker = thread_id or M.worker_alloter()
    local id = M.stateid_alloter()

    M.statecache[id] = worker

    wind.send(worker, "_newstate", classname, id, t, ...)
    return id
end

function M.uniqueservice(name, t)
    if M.service[name] then
        return M.service[name]
    end
    local c = assert(wind.serviceclass[name], "not found preload service class:"..tostring(name))
    local struct = assert(c[2])
    t = t or {}
    -- check struct
    for k,v in pairs(struct) do
        if type(v) == "function" then
            v(t[k])
        else
            if t[k] == nil then
                t[k] = table.clone(v)
            else
                assert(type(v) == type(t[k]), string.format("invalid struct key:%s, want:%s, get:%s", k, type(v), type(t[k])))
            end
        end
    end
    M.service[name] = t
    return setmetatable(t, {__index = c[1]})
end


-- send --> old_worker ---- data ----> root  -- data --> new_worker
-- send 后 可以选择创建一个queue 将后续相关call缓存起来, 避免无效投递
function M.movestate(id, worker)
    local old_worker = assert(M.statecache[id], "not found state: " ..tostring(id))
    wind.send()
end

function M.callstate(id, ...)
    local worker = assert(M.statecache[id], "not found state: " ..tostring(id))
    wind.send(worker, "_callstate", id, ...)
end


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

-- 1. exit workers && root
-- 2. exit logger
function M.exit()
    for _, t in ipairs(config.threads) do
        if t.id > THREAD_ROOT then
            wind.send(t.id, "_exit")
        end
    end
    M.alive = false
end


function M.start(init)
    wind.log("start")
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
    wind.log("exit")
    wind.send(THREAD_LOGGER, "_thread_exited")
end


return M