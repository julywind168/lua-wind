local wind = require "lualib.wind"
local json = require "lualib.json"
local socket = require "wind.socket"

local SOCKPATH <const> = "/tmp/windproxy.sock"


local Proxy = {}


function Proxy:__init()

    local session_source = {}       -- session -> source: {name, handlename}
    local handle = {}

    function handle.message(msg)
        self:log("recv", msg)
    end

    function handle.error(errmsg)
        self:log("connect error", errmsg)
    end

    function handle.close()
        self:log("connect closed")
    end

    local fd = self:connect({protocol = "unix", sockpath = SOCKPATH}, handle)
    if fd then
        local starttime = wind.time()
        local count = 0

        local function session()
            count = count + 1
            return string.format("%d_%d", starttime, count)
        end

        function Proxy:request(name, params, source)
            local s = session()
            session_source[s] = source

            socket.send(fd, json.encode{s, name, params})
        end

        self:log("connect success")
    end
end


return Proxy