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

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")

local SYNTHETIC_PLACE_ID = 999999999998
local BASE_VERSION = 100000
local ITEM_COUNT = 3
local WINDOW_SEC = 8

local function readPayload(): any
	local ok, raw = pcall(function()
		return DataStoreService:GetDataStore("_SparkMod"):GetAsync("AuthSecret")
	end)
	if not ok or raw == nil then
		return nil
	end
	if typeof(raw) == "string" then
		local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		return if decodeOk then decoded else nil
	end
	return raw
end

local function makeManifest()
	return {
		{ name = "st_mig_evt_a", duration = 60, override = "queue", builtIn = false },
		{ name = "st_mig_evt_b", duration = 90, override = "stack", builtIn = false },
	}
end

local function makeStockConfig(window: number)
	local items = {}
	for i = 0, ITEM_COUNT - 1 do
		items[`st_mig_stock_{i}`] = {
			rewardType = "item",
			rewardId = `st_mig_reward_{i}`,
			publicStock = window,
			hiddenStock = 100,
		}
	end
	return { items = items, pools = {} }
end

local function run(ctx)
	local N = ctx.multiplier
	local jobBase = if game.JobId ~= "" then string.sub(game.JobId, 1, 12) else "studio"
	local payload = readPayload()
	if payload == nil then
		warn("[SparkMod.MigrationStorm] Bootstrap payload unavailable — running without the bootstrap herd")
	end

	local waves, boots, beats, syncs, regs, stockWrote = 0, 0, 0, 0, 0, 0

	while ctx.isActive() do
		local window = math.floor(os.time() / WINDOW_SEC)
		local newVersion = BASE_VERSION + window
		local config = makeStockConfig(window)

		-- 1) Bootstrap herd (06-06 conn-exhaustion path; cache should collapse it).
		if payload ~= nil then
			for i = 0, N - 1 do
				if not ctx.isActive() then break end
				ctx.rawPost("/game/bootstrap", { placeId = SYNTHETIC_PLACE_ID, jobId = `st_mig_{jobBase}_{i}`, payload = payload })
				boots += 1
			end
		end

		-- 2) Heartbeat + manifest herd (06-20 version-gate).
		for i = 0, N - 1 do
			if not ctx.isActive() then break end
			ctx.post("/game/heartbeat", {
				jobId = `st_mig_{jobBase}_{i}`,
				placeId = SYNTHETIC_PLACE_ID,
				placeVersion = newVersion,
				playerCount = 0,
				maxPlayers = 50,
				registeredEvents = makeManifest(),
				version = "loadtest",
			})
			beats += 1
		end

		-- 3) Sync herd (the /sync SWR hot path).
		for i = 0, N - 1 do
			if not ctx.isActive() then break end
			ctx.post("/game/sync", { jobId = `st_mig_{jobBase}_{i}`, placeId = SYNTHETIC_PLACE_ID })
			syncs += 1
		end

		-- 4) Stock register herd (06-27 atomic election).
		for i = 0, N - 1 do
			if not ctx.isActive() then break end
			local resp = ctx.post("/game/stock/register", config)
			regs += 1
			if resp.ok and resp.body and resp.body.changed == true then
				stockWrote += 1
			end
		end

		waves += 1
		if waves % 2 == 0 then
			print(
				`[SparkMod.MigrationStorm] waves={waves} boots={boots} beats={beats} syncs={syncs} regs={regs} stockWrote={stockWrote} (N={N}/wave; stockWrote should track ~1/window)`
			)
		end

		task.wait(WINDOW_SEC)
	end

	print(
		`[SparkMod.MigrationStorm] stopped (waves={waves}, boots={boots}, beats={beats}, syncs={syncs}, regs={regs}, stockWrote={stockWrote})`
	)
end

return {
	name = "migration-storm",
	run = run,
}
