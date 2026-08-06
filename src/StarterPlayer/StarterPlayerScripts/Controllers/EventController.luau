local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

local EventDefinitions = require(ReplicatedStorage.Config.EventDefinitions)
local AdminAnnounceSound = require(ReplicatedStorage.Modules.AdminAnnounceSound)
-- LightingController deferred (no presets yet)
-- local LightingController = require(script.Parent.Parent.Util.LightingController)

local EventController = Knit.CreateController({
	Name = "EventController",
})

local function escapeRich(s: string): string
	s = tostring(s)
	s = s:gsub("&", "&amp;")
	s = s:gsub("<", "&lt;")
	s = s:gsub(">", "&gt;")
	return s
end

local function showEventNotification(title: string, text: string)
	AdminAnnounceSound.Play()

	local notificationController = Knit.GetController("NotificationController")
	if notificationController then
		notificationController:Notify({
			text = `{title} — {text}`,
			rich = `<b><font color="#FFD75A">{escapeRich(title)}</font></b><br/><font color="#FFFFFF">{escapeRich(text)}</font>`,
			Duration = 6,
		})
	end
end

EventController.activeEvents = {}
EventController.eventHandlers = {}
EventController.EventAdded = Signal.new()
EventController.EventRemoved = Signal.new()
EventController.EventPaused = Signal.new()
EventController.EventResumed = Signal.new()
EventController.EventUpdated = Signal.new()
EventController.EventOverridden = Signal.new()
EventController.EventStateChanged = Signal.new()

local eventService

local function getEventHandler(eventName)
	if EventController.eventHandlers[eventName] then
		return EventController.eventHandlers[eventName]
	end

	local handlerModule = script:FindFirstChild(eventName)
	if not handlerModule then
		return nil
	end

	local handler = require(handlerModule)
	EventController.eventHandlers[eventName] = handler
	return handler
end

local function onEventStarted(eventName, endsAt, config, duration, isFirstTime, joinedMidEvent)
	local existingEvent = EventController.activeEvents[eventName]

	if existingEvent then
		existingEvent.endsAt = endsAt
		existingEvent.config = config
		existingEvent.paused = nil
		if duration then
			existingEvent.duration = duration
		end

		EventController.EventOverridden:Fire(eventName, endsAt, config)
		return
	end

	local trove = Trove.new()
	local eventDuration = duration or (endsAt - os.time())

	EventController.activeEvents[eventName] = {
		trove = trove,
		endsAt = endsAt,
		duration = eventDuration,
		paused = nil,
		config = config,
		state = {},
	}

	local handler = getEventHandler(eventName)
	local definition = EventDefinitions.get(eventName)
	local isMidEvent = joinedMidEvent or (config and config.midEvent)

	if handler and handler.onActivate then
		local context = {
			trove = trove,
			endsAt = endsAt,
			duration = eventDuration,
			isFirstTime = isFirstTime,
			joinedMidEvent = isMidEvent,
		}

		handler:onActivate(context)
	end

	EventController.EventAdded:Fire(eventName, endsAt, config)

	if definition and not definition.silent then
		local displayName = EventDefinitions.getDisplayName(eventName, config)
		local text = EventDefinitions.getDescription(eventName, config) or (displayName .. " has started!")
		showEventNotification(displayName, text)
	end
end

local function onEventEnded(eventName)
	local event = EventController.activeEvents[eventName]

	if not event then
		return
	end

	local handler = getEventHandler(eventName)
	if handler and handler.onDeactivate then
		handler:onDeactivate()
	end

	event.trove:Clean()
	EventController.activeEvents[eventName] = nil

	EventController.EventRemoved:Fire(eventName)
end

local function onEventPaused(eventName, remaining)
	local event = EventController.activeEvents[eventName]
	if not event then return end

	event.paused = remaining

	EventController.EventPaused:Fire(eventName, remaining)
end

local function onEventResumed(eventName, endsAt)
	local event = EventController.activeEvents[eventName]
	if not event then return end

	event.paused = nil
	event.endsAt = endsAt

	EventController.EventResumed:Fire(eventName, endsAt)
end

local function onEventUpdated(eventName, newConfig)
	local event = EventController.activeEvents[eventName]
	if not event then return end

	event.config = newConfig

	EventController.EventUpdated:Fire(eventName, newConfig)
end

local function onEventStateChanged(eventName, state, changedKeys)
	local event = EventController.activeEvents[eventName]
	if not event then return end
	event.state = state
	EventController.EventStateChanged:Fire(eventName, state, changedKeys)
end

function EventController:fireSignal(eventName, action, ...)
	local args = { ... }
	local inst = nil
	if typeof(args[1]) == "Instance" then
		inst = args[1]
		table.remove(args, 1)
	end
	eventService.ClientEventSignal:Fire({
		eventName = eventName,
		action = action,
		instance = inst,
		args = args,
	})
end

function EventController:isEventActive(eventName)
	return self.activeEvents[eventName] ~= nil
end

function EventController:isEventPaused(eventName)
	local event = self.activeEvents[eventName]
	return event and event.paused ~= nil
end

function EventController:getEventEndsAt(eventName)
	local event = self.activeEvents[eventName]
	return event and event.endsAt
end

function EventController:getEventDuration(eventName)
	local event = self.activeEvents[eventName]
	return event and event.duration
end

function EventController:getEventPausedRemaining(eventName)
	local event = self.activeEvents[eventName]
	return event and event.paused
end

function EventController:getEventConfig(eventName)
	local event = self.activeEvents[eventName]
	return event and event.config
end

function EventController:getEventState(eventName)
	local event = self.activeEvents[eventName]
	return if event then event.state else nil
end

function EventController:getActiveEventNames()
	local names = {}
	for name in self.activeEvents do
		table.insert(names, name)
	end
	return names
end

function EventController:getEventDefinition(eventName)
	return EventDefinitions.get(eventName)
end

function EventController:hasActiveLightingEvent()
	for eventName in self.activeEvents do
		local definition = EventDefinitions.get(eventName)
		if definition and definition.lightingPreset then
			return true
		end
	end
	return false
end

function EventController:getHighestPriorityLighting()
	local bestPreset = nil
	local bestPriority = -1

	for eventName in self.activeEvents do
		local definition = EventDefinitions.get(eventName)
		if definition and definition.lightingPreset then
			local handler = getEventHandler(eventName)
			local priority = (handler and handler.lightingPriority) or 1
			if priority > bestPriority then
				bestPriority = priority
				bestPreset = definition.lightingPreset
			end
		end
	end

	return bestPreset
end

function EventController:KnitStart()
	eventService = Knit.GetService("EventService")

	for _, handlerScript in script:GetChildren() do
		if handlerScript:IsA("ModuleScript") then
			EventController.eventHandlers[handlerScript.Name] = require(handlerScript)
		end
	end

	eventService.EventStarted:Connect(function(payload)
		onEventStarted(payload.eventName, payload.endsAt, payload.config, payload.duration, payload.isFirstTime)
	end)

	eventService.EventEnded:Connect(function(eventName)
		onEventEnded(eventName)
	end)

	eventService.EventPaused:Connect(function(payload)
		onEventPaused(payload.eventName, payload.remaining)
	end)

	eventService.EventResumed:Connect(function(payload)
		onEventResumed(payload.eventName, payload.endsAt)
	end)

	eventService.EventStateChanged:Connect(function(payload)
		onEventStateChanged(payload.eventName, payload.state or {}, payload.changedKeys or {})
	end)

	eventService.EventSignal:Connect(function(payload)
		local handler = getEventHandler(payload.eventName)
		if handler and handler.onSignal then
			local args = payload.args or {}
			handler:onSignal(payload.action, payload.instance, table.unpack(args))
		end
	end)

	-- empty table = valid "no active events"
	local active
	for _ = 1, 5 do
		local ok, result = pcall(function()
			return eventService:GetActiveEvents()
		end)
		if ok and typeof(result) == "table" then
			active = result
			break
		end
		task.wait(0.5)
	end

	if active then
		for eventName, data in active do
			onEventStarted(eventName, data.endsAt, data.config, data.duration, data.isFirstTime, true)
			if data.paused then
				onEventPaused(eventName, data.paused)
			end
			if data.state then
				local event = EventController.activeEvents[eventName]
				if event then
					event.state = data.state
				end
			end
		end
	end
end

return EventController
