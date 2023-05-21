local epoll = require "wind.epoll"
local timerfd = require "wind.timerfd"
local eventfd = require "wind.eventfd"
local wind = require "lualib.wind"
local config = require "config"


local M = {
    alive = true,
    service = {},               -- id => service
    unique_worker = {},         -- name => worker
}


local CMD = {}

function CMD.uniqueservice_initialized(name, worker)
    M.unique_worker[name] = worker
end

function CMD.uniqueservice(name, ...)
    M._uniqueservice(name, ...)
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
        if service._tag[name] then
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


function M._uniqueservice(name, s, ...)
    if M.service[name] then
        return M.service[name]
    end
    local mt = require(string.format("service.unique.%s", name))
    local service = s or {}

    service._tag = service._tag or {}

    setmetatable(service, {__index = mt})
    try(service._init, service, ...)

    M.service[name] = service
    M.unique_worker[name] = wind.self().id
    M._send2other("uniqueservice_initialized", name, wind.self().id)
    return service
end

-- attach wind api
function wind.uniqueservice(worker, ...)
    if worker == wind.self().id then
        return M._uniqueservice(...)
    else
        wind.send(worker, "uniqueservice", ...)
    end
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