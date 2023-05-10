local core = require "wind.core"
local serialize = require "wind.serialize"


local wind = {
    THREAD_MAIN = 0,
    THREAD_ROOT = 1,
    sclass = {}
}

function wind.nthread()
    if not wind._nthread then
        wind._nthread = core.nthread()
    end
    return wind._nthread
end

function wind.nworker()
    return wind.nthread() - 2
end

function wind.self()
    if not wind._self then
        local id, efd, epollfd = core.self()

        local name = "main"
        if id == 1 then
            name = "root"
        elseif id >= 2 then
            name = "worker"
        end

        wind._self = {
            id = id,
            name = name,
            efd = efd,
            epollfd = epollfd
        }
    end
    return wind._self
end

function wind.is_main()
    return wind.self().id == wind.THREAD_MAIN
end


function wind.is_root()
    return wind.self().id == wind.THREAD_ROOT
end


function wind.is_worker()
    return wind.self().id > wind.THREAD_ROOT
end


function wind.send(thread_id, ...)
    print("send", thread_id, ...)
    return core.send(thread_id, serialize.pack(wind.self().id, ...))
end

function wind.send2workers(...)
    for i = 2, 2 + wind.nworker()-1 do
        wind.send(i, ...)
    end
end


function wind.recv()
    local data = core.recv()
    if data then
        return serialize.unpack(data)
    end
end


return wind