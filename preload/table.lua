function table.clone( obj )
    local function _copy( t )
        if type(t) ~= 'table' then
            return t
        else
            local tmp = {}
            for k,v in pairs(t) do
                tmp[k] = _copy(v)
            end
            return tmp
        end
    end
    return _copy(obj)
end