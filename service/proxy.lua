local wind = require "lualib.wind"
local json = require "lualib.json"
local socket = require "wind.socket"

local SOCKPATH <const> = "/tmp/windproxy.sock"


local Proxy = {}


function Proxy:__init()

    local session_source = {}       -- session -> source: {name, handlename}
    local handle = {}

    function handle.message(msg)
        -- self:log("recv", msg)
        local response = json.decode(msg)
        local session = response.session
        local source = session_source[session]
        response.session = nil
        wind.call(source.name, source.handlename, response)
    end

    function handle.error(errmsg)
        self:log("connect error", errmsg)
    end

    function handle.close()
        self:log("connect closed")
    end

    local fd = self:connect({protocol = "unix", sockpath = SOCKPATH}, handle)
    if fd then
        function Proxy:request(session, name, params, source)
            session_source[session] = source
            socket.send(fd, json.encode{session, name, params})
        end
        self:log("connect success")
    end
end


return Proxy