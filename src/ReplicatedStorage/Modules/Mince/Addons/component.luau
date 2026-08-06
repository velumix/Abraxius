-- CollectionService-backed component lifecycle for Mince.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Identity
local Mince = _G.MinceRef
local MinceComponent = {
	ComponentRegistry = {},
	CatchupQueues = {
		Critical = { Head = 1, Items = {} },
		Gameplay = { Head = 1, Items = {} },
		Deferred = { Head = 1, Items = {} },
	},
	CatchupDiagnostics = {},
}
MinceComponent.__index = MinceComponent

local CATCHUP_PHASES = { "Critical", "Gameplay", "Deferred" }
local DEFAULT_CATCHUP_PHASE = "Gameplay"
local DEFAULT_CLIENT_BUDGET_SECONDS = 0.0025
local DEFAULT_SERVER_BUDGET_SECONDS = 0.005
local SLOW_CONSTRUCTOR_SECONDS = 0.01
local catchupProcessorRunning = false

local function getCatchupBudgetSeconds(): number
	local configuredMilliseconds = script:GetAttribute("ComponentBudgetMs")
	if typeof(configuredMilliseconds) == "number" and configuredMilliseconds > 0 then
		return configuredMilliseconds / 1000
	end

	return if RunService:IsClient() then DEFAULT_CLIENT_BUDGET_SECONDS else DEFAULT_SERVER_BUDGET_SECONDS
end

local function getCatchupPhase(component): string
	local phase = component.ComponentPhase or component.BootPhase
	for _, knownPhase in CATCHUP_PHASES do
		if phase == knownPhase then
			return phase
		end
	end
	return DEFAULT_CATCHUP_PHASE
end

local function hasCatchupJobs(): boolean
	for _, phase in CATCHUP_PHASES do
		local queue = MinceComponent.CatchupQueues[phase]
		if queue.Items[queue.Head] then
			return true
		end
	end
	return false
end

local function popCatchupJob()
	for _, phase in CATCHUP_PHASES do
		local queue = MinceComponent.CatchupQueues[phase]
		local job = queue.Items[queue.Head]
		if job then
			queue.Head += 1
			if queue.Head > #queue.Items then
				queue.Head = 1
				table.clear(queue.Items)
			end
			return job
		end
	end
	return nil
end

local function processCatchupQueue()
	if catchupProcessorRunning then
		return
	end
	catchupProcessorRunning = true

	task.defer(function()
		while true do
			local sliceStartedAt = os.clock()
			local launched = 0

			while true do
				local job = popCatchupJob()
				if not job then
					break
				end

				launched += 1
				task.spawn(function()
					local success, result = xpcall(function()
						job.Component:InstanceAddedOrExisted(job.Instance, true)
					end, debug.traceback)
					if not success then
						warn(`Component catch-up failed for <{job.Component.Tag}>: {result}`)
					end
				end)

				if os.clock() - sliceStartedAt >= getCatchupBudgetSeconds() then
					break
				end
			end

			if launched == 0 and not hasCatchupJobs() then
				catchupProcessorRunning = false
				return
			end

			task.wait()
		end
	end)
end

local function enqueueCatchup(component, instance)
	local phase = getCatchupPhase(component)
	table.insert(MinceComponent.CatchupQueues[phase].Items, {
		Component = component,
		Instance = instance,
	})
	processCatchupQueue()
end

function MinceComponent.newComponent(ModuleContainer)
	if ModuleContainer and ModuleContainer.Tag and MinceComponent.ComponentRegistry[ModuleContainer.Tag] then
		warn(`Component '{ModuleContainer.Tag}' already exists, reusing existing component.`)
		return MinceComponent.ComponentRegistry[ModuleContainer.Tag]
	end

	local ThisComponent = setmetatable(ModuleContainer, MinceComponent)
	local BeginToCreate = function()
		assert(
			not MinceComponent.ComponentRegistry[ThisComponent.Tag],
			`There is already a component by the name of '{ThisComponent.Tag}'`
		)
		MinceComponent.ComponentRegistry[ThisComponent.Tag] = ThisComponent
		assert(ModuleContainer.Construct, "A component requires a Construct method.")
		ThisComponent:__Create(ModuleContainer)
	end

	ThisComponent.Registry = {}

	if Mince.Started then
		-- A component module may be required lazily after Mince starts. Defer its
		-- registration so the module can finish defining Construct and helpers.
		task.defer(BeginToCreate)
	else
		Mince:WhenStart(BeginToCreate)
	end

	return ThisComponent
end

function MinceComponent:CallTable(CallMethod)
	-- General structure.
	-- [Index]<Call>(...) --> Index ...
	-- [Index][Index2]<Call>(...) --> {Index, Index2} ...
	return setmetatable({}, {
		__index = function(Table, Key) -- --> [Index] <--- --
			---  returns a method for both calling as a functgion and new indexes1
			rawset(
				Table,
				Key,
				setmetatable({}, { -- [Index]<Call>(...)
					__call = function(_, _, ...)
						CallMethod(Key, ...)
					end, -- [Index][Index2] --> ()->()
					__index = function(Table, DepthKey)
						rawset(Table, Key, function(_, ...)
							CallMethod({ Key, DepthKey }, ...) -- Just pass methods for a full [Index][Index2]<Call>(...)
						end)

						return rawget(Table, Key) -- return value everytime
					end,
				})
			)

			return rawget(Table, Key) -- return value everytime
		end,
	})
end

function MinceComponent:__ConnectCommunicationMethods(SubComponent)
	if Identity == "Server" then
		SubComponent.Client = self:CallTable(function(Method, ...)
			if typeof(Method) == "table" then
				if Method[2] == "Fire" then
					local Player = ...
					self.CommunicationEvent[Method[2]](
						self.CommunicationEvent,
						Player,
						Method[1],
						SubComponent.Instance,
						select(2, ...)
					)
					return
				end

				self.CommunicationEvent[Method[2]](self.CommunicationEvent, Method[1], SubComponent.Instance, ...)
				return
			end

			self.CommunicationEvent:FireAll(Method, SubComponent.Instance, ...)
		end)
	elseif Identity == "Client" then
		SubComponent.Server = self:CallTable(function(Method, ...)
			warn(Method, ...)
			if typeof(Method) == "table" then
				if not self.WhitelistedMethods[Method[1]] then
					error(`The '{Method[1]}' is not whitelisted from the server!`)
				end

				self.CommunicationEvent[Method[2]](self.CommunicationEvent, Method[1], SubComponent.Instance, ...)
				return
			end

			if not self.WhitelistedMethods[Method] then
				error(`The Method '{Method}' is not whitelisted from the server!`)
			end
			self.CommunicationEvent:Fire(Method, SubComponent.Instance, ...)
		end)
	end

	SubComponent.__IsCommunicationReady = true
end

function MinceComponent:__CreateCommunicationMethods()
	self.CommunicationEvent = Mince:GetEvent(self.Tag)

	self[Identity] = self:CallTable(function(_Method)
		error(`You cannot use '{Identity}'! Please use the opposite identity!`)
	end)

	if Identity == "Server" then
		self.CommunicationEvent.Event:Connect(function(Player: Player, Method, CompInstance, ...)
			assert(typeof(Method) == "string", "Invalid communication method through communication event!")
			assert(typeof(CompInstance) == "Instance", "Invalid communication method through communication event!")
			self:CallExisting(Method, CompInstance, Player, ...)
		end)
	elseif Identity == "Client" then
		local WhitelistedMethods = self.CommunicationConfiguration:GetAttributes()
		self.CommunicationConfiguration.AttributeChanged:Connect(function(AttributeName)
			WhitelistedMethods[AttributeName] = self.CommunicationConfiguration:GetAttribute(AttributeName)
		end)

		self.CommunicationEvent.Event:Connect(function(Method, CompInstance, ...)
			if Workspace.StreamingEnabled and not CompInstance then
				return
			end -- Instances that are sent to the client may NOT exist, if Streaming Is Enabled!!
			assert(typeof(Method) == "string", "Invalid communication method through communication event!")
			assert(typeof(CompInstance) == "Instance", "Invalid communication method through communication event!")
			self:CallExisting(Method, CompInstance, ...)
		end)

		self.WhitelistedMethods = WhitelistedMethods
	end

	-- any unconnected components connect!
	for _, SubComponent in self:GetAll() do
		if not SubComponent.__IsCommunicationReady then
			self:__ConnectCommunicationMethods(SubComponent)
		end
	end

	self.CommunicationReady = true
end

function MinceComponent:__Create(ModuleContainer)
	self.Added = Mince.Signal.new()
	self.ModuleContainer = ModuleContainer
	self.ExistenceEvents = {}
	self.InstanceEvents = {}
	self.Connected = true

	if self.CommunicationMethods and Identity == "Server" then
		self.CommunicationConfiguration = Instance.new("Configuration")
		self.CommunicationConfiguration.Name = self.Tag
		self.CommunicationConfiguration.Parent = script

		for _, CommunicationMethod in self.CommunicationMethods do
			self.CommunicationConfiguration:SetAttribute(CommunicationMethod, true)
		end

		self:__CreateCommunicationMethods()
	elseif Identity == "Client" then
		local WhenCommunicationConfiguration = function()
			self:__CreateCommunicationMethods()
		end

		self.CommunicationConfiguration = script:FindFirstChild(self.Tag)

		if self.CommunicationConfiguration then
			WhenCommunicationConfiguration()
		else
			self.ExistenceEvents.CommAdded = script.ChildAdded:Connect(function(Child)
				if Child.Name == self.Tag then
					self.CommunicationConfiguration = Child
					self.ExistenceEvents.CommAdded:Disconnect()
					WhenCommunicationConfiguration()
				end
			end)
		end
	end

	self.ExistenceEvents.Removed = CollectionService:GetInstanceRemovedSignal(self.Tag):Connect(function(ThisInstance)
		self:InstanceRemoved(ThisInstance)
	end)

	self.ExistenceEvents.Added = CollectionService:GetInstanceAddedSignal(self.Tag):Connect(function(ThisInstance)
		self:InstanceAddedOrExisted(ThisInstance)
	end)

	local taggedInstances = CollectionService:GetTagged(self.Tag)
	self.CatchupCount = #taggedInstances
	self.CatchupStartedAt = os.clock()
	MinceComponent.CatchupDiagnostics[self.Tag] = {
		Count = #taggedInstances,
		Constructed = 0,
		TotalConstructorTime = 0,
		MaximumConstructorTime = 0,
	}

	for _, thisInstance in taggedInstances do
		enqueueCatchup(self, thisInstance)
	end
end

function MinceComponent:CallExisting(Index, CompInstance, ...)
	if not self[Index] then
		return
	end
	local SubComponent = self:Get(CompInstance)
	if not SubComponent then
		return
	end

	self[Index](SubComponent, ...)
end

function MinceComponent:NewSubComponent(ThisInstance, isCatchup: boolean?)
	local SubComponent = ThisInstance:GetAttributes()
	local events = self.InstanceEvents[ThisInstance]
	events.AttributeChanged = ThisInstance.AttributeChanged:Connect(function(AttributeName)
		SubComponent[AttributeName] = ThisInstance:GetAttribute(AttributeName)
	end)

	SubComponent.Instance = ThisInstance

	setmetatable(SubComponent, { __index = self.ModuleContainer })

	if self.AttributeDefaults then
		for Key, Value in self.AttributeDefaults do
			SubComponent.Instance:SetAttribute(Key, Value)
		end
	end

	self.Registry[SubComponent.Instance] = SubComponent

	local constructorStartedAt = os.clock()
	local Success, Result = pcall(function()
		return self.ModuleContainer.Construct(SubComponent)
	end)
	local constructorDuration = os.clock() - constructorStartedAt

	local diagnostics = MinceComponent.CatchupDiagnostics[self.Tag]
	if diagnostics and isCatchup then
		diagnostics.Constructed += 1
		diagnostics.TotalConstructorTime += constructorDuration
		diagnostics.MaximumConstructorTime = math.max(diagnostics.MaximumConstructorTime, constructorDuration)
		if diagnostics.Constructed == diagnostics.Count then
			diagnostics.Elapsed = os.clock() - self.CatchupStartedAt
			Mince:Print(
				`Component {self.Tag}: constructed {diagnostics.Count} instances in {diagnostics.Elapsed * 1000 // 1}ms ({diagnostics.TotalConstructorTime * 1000 // 1}ms constructor time).`
			)
		end
	end

	if not Success then
		warn(`Failure when constructing component <{self.Tag}>.`)
		warn(Result)
	elseif constructorDuration >= SLOW_CONSTRUCTOR_SECONDS then
		warn(
			`Slow component constructor <{self.Tag}> for {ThisInstance:GetFullName()}: {constructorDuration * 1000 // 1}ms.`
		)
	end

	if self.CommunicationReady then
		self:__ConnectCommunicationMethods(SubComponent)
	end

	self.Added:Fire(SubComponent)
end

function MinceComponent:InstanceRemoved(ThisInstance: Instance)
	self:RemoveFromRegistry(ThisInstance)
end

function MinceComponent:CheckIfHasValidParentsToInsert(ThisInstance)
	if not self.CreationParents or not next(self.CreationParents) then
		return true
	end

	for _, Parent in self.CreationParents or {} do
		if ThisInstance:IsDescendantOf(Parent) then
			return true
		end
	end
	return false
end

function MinceComponent:InstanceAddedOrExisted(ThisInstance: Instance, _Existed: boolean?)
	if self.Registry[ThisInstance] or not CollectionService:HasTag(ThisInstance, self.Tag) then
		return
	end

	self.InstanceEvents[ThisInstance] = self.InstanceEvents[ThisInstance] or {}
	local Events = self.InstanceEvents[ThisInstance]
	local CanBeAdded = self:CheckIfHasValidParentsToInsert(ThisInstance)
	if not CanBeAdded then
		-- Only reconect the ParentChanign event if it's not listneing
		if Events.ParentChanging then
			return
		end

		Events.ParentChanging = ThisInstance.AncestryChanged:Connect(function()
			if ThisInstance.Parent == nil then
				return
			end
			-- It'll just ignore all nil-parents because {Parents} can only NOT be nil. Also destroying it'll become nil-aparented
			CanBeAdded = self:CheckIfHasValidParentsToInsert(ThisInstance)
			if CanBeAdded then
				Events.ParentChanging:Disconnect()
				self:InstanceAddedOrExisted(ThisInstance, true)
			end
		end)
		return
	end

	Events.InstanceDestroying = ThisInstance.Destroying:Once(function()
		if not self.Connected then
			return
		end
		if self.Registry[ThisInstance] then -- Only listen to the destroy methods if still registed!
			self:CallExisting("Destroying", ThisInstance)
			self:RemoveFromRegistry(ThisInstance)
		end
	end)

	self:NewSubComponent(ThisInstance, _Existed)
end

function MinceComponent:RemoveFromRegistry(ThisInstance: Instance)
	local InstanceEvents = self.InstanceEvents[ThisInstance] or {}
	for _, InstanceEvent: RBXScriptConnection in InstanceEvents do
		InstanceEvent:Disconnect()
	end

	if self.Registry[ThisInstance] then
		self:CallExisting("Removing", ThisInstance)
		self.Registry[ThisInstance] = nil
	end
	self.InstanceEvents[ThisInstance] = nil
end

function MinceComponent:Get(ThisInstance)
	return self.Registry[ThisInstance]
end

function MinceComponent:GetAll()
	local Components = {}
	for _, Component in self.Registry do
		table.insert(Components, Component)
	end
	return Components
end

local ComponentAddon = {}

local ComponentFactory = setmetatable({}, {
	__call = function(_, ModuleContainer)
		return MinceComponent.newComponent(ModuleContainer)
	end,
})

ComponentFactory.Get = function(target)
	if not target then
		return nil
	end

	if typeof(target) == "Instance" then
		for _, component in MinceComponent.ComponentRegistry do
			local ok, result = pcall(function()
				return component:Get(target)
			end)
			if ok and result then
				return result
			end
		end

		return nil
	end

	return MinceComponent.ComponentRegistry[target]
end

ComponentFactory.GetAll = function()
	return MinceComponent.ComponentRegistry
end

ComponentAddon.Component = ComponentFactory

return {
	Server = ComponentAddon,
	Client = ComponentAddon,
	Identity = function(ThisIdentity)
		Identity = ThisIdentity
	end,
}
