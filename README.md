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
```

## Thread 功能分配
```
    1. main 主线程
        server: 负责启动 root 和 worker 线程. 最后 join_threads
        client: 负责启动 root 和 worker 线程. 随后进入渲染循环 (game engine), 最后 join_threads

    2. root 事件生产者 (单个)
        a. 创建 state 并分配至 worker
        b. 接收 外部 socket 事件
        c. 生产 timer::tick 事件

    3. worker 事件消费者 (多个)
        state 将会分配给各个worker, 处理 root 或其他 worker 产生的事件
```


## State 特性
```
    定义:
        state 是一个可序列化的 lua table (不能包含函数, userdata)，它可以附带一个元表(sclass) 来处理调用
        state 可以嵌套
        state 只能处于 woker thread
    所有权:
        state 属于 parent state, parent state 属于 worker 线程

    move:
        state 所有权在 worker 中转移, 数据全量拷贝
```

### Service
```
    定义:
        service 只能处于 root thread
    用途:
        一些中心化的服务, 比如 user_mgr, match_mgr, room_mgr
```

## state class && pubsub (事件订阅)
```lua
    --看一个 User State 的 例子, 下面是它的实例及元表(class)
    --[[
        // 下划线开头的字段 均为框架保留
        {
            id = "1001",
            nick = "wind",

            _id = 1,                // _id 保留字段 由系统生成的 state_id
            _tick_1000 = true       // 一个 tick_1000 tag, 表示该 state 订阅了 tick_1000 事件 (每1000ms 1个tick)
        }
    ]]

    local User = {}

    -- state initialized, call by framework
    function User:_init()
    end

    -- child state joined, call by framework
    function User:_join()
    end

    -- 与 tag 同名的 event handler (your define in preload)
    function User:_tick_1000()
    end
```