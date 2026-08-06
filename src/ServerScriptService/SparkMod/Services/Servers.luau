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

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local Http = require(script.Parent.Parent.Internal.Http)
local ServerTypes = require(game.ReplicatedStorage.SparkMod.Types.Servers)

-- ========== Module ========== --

local Servers = {}

function Servers:GetAll(): { ServerTypes.ServerInfo }
	local response = Http.Get("/game/servers")
	if response.ok and response.body then
		local body = response.body :: any
		return body.servers or {}
	end
	return {}
end

function Servers:FindPlayer(query: string): { ServerTypes.PlayerLocation }
	local encoded = HttpService:UrlEncode(query)
	local response = Http.Get("/game/players/search?q=" .. encoded)
	if response.ok and response.body then
		local body = response.body :: any
		return body.players or {}
	end
	return {}
end

function Servers:GetPlayerLocation(userId: number): ServerTypes.PlayerLocation?
	local response = Http.Get("/game/players/" .. tostring(userId))
	if response.ok and response.body then
		local body = response.body :: any
		return body.player
	end
	return nil
end

function Servers:GetTotalPlayerCount(): number
	local response = Http.Get("/game/servers/stats")
	if response.ok and response.body then
		local body = response.body :: any
		return body.totalPlayers or 0
	end
	return 0
end

function Servers:GetCurrentServerInfo(): ServerTypes.ServerInfo?
	local jobId = game.JobId
	if jobId == "" then
		return nil
	end
	local response = Http.Get("/game/servers/" .. HttpService:UrlEncode(jobId))
	if response.ok and response.body then
		local body = response.body :: any
		return body.server
	end
	return nil
end

function Servers:ReserveServer(placeId: number?, ttlSeconds: number?): (string?, string?)
	local effectivePlaceId = placeId or game.PlaceId
	local ok, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServer(effectivePlaceId)
	end)
	if not ok or typeof(accessCode) ~= "string" or typeof(privateServerId) ~= "string" then
		return nil, nil
	end
	self:RegisterReservedCode(privateServerId, accessCode, ttlSeconds)
	return accessCode, privateServerId
end

function Servers:RegisterReservedCode(privateServerId: string, accessCode: string, ttlSeconds: number?): boolean
	local response = Http.Post("/game/servers/reserved", {
		privateServerId = privateServerId,
		accessCode = accessCode,
		ttlSeconds = ttlSeconds,
	})
	return response.ok
end

function Servers:GetReservedCode(privateServerId: string): string?
	local response = Http.Get("/game/servers/reserved/" .. HttpService:UrlEncode(privateServerId))
	if response.ok and response.body then
		local body = response.body :: any
		local code = body.accessCode
		if typeof(code) == "string" and code ~= "" then
			return code
		end
	end
	return nil
end

function Servers:RequestServer(tag: string, slots: number?, options: ServerTypes.RequestServerOptions?): ServerTypes.MatchResult?
	local opts: ServerTypes.RequestServerOptions = options or {}
	local response = Http.Post("/game/servers/match", {
		tag = tag,
		slots = slots,
		expectedMaxPlayers = opts.expectedMaxPlayers or Players.MaxPlayers,
	})
	if not response.ok or not response.body then
		return nil
	end
	local body = response.body :: any
	if body.ok ~= true then
		return nil
	end
	if body.action == "join" and typeof(body.accessCode) == "string" and body.accessCode ~= "" then
		return { action = "join", accessCode = body.accessCode } :: ServerTypes.MatchResult
	end
	if body.action == "reserve" and typeof(body.token) == "string" and body.token ~= "" then
		local accessCode, privateServerId = self:RegisterReservedServer(body.token, { tag }, opts, slots)
		if accessCode and privateServerId then
			return {
				action = "reserve",
				accessCode = accessCode,
				privateServerId = privateServerId,
			} :: ServerTypes.MatchResult
		end
	end
	return nil
end

function Servers:RegisterReservedServer(token: string, tags: { string }?, options: ServerTypes.RequestServerOptions?, slots: number?): (string?, string?)
	local opts: ServerTypes.RequestServerOptions = options or {}
	local effectivePlaceId = opts.placeId or game.PlaceId
	local ok, accessCode, privateServerId = pcall(function()
		return TeleportService:ReserveServer(effectivePlaceId)
	end)
	if not ok or typeof(accessCode) ~= "string" or typeof(privateServerId) ~= "string" then
		return nil, nil
	end
	local response = Http.Post("/game/servers/reserved", {
		privateServerId = privateServerId,
		accessCode = accessCode,
		ttlSeconds = opts.ttlSeconds,
		token = token,
		tags = tags,
		slots = slots,
		expectedMaxPlayers = opts.expectedMaxPlayers or Players.MaxPlayers,
	})
	if not response.ok or not response.body or (response.body :: any).pooled ~= true then
		warn("[SparkMod] RegisterReservedServer: backend registration failed; reservation not pooled")
		return nil, nil
	end
	return accessCode, privateServerId
end

-- ========== Initialization ========== --

function Servers._Init() end

return Servers
