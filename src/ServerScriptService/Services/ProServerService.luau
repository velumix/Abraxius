local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GetEnv = require(ReplicatedStorage.GetEnv)
local ProServerConfig = require(ReplicatedStorage.Config.ProServerConfig)

local MAX_RETRIES = 3
local RETRY_DELAY = 2
local function trimAccessCode(raw)
	if type(raw) ~= "string" then
		return nil
	end

	local cleaned = raw:match("^%s*(.-)%s*$")
	if cleaned == "" then
		return nil
	end

	return cleaned:upper()
end

local function makeErrorCode(code)
	return code or "unknown"
end

local ProServerService = Knit.CreateService({
	Name = "ProServerService",
	Client = {},
})

local StatsService
local DataService

local function stats()
	if not StatsService then
		StatsService = Knit.GetService("StatsService")
	end
	return StatsService
end

local function data()
	if not DataService then
		DataService = Knit.GetService("DataService")
	end
	return DataService
end

local function getTargetPlaceId()
	local placeId = GetEnv:GetPlaceIdByName(ProServerConfig.PlaceName)
	if placeId then
		return placeId
	end

	return GetEnv:GetPlaceIdByName(ProServerConfig.FallbackPlaceName) or game.PlaceId
end

local function nowTime()
	return os.time()
end

local REGISTRY = ProServerConfig.Registry
local REGISTRY_KEY = REGISTRY.KeyName
local registryStore
local registryStoreReady = nil
local heartbeatTask
local currentAccessCode
local registryCache = {}
local registryCacheAt = 0
local teleportCooldowns = {}
local pruneExpiredLobbies

local function hasDataStoreBudget(requestType, minimum)
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(requestType)
	end)
	return ok and budget >= (minimum or 1)
end

local function tryBeginTeleport(player)
	local cooldown = tonumber(ProServerConfig.TeleportCooldownSeconds) or 8
	local now = os.clock()
	local last = teleportCooldowns[player.UserId]
	if last and now - last < cooldown then
		return false, math.ceil(cooldown - (now - last))
	end

	teleportCooldowns[player.UserId] = now
	return true, 0
end

local function getRegistryStore()
	if registryStoreReady ~= nil then
		return registryStore
	end

	registryStoreReady = false
	if REGISTRY.DataStoreName == "" then
		return nil
	end

	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(REGISTRY.DataStoreName)
	end)
	if not ok then
		warn(`[ProServerService] Failed to open lobby registry data store: {tostring(store)}`)
		return nil
	end

	registryStore = store
	registryStoreReady = true
	return store
end

local function withRegistryUpdate(mutator)
	local store = getRegistryStore()
	if not store then
		return false
	end
	if not hasDataStoreBudget(Enum.DataStoreRequestType.GetAsync, REGISTRY.MinReadBudget)
		or not hasDataStoreBudget(Enum.DataStoreRequestType.SetIncrementAsync, REGISTRY.MinWriteBudget)
	then
		warn("[ProServerService] Skipping registry write; DataStore update budget is low")
		return false
	end

	local ok, err = pcall(function()
		store:UpdateAsync(REGISTRY_KEY, function(existing)
			local map = type(existing) == "table" and existing or {}
			pruneExpiredLobbies(map, nowTime())
			mutator(map)
			return map
		end)
	end)
	if not ok then
		warn(`[ProServerService] Registry update failed: {tostring(err)}`)
		return false
	end
	registryCache = {}
	registryCacheAt = 0
	return true
end

local function normalizeLobbyPlayers()
	return #Players:GetPlayers()
end

local function getCurrentServerCode()
	if currentAccessCode then
		return currentAccessCode
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local ok, joinData = pcall(function()
			return player:GetJoinData()
		end)
		if ok and type(joinData) == "table" and type(joinData.TeleportData) == "table" then
			local code = trimAccessCode(joinData.TeleportData.ProServerCode)
			if code then
				currentAccessCode = code
				return code
			end
		end
	end

	return nil
end

local function hasExpired(entry, now)
	return type(entry) ~= "table"
		or type(entry.code) ~= "string"
		or type(entry.expiresAt) ~= "number"
		or entry.expiresAt <= now
end

function pruneExpiredLobbies(map, now)
	for code, entry in pairs(map) do
		if hasExpired(entry, now) then
			map[code] = nil
		end
	end
end

local function getLiveRegistry(force)
	if not force and registryCacheAt > 0 and os.clock() - registryCacheAt <= REGISTRY.ReadCacheSeconds then
		return registryCache
	end

	local store = getRegistryStore()
	if not store then
		return {}
	end
	if not hasDataStoreBudget(Enum.DataStoreRequestType.GetAsync, REGISTRY.MinReadBudget) then
		warn("[ProServerService] Using cached Pro lobby registry; DataStore read budget is low")
		return registryCache
	end

	local now = nowTime()
	local ok, raw = pcall(function()
		return store:GetAsync(REGISTRY_KEY)
	end)
	if not ok or type(raw) ~= "table" then
		return registryCache
	end

	pruneExpiredLobbies(raw, now)
	registryCache = raw
	registryCacheAt = os.clock()
	return raw
end

local function publishLobbyNow(code, creatorUserId, creatorDisplayName, isHost, status)
	local placeId = getTargetPlaceId()
	local now = nowTime()

	return withRegistryUpdate(function(map)
		map[code] = {
			code = code,
			status = status or "Starting",
			creatorUserId = creatorUserId,
			creatorDisplayName = creatorDisplayName,
			isHost = isHost == true,
			joinable = true,
			placeId = placeId,
			serverJobId = game.JobId,
			createdAt = now,
			lastSeenAt = now,
			expiresAt = now + REGISTRY.LobbyTTLSeconds,
			playerCount = 1,
		}
	end)
end

local function refreshCurrentLobby()
	local code = getCurrentServerCode()
	if not code then
		return false
	end

	local now = nowTime()
	return withRegistryUpdate(function(map)
		local entry = map[code]
		if not entry then
			map[code] = {
				code = code,
				status = "Ready",
				creatorUserId = 0,
				creatorDisplayName = "Unknown",
				isHost = false,
				joinable = true,
				placeId = getTargetPlaceId(),
				serverJobId = game.JobId,
				createdAt = now,
				lastSeenAt = now,
				expiresAt = now + REGISTRY.LobbyTTLSeconds,
				playerCount = normalizeLobbyPlayers(),
			}
			return
		end

		entry.status = "Ready"
		entry.joinable = true
		entry.lastSeenAt = now
		entry.expiresAt = now + REGISTRY.LobbyTTLSeconds
		entry.playerCount = normalizeLobbyPlayers()
		entry.serverJobId = game.JobId
		entry.placeId = getTargetPlaceId()
	end)
end

local function isLobbyJoinable(entry)
	if type(entry) ~= "table" then
		return false
	end
	if entry.joinable == false then
		return false
	end
	if entry.status ~= "Ready" and entry.status ~= "Starting" then
		return false
	end
	return type(entry.code) == "string" and entry.code ~= ""
end

local function findBestJoinableLobby()
	local raw = getLiveRegistry(true)
	local now = nowTime()
	local bestReady
	local bestStarting

	for _, entry in pairs(raw) do
		if not hasExpired(entry, now) and isLobbyJoinable(entry) then
			if entry.status == "Ready" then
				if not bestReady or (entry.createdAt or 0) > (bestReady.createdAt or 0) then
					bestReady = entry
				end
			elseif entry.status == "Starting" then
				if not bestStarting or (entry.createdAt or 0) > (bestStarting.createdAt or 0) then
					bestStarting = entry
				end
			end
		end
	end

	return bestReady or bestStarting
end

local function stopHeartbeat()
	if heartbeatTask then
		task.cancel(heartbeatTask)
		heartbeatTask = nil
	end
end

local function startHeartbeat()
	if getTargetPlaceId() ~= game.PlaceId then
		stopHeartbeat()
		return
	end

	stopHeartbeat()
	heartbeatTask = task.spawn(function()
		while game.PlaceId == getTargetPlaceId() and task.wait(REGISTRY.HeartbeatInterval) do
			refreshCurrentLobby()
		end
	end)
end

local function formatLobbyList()
	local raw = getLiveRegistry()
	local now = nowTime()
	local list = {}

	for code, entry in pairs(raw) do
		if type(entry) == "table" and type(code) == "string" then
			if not hasExpired(entry, now) then
				table.insert(list, {
					code = code,
					creatorUserId = entry.creatorUserId or 0,
					creatorName = entry.creatorDisplayName or "Unknown",
					playerCount = tonumber(entry.playerCount) or 0,
					status = entry.status or "Ready",
					placeId = tonumber(entry.placeId) or getTargetPlaceId(),
					createdAt = tonumber(entry.createdAt) or 0,
				})
			end
		end
	end

	table.sort(list, function(a, b)
		return (a.createdAt or 0) > (b.createdAt or 0)
	end)

	if #list > ProServerConfig.LobbyListMaxEntries then
		local trimmed = {}
		for index = 1, ProServerConfig.LobbyListMaxEntries do
			trimmed[index] = list[index]
		end
		list = trimmed
	end

	return list
end

local function getLobbyByCode(code)
	local raw = getLiveRegistry()
	local now = nowTime()
	local entry = raw[code]
	if hasExpired(entry, now) then
		return nil
	end
	return entry
end

function ProServerService:GetStatus(player)
	data():WaitForData(player)
	local wins = stats():GetWins(player)
	local requiredWins = ProServerConfig.RequiredWins

	return {
		wins = wins,
		requiredWins = requiredWins,
		eligible = wins >= requiredWins,
		currentServerCode = getCurrentServerCode(),
		servers = formatLobbyList(),
	}
end

function ProServerService:QuickJoin(player)
	local status = self:GetStatus(player)
	if not status.eligible then
		return {
			ok = false,
			reason = "notEnoughWins",
			wins = status.wins,
			requiredWins = status.requiredWins,
		}
	end

	local lobby = findBestJoinableLobby()
	if lobby then
		return self:JoinByCode(player, lobby.code)
	end

	local canTeleport, retryAfter = tryBeginTeleport(player)
	if not canTeleport then
		return {
			ok = false,
			reason = "cooldown",
			retryAfter = retryAfter,
			wins = status.wins,
			requiredWins = status.requiredWins,
		}
	end
	if not hasDataStoreBudget(Enum.DataStoreRequestType.GetAsync, REGISTRY.MinReadBudget)
		or not hasDataStoreBudget(Enum.DataStoreRequestType.SetIncrementAsync, REGISTRY.MinWriteBudget)
	then
		return {
			ok = false,
			reason = "registryBusy",
			wins = status.wins,
			requiredWins = status.requiredWins,
		}
	end
	if RunService:IsStudio() then
		return {
			ok = false,
			reason = "studioUnsupported",
			wins = status.wins,
			requiredWins = status.requiredWins,
		}
	end

	local placeId = getTargetPlaceId()
	local accessCode
	local ok, err

	for attempt = 1, MAX_RETRIES do
		ok, err = pcall(function()
			accessCode = TeleportService:ReserveServerAsync(placeId)
		end)
		if ok and accessCode then
			break
		end
		warn(`[ProServerService] ReserveServerAsync attempt {attempt} failed: {err}`)
		task.wait(RETRY_DELAY)
	end

	if not accessCode then
		return {
			ok = false,
			reason = "reserveFailed",
			wins = status.wins,
			requiredWins = status.requiredWins,
		}
	end

	accessCode = trimAccessCode(accessCode)
	if not accessCode then
		return {
			ok = false,
			reason = "reserveFailed",
			wins = status.wins,
			requiredWins = status.requiredWins,
		}
	end

	local published = publishLobbyNow(accessCode, player.UserId, player.DisplayName, true, "Starting")
	if not published then
		return {
			ok = false,
			reason = "registryBusy",
			wins = status.wins,
			requiredWins = status.requiredWins,
		}
	end

	currentAccessCode = accessCode
	for attempt = 1, MAX_RETRIES do
		ok, err = pcall(function()
			TeleportService:TeleportToPrivateServer(
				placeId,
				accessCode,
				{ player },
				nil,
				{
					ProServerCode = accessCode,
					ProServerHostUserId = player.UserId,
					ProServerHostDisplayName = player.DisplayName,
				}
			)
		end)
		if ok then
			return {
				ok = true,
				wins = status.wins,
				requiredWins = status.requiredWins,
			}
		end
		warn(`[ProServerService] TeleportToPrivateServer attempt {attempt} failed: {err}`)
		task.wait(RETRY_DELAY)
	end

	return {
		ok = false,
		reason = "teleportFailed",
		wins = status.wins,
		requiredWins = status.requiredWins,
	}
end

function ProServerService:JoinByCode(player, accessCode)
	local status = self:GetStatus(player)
	if not status.eligible then
		return {
			ok = false,
			reason = "notEnoughWins",
			wins = status.wins,
			requiredWins = status.requiredWins,
		}
	end

	accessCode = trimAccessCode(accessCode)
	if not accessCode then
		return {
			ok = false,
			reason = "invalidCode",
		}
	end

	local lobby = getLobbyByCode(accessCode)
	if not lobby then
		return {
			ok = false,
			reason = "lobbyUnavailable",
		}
	end

	local canTeleport, retryAfter = tryBeginTeleport(player)
	if not canTeleport then
		return {
			ok = false,
			reason = "cooldown",
			retryAfter = retryAfter,
			targetCode = accessCode,
		}
	end

	local placeId = tonumber(lobby.placeId) or getTargetPlaceId()
	local hostName = lobby.creatorDisplayName or "Unknown"
	if placeId == nil or placeId == 0 then
		placeId = getTargetPlaceId()
	end
	if RunService:IsStudio() then
		return {
			ok = false,
			reason = "studioUnsupported",
			targetCode = accessCode,
		}
	end

	local ok, err
	for attempt = 1, MAX_RETRIES do
		ok, err = pcall(function()
			TeleportService:TeleportToPrivateServer(
				placeId,
				accessCode,
				{ player },
				nil,
				{
					ProServerCode = accessCode,
					ProServerHostUserId = lobby.creatorUserId,
					ProServerHostDisplayName = hostName,
				}
			)
		end)
		if ok then
			return {
				ok = true,
				targetCode = accessCode,
			}
		end
		warn(`[ProServerService] TeleportToPrivateServer join attempt {attempt} failed: {tostring(err)}`)
		task.wait(RETRY_DELAY)
	end

	return {
		ok = false,
		reason = "teleportFailed",
		targetCode = accessCode,
	}
end

function ProServerService.Client:GetStatus(player)
	return ProServerService:GetStatus(player)
end

function ProServerService.Client:QuickJoin(player)
	return ProServerService:QuickJoin(player)
end

function ProServerService.Client:JoinByCode(player, accessCode)
	return ProServerService:JoinByCode(player, accessCode)
end

function ProServerService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		if getTargetPlaceId() == game.PlaceId then
			refreshCurrentLobby()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		teleportCooldowns[player.UserId] = nil
		if getTargetPlaceId() == game.PlaceId then
			task.defer(refreshCurrentLobby)
		end
	end)

	startHeartbeat()
	refreshCurrentLobby()
end

function ProServerService:KnitStop()
	stopHeartbeat()
end

return ProServerService