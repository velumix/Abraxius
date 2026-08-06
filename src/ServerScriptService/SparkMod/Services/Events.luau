--!strict

--[[
	SparkMod — Centralized Coordinator for Roblox Game Servers

	Copyright 2026 Nicholas Rice

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

		http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
]]

-- ========== Dependencies ========== --

local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)
local Http = require(script.Parent.Parent.Internal.Http)
local MessageRouter = require(script.Parent.Parent.Internal.MessageRouter)
local Remotes = require(game.ReplicatedStorage.SparkMod.Internal.Remotes)
local EventTypes = require(game.ReplicatedStorage.SparkMod.Types.Events)

-- ========== Types ========== --

type ActiveEvent = {
	handler: EventTypes.Handler,
	eventName: string,
	endsAt: number,
	duration: number,
	paused: boolean,
	remainingAtPause: number?,
	config: { [string]: any },
	state: { [string]: any },
	stateSignal: Signal.Type,
	timerThread: thread?,
	isGlobal: boolean,
	triggeredBy: string?,
}

-- ========== State ========== --

local initialized = false
local ready = false

local handlers: { [string]: EventTypes.Handler } = {}
local builtInFlags: { [string]: boolean } = {}
local activeEvents: { [string]: ActiveEvent } = {}

local pendingHydration: { [string]: { duration: number, config: { [string]: any }?, state: { [string]: any }?, paused: boolean, remainingAtPause: number? } } = {}

-- ========== Signals ========== --

local Events = {}

Events.Ready = Signal.new()

Events.Started = Signal.new()
Events.Ended = Signal.new()
Events.Paused = Signal.new()
Events.Resumed = Signal.new()
Events.StateChanged = Signal.new()
Events.RegistrationChanged = Signal.new()

-- ========== Hooks ========== --

Events.OnBeforeActivate = nil :: ((eventName: string, handler: EventTypes.Handler, context: EventTypes.Context) -> EventTypes.Context)?
Events.OnAfterDeactivate = nil :: ((eventName: string, handler: EventTypes.Handler) -> ())?

-- ========== Registration ========== --

function Events:Register(eventName: string, handler: EventTypes.Handler, options: EventTypes.HandlerOptions?)
	local opts: EventTypes.HandlerOptions = options or {}
	local isBuiltIn = opts.builtIn == true
	local existingIsBuiltIn = builtInFlags[eventName] == true

	if handlers[eventName] then
		if existingIsBuiltIn and not isBuiltIn then
			-- Rung 4: public registration overriding a built-in handler — allowed.
		elseif existingIsBuiltIn and isBuiltIn then
			error(`[SparkMod.Events] Duplicate built-in registration for '{eventName}'`)
		else
			error(`[SparkMod.Events] Handler for '{eventName}' is already registered`)
		end
	end

	handlers[eventName] = handler
	builtInFlags[eventName] = isBuiltIn
	Events.RegistrationChanged:Fire()

	local pending = pendingHydration[eventName]
	if pending then
		pendingHydration[eventName] = nil
		
		if pending.paused then
			Events._Activate(eventName, pending.remainingAtPause or 0, pending.config, pending.state, nil, true)
			Events._Pause(eventName, pending.remainingAtPause)
		else
			if pending.duration > 0 then
				Events._Activate(eventName, pending.duration, pending.config, pending.state, nil, true)
			end
		end
	end
end

function Events:Unregister(eventName: string)
	if activeEvents[eventName] then
		Events._Deactivate(eventName)
	end
	handlers[eventName] = nil
	builtInFlags[eventName] = nil
end

function Events:IsRegistered(eventName: string): boolean
	return handlers[eventName] ~= nil
end

function Events:GetRegisteredNames(): { string }
	local names = {}
	for name in handlers do
		table.insert(names, name)
	end
	return names
end

function Events:GetManifest(): { EventTypes.EventManifestEntry }
	local manifest = {}
	for name, handler in handlers do
		table.insert(manifest, {
			name = name,
			duration = handler.Duration or 60,
			override = handler.Override or "queue",
			builtIn = builtInFlags[name] == true,
		})
	end
	return manifest
end

-- ========== Queries ========== --

function Events:IsActive(eventName: string): boolean
	return activeEvents[eventName] ~= nil
end

function Events:GetActive(eventName: string): ActiveEvent?
	return activeEvents[eventName]
end

function Events:GetAllActive(): { [string]: ActiveEvent }
	return activeEvents
end

-- ========== Async Queries ========== --

function Events:IsActiveAsync(eventName: string): boolean
	if not ready then Events.Ready:Wait() end
	return Events:IsActive(eventName)
end

function Events:GetActiveAsync(eventName: string): ActiveEvent?
	if not ready then Events.Ready:Wait() end
	return Events:GetActive(eventName)
end

function Events:GetAllActiveAsync(): { [string]: ActiveEvent }
	if not ready then Events.Ready:Wait() end
	return Events:GetAllActive()
end

-- ========== Internal Lifecycle ========== --

local function stopTimer(event: ActiveEvent)
	if event.timerThread then
		pcall(task.cancel, event.timerThread)
		event.timerThread = nil
	end
end

function Events._Deactivate(eventName: string)
	local event = activeEvents[eventName]
	if not event then return end

	stopTimer(event)

	if event.handler.Deactivate then
		local ok, err = pcall(event.handler.Deactivate)
		if not ok then
			warn(`[SparkMod.Events] Deactivate error for '{eventName}': {err}`)
		end
	end

	if Events.OnAfterDeactivate then
		pcall(Events.OnAfterDeactivate, eventName, event.handler)
	end

	event.stateSignal:Destroy()
	
	activeEvents[eventName] = nil
	Events.Ended:FireAsync(eventName)
end

function Events._Activate(eventName: string, durationSeconds: number, config: { [string]: any }?, state: { [string]: any }?, startTime: number?, isGlobal: boolean?, triggeredBy: string?)
	local existing = activeEvents[eventName]

	if existing then
		if existing.isGlobal and not isGlobal then
			return
		end
		
		Events._Deactivate(eventName)
	end

	local handler = handlers[eventName]
	if not handler then
		warn(`[SparkMod.Events] No handler registered for '{eventName}', ignoring activation`)
		return
	end

	if handler.CanActivate then
		local canActivate, reason = handler.CanActivate()
		if not canActivate then
			warn(`[SparkMod.Events] CanActivate rejected '{eventName}': {reason or "unknown"}`)
			return
		end
	end

	local now = os.time()
	local effectiveStart = startTime or now
	local endsAt = now + durationSeconds
	local stateSignal = Signal.new()

	local event: ActiveEvent = {
		handler = handler,
		eventName = eventName,
		endsAt = endsAt,
		duration = durationSeconds,
		paused = false,
		remainingAtPause = nil,
		config = config or {},
		state = state or {},
		stateSignal = stateSignal,
		timerThread = nil,
		isGlobal = isGlobal or false,
		triggeredBy = triggeredBy,
	}

	activeEvents[eventName] = event

	event.timerThread = task.delay(durationSeconds, function()
		if activeEvents[eventName] == event then
			Events._Deactivate(eventName)
		end
	end)

	local context: EventTypes.Context = {
		EventName = eventName,
		Duration = durationSeconds,
		Remaining = durationSeconds,
		Config = event.config,
		State = event.state,
		StartTime = effectiveStart,
		isGlobal = event.isGlobal,
		Signal = function(action: string, ...: any)
			Events.StateChanged:FireAsync(eventName, action, ...)
		end,
	}

	if Events.OnBeforeActivate then
		local ok, enriched = pcall(Events.OnBeforeActivate, eventName, handler, context)
		if ok and enriched then
			context = enriched
		end
	end

	if handler.Activate then
		local ok, err = pcall(handler.Activate, context)
		if not ok then
			warn(`[SparkMod.Events] Activate error for '{eventName}': {err}`)
		end
	end

	Events.Started:FireAsync(eventName, event)
end

function Events._Pause(eventName: string, remainingSeconds: number?)
	local event = activeEvents[eventName]
	if not event or event.paused then return end

	stopTimer(event)
	
	local remaining = remainingSeconds or math.max(0, event.endsAt - os.time())
	event.paused = true
	event.remainingAtPause = remaining

	Events.Paused:FireAsync(eventName, remaining)
end

function Events._Resume(eventName: string, newEndsAt: number?)
	local event = activeEvents[eventName]
	if not event or not event.paused then return end

	local remaining = event.remainingAtPause or 0
	local endsAt = newEndsAt or (os.time() + remaining)

	event.paused = false
	event.remainingAtPause = nil
	event.endsAt = endsAt

	event.timerThread = task.delay(math.max(0, endsAt - os.time()), function()
		if activeEvents[eventName] == event then
			Events._Deactivate(eventName)
		end
	end)

	Events.Resumed:FireAsync(eventName, endsAt)
end

function Events._ApplyState(eventName: string, stateUpdates: { [string]: any }, changedKeys: { string })
	local event = activeEvents[eventName]
	if not event then return end

	for key, value in stateUpdates do
		event.state[key] = value
	end

	event.stateSignal:Fire(event.state, changedKeys)

	if event.handler.StateChanged then
		local ok, err = pcall(event.handler.StateChanged, event.state, changedKeys)
		if not ok then
			warn(`[SparkMod.Events] StateChanged error for '{eventName}': {err}`)
		end
	end

	Events.StateChanged:FireAsync(eventName, event.state, changedKeys)
end

-- ========== Coordinator Message Handler ========== --

local function onCoordinatorEvent(action: string, data: { [string]: any })
	local eventName = data.eventName
	if not eventName then return end

	if action == "start" or action == "override" then
		local remaining = if data.endsAt then math.max(0, (data.endsAt :: number) - os.time()) else (data.durationSeconds or 0)
		if handlers[eventName] then
			Events._Activate(eventName, remaining, data.config, data.state, nil, true, data.triggeredBy)
		elseif remaining > 0 then
			-- Handler still loading (boot-window race): park so the event activates the
			-- instant its handler registers instead of being dropped. Mirrors _Hydrate.
			pendingHydration[eventName] = {
				duration = remaining,
				config = data.config,
				state = data.state,
				paused = false,
			}
		end
	elseif action == "cancel" then
		pendingHydration[eventName] = nil
		Events._Deactivate(eventName)
	elseif action == "pause" then
		Events._Pause(eventName, data.remainingSeconds)
	elseif action == "resume" then
		Events._Resume(eventName, data.endsAt)
	elseif action == "state" then
		Events._ApplyState(eventName, data.stateUpdates or {}, data.changedKeys or {})
	end
end

-- ========== Backend Requests ========== --

function Events:Start(eventName: string, durationSeconds: number, triggeredBy: string, config: { [string]: any }?, overrideBehavior: string?)
	local handler = handlers[eventName]
	return Http.Post("/game/events/start", {
		eventName = eventName,
		durationSeconds = durationSeconds or (handler and handler.Duration) or 60,
		triggeredBy = triggeredBy,
		config = config,
		overrideBehavior = overrideBehavior or (handler and handler.Override) or "queue",
	})
end

function Events:Cancel(eventName: string)
	return Http.Post("/game/events/cancel", { eventName = eventName })
end

function Events:Pause(eventName: string)
	return Http.Post("/game/events/pause", { eventName = eventName })
end

function Events:Resume(eventName: string)
	return Http.Post("/game/events/resume", { eventName = eventName })
end

function Events:Extend(eventName: string, additionalSeconds: number)
	return Http.Post("/game/events/extend", {
		eventName = eventName,
		additionalSeconds = additionalSeconds,
	})
end

function Events:UpdateState(eventName: string, stateUpdates: { [string]: any })
	return Http.Post("/game/events/state", {
		eventName = eventName,
		stateUpdates = stateUpdates,
	})
end

function Events:Queue(eventName: string, durationSeconds: number, triggeredBy: string, config: { [string]: any }?)
	local handler = handlers[eventName]
	return Http.Post("/game/events/queue", {
		eventName = eventName,
		durationSeconds = durationSeconds or (handler and handler.Duration) or 60,
		triggeredBy = triggeredBy,
		config = config,
	})
end

-- ========== Local Events ========== --

function Events:StartLocal(eventName: string, durationSeconds: number?, config: { [string]: any }?, triggeredBy: string?)
	local handler = handlers[eventName]
	if not handler then
		return false, `Event '{eventName}' is not registered`
	end
	
	local duration = durationSeconds or handler.Duration or 60
	Events._Activate(eventName, duration, config, nil, nil, false, triggeredBy)
	
	return true, nil
end

function Events:CancelLocal(eventName: string)
	local event = activeEvents[eventName]
	if not event then return end
	if event.isGlobal then return end
	
	Events._Deactivate(eventName)
end

function Events:IsGlobal(eventName: string): boolean
	local event = activeEvents[eventName]
	return event ~= nil and event.isGlobal
end

-- ========== Initialization ========== --

function Events._Init()
	if initialized then return end
	initialized = true

	MessageRouter.Register("event", onCoordinatorEvent)
	Remotes:Init()

	Events.Started:Connect(function(eventName, event)
		Remotes:FireAllClients("SparkMod.Events.Started", eventName, {
			eventName = eventName,
			status = "active",
			endsAt = event.endsAt,
			duration = event.duration,
			paused = false,
			config = event.config,
			state = event.state,
			triggeredBy = event.triggeredBy,
		})
	end)

	Events.Ended:Connect(function(eventName)
		Remotes:FireAllClients("SparkMod.Events.Ended", eventName)
	end)

	Events.Paused:Connect(function(eventName, remaining)
		Remotes:FireAllClients("SparkMod.Events.Paused", eventName, remaining)
	end)

	Events.Resumed:Connect(function(eventName, endsAt)
		Remotes:FireAllClients("SparkMod.Events.Resumed", eventName, endsAt)
	end)

	Events.StateChanged:Connect(function(eventName, state, changedKeys)
		Remotes:FireAllClients("SparkMod.Events.StateChanged", eventName, state, changedKeys)
	end)

	Remotes:OnInvoke("SparkMod.Events.GetState", function(player)
		local eventStates: { [string]: any } = {}
		for name, event in activeEvents do
			eventStates[name] = {
				eventName = name,
				status = if event.paused then "paused" else "active",
				endsAt = event.endsAt,
				duration = event.duration,
				paused = event.paused,
				remainingAtPause = event.remainingAtPause,
				config = event.config,
				state = event.state,
			}
		end
		
		return {
			events = eventStates,
			registeredNames = Events:GetRegisteredNames(),
		}
	end)
end

function Events._Hydrate(syncData: { [string]: any })
	local cachedEvents = syncData.events
	if not cachedEvents or typeof(cachedEvents) ~= "table" then
		ready = true
		Events.Ready:Fire()
		return
	end

	for eventName, eventData in cachedEvents do
		if typeof(eventData) == "table" and (eventData.status == "active" or eventData.status == "paused") then
			if eventData.status == "active" then
				local remaining = math.max(0, (eventData.endsAt or 0) - os.time())
				if remaining > 0 and not activeEvents[eventName] then
					if handlers[eventName] then
						Events._Activate(eventName, remaining, eventData.config, eventData.state, nil, true)
					else
						pendingHydration[eventName] = {
							duration = remaining,
							config = eventData.config,
							state = eventData.state,
							paused = false,
						}
					end
				end
			elseif eventData.status == "paused" then
				if not activeEvents[eventName] then
					if handlers[eventName] then
						Events._Activate(eventName, eventData.remainingAtPause or 0, eventData.config, eventData.state, nil, true)
						Events._Pause(eventName, eventData.remainingAtPause)
					else
						pendingHydration[eventName] = {
							duration = eventData.remainingAtPause or 0,
							config = eventData.config,
							state = eventData.state,
							paused = true,
							remainingAtPause = eventData.remainingAtPause,
						}
					end
				end
			end
		end
	end

	ready = true
	Events.Ready:Fire()
end

return Events
