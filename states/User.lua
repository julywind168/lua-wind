local util = require "lualib.util"

local Struct = {
    id = util.required("string"),       -- required a string
    nick = util.required("string"),     -- required a string
    gold = 0,                           -- optional a number, default 0
    loginc = 0                          -- optional a number, default 0
}


local User = {}

function User:_init(...)
    print("User._init", dump(self), ...)
end

function User:login()
    self.loginc = self.loginc + 1
    return self
end


return {User, Struct}