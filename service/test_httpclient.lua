local TestHttpClient = {}


function TestHttpClient:__init()
    -- test http.get
    self:fetch("https://api.vvhan.com/api/joke", function (r)
        self:log("get response:", r.body)
    end)

    -- test http.post
    self:fetch(
        "https://jsonplaceholder.typicode.com/posts",
        {
            method = "POST",
            body = {useId = 1, nick = "windy"}
        },
        function (r)
            self:log("post response:", r.body)
        end
    )
end


return TestHttpClient