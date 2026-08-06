-- ServerState..... aka the literal worst :3
-- It's very memory intensive, optimizations can probably be made

-- Let's play a little game, count the number of times this script says Index! :D
local HttpService = game:GetService("HttpService")

local MinceFolder = script.Parent.Parent.Parent
local StateFolder = script.Parent:WaitForChild("States")

local Signal = require(MinceFolder.Signal)
local Util = require(script.Parent.TableUtil)
local Inspect = require(MinceFolder.inspect)
local MicroId = require(MinceFolder.MicroID)
local RefMutate = require(MinceFolder.RefMutate)

local ObserverIdentifier = MicroId.gen(50)

local function IsAPlayer(Player) 
	return typeof(Player) == "Instance" and Player:IsA("Player") 
end

local StateExistence = {}

local function IsObserver(Table: any)
	local CanCall, Result = pcall(Table)
	return CanCall and Result == ObserverIdentifier
end

local function ObserveTable(Table, IndexBuilder, Proxy) -- We need to see when a table updates
	if IsObserver(Table) then return Table end
	
	local MetaTable = {}

	--print(IndexBuilder)

	MetaTable.__index = Table

	MetaTable.__newindex = function(_, Key, Value)
		local NewIndexBuilder = table.clone(IndexBuilder)
		table.insert(NewIndexBuilder, Key)
		--print(Key, type(Value), NewIndexBuilder)
		
		Table[Key] = type(Value) == 'table' and ObserveTable(Value, NewIndexBuilder, Proxy) or Value
		Proxy.Changed:Fire(NewIndexBuilder, Value)

		if Value == nil then
			Util.RecursiveRemoveIndex(NewIndexBuilder, Proxy)
		else
			Proxy.Indexes[Util.SerializeArray(NewIndexBuilder)] = IsObserver(Value) and {} or Value
		end
	end

	MetaTable.__iter = function(_)
		return pairs(Table)
	end
	
	MetaTable.__tostring = function()
		local Data = Proxy:GetRawData()
		local NewTable = {}
		for Position, Index in IndexBuilder do
			Data = Data[Index]
			if Position == #IndexBuilder then
				NewTable = Data
			end
		end
		
		return Inspect(NewTable)
	end

	MetaTable.__call = function()
		return ObserverIdentifier
	end

	return setmetatable({}, MetaTable)
end

local ServerState = {}
ServerState.__index = ServerState

function ServerState:GetState(Value)
	local MutatedIndex = RefMutate.Convert(Value)
	if StateExistence[MutatedIndex] then
		return StateExistence[MutatedIndex]
	end

	StateExistence[MutatedIndex] = ServerState.NewState(MutatedIndex)
	return StateExistence[MutatedIndex]
end

function ServerState.NewState(Index)
	local StateProxy = setmetatable({}, ServerState)
	StateProxy:__Create(Index)

	local NewState = {}

	local StateWatcherTable = {}
	function StateWatcherTable:__index(Index)
		return StateProxy.Data[Index] or StateProxy[Index]
	end

	function StateWatcherTable:__newindex(Index, Value)
		if StateProxy.Data[Index] == Value then 
			return 
		end

		local function AddTableSequentially(Table, Key, Value, IndexBuilder)
			local NewIndexBuilder = table.clone(IndexBuilder)
			table.insert(NewIndexBuilder, Key)

			if type(Value) == "table" then
				Table[Key] = ObserveTable({}, NewIndexBuilder, StateProxy)

				for subKey, subValue in pairs(Value) do
					AddTableSequentially(Table[Key], subKey, subValue, NewIndexBuilder)
				end
			else
				--print(Value, Key)
				Table[Key] = Value
			end
		end

		AddTableSequentially(StateProxy.Data, Index, Value, {})

		StateProxy.Indexes[Util.SerializeArray({ Index })] = Value
		
		if Value == nil then
			Util.RecursiveRemoveIndex({Index}, StateProxy.Indexes)
		end

		StateProxy.Changed:Fire({Index}, Value)
	end

	function StateWatcherTable:__iter()
		return pairs(StateProxy.Data)
	end
	
	function StateWatcherTable:__tostring()
		return Inspect(self:GetRawData())
	end

	function StateWatcherTable:__call(MethodToCall)
		if not StateProxy[MethodToCall] then
			error(`Attempt to call missing method {MethodToCall}`)
		end
		
		return function(...)
			return StateProxy[MethodToCall](StateProxy, ...)
		end
	end

	return setmetatable(NewState, StateWatcherTable)
end

function ServerState:__Create(RegisterIndex)
	self.HasIncludeList = false
	self.PlayersIncluded = {}
	self.RequestFunctions = {}
	self.Data = {}
	self.Indexes = {}
	self.Changed = Signal.new()

	self.RegisterIndex = RegisterIndex
	self.StateConfig = Instance.new("Configuration", StateFolder) :: Configuration
	self.StateConfig.Name = RegisterIndex

	self.RequestFunction = Instance.new("RemoteFunction", self.StateConfig)
	self.RequestFunction.Name = "Request"

	self.UpdateEvent = Instance.new("RemoteEvent", self.StateConfig)
	self.UpdateEvent.Name = "Update"

	self.Changed:Connect(function(...)
		self:__ValueChanged(...)
	end)

	self.RequestFunction.OnServerInvoke = function(Player, RequestType, ...)
		if RequestType == "Get" then
			return self:__DataRequested(Player, ...)
		elseif RequestType == "Set" then
			return self:__IndexSetRequested(Player, ...)
		end
	end
end

function ServerState:GetRawData() -- Get the raw values without any metatable jank, we do this with our index lookup table that already has all of the data
	local DataCopy = {}
	local IndexArray = {}
	
	for Index in self.Indexes do
		table.insert(IndexArray, {Util.UnserializeArray(Index), Index})
	end
		
	table.sort(IndexArray, function(IndexA, IndexB)
		return #IndexA[1] < #IndexB[1]
	end)
	
	for _, Index in ipairs(IndexArray) do
		local Path = Index[1]
		local Result = DataCopy
		local SerializedIndex = Index[2]

		if #Path > 1 then
			for Iteration, Index in ipairs(Path) do			
				if Iteration < #Path then
					if not Result[Index] then Result[Index] = {} end
					Result = Result[Index]
				else
					Result[Index] = self.Indexes[SerializedIndex]
				end
			end
		else
			Result[Path[1]] = self.Indexes[SerializedIndex]
		end
	end
	
	return DataCopy
end

function ServerState:__DataRequested(Player)
	assert(IsAPlayer(Player), "A non-player tried to get something???")

	if self.HasIncludeList and not table.find(self.PlayersIncluded, Player) then
		warn(`Player {Player} tried to access a state they have no access to!`)
		return {}
	end
	
	return self:GetRawData()
end

function ServerState:__IndexSetRequested(Player, Index, NewValue)
	Index = type(Index) == 'string' and string.split(Index, ".") or Index
	
	local IsValidPath, Issue = pcall(Util.GetPath, Index, self.Data)
	if not IsValidPath then 
		warn(`Attempt to set {table.concat(Index, ".")} in invalid place.`)
		warn(Issue)
		return nil 
	end
	
	local RequestFunction = self.RequestFunctions[Util.SerializeArray(Index)]
	
	if not RequestFunction then
		warn(`Attempt to set {table.concat(Index, ".")} but no request handler exists!`)
		return nil
	end
	
	return RequestFunction(Player, NewValue)
end

function ServerState:Destroy()
	self.StateConfig:Destroy()
	self.Changed:Destroy()
	StateExistence[self.RegisterIndex] = nil
	
	self.Indexes = nil
	setmetatable(self, nil)
end

function ServerState:RegisterSetHandler(Index, RequestFunction)
	assert(type(RequestFunction) == 'function', `Expected function got {type(RequestFunction)}`)
	Index = type(Index) == 'string' and string.split(Index, ".") or Index
	
	self.RequestFunctions[Util.SerializeArray(Index)] = RequestFunction
end

function ServerState:__ValueChanged(Index, Value)
	self.Indexes[Util.SerializeArray(Index)] = IsObserver(Value) and {} or Value

	if self.HasIncludeList then
		for _, Player in self.PlayersIncluded do
			self.UpdateEvent:FireClient(Player, Index, Value)
		end
	else
		self.UpdateEvent:FireAllClients(Index, Value)
	end
end

function ServerState:SetAudience(PlayerList)
	self.PlayersIncluded = {}
	self.HasIncludeList = true

	if not PlayerList then
		self.HasIncludeList = false
		
		return
	end

	if type(PlayerList) ~= 'table' then
		PlayerList = { PlayerList }
	end

	for _, Player in PlayerList do
		if not IsAPlayer(Player) then
			error(`ServerState:ReplicateTo[1]: Expected player got {typeof(Player)}`)
		end

		table.insert(self.PlayersIncluded, Player)
	end
end

return ServerState