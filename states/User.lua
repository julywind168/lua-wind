--[[
{
    id = 1,
    nick = "windy",
    gold = 100,
    loginc = 0
}
]]
local User = {}

function User:_init(...)
    print("User._init", dump(self), ...)
end

function User:login()
    self.loginc = self.loginc + 1
    return self
end


return User