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

local Players = game:GetService("Players")

-- ========== Internal Modules ========== --

local Http = require(script.Internal.Http)
local Queue = require(script.Internal.Queue)
local Signal = require(game.ReplicatedStorage.SparkMod.Internal.Signal)
local MessageRouter = require(script.Internal.MessageRouter)
local Session = require(script.Internal.Session)

-- ========== Types ========== --

local ConfigTypes = require(script.Types.Config)
local InternalTypes = require(script.Types.Internal)

-- ========== Constants ========== --

local DEFAULT_HEARTBEAT_INTERVAL = 45

-- ========== State ========== --

local initialized = false
local offboarded = false
local heartbeatThread: thread? = nil

local sdkVersion: string? = nil
do
	local packageLink = script:FindFirstChildWhichIsA("PackageLink")
	if packageLink then
		local ok, version = pcall(function()
			return (packageLink :: any).VersionNumber
		end)
		if ok and version ~= nil then
			sdkVersion = tostring(version)
		end
	end
end

-- ========== Config ========== --

local Config: ConfigTypes.Config = {
	apiKey = "",
	heartbeatInterval = DEFAULT_HEARTBEAT_INTERVAL,
	requestTimeout = 10,
	maxRetries = 3,
	enableEncryption = true,
}

-- ========== Module ========== --

local SparkMod = {}
SparkMod.initialized = false

-- ========== Signals ========== --

SparkMod.Connected = Signal.new()
SparkMod.Disconnected = Signal.new()
SparkMod.HeartbeatSent = Signal.new()
SparkMod.CommandReceived = Signal.new()

-- ========== Service Loader ========== --

local services: { any } = {}
local manifestProvider: any = nil

for _, child in script.Services:GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, service = pcall(require, child)
		if ok and typeof(service) == "table" then
			table.insert(services, service)
			if typeof(rawget(service, "GetManifest")) == "function" then
				manifestProvider = service
			end
		else
			warn(`[SparkMod] Failed to load service '{child.Name}': {service}`)
		end
	end
end

-- ========== Lifecycle ========== --

function SparkMod.InitLocal()
	for _, service in services do
		local ok, err = pcall(service._Init)
		if not ok then
			warn(`[SparkMod] Service _Init failed: {err}`)
		end
	end
end

function SparkMod.Init(config: ConfigTypes.Config)
	if initialized then
		warn("[SparkMod] Already initialized")
		return
	end

	Config = {
		apiKey = config.apiKey,
		heartbeatInterval = config.heartbeatInterval or DEFAULT_HEARTBEAT_INTERVAL,
		requestTimeout = config.requestTimeout or 10,
		maxRetries = config.maxRetries or 3,
		enableEncryption = if config.enableEncryption ~= nil then config.enableEncryption else true,
	}

	Http.Configure({
		apiKey = Config.apiKey,
		requestTimeout = Config.requestTimeout,
		maxRetries = Config.maxRetries,
		enableEncryption = Config.enableEncryption,
	})

	Http.Offboarded:Once(function()
		SparkMod._Offboard()
	end)

	MessageRouter.Register("cmd", function(action, data)
		local targets = data.target
		if targets and typeof(targets) == "table" then
			local isTarget = false
			for _, jobId in targets do
				if jobId == Session.Get() then
					isTarget = true
					break
				end
			end
			if not isTarget then return end
		end
		SparkMod.CommandReceived:FireAsync(action, data)
	end)

	MessageRouter.Subscribe(Config.apiKey, Session.Get())
	Queue.Start()

	for _, service in services do
		local ok, err = pcall(service._Init)
		if not ok then
			warn(`[SparkMod] Service _Init failed: {err}`)
		end
	end

	initialized = true
	SparkMod.initialized = true
	SparkMod._StartHeartbeat()

	task.spawn(function()
		SparkMod._SyncAndHydrate(true)
	end)

	MessageRouter.Reconnected:Connect(function()
		task.spawn(function()
			SparkMod._SyncAndHydrate(true)
		end)
	end)

	game:BindToClose(function()
		SparkMod.Shutdown()
	end)
end

function SparkMod.Shutdown()
	if heartbeatThread then
		task.cancel(heartbeatThread)
		heartbeatThread = nil
	end

	Queue.Stop()
	Queue.Clear()

	if not offboarded then
		pcall(function()
			Http.Post("/game/heartbeat", {
				jobId = Session.Get(),
				placeId = game.PlaceId,
				playerCount = 0,
				maxPlayers = 0,
				privateServerId = if game.PrivateServerOwnerId == 0 and game.PrivateServerId ~= "" then game.PrivateServerId else nil,
			})
		end)
	end

	initialized = false
	SparkMod.initialized = false
	SparkMod.Disconnected:Fire()
end

function SparkMod._Offboard()
	if offboarded then return end
	offboarded = true

	warn("[SparkMod] Backend signalled GAME_OFFBOARDED. Going quiet for this server's lifetime.")

	if heartbeatThread then
		task.cancel(heartbeatThread)
		heartbeatThread = nil
	end

	Queue.Stop()
	Queue.Clear()
	MessageRouter.Stop()

	initialized = false
	SparkMod.initialized = false
	SparkMod.Disconnected:Fire()
end

-- ========== Heartbeat ========== --

local lastHeartbeatTime = 0
local lastReportedPlayerCount = 0
local heartbeatSeq = 0
local playerJoinTimes: {[number]: number} = {}

function SparkMod._SendHeartbeat()
	lastHeartbeatTime = os.clock()
	heartbeatSeq += 1
	local currentPlayers = Players:GetPlayers()
	lastReportedPlayerCount = #currentPlayers

	local playersPayload = table.create(#currentPlayers)
	for i, player in currentPlayers do
		playersPayload[i] = {
			userId = player.UserId,
			displayName = player.DisplayName,
			username = player.Name,
			joinedAt = playerJoinTimes[player.UserId] or os.time(),
		}
	end

	local response = Http.Post("/game/heartbeat", {
		jobId = Session.Get(),
		placeId = game.PlaceId,
		placeVersion = game.PlaceVersion,
		privateServerId = if game.PrivateServerOwnerId == 0 and game.PrivateServerId ~= "" then game.PrivateServerId else nil,
		beatSeq = heartbeatSeq,
		playerCount = lastReportedPlayerCount,
		maxPlayers = Players.MaxPlayers,
		players = playersPayload,
		registeredEvents = if manifestProvider then manifestProvider:GetManifest() else {},
		version = sdkVersion,
	})

	if response.ok and response.body then
		local commands = response.body.pendingCommands
		if commands and typeof(commands) == "table" then
			for _, cmd in commands do
				SparkMod.CommandReceived:FireAsync(cmd.type, cmd.data)
			end
		end

		for _, service in services do
			if service._ReconcileHeartbeat then
				local ok, err = pcall(service._ReconcileHeartbeat, response.body)
				if not ok then
					warn(`[SparkMod] Service _ReconcileHeartbeat failed: {err}`)
				end
			end
		end

		SparkMod.HeartbeatSent:Fire(response.body)
	end
end

function SparkMod._StartHeartbeat()
	local debounceThread: thread? = nil

	if manifestProvider and manifestProvider.RegistrationChanged then
		local resyncThread: thread? = nil
		manifestProvider.RegistrationChanged:Connect(function()
			if resyncThread then task.cancel(resyncThread) end
			resyncThread = task.delay(2, function()
				resyncThread = nil
				-- Report the new event manifest to the backend. Active events a late-
				-- registering handler can now run are recovered via pendingHydration (the
				-- boot sync AND the real-time broadcast both park unhandled events), so a
				-- second full sync here is redundant.
				SparkMod._SendHeartbeat()
			end)
		end)
	end

	local function onPlayerChanged()
		if not initialized then return end
		
		if debounceThread then task.cancel(debounceThread) end
		debounceThread = task.delay(5, function()
			debounceThread = nil
			if math.abs(#Players:GetPlayers() - lastReportedPlayerCount) > 1 then
				SparkMod._SendHeartbeat()
			end
		end)
	end

	for _, player in Players:GetPlayers() do
		playerJoinTimes[player.UserId] = os.time()
	end
	Players.PlayerAdded:Connect(function(player)
		playerJoinTimes[player.UserId] = os.time()
	end)
	Players.PlayerRemoving:Connect(function(player)
		playerJoinTimes[player.UserId] = nil
	end)

	Players.PlayerAdded:Connect(onPlayerChanged)
	Players.PlayerRemoving:Connect(onPlayerChanged)

	heartbeatThread = task.spawn(function()
		while initialized do
			local elapsed = os.clock() - lastHeartbeatTime
			local interval = Config.heartbeatInterval or DEFAULT_HEARTBEAT_INTERVAL

			if elapsed >= interval then
				SparkMod._SendHeartbeat()
			end

			task.wait(interval - math.min(elapsed, interval))
		end
	end)
end

-- ========== Sync ========== --

function SparkMod.Sync(): InternalTypes.SyncResponse?
	local response = Http.Post("/game/sync", {
		jobId = Session.Get(),
		placeId = game.PlaceId,
	})

	if not response.ok or not response.body then
		return nil
	end

	if typeof(response.body.sharding) == "table" then
		Session.SetShardConfig(response.body.sharding)
	end

	return response.body
end

function SparkMod._SyncAndHydrate(fireConnected: boolean?)
	local syncResponse = SparkMod.Sync()
	if not syncResponse then
		warn("[SparkMod] Sync failed — backend may be unreachable")
		return
	end
	for _, service in services do
		if service._Hydrate then
			local ok, err = pcall(service._Hydrate, syncResponse)
			if not ok then
				warn(`[SparkMod] Service _Hydrate failed: {err}`)
			end
		end
	end
	if fireConnected then
		SparkMod.Connected:Fire()
	end
end

return SparkMod
