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

local POLL_ID = "st_loadtest"
local OPTION_COUNT = 4
local MAX_BATCH = 1000
local USERID_BASE = 1_000_000_000_000

local function ensurePoll(ctx)
	local options = table.create(OPTION_COUNT)
	for i = 1, OPTION_COUNT do
		options[i] = "opt" .. i
	end
	
	ctx.post("/game/polls/create", {
		pollId = POLL_ID,
		question = "loadtest",
		options = options,
		duration = math.max(60, math.floor(ctx.durationSec)),
		synthetic = true,
	})
end

local function run(ctx)
	ensurePoll(ctx)

	local started = os.clock()
	local sent, throttled, totalVotes = 0, 0, 0
	local lastLog = os.clock()

	while ctx.isActive() do
		local ramp = if ctx.rampSec > 0
			then math.clamp((os.clock() - started) / ctx.rampSec, 0, 1)
			else 1

		local target = math.max(1, math.floor(ctx.batchSize * ctx.multiplier * ramp))
		local remaining = target
		while remaining > 0 and ctx.isActive() do
			local n = math.min(MAX_BATCH, remaining)
			local batch = table.create(n)
			for i = 1, n do
				batch[i] = {
					userId = USERID_BASE + math.random(1, 100000),
					optionIndex = math.random(0, OPTION_COUNT - 1),
				}
			end
			local resp = ctx.post("/game/polls/vote-batch", { pollId = POLL_ID, votes = batch })
			sent += 1
			totalVotes += n
			if not resp.ok then
				throttled += 1
			end
			remaining -= n
		end

		if os.clock() - lastLog >= 10 then
			local elapsed = math.max(0.001, os.clock() - started)
			print(
				`[SparkMod.PollVoteFlood] requests={sent} throttled={throttled} ~{math.floor(totalVotes / elapsed)} votes/s`
			)
			lastLog = os.clock()
		end

		task.wait(1)
	end

	print(`[SparkMod.PollVoteFlood] stopped (sent {sent} requests, {throttled} throttled)`)
end

return {
	name = "poll-vote-flood",
	run = run,
}
