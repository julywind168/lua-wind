local config = require "preload"
local main = require "wind.main"


print('hello world')

for _, thread in ipairs(config.threads) do
    main.fork(thread.filename)
end


main.join_threads()


print("bye")