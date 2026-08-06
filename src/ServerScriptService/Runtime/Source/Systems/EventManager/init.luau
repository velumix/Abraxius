local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService('RunService')
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)

local EventInteract = Mince:GetEvent("EventInteract")
local EventToggle = Mince:GetEvent("EventToggle")

local CreatureEventNotice = Mince:Get("CreatureEventNotice")
local Notice = Mince:Get("Notice")
local DEFAULT_EVENT_COOLDOWN = 60

local EventManager = {
	Name = "EventManager",
	Events = {},
	ActiveTimers = {},
	Random = Random.new(os.clock()),
	CheckingEnabled = true,
	PostEventCooldown = DEFAULT_EVENT_COOLDOWN,
	_lastEventId = nil,
}

local function resolveEventChance(value)
	local chance = tonumber(value)
	if not chance then
		return 1
	end

	return math.clamp(chance, 0, 1)
end

function EventManager.SetNextWaitDuration(duration)
	local minCooldown = math.max(EventManager.PostEventCooldown or 0, 0)
	local resolved = tonumber(duration)

	if not resolved or resolved <= 0 then
		resolved = minCooldown
	end

	if minCooldown > 0 and resolved < minCooldown then
		resolved = minCooldown
	end

	if not resolved or resolved <= 0 then
		warn("Attempted to set invalid wait duration for next event.")
		return nil
	end

	EventManager.EventWaitDuration = resolved
	return resolved
end

local function getPlayer(value)
	if typeof(value) == "Instance" and value:IsA("Player") then
		return value
	end
	return nil
end

local function getColor(value)
	if typeof(value) == "Color3" then
		return value
	end
	return nil
end

local function sendNotice(player, text, duration, sound, color)
	if not player or not player:IsA("Player") then
		return
	end

	local resolvedColor = getColor(color) or Color3.new(1, 1, 1)
	if Notice and Notice.SendNotice then
		Notice.SendNotice(player, text, resolvedColor, duration, sound)
	else
		CreatureEventNotice:Send(player, text, duration, sound, resolvedColor)
	end
end

local function broadcastNotice(text, duration, sound, color)
	for _, player in Players:GetPlayers() do
		sendNotice(player, text, duration, sound, color)
	end
end

function EventManager.Message(...)
	local args = table.pack(...)

	if args.n > 0 then
		local first = args[1]
		if typeof(first) == "table" and first ~= EventManager then
			if first.Message and args.n > 1 then
				table.remove(args, 1)
				args.n = args.n - 1
			end
		end
	end

	local text = args[1]
	local duration = args[2]
	local sound = args[3]
	local color = getColor(args[4])
	local player = if color then getPlayer(args[5]) else getPlayer(args[4])

	if not color then
		color = getColor(args[5])
	end

	if not player then
		player = getPlayer(args[5])
	end

	if typeof(text) == "table" then
		local template = text
		text = template.text or template[1]
		duration = duration or template.duration or template[2]
		sound = sound or template.sound or template[3]
		color = color or getColor(template.color) or getColor(template[4]) or getColor(template[5])
		if not player then
			player = template.player or template.targetPlayer or template[4] or template[5]
		end
	end

	if typeof(text) ~= "string" or text == "" then
		return
	end

	player = getPlayer(player)
	color = getColor(color)

	if player then
		sendNotice(player, text, duration, sound, color)
		return
	end

	broadcastNotice(text, duration, sound, color)
end

function EventManager.StartEventTimer(event)
	local eventId = event.Name or tostring(event)

	if EventManager.ActiveTimers[eventId] then
		return
	end

	local function scheduleNext()
		local waitTime = event:GetNextWait()

		EventManager.ActiveTimers[eventId] = task.delay(waitTime, function()
			EventManager.ActiveTimers[eventId] = nil

			local chance = resolveEventChance(event.EventChance)
			if EventManager.Random:NextNumber() <= chance then
				EventManager.TriggerEvent(event)
			else
				-- print("Event skipped due to chance:", event.Name)
			end

			scheduleNext()
		end)
	end

	scheduleNext()
end

function EventManager.TriggerEvent(event)
	EventManager._lastEventId = event.Identifier or event.Name or tostring(event)

	local storage = {
		Message = EventManager.Message,
		End = function()
			if event.End then
				event:End()
			end
		end,
		SetNextWait = function(duration)
			EventManager.SetNextWaitDuration(duration)
		end,
		IsEnabled = true
	}

	local success, result = pcall(function()
		if event.Start then
			return event:Start(storage)
		end
	end)

	if not success then
		warn("Event failed:", event.Name, result)
	end

	return success
end

function EventManager.StopEventTimer(eventName)
	local timer = EventManager.ActiveTimers[eventName]
	if timer then
		task.cancel(timer)
		EventManager.ActiveTimers[eventName] = nil
	end
end

local function collectCandidates(skipLast)
	local candidates = {}

	for _, event in EventManager.Events do
		if not event.Disabled then
			local identifier = event.Identifier or event.Name or tostring(event)
			if not skipLast or identifier ~= EventManager._lastEventId then
				table.insert(candidates, event)
			end
		end
	end

	return candidates
end

local function shuffle(events)
	for i = #events, 2, -1 do
		local j = EventManager.Random:NextInteger(1, i)
		events[i], events[j] = events[j], events[i]
	end
end

function EventManager.GetNewEvent()
	if #EventManager.Events == 0 then
		return nil
	end

	local candidates = collectCandidates(true)
	if #candidates == 0 then
		candidates = collectCandidates(false)
	end

	if #candidates == 0 then
		return nil
	end

	shuffle(candidates)

	for _, event in candidates do
		local chance = resolveEventChance(event.EventChance)
		if chance >= 1 then
			return event
		end

		if chance > 0 and EventManager.Random:NextNumber() <= chance then
			return event
		end
	end

	return candidates[EventManager.Random:NextInteger(1, #candidates)]
end

function EventManager.EndEvent()
	if EventManager.CurrentEvent and EventManager.EventStartingPending then 
		warn(`Attempt to start event whilst previous pending event '{EventManager.CurrentEvent.Name}'!`)
		return
	end

	EventManager.EventStartingPending = false 
	EventManager.EventIsBeingActive = false
	EventManager.CheckingEnabled = false 

	EventManager.EventStorage.IsEnabled = false 

	local Success, Result = pcall(function()
		return 	EventManager.HCall("End", EventManager.EventStorage)
	end)

	if not Success then
		warn(`Error whilst ending event '{EventManager.CurrentEvent.Name}'!`)
		warn(Result)
	end

	EventManager.EventWaitingPeroid = true
	EventManager.SetNextWaitDuration(EventManager.EventWaitDuration)
	EventManager.CurrentEvent = nil
	EventManager.TimeElapsed = 0

	EventManager.CheckingEnabled = true

end

function EventManager.NextEvent()
	if EventManager.EventIsBeingActive then
		EventManager.EndEvent()
		return
	end

	EventManager.EventIsBeingActive = true

	EventManager.EventStorage = {
		Message = EventManager.Message,
		Wait = EventManager.Wait, 
		End = EventManager.EndEvent,
		SetNextWait = function(Duration)
			EventManager.SetNextWaitDuration(Duration)
		end,

		GetNextWait = function()
			return EventManager.EventWaitDuration or EventManager.PostEventCooldown
		end,

		IsActive = function()
			return EventManager.EventStorage.IsEnabled
		end,

		IsEnabled = true
	}

	EventManager.CurrentEvent = EventManager.GetNewEvent()
	EventManager.TimeElapsed = -math.huge

	EventManager.EventWaitingPeroid = false
	EventManager.EventStartingPending = true

	local Success, Failure = pcall(function()
		return EventManager.HCall("Start", EventManager.EventStorage)
	end)

	if not Success then
		warn("Event ended due to error")
		warn(Failure)

		EventManager.EventStartingPending = false
		EventManager.EndEvent()
		return
	end

	EventManager.EventStartingPending = false
	EventManager.JumpEvent()
end

function EventManager.JumpEvent()
	if not EventManager.EventIsBeingActive then return end
	EventManager.EventStartingPending = false
	EventManager.TimeElapsed = 0
end

function EventManager.GetEvent() 
	if not EventManager.CheckingEnabled then return end 
	return not EventManager.EventWaitingPeroid and EventManager.CurrentEvent and EventManager.CurrentEvent.Name
end

function EventManager.Update(DeltaTime)
	EventManager.TimeElapsed += DeltaTime

	if EventManager.CheckingEnabled then
		if EventManager.EventWaitingPeroid then 
			if EventManager.TimeElapsed > EventManager.EventWaitDuration then
				EventManager.NextEvent()
			end
		else
			if EventManager.CurrentEvent then
				if EventManager.TimeElapsed > EventManager.CurrentEvent.EventDuration then
					EventManager.EndEvent()
				end
			end
		end

	end
end

function EventManager.LoadEvents()
	for _, EventModuleScript in script.Events:GetChildren() do 
		local success, event = pcall(require, EventModuleScript)

		if not success then
			warn("[EventManager] Failed to load event:", EventModuleScript.Name, event)
			continue
		end

		if event.Disabled then 
			continue 
		end

		table.insert(EventManager.Events, event)
	end
end

function EventManager.PlayerAdded(Player :Player)
	Player:SetAttribute("Events", true)
end 

function EventManager:Setup()

	for _, Player in Players:GetPlayers() do
		EventManager.PlayerAdded(Player)
	end

	Players.PlayerAdded:Connect(EventManager.PlayerAdded)

	EventToggle.Event:Connect(function(Player :Player, Bool)
		assert(typeof(Bool) == "boolean", "Must be an boolean")
		Player:SetAttribute("Events", Bool)
	end)

	EventInteract.Event:Connect(function(...)

	end)
end

function EventManager:GameStart()
	EventManager.LoadEvents()
end

return EventManager