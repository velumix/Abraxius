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

local WINDOW_SEC = 5

local function run(ctx)
	local jobBase = if game.JobId ~= "" then string.sub(game.JobId, 1, 12) else "studio"
	local waves, started, cancelled, deduped, seq = 0, 0, 0, 0, 0

	while ctx.isActive() do
		local N = ctx.multiplier
		local names = {}

		for _ = 1, N do
			if not ctx.isActive() then break end
			seq += 1
			local name = `st_evt_{jobBase}_{seq}`
			table.insert(names, name)
			local resp = ctx.post("/game/events/start", {
				eventName = name,
				durationSeconds = 30,
				triggeredBy = "loadtest",
			})
			started += 1
			if resp.ok and resp.body and resp.body.deduped == true then
				deduped += 1
			end
		end

		for _, name in names do
			if not ctx.isActive() then break end
			ctx.post("/game/events/cancel", { eventName = name })
			cancelled += 1
		end

		waves += 1
		if waves % 3 == 0 then
			print(
				`[SparkMod.EventBroadcastStorm] waves={waves} started={started} cancelled={cancelled} deduped={deduped} (N={N}/wave)`
			)
		end

		task.wait(WINDOW_SEC)
	end

	print(
		`[SparkMod.EventBroadcastStorm] stopped (waves={waves}, started={started}, cancelled={cancelled}, deduped={deduped})`
	)
end

return {
	name = "event-broadcast-storm",
	run = run,
}
