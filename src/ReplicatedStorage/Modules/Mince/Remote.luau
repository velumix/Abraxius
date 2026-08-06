
local Signal = require(script.Parent.Signal)
local Identity = require(script.Parent.Identity)
local RefMutate = require(script.Parent.RefMutate)

local Remote = {} 
Remote.__index = Remote
 
function Remote.new() 
	local ThisRemote = setmetatable({}, Remote)
	ThisRemote:__Create() 
	return ThisRemote
end

function Remote:__Create()  
	self.Event = Signal.new() 
	self.Extenders = {}  
	self.DoesExtend = false 
end

return Remote