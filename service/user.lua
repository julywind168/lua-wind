local wind = require "lualib.wind"

local User = {}


function User:_init()
    wind.log("User start =====================", self._name)
end

function User:hello(...)
end



return User