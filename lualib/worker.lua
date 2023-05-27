local epoll = require "wind.epoll"
local timerfd = require "wind.timerfd"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"
local config = require "config"

local function try(f, ...)
    if f then
        return f(...)
    end
end


local M = {
    alive = true,
    service = {},               -- id => service
    service_worker = {},        -- name => worker
    class_cache = {},
}


local CMD = {}

function CMD.sync_service_worker(name, worker)
    M.service_worker[name] = worker
end

function CMD.newservice(name, ...)
    M._newservice(name, ...)
end

function CMD.callservice(...)
    M._callservice(...)
end

function CMD.moveto(name, dest)
    local s = M.service[name]
    if dest == wind.self().id then
        try(s._moved, s)
    else
        wind.send(dest, "move_arrived", name, s)
        M.service_worker[name] = dest
        for i = 1, config.nworker do
            if i ~= wind.self().id and i ~= dest then
                wind.send(i, "sync_service_worker", name, dest)
            end
        end
    end
end

function CMD.move_arrived(name, s)
    M._newservice(name, s._class, s, true)
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


function M._send2other(...)
    for i = 1, config.nworker do
        if i ~= wind.self().id then
            wind.send(i, ...)
        end
    end
end


function M._require_class(name)
    if not M.class_cache[name] then
        local class = require(string.format("service.%s", name))

        if not class.log then
            function class:log(...)
                wind.log(self._name..":", ...)
            end
        end

        if not class.error then
            function class:error(...)
                wind.error(self._name..":", ...)
            end
        end

        M.class_cache[name] = class
    end
    return M.class_cache[name]
end


function M._newservice(name, classname, s, is_move)
    if M.service[name] then
        return M.service[name]
    end
    if type(classname) ~= "string" then
        classname = name
    end
    local mt = M._require_class(classname)
    local service = s or {}

    service._name = name
    service._class = classname
    service._sub = service._sub or {}

    setmetatable(service, {__index = mt})

    M.service[name] = service
    M.service_worker[name] = wind.self().id

    try(is_move and service._moved or service._init, service)
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
            wind.send(i, "sync_service_worker", name, worker)
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

function wind.moveto(name, dest)
    local source = assert(M.service_worker[name], name)
    if source == dest then
        -- arrived
        if source == wind.self().id then
            local s = M.service[name]
            try(s._moved, s)
        else
            wind.send(source, "moveto", name, dest)
        end
    else
        wind.send(source, "moveto", name, dest)
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