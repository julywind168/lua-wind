# wind
A multithreading framework written for lua

    Wind 的目标是 一个跨平台的, 可用于（游戏）服务端/客户端 的 多线程运行时。
[main](https://github.com/HYbutterfly/wind)
    wind 框架的核心功能, 未来期望是多平台运行

[server]( https://github.com/HYbutterfly/wind/tree/server )
    包含核心及服务端开发需要的功能 (http, websocket, mongodb, cjson, md5 ...) , 目标平台: linux
    
[ddz]( https://github.com/HYbutterfly/wind/tree/ddz )
    基于 server 分支 开发的 简版斗地主 demo

## Test (only linux now)
```
    1. git clone https://github.com/HYbutterfly/wind.git
    2. git checkout server
    3. cd wind/3rd/lua-5.4.6 && make linux
    4. cd wind && make
    5. cd wind/proxy && go run .
    6. ./wind main.lua
```

## Server 分支说明
    这个分支相对于 main 分支，添加了很多服务端开发必备的功能

    1. 添加了一个 独立的 golang proxy 进程, wind 框架 通过 Unix socket 与之连接, 借用 golang 的生态
        实现了 http/websocket 的正反代理, 大家也可以根据自己需求 修改 proxy 来添加更多功能！(这样做的
        前提是在lua 或 c 实现中 很难或很复杂)

    2. mongo 驱动, 这部分代码大部分来自 skynet, 其中的 socket 部分用的是 lua-mongo 中的。

    3. 还有一些 c 库, cjson md5 crypt ...


## Thanks
[echo](https://github.com/labstack/echo)
[skynet](https://github.com/cloudwu/skynet)
[lua-mongo](https://github.com/cloudwu/lua-mongo)