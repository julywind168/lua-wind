local wind = require "lualib.wind"
local json = require "wind.cjson"
local socket = require "wind.socket"

local SOCKPATH <const> = "/tmp/windproxy.sock"


local Proxy = {}


function Proxy:__init()

    local session_source = {}       -- session -> source: {name, handlename}
    local handle = {}

    local function split(s)
        local packs = {}
        while true do
            if #s < 2 then
                break
            end
            local sz = s:byte(1)*256 + s:byte(2)
            if #s >= sz + 2 then
                packs[#packs+1] = s:sub(3, 2+sz)
                s = s:sub(3+sz)
            else
                break
            end
        end
        return s, packs
    end

    local last = ""
    local packs

    function handle.message(msg)
        last, packs = split(last..msg)
        for _, pack in ipairs(packs) do
            -- self:log("recv", #pack, pack)
            local response = json.decode(pack)
            local session = response.session
            local source = session_source[session]
            response.session = nil
            wind.call(source.name, source.handlename, response)
        end
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
            -- self:log("send", session, name, params, source)
            if source then
                session_source[session] = source
            end
            socket.send(fd, string.pack(">s2",json.encode{session, name, params}))
        end
        self:log("connect success")
    end
end


return Proxy