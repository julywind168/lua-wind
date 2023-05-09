local core = require "wind.core"

local wind = {
    sclass = {}
}


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





return wind