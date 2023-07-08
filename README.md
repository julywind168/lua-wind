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

## ddz 分支说明
```
    这是基于 server 分支 开发的一个 简版斗地主 demo, 旨在通过一个实际案例来展示 wind框架 的使用
    client 计划将基于 svelte + flowbite 开发
```


## Thanks
[echo](https://github.com/labstack/echo)
[skynet](https://github.com/cloudwu/skynet)
[lua-mongo](https://github.com/cloudwu/lua-mongo)