

local wind = require "lualib.wind"
local mongo = require "lualib.mongo"


local conf = {
    host = "127.0.0.1",
	port = 27017,
	dbname = "game",                    -- your dbname
	username = "YOUR_USERNAME",         -- your username
	password = "YOUR_PASSWORD",         -- your password
	authdb = "admin"
}


local Mongo = {}

function Mongo:__init()
    if conf.username == "YOUR_USERNAME" and conf.password == "YOUR_PASSWORD" then
        error("What is your mongodb username and password?")
    end
    local client = mongo.client(conf)
    local db = client:getDB(conf.dbname)

    local user = db.user:findOne({id = 1})

    self:log("findOne", tostring(user))

end


return Mongo