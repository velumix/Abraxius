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
local PollTypes = require(game.ReplicatedStorage.SparkMod.Types.Polls)

-- ========== State ========== --

local initialized = false
local ready = false

local activePolls: { [string]: PollTypes.PollData } = {}

local pendingVotes: { [string]: { { userId: number, optionIndex: number } } } = {}
local voteCallbacks: { [string]: { [number]: (boolean) -> () } } = {}

local pollTimers: { [string]: thread } = {}
local POLL_END_GRACE = 3

local POLL_RECONCILE_MISS_LIMIT = 2
local pollReconcileMisses: { [string]: number } = {}

-- ========== Signals ========== --

local Polls = {}

Polls.Ready = Signal.new()

Polls.PollStarted = Signal.new()
Polls.PollEnded = Signal.new()
Polls.TalliesUpdated = Signal.new()

-- ========== Public API ========== --

function Polls:Create(params: PollTypes.CreatePollParams): { ok: boolean, pollId: string?, error: string? }
	local response = Http.Post("/game/polls/create", {
		pollId = params.pollId,
		question = params.question,
		options = params.options,
		duration = params.duration,
		config = params.config,
	})

	if response.ok and response.body then
		return { ok = true, pollId = params.pollId }
	end

	return { ok = false, error = response.error or "Failed to create poll" }
end

function Polls:Vote(pollId: string, player: Player, optionIndex: number): { ok: boolean, changed: boolean, error: string? }
	local poll = activePolls[pollId]
	if not poll then return { ok = false, changed = false, error = "Poll not active" } end

	if not pendingVotes[pollId] then
		pendingVotes[pollId] = {}
	end
	
	table.insert(pendingVotes[pollId], {
		userId = player.UserId,
		optionIndex = optionIndex - 1,
	})

	if optionIndex >= 1 and optionIndex <= #poll.tallies then
		poll.tallies[optionIndex] += 1
		poll.totalResponses += 1
	end

	return { ok = true, changed = true, error = nil }
end

function Polls:Close(pollId: string)
	local response = Http.Post("/game/polls/close", {
		pollId = pollId,
	})

	if response.ok then
		local body = response.body :: any
		if body and body.results then
			return { ok = true :: boolean, results = body.results, error = nil :: string? }
		end
	end

	return { ok = false :: boolean, results = nil :: any, error = (response.error or "Failed to close poll") :: string? }
end

function Polls:GetActive(): { [string]: PollTypes.PollData }
	return activePolls
end

function Polls:GetResults(pollId: string): PollTypes.PollData?
	return activePolls[pollId]
end

function Polls:IsActive(pollId: string): boolean
	return activePolls[pollId] ~= nil
end

-- ========== Async Queries ========== --

function Polls:GetActiveAsync(): { [string]: PollTypes.PollData }
	if not ready then Polls.Ready:Wait() end
	return Polls:GetActive()
end

function Polls:GetResultsAsync(pollId: string): PollTypes.PollData?
	if not ready then Polls.Ready:Wait() end
	return Polls:GetResults(pollId)
end

function Polls:IsActiveAsync(pollId: string): boolean
	if not ready then Polls.Ready:Wait() end
	return Polls:IsActive(pollId)
end

-- ========== End / Expiry ========== --

local function clearPollTimer(pollId: string)
	local thread = pollTimers[pollId]
	if thread then
		pcall(task.cancel, thread)
		pollTimers[pollId] = nil
	end
end

local function endPoll(pollId: string, finalResults: { tallies: { number }, totalResponses: number }?)
	local poll = activePolls[pollId]
	if not poll then return end
	clearPollTimer(pollId)
	activePolls[pollId] = nil
	pollReconcileMisses[pollId] = nil
	Polls.PollEnded:FireAsync(pollId, finalResults or {
		tallies = poll.tallies,
		totalResponses = poll.totalResponses,
	})
end

local function schedulePollTimer(pollId: string, endsAt: number)
	clearPollTimer(pollId)
	if endsAt <= 0 then return end
	local delay = math.max(0, endsAt - os.time()) + POLL_END_GRACE
	pollTimers[pollId] = task.delay(delay, function()
		pollTimers[pollId] = nil
		if activePolls[pollId] then
			endPoll(pollId)
		end
	end)
end

-- ========== Message Handler ========== --

local function onPollMessage(action: string, data: { [string]: any })
	local pollId = data.pollId
	if not pollId then return end

	if action == "start" then
		
		local pollData: PollTypes.PollData = {
			pollId = pollId,
			question = data.question or "",
			options = data.options or {},
			tallies = {},
			totalResponses = 0,
			playerCount = 0,
			status = "active",
			endsAt = data.endsAt or 0,
			duration = data.duration or 0,
		}

		for i = 1, #pollData.options do
			pollData.tallies[i] = 0
		end

		activePolls[pollId] = pollData
		schedulePollTimer(pollId, pollData.endsAt)
		Polls.PollStarted:FireAsync(pollData)

	elseif action == "tally" then
		
		local poll = activePolls[pollId]
		if not poll then return end

		local tallies = data.tallies
		if tallies and typeof(tallies) == "table" then
			local converted = {}
			for i, count in tallies do
				converted[i] = count
			end
			poll.tallies = converted
		end

		poll.totalResponses = data.totalResponses or poll.totalResponses
		poll.playerCount = data.playerCount or poll.playerCount
		Polls.TalliesUpdated:FireAsync(pollId, poll.tallies, poll.totalResponses, poll.playerCount)

	elseif action == "end" then
		
		local poll = activePolls[pollId]

		local tallies = data.tallies
		local finalTallies = {}
		if tallies and typeof(tallies) == "table" then
			for i, count in tallies do
				finalTallies[i] = count
			end
		end

		local finalResults = {
			tallies = finalTallies,
			totalResponses = data.totalResponses or (poll and poll.totalResponses or 0),
		}

		endPoll(pollId, finalResults)
		
	end
end

-- ========== Initialization ========== --

function Polls._Init()
	if initialized then return end
	initialized = true

	MessageRouter.Register("poll", onPollMessage)
	Remotes:Init()

	Polls.PollStarted:Connect(function(pollData)
		Remotes:FireAllClients("SparkMod.Polls.Started", pollData)
	end)

	Polls.PollEnded:Connect(function(pollId, results)
		Remotes:FireAllClients("SparkMod.Polls.Ended", pollId, results)
	end)

	Polls.TalliesUpdated:Connect(function(pollId, tallies, totalResponses, playerCount)
		Remotes:FireAllClients("SparkMod.Polls.Tallies", pollId, tallies, totalResponses, playerCount)
	end)

	Remotes:OnInvoke("SparkMod.Polls.GetState", function(_player)
		return activePolls
	end)

	task.spawn(function()
		while true do
			task.wait(2)

			for pollId, votes in pendingVotes do
				if #votes == 0 then continue end

				local batch = votes
				pendingVotes[pollId] = {}

				task.spawn(function()
					local ok, err = pcall(function()
						local response = Http.Post("/game/polls/vote-batch", {
							pollId = pollId,
							votes = batch,
						})
					end)
					
					if not ok then
						warn(`[SparkMod.Polls] Batch vote flush failed for '{pollId}': {err}`)
					end
				end)
			end
		end
	end)
end

function Polls._Hydrate(syncData: { [string]: any })
	local snapshot = syncData.polls
	if typeof(snapshot) ~= "table" then
		snapshot = {}
	end

	for pollId, poll in activePolls do
		local snap = snapshot[pollId]
		if typeof(snap) ~= "table" or snap.status ~= "active" then
			endPoll(pollId, {
				tallies = poll.tallies,
				totalResponses = poll.totalResponses,
			})
		end
	end

	for pollId, pollData in snapshot do
		if typeof(pollData) == "table" and pollData.status == "active" and not activePolls[pollId] then
			local remaining = math.max(0, (pollData.endsAt or 0) - os.time())
			if remaining > 0 then
				local options = pollData.options or {}
				local tallies = pollData.tallies or {}

				local normalizedTallies = {}
				for i = 1, #options do
					normalizedTallies[i] = tallies[i] or 0
				end

				activePolls[pollId] = {
					pollId = pollId,
					question = pollData.question or "",
					options = options,
					tallies = normalizedTallies,
					totalResponses = pollData.totalResponses or 0,
					playerCount = pollData.playerCount or 0,
					status = "active",
					endsAt = pollData.endsAt or 0,
					duration = pollData.duration or 0,
				}
				schedulePollTimer(pollId, pollData.endsAt or 0)
			end
		end
	end

	Remotes:FireAllClients("SparkMod.Polls.Sync", activePolls)

	if not ready then
		ready = true
		Polls.Ready:Fire()
	end
end

function Polls._ReconcileHeartbeat(body: { [string]: any })
	local activeIds = body.activePollIds
	if typeof(activeIds) ~= "table" then return end

	local active: { [string]: boolean } = {}
	for _, pollId in activeIds do
		active[pollId] = true
	end

	for pollId, poll in activePolls do
		if active[pollId] then
			pollReconcileMisses[pollId] = nil
		else
			local misses = (pollReconcileMisses[pollId] or 0) + 1
			pollReconcileMisses[pollId] = misses
			
			if misses >= POLL_RECONCILE_MISS_LIMIT then
				pollReconcileMisses[pollId] = nil
				endPoll(pollId, {
					tallies = poll.tallies,
					totalResponses = poll.totalResponses,
				})
			end
		end
	end
end

return Polls
