local wind = require "lualib.wind"
local util = require "lualib.util"

local Struct = {
    id = util.required("string"),       -- required a string
    nick = util.required("string"),     -- required a string
    gold = 0,                           -- optional a number, default 0
    loginc = 0                          -- optional a number, default 0
}


local User = {}

function User:_init(...)
    wind.log("User._init", dump(self), ...)
    wind.call("MatchMgr", "start_match", {_id = self._id, id = self.id})
end

function User:_moved(from)
    wind.log("User._moved ===============", from)
end

function User:login()
    self.loginc = self.loginc + 1
    return self
end

function User:print()
    wind.log("User.print =============", dump(self) )
end


return {User, Struct}