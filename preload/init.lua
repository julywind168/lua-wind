require "preload.dump"
require "preload.string"
require "preload.table"

function ENUM(t)
	for k,v in pairs(t) do
		t[v] = k
	end
	return t
end