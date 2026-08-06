local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SharedTableRegistry = game:GetService("SharedTableRegistry")

local MicroID = require(script.Parent.Parent.MicroID)

local WorkerAddon = {}
WorkerAddon.Server = {}
WorkerAddon.Client = {}

local PendingRequests = {}
local IsActorContext = false
local Identity
local ContainerParent

pcall(function()
	local Event = Instance.new("BindableEvent")
	Event.Event:ConnectParallel(function() end)
	Event:Destroy()
	IsActorContext = true
end)

local function CreateActor(Name, Id, SourceModule, SharedId, ResponseBindable)
	local NewActor = Instance.new("Actor")
	NewActor.Name = Name .. "_Worker_" .. Id

	local ModuleRef = Instance.new("ObjectValue")
	ModuleRef.Name = "SourceModule"
	ModuleRef.Value = SourceModule
	ModuleRef.Parent = NewActor

	local ResponseRef = Instance.new("ObjectValue")
	ResponseRef.Name = "ResponseBindable"
	ResponseRef.Value = ResponseBindable
	ResponseRef.Parent = NewActor

	if SharedId then
		local SharedRef = Instance.new("StringValue")
		SharedRef.Name = "SharedTableId"
		SharedRef.Value = SharedId
		SharedRef.Parent = NewActor
	end

	local RunnerTemplate = script:QueryDescendants(`Script#Runner{RunService:IsServer() and "Server" or "Client"}`)[1]
	if not RunnerTemplate then
		error("[Mince Worker] Missing Runners inside Worker Addon module.")
	end

	local Runner = RunnerTemplate:Clone()
	Runner.Parent = NewActor
	Runner.Disabled = false

	return NewActor
end

local function DefineWorker(SourceModule: ModuleScript)
	if IsActorContext then
		warn("[Mince Worker]: Worker attempted to be created while already in parallel! what da fweak!")
		return
	end

	if typeof(SourceModule) ~= "Instance" or not SourceModule:IsA("ModuleScript") then
		warn("The follow module isnt a valid modulescript!")
		error(SourceModule, 2)
	end

	local Definition = require(SourceModule)
	local Name = Definition.Name or SourceModule.Name
	local MaxPoolSize = Definition.PoolSize or 16

	local SharedData = nil
	local SharedId = nil

	if Definition.Shared then
		SharedData = SharedTable.new(Definition.Shared)
		SharedId = Name .. "_Shared_" .. MicroID.gen()
		SharedTableRegistry:SetSharedTable(SharedId, SharedData)
	end

	local Container = nil
	local IsInitialized = false

	local TotalActorsCreated = 0
	local ActiveTasks = 0

	local ResponseBindable = Instance.new("BindableEvent")

	local IdleActors = {}
	local ReadyActors = {}
	local NextWorkerIndex = 1

	local RequestQueue = {}
	local ThreadWaiters = {}

	local RequestToActorMap = {}

	local ProcessQueue 

	local function OnActorResponse(ActorInstance, RequestId, Success, ...)
		if RequestId == "WorkerReady" then
			table.insert(IdleActors, ActorInstance)
			table.insert(ReadyActors, ActorInstance)
			ProcessQueue()
			return
		end

		ActiveTasks -= 1

		RequestToActorMap[RequestId] = nil

		local Thread = PendingRequests[RequestId]
		if Thread then
			PendingRequests[RequestId] = nil
			if Success then
				task.spawn(Thread, ...)
			else
				local ErrMessage = ...
				task.spawn(Thread) 
				error(string.format("[Mince Worker Error] %s: %s", Name, tostring(ErrMessage)), 4)
			end
		end

		if ActiveTasks == 0 and #ThreadWaiters > 0 then
			for _, Waiter in ThreadWaiters do
				task.spawn(Waiter)
			end
			table.clear(ThreadWaiters)
		end

		if #RequestQueue > 0 then
			table.insert(IdleActors, ActorInstance)
			ProcessQueue()
		else
			table.insert(IdleActors, ActorInstance)
		end
	end

	local function InitializeContainer()
		if IsInitialized then return end
		IsInitialized = true

		Container = Instance.new("Folder")
		Container.Name = Name .. "_Pool"
		Container.Parent = ContainerParent

		ResponseBindable.Name = "WorkerResponse" 
		ResponseBindable.Parent = Container
		ResponseBindable.Event:Connect(OnActorResponse)
	end

	function ProcessQueue()
		if #RequestQueue == 0 then return end

		while #IdleActors > 0 and #RequestQueue > 0 do
			local ActorInstance = table.remove(IdleActors)
			local Task = table.remove(RequestQueue, 1)

			RequestToActorMap[Task.RequestId] = ActorInstance
			ActorInstance:SendMessage("Task", Task.RequestId, Task.Key, unpack(Task.Args))
		end

		if #RequestQueue == 0 then return end

		if TotalActorsCreated < MaxPoolSize then
			TotalActorsCreated += 1
			local NewIndex = TotalActorsCreated

			local ActorInstance = CreateActor(Name, NewIndex, SourceModule, SharedId, ResponseBindable)
			ActorInstance.Parent = Container

		elseif #ReadyActors > 0 then
			while #RequestQueue > 0 do
				local Task = table.remove(RequestQueue, 1)

				local ActorInstance = ReadyActors[NextWorkerIndex]
				NextWorkerIndex = (NextWorkerIndex % #ReadyActors) + 1

				RequestToActorMap[Task.RequestId] = ActorInstance
				ActorInstance:SendMessage("Task", Task.RequestId, Task.Key, unpack(Task.Args))
			end
		end
	end

	local Proxy = {}

	if SharedData then
		Proxy.Shared = SharedData
	end

	function Proxy:AwaitAll()
		if ActiveTasks > 0 then
			table.insert(ThreadWaiters, coroutine.running())
			return coroutine.yield()
		end
	end

	setmetatable(Proxy, {
		__newindex = function(k)
			warn(`Attempted to add member "{k}" onto worker! It runs in a separate vm, so you can't do this!`)
		end,

		__index = function(_, Key)
			if rawget(Proxy, Key) then
				return rawget(Proxy, Key)
			end

			return function(Self, ...)
				if not IsInitialized then InitializeContainer() end

				local RequestId = MicroID.gen()
				local CurrentThread = coroutine.running()

				PendingRequests[RequestId] = CurrentThread
				ActiveTasks += 1

				table.insert(RequestQueue, {
					RequestId = RequestId,
					Key = Key,
					Args = { ... }
				})

				ProcessQueue()

				return coroutine.yield()
			end
		end,

		__tostring = function()
			local String = `[Mince Worker] ({ActiveTasks} Active Tasks | {TotalActorsCreated}/{MaxPoolSize} Actors) \n\t\t\t\tMethods: AwaitAll`

			for Key, Value in Definition do
				if type(Value) == "function" then
					String ..= `, {Key}`
				end
			end

			if SharedData then
				String ..= `\n\t\t\t\tShared Data:`
				for Key, Value in SharedData do
					String..= ` ({Key}: {Value})`
				end
			end

			return String
		end,
	})

	return Proxy
end

function WorkerAddon.Server.Worker(Definition)
	return DefineWorker(Definition)
end

function WorkerAddon.Client.Worker(Definition)
	return DefineWorker(Definition)
end

function WorkerAddon.Identity(ThisIdentity) 
	Identity = ThisIdentity

	if IsActorContext then 
		return
	end

	ContainerParent = Instance.new("Folder", script)
	ContainerParent.Name = `{Identity}Workers`
end

return WorkerAddon