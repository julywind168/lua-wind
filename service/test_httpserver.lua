local wind = require "lualib.wind"


local TestHttpServer = {}

function TestHttpServer:__init()

    local get = {
        ["/joke"] =  function (c)
            self:fetch("https://api.vvhan.com/api/joke", function (r)
                c.response(r.body)
            end)
        end
    }

    local post = {
        ["/"] = function (c)
            return c.body
        end
    }

    self:httpserver({port = 8888}, {get = get, post = post})
end

function TestHttpServer:test_fetch()

end


return TestHttpServer