-- Services // Modules
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Identity = require(script.Identity)
local Signal = require(script.Signal)

local MAXIMUM_SETUP_SECONDS = 45
local MAXIMUM_GAME_START_GROUP_SECONDS = 1
local REQUIRE_SLICE_SECONDS = if RunService:IsClient() then 0.004 else 0.008
local SLOW_OPERATION_SECONDS = 0.05
local DEFAULT_BOOT_PHASE = "Gameplay"
local BOOT_PHASE_ORDER = {
	Critical = 1,
	Gameplay = 2,
	Deferred = 3,
}

local function getBootPhase(moduleScript: ModuleScript, moduleContents): string
	local phase = moduleScript:GetAttribute("BootPhase")
	if phase == nil and typeof(moduleContents) == "table" then
		phase = moduleContents.BootPhase
	end

	if typeof(phase) ~= "string" or BOOT_PHASE_ORDER[phase] == nil then
		return DEFAULT_BOOT_PHASE
	end

	return phase
end

local function getBootOrder(moduleScript: ModuleScript): number
	local order = moduleScript:GetAttribute("BootOrder")
	return if typeof(order) == "number" then order else 0
end

local function getLifecyclePriority(moduleScript: ModuleScript, moduleContents): number
	local priority = moduleContents.LoadOrder or moduleContents.Priority
	return if typeof(priority) == "number" then priority else getBootOrder(moduleScript)
end

local function measureOperation(callback)
	local startedAt = os.clock()
	local success, result = xpcall(callback, debug.traceback)
	local duration = os.clock() - startedAt
	return success, result, duration
end

--[[
	@class Mince

	Lightweight runtime loader and service registry used by Observatory.

	Mince loads configuration ModuleScripts into `Mince.Config`, requires
	runtime modules into `Mince.Modules`, and runs module lifecycle methods in
	two phases: `Setup` first, then `GameStart`. Server and client runtimes use
	the same registry surface, while addons provide remotes, state replication,
	components, and task helpers.
]]

export type Identity = Identity.Identity
export type RemoteExtend = {
	Event: RBXScriptSignal,
	Fire: (self) -> (),
	FireAll: (self) -> (),
}

export type GenericRemoteEventRegister = {
	Event: RBXScriptSignal,
	Fire: (self) -> (),
	FireAll: (self) -> (),
	Extend: (self, Name: string) -> RemoteExtend,
}

export type GenericRemoteFunctionRegister = {
	Invoke: (self) -> (),
	OnInvoke: (self) -> (),
	Add: (Middleware) -> (),
}

export type GenericStateRegister = {
	Observe: (self, Index: string) -> (),
}

export type PacketDefinition = {
	Value: any,
	Reliability: ("reliable" | "unreliable")?,
	CallbackBehavior: {
		spawnThread: boolean,
		allowMultiple: boolean,
	}?,
}

type Mince = {
	GetFunction: (self, FunctionName: string) -> GenericRemoteFunctionRegister,
	GetEvent: (self, EventName: string) -> GenericRemoteEventRegister,
	GetState: (self, StateName: string) -> GenericStateRegister,
	GetByteNet: (self) -> any,
	DefinePackets: (self, NamespaceName: string, Define: (any) -> { [string]: PacketDefinition }) -> { [string]: any },
	GetPacket: (self, NamespaceName: string, PacketName: string) -> any,
	WaitUntilHandshake: (self, Player: Player) -> (),
	GetHandshake: (self, Player: Player) -> (),
	Get: (self, ModuleName: string | Instance | any) -> (),
	LoadConfig: (self, Folder: Instance) -> (),
	LoadModules: (self, Folder: Instance) -> (),
	WaitUntilSetup: (self, Identity: Identity.Identity) -> (),
	WhenStart: (self, UponReady: () -> ()) -> (),
	Start: (self) -> (),
}

local Mince: Mince = {
	_VERSION = "0.2",
	_DESCRIPTION = "Basic, superceed of weave.",
	_LICENSE = "cc-0",
	_AUTHORS = { "whim@awesomexforlife", "inty@intykat" },
	------------------------------------------------------

	Signal = Signal,
	Identity = Identity,

	Started = false,
	Initialized = false,

	SetupMethodIndex = "Setup",
	PostMethodIndex = "GameStart",

	SetupMethods = {},
	PostMethods = {},
	Diagnostics = {
		Requires = {},
		Lifecycle = {},
	},

	Config = {},
	Modules = {},
	FailedModules = {},
	MissingModules = {},
	MissingModuleProxies = {},
	ReadyPlayerStatus = {},

	DoPcalling = true,

	SignalNames = { "UponStart", "UponInitComplete", "UponPlayerReadyHandshake", "ModuleAdded" },

	VerboseMethods = {
		[print] = "Print",
		[warn] = "Warn",
		[error] = "Error",
	},
}

--[[
	Starts module lifecycle execution.

	Lifecycle records are ordered by `BootPhase`, then `LoadOrder`/`Priority`.
	Records sharing a phase and priority run concurrently; each group forms a
	completion barrier before the next group begins. GameStart remains detached
	from the ready gate for compatibility.

	@within Mince
]]
local function sortLifecycleRecords(records)
	table.sort(records, function(a, b)
		local phaseA = BOOT_PHASE_ORDER[a.Phase] or BOOT_PHASE_ORDER[DEFAULT_BOOT_PHASE]
		local phaseB = BOOT_PHASE_ORDER[b.Phase] or BOOT_PHASE_ORDER[DEFAULT_BOOT_PHASE]
		if phaseA ~= phaseB then
			return phaseA < phaseB
		end
		if a.Priority ~= b.Priority then
			return a.Priority < b.Priority
		end
		return a.Name < b.Name
	end)
end

function Mince:__RunLifecycle(
	records,
	methodName: string,
	waitForCompletion: boolean,
	timeoutSeconds: number?,
	maxGroupWaitSeconds: number?
)
	if #records == 0 then
		return true
	end

	sortLifecycleRecords(records)

	local function executeRecord(record, onCompleted)
		task.spawn(function()
			local success, result, duration = measureOperation(function()
				record.Module[methodName](record.Module)
			end)

			record.Completed = true
			record.Duration = duration
			table.insert(Mince.Diagnostics.Lifecycle, {
				Name = record.Name,
				Method = methodName,
				Phase = record.Phase,
				Duration = duration,
				Success = success,
			})

			if not success then
				Mince:Error(`Failed to run {methodName} for '{record.Name}'.`)
				Mince:Error(result)
			elseif duration >= SLOW_OPERATION_SECONDS then
				Mince:Warn(`Slow {methodName}: {record.Name} completed in {duration * 1000 // 1}ms.`)
			end

			onCompleted()
		end)
	end

	local function executeGroups()
		local deadline = if timeoutSeconds then os.clock() + timeoutSeconds else nil
		local index = 1

		while index <= #records do
			local first = records[index]
			local group = {}
			while index <= #records do
				local candidate = records[index]
				if candidate.Phase ~= first.Phase or candidate.Priority ~= first.Priority then
					break
				end
				table.insert(group, candidate)
				index += 1
			end

			local groupCompleted = 0
			for _, record in group do
				executeRecord(record, function()
					groupCompleted += 1
				end)
			end

			local groupDeadline = if maxGroupWaitSeconds then os.clock() + maxGroupWaitSeconds else nil
			while
				groupCompleted < #group
				and (deadline == nil or os.clock() < deadline)
				and (groupDeadline == nil or os.clock() < groupDeadline)
			do
				task.wait()
			end

			if groupCompleted < #group then
				local unfinished = {}
				for _, record in group do
					if not record.Completed then
						table.insert(unfinished, record.Name)
					end
				end
				if deadline and os.clock() >= deadline then
					Mince:Warn(
						`{methodName} timed out after {timeoutSeconds}s. Waiting on: {table.concat(unfinished, ", ")}`
					)
					return false
				end

				Mince:Warn(
					`{methodName} group exceeded {maxGroupWaitSeconds}s; releasing the next group while these continue: {table.concat(
						unfinished,
						", "
					)}`
				)
			end

			-- Preserve phase ordering while allowing Roblox one scheduler turn to
			-- present frames and service engine work between lifecycle barriers.
			task.wait()
		end

		return true
	end

	if waitForCompletion then
		return executeGroups()
	end

	task.spawn(executeGroups)
	return true
end

function Mince:Start()
	if Mince.__AsyncStarted then
		error("Modules have already begun loading.")
	end
	Mince.__AsyncStarted = true

	local startedAt = os.clock()
	Mince:__RunLifecycle(Mince.SetupMethods, Mince.SetupMethodIndex, true, MAXIMUM_SETUP_SECONDS)

	Mince:SetIdentityStatus(true)
	Mince.Started = true
	Mince.UponStart:Fire()

	-- GameStart is intentionally non-blocking for compatibility. It still uses
	-- deterministic queue order and emits per-module diagnostics.
	Mince:__RunLifecycle(Mince.PostMethods, Mince.PostMethodIndex, false, nil, MAXIMUM_GAME_START_GROUP_SECONDS)

	Mince:Print(
		`Startup ready in {(os.clock() - startedAt) * 1000 // 1}ms: {#Mince.SetupMethods} setup, {#Mince.PostMethods} game-start methods.`
	)
end

--[[
	Gets a registered runtime module by name.

	If the module has not been loaded yet, this returns a forwarding table that
	binds to the real module when it is registered. After initialization
	completes, missing modules raise an error.

	@within Mince
	@param Name string -- Module registry name.
	@return table
]]
function Mince:Get(Name)
	if Mince.Modules[Name] then
		return Mince.Modules[Name]
	end
	if Mince.InitComplete then
		if not Mince.MissingModules[Name] then
			Mince.MissingModules[Name] = true
			Mince:Warn(`Module '{Name}' was requested after discovery, but it is not registered.`)
		end
		Mince.MissingModuleProxies[Name] = Mince.MissingModuleProxies[Name] or {}
		return Mince.MissingModuleProxies[Name]
	end

	local Storage, ModulePredef = {}, {
		__Mince = {},
	}

	local Connections = {}
	Connections.InitComplete = Mince.UponInitComplete:Connect(function()
		if not ModulePredef.__Mince.Acquired then
			Mince:Warn(`Module '{Name}' was requested but was not registered before discovery completed.`)
			for _, Connection in Connections do
				Connection:Disconnect()
			end
		end
	end)

	Connections.ModuleAdded = Mince.ModuleAdded:Connect(function(AddedName, ModuleContents)
		if AddedName == Name then
			Storage = ModuleContents

			ModulePredef.__Mince.Acquired = true
			ModulePredef.__Mince.Table = ModuleContents

			for _, Connection in Connections do
				Connection:Disconnect()
			end
		end
	end)

	return setmetatable(ModulePredef, {
		__index = function(_, Index)
			return Storage[Index]
		end,
		__newindex = function(_, Index, Value)
			Storage[Index] = Value
		end,
	})
end

--[[
	Requires eligible ModuleScripts below a folder and registers their returned
	tables.

	Only top-level ModuleScripts in ordinary folders are registered; ModuleScript
	children and Configuration descendants are intentionally skipped.

	@within Mince
	@param ModuleFolder Folder -- Root folder to scan for runtime modules.
]]
function Mince:LoadModules(ModuleFolder: Folder)
	if Mince.__InitAsyncStarted then
		error("Modules have already begun loading.")
	end
	Mince.__InitAsyncStarted = true

	local candidates = Mince:__GetEligibleModules(ModuleFolder)
	local sliceStartedAt = os.clock()
	local loadStartedAt = sliceStartedAt
	local summedRequireSeconds = 0
	local pacingWaitSeconds = 0

	for _, moduleScript in candidates do
		local moduleContents, name, requireDuration = Mince:__SafeRequire(moduleScript)
		summedRequireSeconds += requireDuration
		local phase = getBootPhase(moduleScript, moduleContents)
		local priority = getLifecyclePriority(moduleScript, moduleContents)

		table.insert(Mince.Diagnostics.Requires, {
			Name = name,
			Path = moduleScript:GetFullName(),
			Phase = phase,
			Duration = requireDuration,
		})

		if requireDuration >= SLOW_OPERATION_SECONDS then
			Mince:Warn(`Slow require: {moduleScript:GetFullName()} completed in {requireDuration * 1000 // 1}ms.`)
		end

		if Mince.Modules[name] then
			warn(`There's another module by the name of '{name}'! It has been overwritten.`)
		end

		local record = {
			Module = moduleContents,
			Name = name,
			Priority = priority,
			Phase = phase,
			Script = moduleScript,
		}
		if moduleContents[Mince.SetupMethodIndex] then
			table.insert(Mince.SetupMethods, record)
		end
		if moduleContents[Mince.PostMethodIndex] then
			table.insert(Mince.PostMethods, table.clone(record))
		end

		Mince.Modules[name] = moduleContents
		Mince.ModuleAdded:FireImmediate(name, moduleContents)

		if os.clock() - sliceStartedAt >= REQUIRE_SLICE_SECONDS then
			local waitStartedAt = os.clock()
			task.wait()
			pacingWaitSeconds += os.clock() - waitStartedAt
			sliceStartedAt = os.clock()
		end
	end

	Mince.Initialized = true
	Mince.InitComplete = true
	Mince.UponInitComplete:Fire()
	Mince:Print(
		`Required {#candidates} modules in {(os.clock() - loadStartedAt) * 1000 // 1}ms ({summedRequireSeconds * 1000 // 1}ms summed require, {pacingWaitSeconds * 1000 // 1}ms pacing wait).`
	)

	if next(Mince.FailedModules) then
		local FailedNames = {}
		for _, Failure in Mince.FailedModules do
			table.insert(FailedNames, Failure.Name)
		end
		Mince:Warn(`Module require failures recorded: {table.concat(FailedNames, ", ")}.`)
	end
end

--[[
	Requires configuration ModuleScripts below a folder into `Mince.Config`.

	Configuration modules are expected to be pure and non-yielding because they
	are loaded during the boot path.

	@within Mince
	@param ConfigFolder Folder -- Root config folder to scan.
]]
function Mince:LoadConfig(ConfigFolder: Folder) -- IT IS EXEPCTED THAT THESE FUNCTIONS WILL NOT YEILD!
	Mince:__IterateRules(ConfigFolder, function(ModuleScript: ModuleScript)
		local ModuleContents, Name = Mince:__SafeRequire(ModuleScript)

		Mince.Config[Name] = ModuleContents
	end)
end

function Mince:WaitUntilHandshake(Player: Player)
	if Identity == "Client" then
		Mince:__WaitInstAttrTrueChange(Player, "_ReplicatedHandshakeStatus")
	elseif Identity == "Server" then
		if Mince.ReadyPlayerStatus[Player] then
			return
		end

		local RunningThread, ThisWatcher = coroutine.running(), nil
		ThisWatcher = Mince.UponPlayerReadyHandshake:Connect(function(ComparePlayer: Player)
			if ComparePlayer ~= Player then
				return
			end
			ThisWatcher:Disconnect()
			task.spawn(RunningThread) -- resume safely even if current thread is deferred
		end)

		coroutine.yield()
	end
end

function Mince:GetHandshake(Player: Player)
	return Mince.ReadyPlayerStatus[Player] or Player:GetAttribute("_ReplicatedHandshakeStatus")
end

function Mince:SetIdentityStatus(Boolean: boolean)
	Mince.StatusConfiguration:SetAttribute(Identity, Boolean)
end

function Mince:WhenStart(UponReady: () -> ())
	if not Mince.Started then
		Mince.UponStart:Once(UponReady)
	else
		UponReady()
	end
end

function Mince:WaitUntilSetup(Identity)
	Mince:__WaitInstAttrTrueChange(Mince.StatusConfiguration, Identity)
end

--[[
	Requires a module and records failures in `Mince.FailedModules`.

	@within Mince
	@param ModuleScript ModuleScript
	@return table
	@return string
]]
function Mince:__SafeRequire(ModuleScript: ModuleScript)
	local ModuleContents, Name = {}, ModuleScript.Name
	local RequireStartedAt = os.clock()

	if Mince.DoPcalling then
		local Success, Result = pcall(function()
			return require(ModuleScript)
		end)

		if not Success then
			warn(":====: :====: :====: :====:")
			warn("ERROR! ERROR! ERROR! ERROR!")
			warn(":====: :====: :====: :====:")
			warn(`Require failure '{ModuleScript:GetFullName()}' occurred.`)
			warn("The module will be registered as an empty table.")
			warn(Result)
			warn(":====: :====: :====: :====:")

			table.insert(Mince.FailedModules, {
				Name = Name,
				Instance = ModuleScript,
				Error = Result,
			})

			ModuleContents = {}
		else
			ModuleContents = Result
		end
	else
		ModuleContents = require(ModuleScript)
	end

	if typeof(ModuleContents) == "table" then
		Name = ModuleContents.Name or Name
	else
		error("Mounted modules must return a table!")
	end

	return ModuleContents, Name, os.clock() - RequireStartedAt
end

function Mince:__IsEligibleModule(root: Instance, candidate: Instance): boolean
	if not candidate:IsA("ModuleScript") then
		return false
	end

	local ancestor = candidate.Parent
	while ancestor and ancestor ~= root do
		if ancestor:IsA("ModuleScript") or ancestor:IsA("Configuration") then
			return false
		end
		ancestor = ancestor.Parent
	end

	return ancestor == root
end

function Mince:__GetEligibleModules(root: Instance): { ModuleScript }
	local modules = {}
	for _, descendant in root:GetDescendants() do
		if Mince:__IsEligibleModule(root, descendant) then
			table.insert(modules, descendant)
		end
	end

	table.sort(modules, function(a, b)
		local phaseA = BOOT_PHASE_ORDER[getBootPhase(a)] or BOOT_PHASE_ORDER[DEFAULT_BOOT_PHASE]
		local phaseB = BOOT_PHASE_ORDER[getBootPhase(b)] or BOOT_PHASE_ORDER[DEFAULT_BOOT_PHASE]
		if phaseA ~= phaseB then
			return phaseA < phaseB
		end

		local orderA = getBootOrder(a)
		local orderB = getBootOrder(b)
		if orderA ~= orderB then
			return orderA < orderB
		end

		return a:GetFullName() < b:GetFullName()
	end)

	return modules
end

function Mince:__IterateRules(instance: Instance, iterateFn: (ModuleScript) -> ())
	for _, moduleScript in Mince:__GetEligibleModules(instance) do
		iterateFn(moduleScript)
	end
end

function Mince:__WaitInstAttrTrueChange(ConfigInstance, Index)
	if ConfigInstance:GetAttribute(Index) then
		return
	end

	local RunningThread, ThisWatcher = coroutine.running(), nil
	ThisWatcher = ConfigInstance:GetAttributeChangedSignal(Index):Connect(function()
		ThisWatcher:Disconnect()
		task.defer(RunningThread) -- deferring just incase script connections may be instant!
	end)

	coroutine.yield()
end

function Mince:MountAddonModule(AddonModuleScript: ModuleScript)
	local Success, Result = pcall(function()
		return require(AddonModuleScript)
	end)

	if not Success then
		Mince.Warn(`Failure to load addon '{AddonModuleScript.Name}'.`)
		return
	end

	local AddonContents = Result[Mince.Identity]

	if AddonContents then
		for Index, Value in AddonContents do
			Mince[Index] = Value
		end
	end

	if Result.Identity then
		Result.Identity(Identity)
	end
end

function Mince:SetupMince()
	-- Instances!>?
	script:WaitForChild("Repl")
	script:WaitForChild("Addons")

	Mince.StatusConfiguration = script.Repl:WaitForChild("Status")
	Mince.HandshakeRemote = script.Repl:WaitForChild("Handshake")

	_G.MinceRef = Mince

	local csnt = function(mth)
		return function(a, b)
			local msg = b or a or ""
			mth("[Mince]:" .. tostring(msg))
		end
	end

	for _, SignalName in Mince.SignalNames do
		Mince[SignalName] = Mince.Signal.new()
	end

	for ThisMethod, VerboseMethod in Mince.VerboseMethods do
		Mince[VerboseMethod] = csnt(ThisMethod)
	end

	Mince:__IterateRules(script.Addons, function(ThisAddon: ModuleScript)
		Mince:MountAddonModule(ThisAddon)
	end)

	if Identity == "Client" then
		local DoAsyncClient = function()
			Mince:WaitUntilSetup("Server")
			Mince:WaitUntilSetup(Identity)
			Mince.HandshakeRemote:FireServer()
		end

		task.defer(DoAsyncClient)
	else
		Mince.HandshakeRemote.OnServerEvent:Connect(function(Player: Player)
			if not Player:IsDescendantOf(Players) then
				return
			end -- disconnected already..!

			Mince.ReadyPlayerStatus[Player] = true
			Mince.UponPlayerReadyHandshake:Fire(Player)

			Player:SetAttribute("_ReplicatedHandshakeStatus", true)
		end)

		Players.PlayerRemoving:Connect(function(Player: Player)
			Mince.ReadyPlayerStatus[Player] = nil
		end)
	end
end

Mince:SetupMince()
return Mince
