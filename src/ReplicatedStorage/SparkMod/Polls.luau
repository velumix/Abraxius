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
local Signal = require(script.Parent.Internal.Signal)
local PollTypes = require(script.Parent.Types.Polls)

-- ========== State ========== --

local activePolls: { [string]: PollTypes.PollData } = {}
local initialized = false
local synced = false
local initialized = false
local synced = false

-- ========== Module ========== --

local Polls = {}

Polls.PollStarted = Signal.new()
Polls.PollEnded = Signal.new()
Polls.TalliesUpdated = Signal.new()
Polls.Ready = Signal.new()

-- ========== Queries ========== --

function Polls:GetActive(): { [string]: PollTypes.PollData }
	return activePolls
end

function Polls:GetResults(pollId: string): PollTypes.PollData?
	return activePolls[pollId]
end

function Polls:IsActive(pollId: string): boolean
	return activePolls[pollId] ~= nil
end

function Polls:GetActiveIds(): { string }
	local ids = {}
	for pollId in activePolls do
		table.insert(ids, pollId)
	end
	table.sort(ids)
	return ids
end

-- ========== Async Queries ========== --

function Polls:GetActiveAsync(): { [string]: PollTypes.PollData }
	if not synced then Polls.Ready:Wait() end
	return Polls:GetActive()
end

function Polls:GetResultsAsync(pollId: string): PollTypes.PollData?
	if not synced then Polls.Ready:Wait() end
	return Polls:GetResults(pollId)
end

function Polls:IsActiveAsync(pollId: string): boolean
	if not synced then Polls.Ready:Wait() end
	return Polls:IsActive(pollId)
end

function Polls:GetActiveIdsAsync(): { string }
	if not synced then Polls.Ready:Wait() end
	return Polls:GetActiveIds()
end

-- ========== Initialization ========== --

function Polls:Init()
	if initialized then return end
	initialized = true

	Remotes:Init()

	if RunService:IsServer() then
		return
	end

	-- Client: listen for server pushes
	Remotes:OnClient("SparkMod.Polls.Started", function(pollData: PollTypes.PollData)
		activePolls[pollData.pollId] = pollData
		Polls.PollStarted:Fire(pollData)
	end)

	Remotes:OnClient("SparkMod.Polls.Ended", function(pollId: string, results: any)
		activePolls[pollId] = nil
		Polls.PollEnded:Fire(pollId, results)
	end)

	Remotes:OnClient("SparkMod.Polls.Tallies", function(pollId: string, tallies: { number }, totalResponses: number, playerCount: number?)
		local poll = activePolls[pollId]
		if poll then
			poll.tallies = tallies
			poll.totalResponses = totalResponses
			poll.playerCount = playerCount or poll.playerCount
		end
		Polls.TalliesUpdated:Fire(pollId, tallies, totalResponses, playerCount or 0)
	end)

	Remotes:OnClient("SparkMod.Polls.Sync", function(data: { [string]: PollTypes.PollData })
		activePolls = data or {}
		if not synced then synced = true; Polls.Ready:Fire() end
	end)

	-- Request initial state
	task.spawn(function()
		local result = Remotes:InvokeServer("SparkMod.Polls.GetState")
		if result and typeof(result) == "table" then
			activePolls = result
		end
		if not synced then synced = true; Polls.Ready:Fire() end
	end)
end

return Polls
