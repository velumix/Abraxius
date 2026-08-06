--Clients got it easy fr

local MinceFolder = script.Parent.Parent.Parent
local StateFolder = script.Parent.States

local Signal = require(MinceFolder.Signal)
local RefMutate = require(MinceFolder.RefMutate)

local StateExistence = {}

local StateExistence = {}

local ClientState = {}
ClientState.__index = ClientState

local function Copy(t, deep)
	if not deep then
		return (table.clone(t))
	end
	local function DeepCopy(tbl)
		local tCopy = table.clone(tbl)
		for k, v in tCopy do
			if type(v) == "table" then
				tCopy[k] = DeepCopy(v)
			end
		end
		return tCopy
	end
	return DeepCopy(t)
end

local function FirstPartOfArrayMatches(Array1, Array2)
	local IsValid = true
	for i=1, #Array1 do
		if Array2[i] ~= Array1[i] then
			IsValid = false
			break
		end
	end

	return IsValid
end

function ClientState:GetState(Value)
	local MutatedIndex = RefMutate.Convert(Value)
	if StateExistence[MutatedIndex] then
		return StateExistence[MutatedIndex]
	end

	StateExistence[MutatedIndex] = ClientState.NewState(MutatedIndex)
	return StateExistence[MutatedIndex]
end

function ClientState.NewState(Index)
	local StateProxy = setmetatable({}, ClientState)
	StateProxy:__Create(Index)

	local NewState = {}

	local StateWatcherTable = {}
	function StateWatcherTable:__index(Index)
		return StateProxy.Data[Index] or StateProxy[Index]
	end

	function StateWatcherTable:__newindex(Index, Value)
		StateProxy.Data[Index] = Value
	end

	function StateWatcherTable:__iter()
		return pairs(StateProxy.Data)
	end
	
	function StateWatcherTable:__call(MethodToCall)
		return function(...)
			return StateProxy[MethodToCall](StateProxy, ...)
		end
	end

	return setmetatable(NewState, StateWatcherTable)
end

function ClientState:__Create(RegisterIndex)
	self.Observers = {}

	self.RegisterIndex = RegisterIndex
	self.StateConfig = StateFolder:FindFirstChild(RegisterIndex)
	if not self.StateConfig then
		error(`There's no server state by the name of "{RegisterIndex}".`)
	end

	self.RequestFunction = self.StateConfig:FindFirstChild("Request")
	self.UpdateEvent = self.StateConfig:FindFirstChild("Update")

	self.Data = self:RequestStateData()

	--print(self.Data)

	self.UpdateListener = self.UpdateEvent.OnClientEvent:Connect(function(...)
		self:__ValueChanged(...)
	end)
	
	self.StateConfig.Destroying:Once(function()
		self:Disconnect()
	end)
end

function ClientState:Disconnect()
	for _, Observer in self.Observers do
		Observer:Disconnect()
	end
	
	if self.UpdateListener then
		self.UpdateListener:Disconnect()
	end
end

function ClientState:RequestStateData()
	return self.RequestFunction:InvokeServer("Get")
end

function ClientState:RequestSet(Index, NewValue)
	return self.RequestFunction:InvokeServer("Set", Index, NewValue)
end

function ClientState:__ValueChanged(Index, Value)
	local Data = Copy(self.Data)
	
	local function GetPath(Path, Dir)
		local Path = Path
		local Result = Dir or Data
		
		if #Path > 1 then
			for Iteration, Index in ipairs(Path) do				
				if Iteration < #Path then
					Result = Result[Index]
				else
					return Result[Index]
				end
			end
		else
			return Data[Index]
		end
	end
	
	if GetPath(Index) == Value then return end
	
	local Path = type(Index) == 'string' and string.split(Index, '.') or Index
	local Result = self.Data

	if #Path > 1 then
		for Iteration, Index in ipairs(Path) do			
			if Iteration < #Path then
				Result = Result[Index]
			else
				Result[Index] = Value
			end
		end
	else
		Data[Index] = Value
	end
	
	if Value == nil then
		for _, Observer in self.Observers do
			if FirstPartOfArrayMatches(Index, Observer.IndexToObserve) then
				Observer.Observe(nil, Observer.OldValue)
				Observer.OldValue = nil
			end
		end
	end
	
	for _, Observer in self.Observers do
		if FirstPartOfArrayMatches(Observer.IndexToObserve, Index) then
			local Success, Value = pcall(GetPath, Observer.IndexToObserve)
			
			Value = Success and Value or nil
			
			Observer.Observe(Value, Observer.OldValue)
			Observer.OldValue = type(Value) == "table" and Copy(Value, true) or Value
		end
	end
end

function ClientState:Observe(Index, Callback)
	assert(type(Callback) == 'function', `Error while creating observer, expected function got {typeof(Callback)}`)

	local Path = type(Index) == 'string' and string.split(Index, '.') or Index
	local Data = Copy(self.Data)
	local Result = Data

	local DoesExist, Value = pcall(function()
		if #Path > 1 then
			for Iteration, Index in ipairs(Path) do
				Index = tonumber(Index) ~= nil and tonumber(Index) or Index
				
				if Iteration < #Path then
					Result = Result[Index]
				else
					return Result[Index]
				end
			end
		else
			return Data[Index]
		end
	end)

	local Observer = {
		IndexToObserve = Path,
		Observe = Callback
	}

	function Observer:Disconnect()
		table.remove(self.Observers, table.find(self.Observers, self))
	end

	if DoesExist then
		Observer.OldValue = type(Value) == "table" and Copy(Value, true) or Value
		Observer.Observe(Value)
	end

	table.insert(self.Observers, Observer)

	return Observer
end

return ClientState