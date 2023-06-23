local config = {
    nworker = 2,
    tick = 1000,            -- 1000ms
    logservice = "logger",
    proxyservice = "proxy",

    -- The frontmost service is the last to close when wind shutdown
    delay_close_sequence = ENUM{
        "logger",
        "proxy"
    }
}





return config