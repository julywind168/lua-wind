local core = require "wind.core"
local serialize = require "wind.serialize"
local config = require "config"

local wind = {
    serviceclass = {}
}


function wind.self()
    if not wind._self then
        local id, efd = core.self()
        wind._self = {
            id = id,
            efd = efd,
        }
    end
    return wind._self
end

function wind.send(thread_id, ...)
    return core.send(thread_id, serialize.pack(...))
end

-- for main thread
function wind.uniqueservice(worker, name, ...)
    wind.send(worker, "uniqueservice", name, ...)
    for i = 1, config.nworker do
        if i ~= worker then
            wind.send(i, "uniqueservice_created", name, worker)
        end
    end
end


function wind.recv()
    local data = core.recv()
    if data then
        return serialize.unpack(data)
    end
end

wind.time = core.time


return wind