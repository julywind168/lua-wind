# wind
A multithreading framework written for lua

1. 固定线程 1:1 对应 luavm
2. state 是一个lua table (纯数据)，可以附带一个元表处自身理事件
3. Root state 作为一个服务单元
4. 每个线程有一个任务队列


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
    所有权:
        state 属于 parent state, parent state 属于 worker 线程

    move:
        state 所有权在 worker 中转移, 数据全量拷贝
    borrow (借用):
        state 可以借用给另一个线程 (worker or root) 部分拷贝, 借用期间 read-only.
        借用结束, 所有权归还原线程。如果是全量拷贝请使用 move

    区别: move 会销毁本地原数据, borrow 则会保留, 等待所有权返回
```

## 场景分析
```
案例1: 玩家a， 玩家b 在不同线程, 玩家a 想发起交易.
    应该先创建一个 trade_session state, 然后 让a, b 加入
    session = new('trade_session', {a, b})

    fn trade_session:init(parmas)
        move(parmas.a, self_thread())
        move(parmas.b, self_thread())
    end

    fn trade_session:join(p)
        table.insert(self.players, p)
        if #self.players == 2 then
            -- start trade
        end
    end

    思考: 
        a,b 万一进入失败 则要通知 trade_session 解散. 超时的问题可以再考虑

案例2：斗地主游戏中玩家，频繁点击 开始匹配/取消匹配
    这个例子中, 如果我们按照 例子1中的办法的话，创建1个 match_mgr state.
    那么所有玩家都会堆积到 和 match_mgr 同一个线程, 如果取消匹配返回原线程，又会频繁 全量拷贝。

    现在让我们换一个思路：
    1. match_mgr 是一个不那么重要的数据 (重启可丢失)，那么我们完全可以把逻辑写到 root thread 里，不必使用 state
    2. match_mgr 不会修改玩家数据，匹配逻辑也只需要玩家部分字段(金币等)
    这时候我们可以把 玩家state, borrow(借用)至 match_mgr, 匹配完成后归还即可
```