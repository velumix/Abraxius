local Signal = {} 
local SignalMT = {__index=Signal}


function Signal.new()
	local self = setmetatable({}, SignalMT)  
	self.Connections = {}
	
	return self 
end

function Signal:Wait() 
	local __Thread = coroutine.running() 
	self:Once(function() 
		task.defer(__Thread)
	end) 
	coroutine.yield()
end

function Signal:Once(F) 
	local Connection  
	Connection = self:Connect(function() 
		F() 
		Connection:Disconnect()
	end)
end

function Signal:DisconnectAll() 
	for _,Connection in self.Connections do 
		Connection:Disconnect() 
	end
end

function Signal:Connect(F)
	local Connection = {{}}
	Connection.Connected = true
	Connection.Disconnect = function()
		self.Connections[Connection[1]] = nil
		Connection.Connected = false
	end

	self.Connections[Connection[1]] = F

	return Connection
end

function Signal:Fire(...) 
	for _,Function in pairs(self.Connections) do
		task.defer(Function, ...)
	end
end

function Signal:FireImmediate(...) 
	for _,Function in pairs(self.Connections) do
		task.spawn(Function, ...)
	end
end

return Signal 