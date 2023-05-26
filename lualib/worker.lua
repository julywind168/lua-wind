local epoll = require "wind.epoll"
local timerfd = require "wind.timerfd"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"
local config = require "config"


local M = {
    alive = true,
    service = {},               -- id => service
    service_worker = {},        -- name => worker
}


local CMD = {}

function CMD.service_created(name, worker)
    -- print(wind.self().id, "service_created", name, worker)
    M.service_worker[name] = worker
end

function CMD.newservice(name, ...)
    M._newservice(name, ...)
end

function CMD.callservice(...)
    -- print(wind.self().id, "callservice", ...)
    M._callservice(...)
end

local function handle(cmd, ...)
    if not cmd then
        return true
    end
    local f = CMD[cmd]
    if f then
        f(...)
    else
        print("Unknown cmd", cmd, ...)
    end
end

-- CMD END


function M._local_pub(name, ...)
    for _, service in pairs(M.service) do
        if service._sub[name] then
            local f = assert(service[name], name)
            f(service, ...)
        end
    end
end


local function try(f, ...)
    if f then
        return f(...)
    end
end

function M._send2other(...)
    for i = 1, config.nworker do
        if i ~= wind.self().id then
            wind.send(i, ...)
        end
    end
end


function M._newservice(name, classname, s)
    if M.service[name] then
        return M.service[name]
    end
    if type(classname) ~= "string" then
        classname = name
    end
    local mt = require(string.format("service.%s", classname))
    local service = s or {}

    service._name = name
    service._class = classname
    service._sub = service._sub or {}

    setmetatable(service, {__index = mt})
    try(service._init, service)

    M.service[name] = service
    M.service_worker[name] = wind.self().id
    return service
end

function M._callservice(service_name, name, ...)
    local s = M.service[service_name]
    local f = s[name]
    return f(s, ...)
end

-- attach wind api
function wind.newservice(worker, name, ...)
    local service
    if worker == wind.self().id then
        service = M._newservice(name, ...)
    else
        wind.send(worker, "newservice", name, ...)
    end
    M.service_worker[name] = worker

    for i = 1, config.nworker do
        if i ~= wind.self().id and i ~= worker then
            wind.send(i, "service_created", name, worker)
        end
    end
    return service
end

function wind.call(name, ...)
    local service = M.service[name]
    if service then
        M._callservice(name, ...)
        return true
    end
    local worker = M.service_worker[name]
    if worker then
        wind.send(worker, "callservice", name, ...)
        return true
    else
        error(string.format("not found service[%s]", name))
        return false
    end
end

-- query local service
function wind.querylocal(name)
    return assert(M.service[name], string.format("Not found service[%s] in local worker", name))
end


function wind.log(...)
    wind.call("logger", "log", wind.self().id, ...)
end

function wind.error(...)
    wind.call("logger", "error", wind.self().id, ...)
end

-- attach end


function M.start()
    local epfd = assert(epoll.create())
    local tfd = timerfd.create()
    timerfd.settime(tfd, config.tick)
    local efd = wind.self().efd
    epoll.register(epfd, efd, epoll.EPOLLIN | epoll.EPOLLET)
    epoll.register(epfd, tfd, epoll.EPOLLIN | epoll.EPOLLET)

    local tick_event = string.format("_tick_%d", config.tick)

    while M.alive do
        local events = epoll.wait(epfd, -1, 512)
        for fd, event in pairs(events) do
            if fd == efd then
                while true do
                    if handle(wind.recv()) then
                        break
                    end
                end
            elseif fd == tfd then
                timerfd.read(fd)
                M._local_pub(tick_event)
            end
        end
    end
end


return M