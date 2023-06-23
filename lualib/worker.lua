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


-- for worker 1
local shutdown = 0

function CMD.worker_shutdown_completed()
    shutdown = shutdown + 1
    if shutdown == config.nworker - 1 then
        M._shutdown()
    end
    return true
end

-- for worker 2+
function CMD.shutdown()
    M._shutdown()
    return true
end

function CMD.service_exited(name)
    M._clean(name)
end

function CMD.kill(name)
    M._kill(name)
end

function CMD.patch(service_name, patch)
    M._patch(service_name, patch)
end

function CMD.mpatch(classname, patch)
    M._mpatch(classname, patch)
end

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
    if dest == wind.id then
        try(s._moved, s)
    else
        wind.send(dest, "move_arrived", name, s)
        M.service[name] = nil
        M.service_worker[name] = dest
        for i = 1, config.nworker do
            if i ~= wind.id and i ~= dest then
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
        if f(...) then
            return true
        end
    else
        print("Unknown cmd", cmd, ...)
    end
end

-- CMD END
function M._logger_available()
    return M.service_worker[config.logservice]
end

function M._local_pub(name, ...)
    local handle_name = "__" .. name
    for _, service in pairs(M.service) do
        if service._sub[name] then
            local f = assert(service[handle_name], name)
            f(service, ...)
        end
    end
end


function M._send2other(...)
    for i = 1, config.nworker do
        if i ~= wind.id then
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
                getmetatable(self)["__"..eventname] = callback
            end
        end

        if not class.pub then
            function class:pub(...)
                M._local_pub( ...)
                M._send2other("pub",  ...)
            end
        end

        if not class.exit then
            function class:exit()
                wind.kill(self._name)
            end
        end

        -- headers is optional
        if not class.http_get then
            function class:http_get(url, headers, callback)
                if not callback then
                    callback = headers
                    headers = {}
                    assert(type(callback) == "function")
                end

                headers["accept"] = "*/*"

                self._session = (self._session or 0) + 1

                local handlename = "__http_get_"..self._session
                getmetatable(self)[handlename] = function (_, ...)
                    callback(...)
                    getmetatable(self)[handlename] = nil
                end

                wind.call(config.proxyservice, "request", "http_get", {url = url, headers = headers}, {name = self._name, handlename = handlename})
            end
        end

        if not class.connect then
            function class:connect(config, handle)
                config.protocol = config.protocol or "tcp"
                local fd, err

                if config.protocol == "tcp" then
                    fd, err = socket.connect(assert(config.host), assert(config.port), config.family)
                elseif config.protocol == "unix" then
                    fd, err = socket.unix_connect(assert(config.sockpath))
                end

                if err then
                    return nil, err
                end

                self:sub(string.format("socket_message_%d", fd), function (_, _, msg)
                    try(handle.message, msg)
                end)

                self:sub(string.format("socket_error_%d", fd), function (_, _, errmsg)
                    try(handle.error, errmsg)
                end)

                self:sub(string.format("socket_close_%d", fd), function ()
                    try(handle.close)
                end)

                M.fd_type[fd] = FD_TCLIENT
                epoll.register(M.epfd, fd, epoll.EPOLLIN | epoll.EPOLLET)
                return fd
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

                self:sub(string.format("socket_connect_%d", fd), function (_, client, addr)
                    try(handle.connect, client, addr)
                end)

                self:sub(string.format("socket_message_%d", fd), function (_, client, msg)
                    try(handle.message, client, msg)
                end)

                self:sub(string.format("socket_error_%d", fd), function (_, client, errmsg)
                    try(handle.error, client, errmsg)
                end)

                self:sub(string.format("socket_close_%d", fd), function (_, client)
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
    if M._logger_available() then
        wind.error(is_move and "movservice" or "newservice", name, classname, s)
    end
    if type(classname) ~= "string" then
        classname = name
    end
    M._require_class(classname)

    local service = s or {}
    service._name = name
    service._class = classname
    service._sub = service._sub or {}

    local mt = {}
    function mt.__index(_, key)
        return mt[key] or M.class_cache[classname][key]
    end
    setmetatable(service, mt)

    M.service[name] = service
    M.service_worker[name] = wind.id

    try(is_move and service.__moved or service.__init, service)
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

function M._patch(service_name, patch)
    local s = assert(M.service[service_name])
    for k, v in pairs(patch) do
        s[k] = v
    end
end

function M._mpatch(classname, patch)
    for _, s in pairs(M.service) do
        if s._class == classname then
            M._patch(s._name, patch)
        end
    end
end

function M._try_service_exit(s)
    try(s.__exit, s)
    wind.error(s._name..":", "exit")
end

function M._kill(name)
    local s = assert(M.service[name], name)
    M._try_service_exit(s)
    M._clean(name)
end

function M._clean(name)
    M.service[name] = nil
    M.service_worker[name] = nil
end

function M._shutdown()
    -- close normal services
    for _, s in pairs(M.service) do
        if not config.delay_close_sequence[s._name] then
            M._try_service_exit(s)
        end
    end
    -- close delay-close services
    for i = #config.delay_close_sequence, 1, -1 do
        local s = M.service[config.delay_close_sequence[i]]
        if s then
            M._try_service_exit(s)
        end
    end
    if wind.id ~= 1 then
        wind.send(1, "worker_shutdown_completed")
    end
    M.alive = false
end

-- attach wind api

--[[
    安全的关闭 wind 进程
    1. 关闭 worker 2 ~ worker N
    2. 关闭 worker 1
]]
function wind.shutdown()
    local myid = wind.id
    if myid == 1 then
        if config.nworker == 1 then
            M._shutdown()
        else
            M._send2other("shutdown")
        end
    else
        if config.nworker > 2 then
            for i = 2, config.nworker do
                if i ~= myid then
                    wind.send(i, "shutdown")
                end
            end
        end
        M._shutdown()
    end
end

local wind_send = wind.send

function wind.send(thread_id, ...)
    for i = 1, 5 do
        if wind_send(thread_id, ...) then
            if i > 1 then
                wind.error(string.format("warn: wind.send delay %ds, the worker[%d] maybe overload.", i - 1, thread_id))
            end
            return
        else
            if i < 5 then
                wind.sleep(1)
            else
                -- panic
                local errmsg = string.format("panic: wind.send failed, the worker[%d]'s queue maybe is full.", thread_id)
                if thread_id == 1 then  -- logger is in worker 1
                    print(errmsg)
                else
                    wind.error(errmsg)
                end
                -- todo: kill wind process
            end
        end
    end
end


function wind.newservice(worker, name, ...)
    local service
    if worker == wind.id then
        service = M._newservice(name, ...)
    else
        wind.send(worker, "newservice", name, ...)
    end
    M.service_worker[name] = worker

    for i = 1, config.nworker do
        if i ~= wind.id and i ~= worker then
            wind.send(i, "sync_service_worker", name, worker)
        end
    end
    return service
end


function wind.kill(name)
    wind.error("kill", name)
    local worker = M.service_worker[name]
    if worker then
        if worker == wind.id then
            M._kill(name)
        else
            wind.send(worker, "kill", name)
            M._clean(name)
        end
        for i = 1, config.nworker do
            if i ~= worker and i ~= wind.id then
                wind.send(i, "service_exited", name)
            end
        end
    else
        wind.error(string.format("wind.kill: service[%s] not exist", name))
    end
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
        if source == wind.id then
            local s = M.service[name]
            try(s.__moved, s)
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

function wind.patch(service_name, patch)
    if M.service[service_name] then
        M._patch(service_name, patch)
        return true
    else
        local worker = M.service_worker[service_name]
        if not worker then
            return false, string.format("service[%s] not exist", service_name)
        end
        wind.send(worker, "patch", service_name, patch)
    end
end

-- multiple patch
function wind.mpatch(classname, patch)
    M._mpatch(classname, patch)
    M._send2other("mpatch", classname, patch)
end

-- query local service
function wind.querylocal(name)
    return assert(M.service[name], string.format("Not found service[%s] in local worker", name))
end

function wind.queryworker(name)
    return M.service_worker[name]
end


function wind.log(...)
    wind.call(config.logservice, "log", wind.id, ...)
end

function wind.error(...)
    wind.call(config.logservice, "error", wind.id, ...)
end
-- attach end


function M.start()
    local epfd = assert(epoll.create())
    M.epfd = epfd
    local tfd = timerfd.create()
    timerfd.settime(tfd, config.tick)
    local efd = wind.efd
    epoll.register(epfd, efd, epoll.EPOLLIN | epoll.EPOLLET)
    epoll.register(epfd, tfd, epoll.EPOLLIN | epoll.EPOLLET)

    local tick_event = string.format("tick_%d", config.tick)

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
                        M._local_pub(string.format("socket_connect_%d", fd), client_fd, addr)
                    end
                else
                    assert(type == FD_TCLIENT)
                    local listen_fd = M.client_listener[fd] or fd -- maybe is socket.connect fd
                    local msg, err = socket.recv(fd)
                    if err then
                        if err == "closed" then
                            epoll.unregister(epfd, fd)
                            M._local_pub(string.format("socket_close_%d", listen_fd), fd)
                        else
                            M._local_pub(string.format("socket_error_%d", listen_fd), fd, err)
                        end
                    else
                        M._local_pub(string.format("socket_message_%d", listen_fd), fd, msg)
                    end
                end
            end
        end
    end

    epoll.close(epfd)
    timerfd.close(tfd)
end


return M