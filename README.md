# wind
A multithreading framework written for lua

    Wind 的目标是 一个跨平台的, 可用于（游戏）服务端/客户端 的 多线程运行时。
    1. 简单的底层架构
    2. 通过引入一些概念和规范来帮助开发者提高 多线程 code 体验
    3. 更高的开发效率
    4. 更少的BUG
    5. 更低的心智负担
    6. 更高的性能


## Test (only linux now)
```
    1. git clone https://github.com/HYbutterfly/wind.git
    2. cd wind/3rd/lua-5.4.6 && make linux
    3. cd wind && make
    4. ./wind main.lua
    5. 新开一个终端 nc 127.0.0.1 6666 然后输入 hello world
    6. 新开一个终端 nc 127.0.0.1 8000 打开 debugconsle
        a1. 在 debugconsle 中 输入 patch calc {bug=false} [推荐]
        a2. 也可以选择 输入 start 1 calc_bugfix
        b. 修改 calc.lua, 将 add 函数 中的 `*` 改为 `+`
        c. 在 debugconsle 中 输入 reload calc
```

## 框架设计 && 与skynet对比 && 最佳实践
```
    wind 启动时会根据配置启动 N个 worker 线程, 每个线程都拥有一个自己 luavm
    每个worker线程根据epoll事件来驱动。

    服务 service:
        我们可以在某个worker中启动一个service, service 本质上就是一个对象, 
        wind 中要求 service 的状态和方法分离(为什么? 下面解析)

    API:
    wind.newservice(worker, name, classname[opt], self[opt])
        worker:
            worker 线程ID, 比如 1, 2, ...
        name:
            每个服务都应该一个全局唯一的名字, 比如 main, logger, user_1, user_2.
            为啥不像skynet那样使用数字id呢.主要是为了简化设计, 根据示例可见,使用者完全
            可以给出合适的名字
        classname:
            这个对应 service/ 下的文件名, 省略时等于 name。
            对于单例服务来说, 通常省略, 因为 name == classname
        self:
            service 本身初始状态, 省略则 为 {}
        
    wind.call(service_name, func_name, ...)
        与 skynet 不同, call 并没有返回值, 只是简单的调用一个 服务 的某个方法

    wind.querylocal(name)
        从本地worker中查询一个 service 并返回, 这样我们可以从本地使用service,
        与 wind.call 不同的是，因为是本地调用，我们可以获得它的返回值。
        比如：
            local s = wind.querylocal("calc")
            print(s:add(1, 1))

    wind.moveto(service_name, dest_worker)
        将一个服务移动到另一个 worker 中.
        skynet 中 玩家登陆后会有个 agent 服务，来处理一些自娱自乐的逻辑，比如签到，开始匹配，等等。
        玩家匹配成功后 会有专门的 room服务 处理游戏逻辑，这时候 agent, room 通常会用到玩家的金币属性，
        我们要不时同步, 这通常很令人苦恼

        在 wind 中, 玩家一旦匹配成功, 创建了 room , 我们可以把 房间中的所有人(agent) 都移动到
        房间所在的 worker, 结合 wind.querylocal，我们可以愉快的编写 类似单线程程序的逻辑了！

    service 的 sub/pub
        service 拥有一个 _sub 表，表示自己订阅了哪些事件, 并在 service class 中 声明一个与事件名相同的回调 

        比如：订阅框架内部的 tick 事件 (1s once)

        local S = {}

        function S:_init()
            self._sub._tick_1000 = true
        end

        function S:_tick_1000()
            print("tick")
        end

        -- service 生命周期回调函数
            _init           : 被创建时调用
            _moved          : 被移动到新 worker 时调用
            _exit           : 退出时调用

        与 sub 规则一致, 只不过它们无需手动订阅，只要声明了，事件发生时就会被框架自动调用


        -- 另一种方式 使用 self:sub 请查看demo
        -- self:listen 可以开启 tcp 监听, 是对 self:sub 的使用
        -- 从这里可以看出 wind 是一个分层的架构, 通过 c 代码提供基础能力,
        -- 然后引入 worker, service 2大最基础的概念, 然后我们可以设计出更高阶的api

        self:pub(event, ...)
            发布一个事件, 这个事件将广播给所有worker中的所有service
    

    总结: wind 启动了 N个 worker, 每个 worker 线程拥有自己独立的luavm, service 是一个状态和方法分离的对象,
        它们根据需要分散在各个 worker 中，service 只能互相发送消息 或者 pub/sub 来通讯

        没有了 skynet.call 这种 api, 处理 service 之间的强交互逻辑 肯定很麻烦, 但是 wind 中可以移动 service,
        这样它们处于同一个 worker 中，它们将非常愉快～

```