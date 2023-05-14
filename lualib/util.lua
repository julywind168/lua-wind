local util = {}

-- for check State/Service struct
function util.required(valuetype)
    return function(value)
        if type(value) ~= valuetype then
            error(string.format("invalid struct type:%s, want:%s", type(value), valuetype))
        end
    end
end


return util