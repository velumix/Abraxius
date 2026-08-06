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

local HttpService = game:GetService("HttpService")

-- ========== Hardcoded Domains ========== --

local PRODUCTION_URL = "https://game.sparkmod.io"
local DEV_URL = "http://localhost:3000"

-- ========== Session ID ========== --

local SessionJobId: string = game.JobId
if SessionJobId == "" then
	SessionJobId = "studio-" .. HttpService:GenerateGUID(false)
end

-- ========== Sharding ========== --

local BOOTSTRAP_HOSTS: { number } = { 1, 2, 3, 4, 5 }

local shardingEnabled = true
local shardHosts: { number } = table.clone(BOOTSTRAP_HOSTS)

local FAILURE_THRESHOLD = 3
local FALLBACK_SECONDS = 60
local consecutiveFailures = 0
local rotationsSinceSuccess = 0
local shardOffset = 0 -- rotates the JobId->host mapping on persistent failure
local fallbackUntil = 0

local function hashJobId(str: string): number
	local hash = 0
	for i = 1, #str do
		hash = (hash * 31 + string.byte(str, i)) % 2147483647
	end
	return hash
end

-- ========== Module ========== --

local module = {}

function module.Get(): string
	return SessionJobId
end

function module.IsDevMode(): boolean
	return script.Parent.Parent:GetAttribute("DevMode") == true
end

function module.SetShardConfig(config: { enabled: boolean?, count: number?, hosts: { number }? }?)
	if typeof(config) ~= "table" then
		return
	end
	if type(config.enabled) == "boolean" then
		shardingEnabled = config.enabled
	end
	if type(config.hosts) == "table" then
		local hosts: { number } = {}
		for _, v in config.hosts do
			if type(v) == "number" and v >= 1 then
				table.insert(hosts, math.floor(v))
			end
		end
		if #hosts >= 1 then
			shardHosts = hosts
		end
	elseif type(config.count) == "number" and config.count >= 1 then
		local hosts: { number } = {}
		for i = 1, math.floor(config.count) do
			table.insert(hosts, i)
		end
		shardHosts = hosts
	end
end

local function isSharding(): boolean
	return shardingEnabled
		and #shardHosts >= 1
		and os.time() >= fallbackUntil
		and not module.IsDevMode()
end

function module.NoteShardOutcome(ok: boolean)
	if ok then
		consecutiveFailures = 0
		rotationsSinceSuccess = 0
		return
	end
	if not isSharding() then
		return
	end
	consecutiveFailures += 1
	if consecutiveFailures < FAILURE_THRESHOLD then
		return
	end
	consecutiveFailures = 0
	rotationsSinceSuccess += 1
	if rotationsSinceSuccess >= #shardHosts then
		fallbackUntil = os.time() + FALLBACK_SECONDS
		rotationsSinceSuccess = 0
		shardOffset = 0
		warn(`[SparkMod.Session] All shard hosts failing; using {PRODUCTION_URL} for {FALLBACK_SECONDS}s`)
	else
		shardOffset += 1
		warn("[SparkMod.Session] Shard host failing; rotating to next available NLB")
	end
end

function module.GetBaseUrl(): string
	if module.IsDevMode() then
		return DEV_URL
	end
	if isSharding() then
		local pick = ((hashJobId(SessionJobId) + shardOffset) % #shardHosts) + 1
		return `https://api{shardHosts[pick]}.sparkmod.io`
	end
	return PRODUCTION_URL
end

return table.freeze(module)
