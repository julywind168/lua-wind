local wind = require "lualib.wind"


local struct = {
    logged = {},         -- uid => {}
    loginc = 0
}


local UserMgr = {}


function UserMgr:init()
    wind.log("Service user_mgr init =====================================")
    return self
end


function UserMgr:login(user)
    if not self.logged[user.id] then
        self.loginc = self.loginc + 1
    end
    self.logged[user.id] = user
end

function UserMgr:logout(uid)
    if self.logged[uid] then
        self.logged[uid] = nil
        self.loginc = self.loginc - 1
    end
end







return {UserMgr, struct}