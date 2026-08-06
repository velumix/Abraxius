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

local RunService = game:GetService("RunService")
local Remotes = require(script.Parent.Internal.Remotes)
local EventTypes = require(script.Parent.Types.Events)
local Signal = require(script.Parent.Internal.Signal)

-- ========== State ========== --

local activeEvents: { [string]: EventTypes.EventState } = {}
local registeredNames: { string } = {}
local initialized = false
local synced = false

-- ========== Module ========== --

local Events = {}

Events.Started = Signal.new()
Events.Ended = Signal.new()
Events.Paused = Signal.new()
Events.Resumed = Signal.new()
Events.StateChanged = Signal.new()
Events.Ready = Signal.new()

-- ========== Queries ========== --

function Events:IsActive(eventName: string): boolean
	return activeEvents[eventName] ~= nil
end

function Events:GetActive(eventName: string): EventTypes.EventState?
	return activeEvents[eventName]
end

function Events:GetAllActive(): { [string]: EventTypes.EventState }
	return activeEvents
end

function Events:GetRegisteredNames(): { string }
	return registeredNames
end

-- ========== Async Queries ========== --

function Events:IsActiveAsync(eventName: string): boolean
	if not synced then Events.Ready:Wait() end
	return Events:IsActive(eventName)
end

function Events:GetActiveAsync(eventName: string): EventTypes.EventState?
	if not synced then Events.Ready:Wait() end
	return Events:GetActive(eventName)
end

function Events:GetAllActiveAsync(): { [string]: EventTypes.EventState }
	if not synced then Events.Ready:Wait() end
	return Events:GetAllActive()
end

function Events:GetRegisteredNamesAsync(): { string }
	if not synced then Events.Ready:Wait() end
	return Events:GetRegisteredNames()
end

-- ========== Initialization ========== --

function Events:Init()
	if initialized then return end
	initialized = true

	Remotes:Init()

	if RunService:IsServer() then
		return
	end

	-- Client: listen for server pushes
	Remotes:OnClient("SparkMod.Events.Started", function(eventName: string, state: EventTypes.EventState)
		activeEvents[eventName] = state
		Events.Started:Fire(eventName, state)
	end)

	Remotes:OnClient("SparkMod.Events.Ended", function(eventName: string)
		activeEvents[eventName] = nil
		Events.Ended:Fire(eventName)
	end)

	Remotes:OnClient("SparkMod.Events.Paused", function(eventName: string, remaining: number)
		local event = activeEvents[eventName]
		if event then
			event.paused = true
			event.remainingAtPause = remaining
			event.status = "paused"
		end
		Events.Paused:Fire(eventName, remaining)
	end)

	Remotes:OnClient("SparkMod.Events.Resumed", function(eventName: string, endsAt: number)
		local event = activeEvents[eventName]
		if event then
			event.paused = false
			event.remainingAtPause = nil
			event.endsAt = endsAt
			event.status = "active"
		end
		Events.Resumed:Fire(eventName, endsAt)
	end)

	Remotes:OnClient("SparkMod.Events.StateChanged", function(eventName: string, state: { [string]: any }, changedKeys: { string })
		local event = activeEvents[eventName]
		if event then
			if not event.state then event.state = {} end
			for key, value in state do
				event.state[key] = value
			end
		end
		Events.StateChanged:Fire(eventName, state, changedKeys)
	end)

	Remotes:OnClient("SparkMod.Events.Sync", function(data: { events: { [string]: EventTypes.EventState }, registeredNames: { string } })
		activeEvents = data.events or {}
		registeredNames = data.registeredNames or {}
		if not synced then synced = true; Events.Ready:Fire() end
	end)

	-- Request initial state
	task.spawn(function()
		local result = Remotes:InvokeServer("SparkMod.Events.GetState")
		if result and typeof(result) == "table" then
			activeEvents = result.events or {}
			registeredNames = result.registeredNames or {}
		end
		if not synced then synced = true; Events.Ready:Fire() end
	end)
end

return Events
