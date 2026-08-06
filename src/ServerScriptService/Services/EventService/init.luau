local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Events = require(ServerScriptService.SparkMod.Services.Events)
local EventDefinitions = require(ReplicatedStorage.Config.EventDefinitions)
local AdminSignalDispatcher = require(script.Utilities.AdminSignalDispatcher)
local MapManager = require(ServerScriptService.MapManager)
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)

local EVENT_FALLBACK_TOPIC = "SparkModEventFallback"
local DISABLED_EVENTS = {
	Fireworks = true,
	FireworkRain = true,
}

-- ========== State ========== --

local activeGameContexts = {}
local handlersByName = {}

local signalHandlersByEvent = {}
local pendingRoundGated = {}
local pendingRoundGatedDetails = {}

-- ========== Service ========== --

local EventService = Knit.CreateService({
	Name = "EventService",
	Client = {
		EventStarted = Knit.CreateSignal(),
		EventEnded = Knit.CreateSignal(),
		EventPaused = Knit.CreateSignal(),
		EventResumed = Knit.CreateSignal(),
		EventStateChanged = Knit.CreateSignal(),
		EventSignal = Knit.CreateSignal(),
		ClientEventSignal = Knit.CreateSignal(),
	},
})

EventService.EventAdded = Signal.new()
EventService.EventRemoved = Signal.new()

local DataService
local function data()
	if not DataService then DataService = Knit.GetService("DataService") end
	return DataService
end

local ConfigParamService
local function fallbackEnabled(): boolean
	if not ConfigParamService then ConfigParamService = Knit.GetService("ConfigParamService") end
	return ConfigParamService:Get("sparkmod_events_fallback") == true
end

local GameModeService
local function activeGameMode(): string?
	if not GameModeService then
		GameModeService = Knit.GetService("GameModeService")
	end
	return GameModeService:GetActive()
end

local function publishEventFallback(eventName, durationSeconds, config)
	pcall(function()
		MessagingService:PublishAsync(EVENT_FALLBACK_TOPIC, {
			name = eventName,
			durationSeconds = durationSeconds,
			config = config,
		})
	end)
end

-- ========== Helpers ========== --

local function markSeenAndCheck(player, eventName)
	local key = "SeenEvent_" .. eventName
	if data():GetFlag(player, key) then return false end
	data():SetFlag(player, key, true)
	return true
end

local function buildSignalFn(eventName)
	return function(action, ...)
		local args = { ... }
		local inst = nil
		if typeof(args[1]) == "Instance" then
			inst = args[1]
			table.remove(args, 1)
		end
		EventService.Client.EventSignal:FireAll({
			eventName = eventName,
			action = action,
			instance = inst,
			args = args,
		})
	end
end

local function runMiddleware(eventName, options)
	local handler = handlersByName[eventName]
	if not handler or typeof(handler.Middleware) ~= "table" then
		return options
	end
	for name, fn in handler.Middleware do
		if typeof(fn) ~= "function" then continue end
		local ok, err = pcall(fn, options)
		if not ok then
			warn(`[EventService] Middleware '{eventName}.{name}' failed: {err}`)
		end
	end
	return options
end

local function buildActiveEventsPayload(player)
	local payload = {}
	for eventName, event in Events:GetAllActiveAsync() do
		if pendingRoundGated[eventName] then
			continue
		end
		local isFirstTime = markSeenAndCheck(player, eventName)
		payload[eventName] = {
			endsAt = event.endsAt,
			duration = event.duration,
			paused = event.paused,
			config = event.config,
			state = event.state,
			isFirstTime = isFirstTime,
		}
	end
	return payload
end

-- ========== Server API ========== --

function EventService:isEventActive(eventName)
	return Events:IsActive(eventName)
end

function EventService:isEventQueuedForRound(eventName)
	return pendingRoundGated[eventName] == true
end

local function roundActive(): boolean
	return MapManager.isLoaded() and ModifierUtils.anyInRound()
end

local function eventReady(definition): boolean
	if not roundActive() then
		return false
	end
	return not definition.requiredGameMode or activeGameMode() == definition.requiredGameMode
end

local function shouldBypassRoundGate(eventName, definition): boolean
	return eventName == "Luck" or eventName == "BoostLuck" or (definition and definition.requiresRound == false)
end

local function whenRoundReady(eventName, definition, applyFn, queueInfo)
	if eventReady(definition) then
		pendingRoundGated[eventName] = nil
		pendingRoundGatedDetails[eventName] = nil
		applyFn()
		return
	end
	local wasQueued = pendingRoundGated[eventName] == true
	pendingRoundGated[eventName] = true
	if queueInfo then
		local existingDetails = pendingRoundGatedDetails[eventName]
		pendingRoundGatedDetails[eventName] = {
			queuedAt = (existingDetails and existingDetails.queuedAt) or os.time(),
			scope = queueInfo.scope or "unknown",
			triggeredBy = queueInfo.triggeredBy,
			durationSeconds = queueInfo.durationSeconds,
			config = queueInfo.config or {},
			requiredGameMode = definition.requiredGameMode,
		}
	end
	if not wasQueued then
		local requiredMode = definition.requiredGameMode or "any"
		local info = pendingRoundGatedDetails[eventName] or {}
		local durationText = if info.durationSeconds then `{info.durationSeconds}s` else "default"
		print(
			`[EventService] QUEUED '{eventName}' scope={info.scope or "unknown"} requiredMode={requiredMode} activeMode={activeGameMode() or "none"} duration={durationText} triggeredBy={info.triggeredBy or "Server"}`
		)
	end
	if definition.requiredGameMode and activeGameMode() ~= definition.requiredGameMode then
		GameModeService:RequestRoundPreempt(definition.requiredGameMode, eventName)
	end
	task.spawn(function()
		while pendingRoundGated[eventName] and not eventReady(definition) do
			task.wait(0.5)
		end
		if pendingRoundGated[eventName] then
			pendingRoundGated[eventName] = nil
			pendingRoundGatedDetails[eventName] = nil
			applyFn()
		end
	end)
end

local function startGlobalNow(eventName, options, triggeredBy)
	if fallbackEnabled() then
		publishEventFallback(eventName, options.durationSeconds, options.config)
		return true, nil
	end
	local response = Events:Start(
		eventName,
		options.durationSeconds or 300,
		options.triggeredBy or triggeredBy or "Server",
		options.config,
		options.overrideBehavior
	)
	return response.ok, response.error
end

function EventService:startEvent(eventName, durationSeconds, isGlobal, config, _startTime, triggeredBy)
	print(`[EventService] startEvent '{eventName}' global={isGlobal or false} duration={durationSeconds or "default"}`)
	if DISABLED_EVENTS[eventName] then
		return false, "Event ended"
	end
	local definition = EventDefinitions.get(eventName)
	local requiresRound = definition and not shouldBypassRoundGate(eventName, definition)

	local options = runMiddleware(eventName, {
		eventName = eventName,
		durationSeconds = durationSeconds,
		config = config,
		triggeredBy = triggeredBy,
		isGlobal = isGlobal or false,
	})

	if not options.isGlobal and requiresRound and not eventReady(definition) then
		if definition.requiredGameMode then
			return false, `Requires game mode '{definition.requiredGameMode}'`
		end
		return false, "No active round"
	end

	if options.isGlobal then
		print(`[EventService] starting global event '{eventName}' fallback={fallbackEnabled()}`)
		if requiresRound and not eventReady(definition) then
			print(`[EventService] delaying global event '{eventName}' until a compatible live round starts`)
			whenRoundReady(eventName, definition, function()
				local ok, err = startGlobalNow(eventName, options, "Server")
				if not ok then
					warn(`[EventService] delayed global event '{eventName}' failed to start: {err or "unknown"}`)
				end
			end, {
				scope = "global-start",
				triggeredBy = options.triggeredBy or "Server",
				durationSeconds = options.durationSeconds,
				config = options.config,
			})
			return true, nil
		end
		return startGlobalNow(eventName, options, "Server")
	else
		return Events:StartLocal(eventName, options.durationSeconds, options.config, options.triggeredBy)
	end
end

function EventService:startGlobalEvent(eventName, triggeredBy, durationMinutes, config)
	print(`[EventService] startGlobalEvent '{eventName}' duration={durationMinutes or "default"}min`)
	if DISABLED_EVENTS[eventName] then
		return false, "Event ended"
	end
	if pendingRoundGated[eventName] and not Events:IsActive(eventName) then
		return false, "Event is already queued for a compatible round"
	end
	local durationSeconds = if durationMinutes then durationMinutes * 60 else nil
	local options = runMiddleware(eventName, {
		eventName = eventName,
		durationSeconds = durationSeconds,
		config = config,
		triggeredBy = triggeredBy,
		isGlobal = true,
	})
	local definition = EventDefinitions.get(eventName)
	local requiresRound = definition and not shouldBypassRoundGate(eventName, definition)
	if requiresRound and not eventReady(definition) then
		print(`[EventService] delaying global event '{eventName}' until a compatible live round starts`)
		whenRoundReady(eventName, definition, function()
			local ok, err = startGlobalNow(eventName, options, triggeredBy)
			if not ok then
				warn(`[EventService] delayed global event '{eventName}' failed to start: {err or "unknown"}`)
			end
		end, {
			scope = "global-start",
			triggeredBy = triggeredBy,
			durationSeconds = options.durationSeconds,
			config = options.config,
		})
		return true, nil, true
	end
	local ok, err = startGlobalNow(eventName, options, triggeredBy)
	return ok, err, false
end

function EventService:cancelEvent(eventName)
	pendingRoundGated[eventName] = nil
	pendingRoundGatedDetails[eventName] = nil
	-- CancelLocal refuses global events; for global events we need to tell the backend.
	if Events:IsGlobal(eventName) then
		local response = Events:Cancel(eventName)
		if not response.ok then
			warn(`[EventService] Failed to cancel global event '{eventName}': {response.error or "unknown"}`)
		end
	else
		Events:CancelLocal(eventName)
	end
end

function EventService:forceCancel(eventName)
	local wasQueued = pendingRoundGated[eventName] == true
	pendingRoundGated[eventName] = nil
	pendingRoundGatedDetails[eventName] = nil
	if wasQueued and not Events:IsActive(eventName) then
		return true
	end
	local response = Events:Cancel(eventName)
	return response.ok
end

function EventService:forceCancelAllGlobalEvents()
	local eventNames = {}
	local included = {}
	for eventName, event in Events:GetAllActiveAsync() do
		if event.isGlobal then
			table.insert(eventNames, eventName)
			included[eventName] = true
		end
	end
	for eventName in pendingRoundGated do
		if not included[eventName] and not Events:IsActive(eventName) then
			table.insert(eventNames, eventName)
		end
	end

	local cancelled = {}
	local failed = {}
	for _, eventName in ipairs(eventNames) do
		local wasQueued = pendingRoundGated[eventName] == true
		pendingRoundGated[eventName] = nil
		pendingRoundGatedDetails[eventName] = nil
		if wasQueued and not Events:IsActive(eventName) then
			table.insert(cancelled, eventName)
		else
			local response = Events:Cancel(eventName)
			if response.ok then
				table.insert(cancelled, eventName)
			else
				table.insert(failed, {
					eventName = eventName,
					error = response.error or "unknown",
				})
			end
		end
	end

	return {
		cancelled = cancelled,
		failed = failed,
	}
end

-- CancelLocal refuses global events; _Deactivate fires EventEnded
function EventService:endLocal(eventName)
	Events._Deactivate(eventName)
end

function EventService:getAdminSignalsManifest()
	return AdminSignalDispatcher.CollectManifest(handlersByName)
end

function EventService:getPreHooks(eventName)
	local h = handlersByName[eventName]
	if h and typeof(h.PreHooks) == "table" then
		return h.PreHooks
	end
	return {}
end

function EventService:buildPreHookContext(eventName, secondsUntilStart)
	return {
		eventName = eventName,
		secondsUntilStart = secondsUntilStart,
		signal = buildSignalFn(eventName),
	}
end

function EventService:getDebugSnapshot()
	local now = os.time()
	local queued: { any } = {}
	local globalEvents: { any } = {}
	local localEvents: { any } = {}

	for eventName in pendingRoundGated do
		local definition: any = EventDefinitions.get(eventName) or {}
		local details: any = pendingRoundGatedDetails[eventName] or {}
		table.insert(queued, {
			eventName = eventName,
			displayName = EventDefinitions.getDisplayName(eventName, details.config),
			queuedAt = details.queuedAt,
			queuedForSeconds = if details.queuedAt then math.max(0, now - details.queuedAt) else nil,
			scope = details.scope or "compatibility-wait",
			triggeredBy = details.triggeredBy,
			durationSeconds = details.durationSeconds,
			requiredGameMode = definition.requiredGameMode,
			activeGameMode = activeGameMode(),
			ready = eventReady(definition),
			backendActive = Events:IsActive(eventName),
			config = details.config or {},
		})
	end

	for eventName, event in Events:GetAllActiveAsync() do
		local definition: any = EventDefinitions.get(eventName) or {}
		local remaining = if event.paused then event.remainingAtPause or 0 else math.max(0, event.endsAt - now)
		local entry = {
			eventName = eventName,
			displayName = EventDefinitions.getDisplayName(eventName, event.config),
			status = if event.paused then "paused" else "active",
			durationSeconds = event.duration,
			remainingSeconds = remaining,
			endsAt = event.endsAt,
			triggeredBy = event.triggeredBy,
			requiredGameMode = definition.requiredGameMode,
			waitingForCompatibleRound = pendingRoundGated[eventName] == true,
			config = event.config or {},
			state = event.state or {},
		}
		if event.isGlobal then
			table.insert(globalEvents, entry)
		else
			table.insert(localEvents, entry)
		end
	end

	local function byName(a: any, b: any): boolean
		return a.eventName < b.eventName
	end
	table.sort(queued, byName)
	table.sort(globalEvents, byName)
	table.sort(localEvents, byName)

	local phase = "unknown"
	local matchManager = ServerScriptService:FindFirstChild("MatchManager")
	local getPhase = matchManager and matchManager:FindFirstChild("GetPhase")
	if getPhase and getPhase:IsA("BindableFunction") then
		local ok, value = pcall(function()
			return getPhase:Invoke()
		end)
		if ok then
			phase = tostring(value)
		end
	end

	return {
		generatedAt = now,
		server = {
			activeGameMode = activeGameMode(),
			phase = phase,
			mapLoaded = MapManager.isLoaded(),
			playersInRound = ModifierUtils.anyInRound(),
			roundActive = roundActive(),
		},
		queued = queued,
		globalEvents = globalEvents,
		localEvents = localEvents,
	}
end

-- ========== Client API ========== --

function EventService.Client:GetActiveEvents(player)
	return buildActiveEventsPayload(player)
end

function EventService.Client:GetEventAdminSignals(_player)
	return AdminSignalDispatcher.CollectManifest(handlersByName)
end

-- ========== SparkMod Hooks ========== --

Events.OnBeforeActivate = function(eventName, _handler, context)
	local trove = Trove.new()

	activeGameContexts[eventName] = {
		trove = trove,
		eventName = eventName,
		isGlobal = context.isGlobal or false,
	}

	context.trove = trove
	context.isGlobalEvent = context.isGlobal or false
	context.icon = EventDefinitions.getIcon(eventName, context.Config)
	context.signal = buildSignalFn(eventName)

	signalHandlersByEvent[eventName] = {}
	context.onSignal = function(action, signalHandler)
		signalHandlersByEvent[eventName][action] = signalHandler
	end

	return context
end

Events.OnAfterDeactivate = function(eventName, _handler)
	local gameContext = activeGameContexts[eventName]
	if gameContext then
		gameContext.trove:Clean()
		activeGameContexts[eventName] = nil
	end
	signalHandlersByEvent[eventName] = nil
end

-- ========== Client Broadcasts ========== --

local function onEventStarted(eventName, event)
	EventService.EventAdded:Fire(eventName)

	local function announce()
		for _, player in Players:GetPlayers() do
			task.spawn(function()
				local isFirstTime = markSeenAndCheck(player, eventName)
				EventService.Client.EventStarted:Fire(player, {
					eventName = eventName,
					endsAt = event.endsAt,
					duration = event.duration,
					config = event.config or {},
					isFirstTime = isFirstTime,
				})
			end)
		end
	end

	local definition = EventDefinitions.get(eventName)
	if definition and not shouldBypassRoundGate(eventName, definition) and not eventReady(definition) then
		whenRoundReady(eventName, definition, announce, {
			scope = if event.isGlobal then "global-active-local-wait" else "local-active-wait",
			triggeredBy = event.triggeredBy,
			durationSeconds = event.duration,
			config = event.config,
		})
	else
		announce()
	end
end

local function onEventEnded(eventName)
	pendingRoundGated[eventName] = nil
	pendingRoundGatedDetails[eventName] = nil
	EventService.Client.EventEnded:FireAll(eventName)
	EventService.EventRemoved:Fire(eventName)
end

local function onEventPaused(eventName, remaining)
	EventService.Client.EventPaused:FireAll({ eventName = eventName, remaining = remaining })
end

local function onEventResumed(eventName, endsAt)
	EventService.Client.EventResumed:FireAll({ eventName = eventName, endsAt = endsAt })
end

local function onEventStateChanged(eventName, state, changedKeys)
	EventService.Client.EventStateChanged:FireAll({
		eventName = eventName,
		state = state or {},
		changedKeys = changedKeys or {},
	})
end

-- ========== Lifecycle ========== --

function EventService:KnitStart()
	self.Client.ClientEventSignal:Connect(function(player, payload)
		local handlers = signalHandlersByEvent[payload.eventName]
		if not handlers then return end
		local handler = handlers[payload.action]
		if not handler then return end
		local args = payload.args or {}
		local ok, err = pcall(handler, player, payload.instance, table.unpack(args))
		if not ok then
			warn(`[EventService] onSignal '{payload.eventName}.{payload.action}' error: {err}`)
		end
	end)

	pcall(function()
		MessagingService:SubscribeAsync(EVENT_FALLBACK_TOPIC, function(message)
			local d = message.Data
			if type(d) == "table" and d.name then
				print(`[EventService] received fallback event '{d.name}' duration={d.durationSeconds or "default"}`)
				Events:StartLocal(d.name, d.durationSeconds, d.config)
			end
		end)
	end)

	for _, child in script:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, handler = pcall(require, child)
			if ok and typeof(handler) == "table" then
				handlersByName[child.Name] = handler
				Events:Register(child.Name, handler)
			else
				warn(`[EventService] Failed to load handler: {child.Name}`)
			end
		end
	end

	Events.Started:Connect(onEventStarted)
	Events.Ended:Connect(onEventEnded)
	Events.Paused:Connect(onEventPaused)
	Events.Resumed:Connect(onEventResumed)
	Events.StateChanged:Connect(onEventStateChanged)
end

return EventService
