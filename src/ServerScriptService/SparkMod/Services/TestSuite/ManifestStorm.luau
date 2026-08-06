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

local SYNTHETIC_PLACE_ID = 999999999999
local BASE_VERSION = 100000
local WINDOW_SEC = 5

local function makeManifest(isNew: boolean)
	local manifest = {
		{ name = "st_evt_alpha", duration = 60, override = "queue", builtIn = false },
		{ name = "st_evt_beta", duration = 120, override = "stack", builtIn = false },
	}
	if isNew then
		table.insert(manifest, { name = "st_evt_gamma", duration = 90, override = "queue", builtIn = false })
	end
	return manifest
end

local function run(ctx)
	local N = ctx.multiplier
	local split = ctx.split
	local jobBase = if game.JobId ~= "" then string.sub(game.JobId, 1, 12) else "studio"

	local rounds, newReports, oldReports, throttled = 0, 0, 0, 0

	while ctx.isActive() do
		local window = math.floor(os.time() / WINDOW_SEC)
		local oldVersion = BASE_VERSION + window
		local newVersion = oldVersion + 1

		for i = 0, N - 1 do
			if not ctx.isActive() then break end
			
			local isNew = (i + 0.5) / N < split
			if isNew then newReports += 1 else oldReports += 1 end

			local resp = ctx.post("/game/heartbeat", {
				jobId = `st_{jobBase}_{i}`,
				placeId = SYNTHETIC_PLACE_ID,
				placeVersion = if isNew then newVersion else oldVersion,
				playerCount = 0,
				maxPlayers = 50,
				registeredEvents = makeManifest(isNew),
				version = "loadtest",
			})
			if not resp.ok then
				throttled += 1
			end
		end
		rounds += 1

		if rounds % 4 == 0 then
			print(
				`[SparkMod.ManifestStorm] rounds={rounds} split={math.floor(split * 100)}%new new={newReports} old={oldReports} throttled={throttled} ver={oldVersion}->{newVersion}`
			)
		end

		task.wait(WINDOW_SEC)
	end

	print(`[SparkMod.ManifestStorm] stopped (rounds={rounds}, new={newReports}, old={oldReports}, throttled={throttled})`)
end

return {
	name = "manifest-storm",
	run = run,
}
