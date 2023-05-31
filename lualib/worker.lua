local epoll = require "wind.epoll"
local timerfd = require "wind.timerfd"
local eventfd = require "wind.eventfd"
local socket = require "wind.socket"
local wind = require "lualib.wind"
local config = require "config"

local function try(f, ...)
    if f then
        return f(...)
    end
end

local FD_TLISTENER <const> = 1
local FD_TCLIENT <const> = 2

local M = {
    alive = true,
    service = {},               -- id => service
    service_worker = {},        -- name => worker
    class_cache = {},

    -- network
    fd_type = {},
    client_listener = {},       -- client_fd => listen_fd
}


local CMD = {}

function CMD.reload(classname)
    M._reload(classname)
end

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

function CMD.pub(...)
    M._local_pub(...)
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

        if not class.moveto then
            function class:moveto(dest_worker)
                wind.moveto(self._name, dest_worker)
            end
        end

        if not class.log then
            function class:log(...)
                wind.log((self._name or name)..":", ...)
            end
        end

        if not class.error then
            function class:error(...)
                wind.error((self._name or name)..":", ...)
            end
        end

        if not class.sub then
            function class:sub(eventname, callback)
                self._sub[eventname] = true
                class[eventname] = callback
            end
        end

        if not class.pub then
            function class:pub(...)
                M._local_pub( ...)
                M._send2other("pub",  ...)
            end
        end

        -- tcp listen, host is optional
        if not class.listen then
            function class:listen(host, port, handle)
                assert(port)
                if not handle then
                    handle = port
                    port = host
                    host = "0.0.0.0"
                end

                local fd, err = socket.listen(host, port)
                if err then
                    return nil, err
                end

                -- register handle
                self:sub(string.format("_socket_connect_%d", fd), function (_, client, addr)
                    try(handle.connect, client, addr)
                end)

                self:sub(string.format("_socket_message_%d", fd), function (_, client, msg)
                    try(handle.message, client, msg)
                end)

                self:sub(string.format("_socket_error_%d", fd), function (_, client, errmsg)
                    try(handle.error, client, errmsg)
                end)

                self:sub(string.format("_socket_close_%d", fd), function (_, client)
                    try(handle.close, client)
                end)

                M.fd_type[fd] = FD_TLISTENER
                epoll.register(M.epfd, fd, epoll.EPOLLIN | epoll.EPOLLET)
                return fd
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

    setmetatable(service, {__index = function (_, key)
        return M.class_cache[classname][key]
    end})

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

function M._reload_one(name)
    local old = M.class_cache[name]
    if old then
        package.loaded[string.format("service.%s", name)] = nil
        M.class_cache[name] = nil
        local new = M._require_class(name)

        -- old class 可能动态添加了一些方法, 转移给new
        for k, f in pairs(old) do
            new[k] = new[k] or f
        end
    end
end

function M._reload(classname)
    classname = classname or "*"

    if classname == "*" then
        -- reload all
        for name, _ in pairs(M.class_cache) do
            M._reload_one(name)
        end
    else
        M._reload_one(classname)
    end
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

-- reload service class
function wind.reload(classname)
    M._reload(classname)
    M._send2other("reload", classname)
end

-- query local service
function wind.querylocal(name)
    return assert(M.service[name], string.format("Not found service[%s] in local worker", name))
end

function wind.queryworker(name)
    return M.service_worker[name]
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
    M.epfd = epfd
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
                eventfd.read(fd)            -- it's a optional?
                while true do
                    if handle(wind.recv()) then
                        break
                    end
                end
            elseif fd == tfd then
                timerfd.read(fd)
                M._local_pub(tick_event)
            else
                local type = M.fd_type[fd]
                if type == FD_TLISTENER then
                    -- accept
                    local client_fd, addr, err = socket.accept(fd)
                    if err then
                        wind.error("accept error", err)
                    else
                        M.fd_type[client_fd] = FD_TCLIENT
                        M.client_listener[client_fd] = fd
                        epoll.register(epfd, client_fd, epoll.EPOLLIN | epoll.EPOLLET)
                        local socket_connect = string.format("_socket_connect_%d", fd)
                        M._local_pub(socket_connect, client_fd, addr)
                    end
                else
                    assert(type == FD_TCLIENT)
                    local listen_fd = M.client_listener[fd]
                    local msg, err = socket.recv(fd)
                    if err then
                        if err == "closed" then
                            epoll.unregister(epfd, fd)
                            M._local_pub(string.format("_socket_close_%d", listen_fd), fd)
                        else
                            M._local_pub(string.format("_socket_error_%d", listen_fd), fd, err)
                        end
                    else
                        M._local_pub(string.format("_socket_message_%d", listen_fd), fd, msg)
                    end
                end
            end
        end
    end
end


return M