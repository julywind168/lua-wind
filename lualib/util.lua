local util = {}

-- for check State/Service struct
function util.required(valuetype)
    return function(value)
        assert(type(value) == valuetype, string.formate("invalid struct type:%s, want:%s", type(value), valuetype))
    end
end


return util