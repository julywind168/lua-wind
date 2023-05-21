--[[
    服务生命周期回调
    _init           : 被创建时调用
    _moved          : 被移动到新worker时调用
    _joind          : 子service加入时调用
    _exit           : 退出时调用
]]


local Main = {}


function Main:_init()
    print("Main start =====================")
    self._tag._tick_1000 = true         -- sub `_tick_1000` event
end

function Main:_tick_1000()
    print("Main Tick")
end

function Main:_exit()
end


return Main