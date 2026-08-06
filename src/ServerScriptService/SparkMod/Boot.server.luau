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
--!strict

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")

local SparkMod = require(script.Parent)
local Session = require(script.Parent.Internal.Session)

type BootResult = "success" | "transient" | "permanent"

local TRANSIENT_CODES: { [number]: boolean } = {
	[429] = true,
	[500] = true,
	[502] = true,
	[503] = true,
	[504] = true,
}

local function attemptBoot(): BootResult
	local baseUrl = Session.GetBaseUrl()

	local ok, result = pcall(function()
		local store = DataStoreService:GetDataStore("_SparkMod")
		return store:GetAsync("AuthSecret")
	end)

	if not ok then
		return "transient"
	end

	if typeof(result) == "string" then
		local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, result)
		if decodeOk and typeof(decoded) == "table" then
			result = decoded
		end
	end

	if not result or typeof(result) ~= "table" or not result.ciphertext then
		return "permanent"
	end

	local reqOk, response = pcall(function()
		return HttpService:RequestAsync({
			Url = baseUrl .. "/game/bootstrap",
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode({
				placeId = game.PlaceId,
				jobId = Session.Get(),
				payload = result,
			}),
		})
	end)

	Session.NoteShardOutcome(reqOk and response.StatusCode > 0 and response.StatusCode < 500)

	if not reqOk then
		warn("[SparkMod.Boot] Bootstrap request failed:", response)
		return "transient"
	end

	if response.StatusCode ~= 200 then
		warn(`[SparkMod.Boot] Bootstrap returned {response.StatusCode}: {response.Body}`)
		return if TRANSIENT_CODES[response.StatusCode] then "transient" else "permanent"
	end

	local decodeOk, decoded = pcall(HttpService.JSONDecode, HttpService, response.Body)
	if not decodeOk or typeof(decoded) ~= "table" or not decoded.key then
		warn("[SparkMod.Boot] Invalid bootstrap response")
		return "permanent"
	end

	if typeof(decoded.sharding) == "table" then
		Session.SetShardConfig(decoded.sharding)
	end

	SparkMod.Init({
		apiKey = decoded.key,
	})

	return "success"
end

-- ========== Main ========== --

local result = attemptBoot()

SparkMod.InitLocal()

-- ========== Transient Retry ========== --

if result == "transient" then
	local delays = { 10, 30, 60, 60, 60 }
	for i, delay in delays do
		warn(`[SparkMod.Boot] Retrying in {delay}s (attempt {i + 1})`)
		task.wait(delay)
		result = attemptBoot()
		if result == "success" then
			break
		end
		if result == "permanent" then
			break
		end
	end
end

if result == "success" then
	return
end

MessagingService:SubscribeAsync("coord:recovery", attemptBoot)
