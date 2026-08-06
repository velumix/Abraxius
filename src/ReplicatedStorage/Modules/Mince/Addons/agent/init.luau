local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local SharedTableRegistry = game:GetService("SharedTableRegistry")

local MicroID = require(script.Parent.Parent.MicroID)

local AgentAddon = {}
AgentAddon.Server = {}
AgentAddon.Client = {}

local Identity
local ContainerParent
local IsActorContext = false

pcall(function()
	local Event = Instance.new("BindableEvent")
	Event.Event:ConnectParallel(function() end)
	Event:Destroy()
	IsActorContext = true
end)

local function CreateActor(Name, SourceModule, SharedId)
	local Id = MicroID.gen()
	local NewActor = Instance.new("Actor")
	NewActor.Name = Name .. "_Agent_" .. Id

	local ResponseBindable = Instance.new("BindableEvent")
	ResponseBindable.Name = "Response"
	ResponseBindable.Parent = NewActor

	local ModuleRef = Instance.new("ObjectValue")
	ModuleRef.Name = "SourceModule"
	ModuleRef.Value = SourceModule
	ModuleRef.Parent = NewActor

	if SharedId then
		local SharedRef = Instance.new("StringValue")
		SharedRef.Name = "SharedTableId"
		SharedRef.Value = SharedId
		SharedRef.Parent = NewActor
	end

	local RunnerTemplate = script:QueryDescendants(`Script#Runner{RunService:IsServer() and "Server" or "Client"}`)[1]
	if not RunnerTemplate then
		error("[Mince Agent]: Missing Runners inside Agent Addon module.")
	end

	local Runner = RunnerTemplate:Clone()
	Runner.Parent = NewActor
	Runner.Disabled = false

	return {
		Instance = NewActor,
		Response = ResponseBindable,
	}
end

local function DefineAgent(SourceModule)
	if IsActorContext then
		warn("[Mince Agent]: Agent attempted to be created while already in parallel! what da fweak!")
		return
	end

	if typeof(SourceModule) ~= "Instance" or not SourceModule:IsA("ModuleScript") then
		warn("The source module isnt a valid modulescript!")
		error(SourceModule, 2)
	end

	local Definition = require(SourceModule)
	local Name = Definition.Name or SourceModule.Name

	local SharedData = nil
	local SharedId = nil

	if Definition.Shared then
		SharedData = SharedTable.new(Definition.Shared)
		SharedId = Name .. "_Shared_" .. MicroID.gen()
		SharedTableRegistry:SetSharedTable(SharedId, SharedData)
	end

	local AgentClass = {}

	function AgentClass.New(...)
		local ConstructorArgs = { ... }

		local ActorData = CreateActor(Name, SourceModule, SharedId)
		local ActorInstance = ActorData.Instance
		local RecvEvent = ActorData.Response

		ActorInstance.Parent = ContainerParent

		local PendingRequests = {}
		local IsRunnerReady = false
		local IsConstructed = false
		local InitSuccess, InitErr

		RecvEvent.Event:Connect(function(Topic, Success, ...)
			if Topic == "ReadyToLoad" then
				IsRunnerReady = true
				return
			elseif Topic == "AgentStarted" then
				InitSuccess = Success
				InitErr = (...)
				IsConstructed = true
				return
			end

			local RequestId = Topic
			local Thread = PendingRequests[RequestId]

			if not Thread then
				return
			end

			PendingRequests[RequestId] = nil

			if Success then
				task.spawn(Thread, ...)
			else
				local ErrMessage = ...
				error(string.format("[Mince Agent Error] %s: %s", Name, tostring(ErrMessage)))
			end
		end)

		local StartTime = os.clock()
		while not IsRunnerReady do
			if os.clock() - StartTime > 5 then
				ActorInstance:Destroy()
				error(`[Mince Agent]: Timeout waiting for Actor bindings.`, 4)
			end
			task.wait()
		end

		ActorInstance:SendMessage("Construct", unpack(ConstructorArgs))

		while not IsConstructed do
			if os.clock() - StartTime > 15 then
				InitSuccess = true
				warn(`[Mince Agent]: Skipped full agent OnNew for "{Name}" because it took more than 15 seconds.`, 4)
			end
			task.wait()
		end

		if not InitSuccess then
			error(`[Mince Agent]: Failed to start {Name}: {InitErr}`, 2)
		end

		local InstanceProxy = {}
		InstanceProxy.Shared = SharedData

		function InstanceProxy:AssignInstance(Key, TargetInstance)
			if typeof(Key) ~= "string" then
				error(`[Mince Agent]: AssignInstance key must be a string, got {typeof(Key)}`, 2)
			end

			if typeof(TargetInstance) ~= "Instance" and TargetInstance ~= nil then
				error(`[Mince Agent]: AssignInstance value must be an Instance or nil, got {typeof(TargetInstance)}`, 2)
			end

			local ObjName = `REF_{Key}`
			local Existing = ActorInstance:FindFirstChild(ObjName)
			if Existing then
				Existing:Destroy()
			end

			if not TargetInstance then
				return
			end

			local RefValue = Instance.new("ObjectValue")
			RefValue.Name = ObjName
			RefValue.Value = TargetInstance
			RefValue.Parent = ActorInstance

			ActorInstance:SendMessage("UpdateInstance", Key, RefValue)
		end

		function InstanceProxy:Destroy()
			ActorInstance:Destroy()
			table.clear(PendingRequests)
		end

		setmetatable(InstanceProxy, {
			__index = function(_, Key)
				return function(Self, ...)
					local RequestId = MicroID.gen()
					local CurrentThread = coroutine.running()
					PendingRequests[RequestId] = CurrentThread

					ActorInstance:SendMessage("Execute", RequestId, Key, ...)

					return coroutine.yield()
				end
			end,

			__newindex = function(k)
				warn(
					`Attempted to add member "{k}" onto agent! It runs in a separate vm, so you can't do this! Use Shared, or AssignInstance for Objects.`
				)
			end,

			__tostring = function()
				local PendingCount = 0
				for _ in PendingRequests do
					PendingCount += 1
				end

				local State = "Initializing"
				if IsConstructed then
					State = "Running"
				end
				if not ActorInstance or not ActorInstance.Parent then
					State = "Destroyed"
				end

				local String =
					`[Mince Agent: {Name}] (State: {State} | Pending Requests: {PendingCount}) \n\t\t\t\tMethods: Destroy, AssignInstance`

				for Key, Value in Definition do
					if type(Value) == "function" then
						if Key ~= "OnNew" and Key ~= "OnStep" and Key ~= "OnDestroy" then
							String ..= `, {Key}`
						end
					end
				end

				if SharedData then
					String ..= `\n\t\t\t\tShared Data:`
					for Key, Value in SharedData do
						String ..= ` ({Key}: {Value})`
					end
				end

				return String
			end,
		})

		return InstanceProxy
	end

	return AgentClass
end

function AgentAddon.Server.Agent(Arg)
	return DefineAgent(Arg)
end
function AgentAddon.Client.Agent(Arg)
	return DefineAgent(Arg)
end

function AgentAddon.Identity(ThisIdentity)
	if IsActorContext then
		return
	end
	Identity = ThisIdentity
	ContainerParent = Instance.new("Folder", script)
	ContainerParent.Name = `{Identity}Agents`
end

return AgentAddon
