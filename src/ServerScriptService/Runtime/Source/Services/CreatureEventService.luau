local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Mince = require(ReplicatedStorage.Modules.Mince)
local EventManager = Mince:Get("EventManager")
local AnalyticsServer = Mince:Get("AnalyticsServer")


local isStudio = game:GetService("RunService"):IsStudio()

local DEFAULT_EVENT_DURATION = 60

local DEFAULT_WAIT_RANGE = {600, 900}

local FADE_IN_TIME = 2
local FADE_OUT_TIME = 2

local RARITY_SETTINGS = {
	Uncommon = {WaitRange = if isStudio then {30, 45} else {720, 1020}},
	Rare = {WaitRange = if isStudio then {60, 120} else {900, 1350}},
	Epic = {WaitRange = if isStudio then {120, 240} else {1050, 1500}},
	Legendary = {WaitRange = if isStudio then {240, 300} else {1500, 2100}},
	Mythical = {WaitRange = if isStudio then {300, 360} else {2100, 2700}},
}

local function deepCopy(source)
	if typeof(source) ~= "table" then
		return source
	end

	local target = {}
	for key, value in source do
		target[key] = deepCopy(value)
	end

	return target
end

local function findFirstAnimation(instance)
	return instance:FindFirstChildWhichIsA("Animation", true)
end

local function hasValidAnimationId(animation)
	if not animation or not animation:IsA("Animation") then
		return false
	end

	local animationId = animation.AnimationId
	return typeof(animationId) == "string"
		and animationId ~= ""
		and animationId ~= "0"
		and animationId ~= "rbxassetid://0"
		and not animationId:match("[?&]id=0$")
end

local function normalizeMessage(message)
	if not message then
		return nil
	end

	if typeof(message) == "string" then
		return { text = message }
	end

	if typeof(message) == "table" then
		if message.text then
			return {
				text = message.text,
				duration = message.duration,
				sound = message.sound,
				color = message.color,
				player = message.player or message.targetPlayer,
			}
		end

		if message[1] then
			return {
				text = message[1],
				duration = message[2],
				sound = message[3],
				color = message[4],
				player = message[5],
			}
		end
	end

	return nil
end

local function TrackLength(track)
	if not track then
		return nil
	end

	local length = track.Length
	if typeof(length) == "number" and length > 0 then
		return length
	end

	local success, value = pcall(function()
		return track:GetTimeLength()
	end)

	if success and typeof(value) == "number" and value > 0 then
		return value
	end

	return nil
end

local CreatureEventService = {
	Name = "CreatureEventService",
	SpawnFolderName = "GlobalEventCreatures",
	SpawnTag = "EventCreatureSpawn",
	DefaultEventDuration = DEFAULT_EVENT_DURATION,
	DefaultWaitRange = DEFAULT_WAIT_RANGE,
	RaritySettings = RARITY_SETTINGS,
}

CreatureEventService.__index = CreatureEventService

local Definition = {}
Definition.__index = Definition

function Definition.new(service, raw)
	assert(service, "CreatureEventService reference required")

	local self = setmetatable({}, Definition)
	self._service = service
	self._raw = deepCopy(raw or {})
	self:_hydrate()
	return self
end

function Definition:SetEventDuration(duration)
	local resolved = duration
	if typeof(resolved) ~= "number" or resolved <= 0 then
		resolved = self._service.DefaultEventDuration
	end

	self.EventDuration = resolved

	if self._eventBinding then
		self._eventBinding.EventDuration = resolved
	end
end

function Definition:_hydrate()
	local data = self._raw
	local service = self._service

	self.Name = data.Name or data.EventName or "Event Creature"
	self.Identifier = data.Identifier or data.Id or data.id or self.Name
	self.Chance = data.Chance or data.EventChance or data.eventChance or data.chance
	self.Disabled = data.Disabled or data.disabled or false
	self.Rarity = data.Rarity or data.rarity or "Rare"
	self.SpawnTag = data.SpawnTag or data.spawnTag or service.SpawnTag
	self.UseSpawnPoints = data.UseSpawnPoints
	self.PreservePosition = data.PreservePosition or data.preservePosition or (self.UseSpawnPoints == false)
	if self.UseSpawnPoints == nil then
		self.UseSpawnPoints = not self.PreservePosition
	end

	self.AnimationLoops = data.AnimationLoops or data.animationLoops or 1
	self.DespawnDelay = data.DespawnDelay or data.despawnDelay or service.DefaultDespawnDelay
	self.BufferTime = data.BufferTime or data.bufferTime or 0

	local raritySettings = service.RaritySettings[self.Rarity]
	self.WaitRange = data.WaitRange or data.waitRange or (raritySettings and raritySettings.WaitRange) or service.DefaultWaitRange

	self.AssetName = data.AssetName or data.assetName or data.ModelName or data.modelName or (data.Asset and data.Asset.Name)
	self.Asset = data.Asset
	self.AssetError = nil
	self.ScanId = data.ScanId or data.scanId or data._fishId

	local messages = data.Messages or data.messages or {}
	self.Messages = {
		Start = normalizeMessage(messages.Start or messages.start),
		Finish = normalizeMessage(messages.Finish or messages.finish),
		Failure = normalizeMessage(messages.Failure or messages.failure),
	}

	self.SpawnOffset = data.SpawnOffset or data.spawnOffset
	self.SpawnRotation = data.SpawnRotation or data.spawnRotation

	self:SetEventDuration(data.EventDuration or data.eventDuration)
	self.EventChance = self.Chance
end

function Definition:GetAsset()
	if self.Asset then
		return self.Asset, self.AssetError
	end

	local asset, err = self._service:GetAsset(self.AssetName)
	self.Asset = asset
	self.AssetError = err
	return asset, err
end

function Definition:GetNextWait()
	return self._service:GetNextWait(self)
end

function Definition:Start(storage)
	local ok, reason = self._service:StartEvent(self, storage)
	if ok then
		if storage and storage.SetNextWait then
			storage.SetNextWait(self:GetNextWait())
		end
		return true
	end
	self._service:NotifyFailure(self, storage, reason)
	return false, reason
end

function Definition:Stop()
	self._service:StopEvent(self)
end

function Definition:Matches(value)
	if value == nil then
		return true
	end
	if value == self or value == self._raw then
		return true
	end
	return value == self.Identifier
end

function Definition:ToEvent()
	local definition = self

	local event = {
		Name = definition.Name,
		EventDuration = definition.EventDuration,
		EventChance = definition.EventChance,
		Disabled = definition.Disabled,
		Definition = definition,
		Start = function(_, storage)
			return definition:Start(storage)
		end,
		End = function()
			definition:Stop()
		end,
		GetNextWait = function()
			return definition:GetNextWait()
		end,
	}

	definition._eventBinding = event

	return event
end

local ActiveEvent = {}
ActiveEvent.__index = ActiveEvent

function ActiveEvent.new(service, definition, storage)
	local spawnPoint
	if definition.UseSpawnPoints ~= false then
		local reason
		spawnPoint, reason = service:GetSpawnPoint(definition)
		if not spawnPoint then
			return nil, reason
		end
	end

	local asset, assetError = definition:GetAsset()
	if not asset then
		return nil, assetError or "Missing asset reference"
	end

	local model = asset:Clone()
	model.Parent = service.SpawnFolder

	if spawnPoint then
		model:PivotTo(service:GetSpawnCFrame(spawnPoint, definition))
	end

	local scannablePart = model:FindFirstChildWhichIsA("Part")
	if scannablePart and definition.ScanId then
		scannablePart:SetAttribute("_fishId", definition.ScanId)
	end

	local track, err = service:AnimationTrack(model)
	if not track then
		model:Destroy()
		return nil, err
	end

	local loops = tonumber(definition.AnimationLoops) or 1
	if loops < 1 then
		loops = 1
	end

	local bufferTime = tonumber(definition.BufferTime) or 0
	if bufferTime < 0 then
		bufferTime = 0
	end

	local trackLength = TrackLength(track)

	if not trackLength or trackLength <= 0 then
		for _ = 1, 10 do
			task.wait(0.1)
			trackLength = TrackLength(track)
			if trackLength and trackLength > 0 then break end
		end
	end

	local self = setmetatable({
		service = service,
		definition = definition,
		storage = storage,
		model = model,
		track = track,
		spawnPoint = spawnPoint,
		animationDuration = trackLength or 0,
		totalLoops = loops,
		bufferTime = bufferTime,
		connections = {},
		finished = false,
		cancelled = false,
		animationTimer = nil,
		remainingLoops = loops,
	}, ActiveEvent)

	local totalDuration = service:GetDefaultEventDuration()
	if trackLength and trackLength > 0 then
		totalDuration = (trackLength * loops) + bufferTime
	end
	self.expectedDuration = totalDuration
	definition:SetEventDuration(math.ceil(totalDuration))

	return self
end

function ActiveEvent:start()
	self.remainingLoops = self.totalLoops or 1
	local function onTrackStopped()
		if self.cancelled or self.finished then
			return
		end

		self.remainingLoops -= 1
		if self.remainingLoops > 0 then
			if not self.cancelled and self.track then
				pcall(function()
					self.track:Play()
				end)
			end
			return
		end

		self:_finishAfterBuffer()
	end

	self.connections.trackStopped = self.track.Stopped:Connect(onTrackStopped)
	self.track:Play()

	if self.expectedDuration then
		self.lifetimeTimer = task.delay(self.expectedDuration + 2, function()
			self.lifetimeTimer = nil
			if not self.finished and not self.cancelled then
				self:complete()
				warn("Had to forcibly complete event:", self.definition.Name)
			end
		end)
	end
end

function ActiveEvent:_finishAfterBuffer()
	if self.cancelled or self.finished then
		return
	end

	local bufferTime = self.bufferTime or 0
	if bufferTime > 0 then
		self.animationTimer = task.delay(bufferTime, function()
			self.animationTimer = nil
			if not self.cancelled then
				self:complete()
			end
		end)
	else
		self:complete()
	end
end

function ActiveEvent:matches(value)
	if value == nil then
		return true
	end
	if value == self or value == self.definition then
		return true
	end
	return self.definition:Matches(value)
end

function ActiveEvent:complete()
	if self.finished then
		return
	end

	self.finished = true
	self.service:TrackAnalytics(self.definition, "finished")
	self.service:SendMessage(self.storage, self.definition.Messages.Finish)

	self:fadeOut()
end

function ActiveEvent:fadeOut()
	if self.cancelled then
		return
	end

	for i, active in ipairs(self.service.ActiveEvents) do
		if active == self then
			table.remove(self.service.ActiveEvents, i)
			break
		end
	end

	self:destroy()
end

function ActiveEvent:destroy()
	if self.cancelled then
		return
	end

	self.cancelled = true

	-- Cancel animation timer
	if self.animationTimer then
		pcall(function()
			task.cancel(self.animationTimer)
		end)
		self.animationTimer = nil
	end

	-- Cancel lifetime timer
	if self.lifetimeTimer then
		pcall(function()
			task.cancel(self.lifetimeTimer)
		end)
		self.lifetimeTimer = nil
	end

	-- Disconnect all connections safely
	for key, connection in pairs(self.connections) do
		pcall(function()
			if connection and connection.Connected then
				connection:Disconnect()
			end
		end)
		self.connections[key] = nil
	end

	-- Stop animation track
	if self.track then
		pcall(function()
			if self.track.IsPlaying then
				self.track:Stop()
			end
		end)
	end

	-- Clear animation cache
	if self.model then
		pcall(function()
			self.service:ClearAnimationCache(self.model)
		end)
	end

	-- Destroy the spawned model
	if self.model then
		pcall(function()
			if self.model.Parent then
				self.model:Destroy()
			end
		end)
	end
end
function CreatureEventService:GetDefaultEventDuration()
	return self.DefaultEventDuration
end

function CreatureEventService:GetDefaultWaitRange()
	return self.DefaultWaitRange
end

function CreatureEventService:Setup()
	self.Random = Random.new(os.clock())
	self._animationCache = {}

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	self.AssetFolders = {}

	if assetsFolder then
		local preferredFolders = {"EventAnimals", "FishModels"}
		for _, name in preferredFolders do
			local folder = assetsFolder:FindFirstChild(name)
			if folder then
				table.insert(self.AssetFolders, folder)
			end
		end
	end

	if not self.AssetFolders or #self.AssetFolders == 0 then
		warn("No event creature asset folders found in ReplicatedStorage.Assets (expected 'EventAnimals' or 'FishModels'). Event creatures will not spawn until one exists.")
	end

	self.SpawnFolder = Workspace:FindFirstChild(self.SpawnFolderName)
	if not self.SpawnFolder then
		self.SpawnFolder = Instance.new("Folder")
		self.SpawnFolder.Name = self.SpawnFolderName
		self.SpawnFolder.Parent = Workspace
	end

	self.SpawnPoints = {}
	self.SpawnPointLookup = {}
	self.ActiveEvents = {}

	self:_trackSpawnPoints()
end

function CreatureEventService:_trackSpawnPoints()
	for _, instance in CollectionService:GetTagged(self.SpawnTag) do
		self:AddSpawnPoint(instance)
	end

	CollectionService:GetInstanceAddedSignal(self.SpawnTag):Connect(function(instance)
		self:AddSpawnPoint(instance)
	end)

	CollectionService:GetInstanceRemovedSignal(self.SpawnTag):Connect(function(instance)
		self:RemoveSpawnPoint(instance)
	end)
end

function CreatureEventService:AddSpawnPoint(instance)
	if not instance or self.SpawnPointLookup[instance] then
		return
	end

	self.SpawnPointLookup[instance] = true
	table.insert(self.SpawnPoints, instance)
end

function CreatureEventService:RemoveSpawnPoint(instance)
	if not instance or not self.SpawnPointLookup[instance] then
		return
	end

	self.SpawnPointLookup[instance] = nil

	for index, item in self.SpawnPoints do
		if item == instance then
			table.remove(self.SpawnPoints, index)
			break
		end
	end
end

function CreatureEventService:GetAsset(assetName)
	if not assetName or assetName == "" then
		return nil, "No asset name provided"
	end

	local folders = self.AssetFolders or {}
	if #folders == 0 then
		return nil, "No event creature asset folders are available"
	end

	for i, folder in folders do
		local asset = folder:FindFirstChild(assetName)
		if asset then
			return asset
		end
	end

	return nil, string.format("Asset '%s' was not found in any configured event creature folders.", assetName)
end

function CreatureEventService:GetSpawnCandidates(definition)
	local candidates = {}
	local usedSpawnPoints = {}

	for _, activeEvent in ipairs(self.ActiveEvents) do
		if activeEvent.spawnPoint then
			usedSpawnPoints[activeEvent.spawnPoint] = true
		end
	end

	for index = #self.SpawnPoints, 1, -1 do
		local spawnPoint = self.SpawnPoints[index]
		if not spawnPoint or not spawnPoint.Parent then
			self.SpawnPointLookup[spawnPoint] = nil
			table.remove(self.SpawnPoints, index)
		else
			if not usedSpawnPoints[spawnPoint] then
				local requiredId = spawnPoint:GetAttribute("EventCreatureId")
				local requiredRarity = spawnPoint:GetAttribute("EventRarity")

				local matchesCreature = not requiredId or requiredId == definition.Identifier
				local matchesRarity = not requiredRarity or requiredRarity == definition.Rarity

				if matchesCreature and matchesRarity then
					table.insert(candidates, spawnPoint)
				end
			end
		end
	end

	return candidates
end

function CreatureEventService:GetSpawnPoint(definition)
	local candidates = self:GetSpawnCandidates(definition)
	if #candidates == 0 then
		return nil, "No spawn points configured."
	end

	return candidates[self.Random:NextInteger(1, #candidates)]
end

function CreatureEventService:GetSpawnCFrame(spawnPoint, definition)
	local baseCFrame

	if spawnPoint:IsA("BasePart") then
		baseCFrame = spawnPoint.CFrame
	else
		local success, result = pcall(function()
			if spawnPoint:IsA("Model") then
				return spawnPoint:GetPivot()
			end
			return spawnPoint.CFrame
		end)

		if success then
			baseCFrame = result
		end
	end

	baseCFrame = baseCFrame or CFrame.new()

	local offset = definition.SpawnOffset
	if typeof(offset) == "Vector3" then
		baseCFrame *= CFrame.new(offset)
	end

	local orientation = definition.SpawnRotation
	if typeof(orientation) == "Vector3" then
		baseCFrame *= CFrame.Angles(math.rad(orientation.X), math.rad(orientation.Y), math.rad(orientation.Z))
	elseif typeof(orientation) == "CFrame" then
		baseCFrame *= orientation
	end

	return baseCFrame
end

function CreatureEventService:_getAnimationKey(animation)
	local animationId = animation.AnimationId
	if typeof(animationId) == "string" and animationId ~= "" then
		return animationId
	end

	return animation.Name
end

function CreatureEventService:_getAnimator(model, create)
	local humanoid = model:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		local animator = humanoid:FindFirstChildWhichIsA("Animator")
		if not animator and create ~= false then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	if not controller and create ~= false then
		controller = Instance.new("AnimationController")
		controller.Name = "EventAnimationController"
		controller.Parent = model
	end

	if not controller then
		return nil
	end

	local animator = controller:FindFirstChildWhichIsA("Animator")
	if not animator and create ~= false then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	return animator
end

function CreatureEventService:ClearAnimationCache(model)
	if not model or not self._animationCache then
		return
	end

	-- Use model as the primary cache key
	self._animationCache[model] = nil
end
function CreatureEventService:AnimationTrack(model)
	local animation = findFirstAnimation(model)
	if not animation then
		return nil, "No Animation object found"
	end
	if not hasValidAnimationId(animation) then
		return nil, "Animation has no valid AnimationId"
	end

	local animator = self:_getAnimator(model, true)
	if not animator then
		return nil, "No Animator available"
	end

	local playingTracks = animator:GetPlayingAnimationTracks()
	for _, oldTrack in ipairs(playingTracks) do
		pcall(function()
			oldTrack:Stop()
		end)
	end

	local animationKey = self:_getAnimationKey(animation)
	local cache = self._animationCache or {}
	self._animationCache = cache

	-- Use model as cache key instead of animator (animator can be GC'd)
	local modelCache = cache[model]
	if not modelCache then
		modelCache = {}
		cache[model] = modelCache
	end

	local cachedTrack = modelCache[animationKey]
	if cachedTrack then
		local ok = pcall(function()
			if cachedTrack.IsPlaying then
				cachedTrack:Stop()
			end
			cachedTrack.Looped = false
		end)
		if ok then
			return cachedTrack
		end
		modelCache[animationKey] = nil
	end
	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not success then
		return nil, track
	end

	track.Looped = false
	modelCache[animationKey] = track
	return track
end

function CreatureEventService:GetNextWait(definition)
	local range = definition and definition.WaitRange or self.DefaultWaitRange
	local min = range[1] or 600
	local max = range[2] or (min + 300)

	if max <= min then
		return min
	end

	return self.Random:NextInteger(min, max)
end

function CreatureEventService:SendMessage(storage, template)
	if not template or not template.text then
		return
	end

	if storage and storage.Message then
		storage.Message(template)
		return
	end

	if EventManager and EventManager.Message then
		EventManager.Message(template)
	end
end

function CreatureEventService:TrackAnalytics(definition, status)
	if not AnalyticsServer or not AnalyticsServer.TrackCreatureEvent then
		return
	end

	local ok, err = pcall(function()
		AnalyticsServer:TrackCreatureEvent(status, definition)
	end)
	if not ok then
		warn("CreatureEvent analytics failed:", err)
	end
end

function CreatureEventService:NotifyFailure(definition, storage, reason)
	local message = tostring(reason)
	warn(string.format("Failed to start '%s': %s", definition.Name, message))
	self:TrackAnalytics(definition, "failed")

	local shouldInformPlayers = message ~= "Another event is already active"

	if shouldInformPlayers then
		self:SendMessage(storage, definition.Messages.Failure)
	end

	if storage and storage.SetNextWait then
		storage.SetNextWait(self:GetNextWait(definition))
	end

	if shouldInformPlayers and storage and storage.End then
		task.defer(storage.End, storage)
	end
end

function CreatureEventService:CreateDefinition(raw)
	return Definition.new(self, raw)
end

function CreatureEventService:EnsureDefinition(definition)
	if getmetatable(definition) == Definition then
		definition._service = self
		definition:GetAsset()
		return definition
	end

	local created = Definition.new(self, definition)
	created:GetAsset()
	return created
end

function CreatureEventService:StartEvent(definition, storage)
	local prepared, err = self:EnsureDefinition(definition)
	if not prepared then
		return false, err or "Invalid event definition"
	end

	if not prepared.Asset then
		return false, prepared.AssetError or "Missing asset reference"
	end

	-- if #self.ActiveEvents > 0 then
	-- 	return false, "Another event is already active"
	-- end

	local active, startErr = ActiveEvent.new(self, prepared, storage)
	if not active then
		return false, startErr
	end

	table.insert(self.ActiveEvents, active)
	active:start()

	if table.find({"Uncommon", "Rare", "Epic", "Legendary", "Mythical"}, prepared.Rarity) then
		local AchievementService = Mince:Get("AchievementService")
		if AchievementService then
			for _, player in ipairs(Players:GetPlayers()) do
				AchievementService:RecordStat(player, "RareEvent", 1)
			end
		end
	end

	print("Event Started", definition, storage)

	self:TrackAnalytics(definition, "started")
	self:SendMessage(storage, definition.Messages.Start)

	return true
end

function CreatureEventService:StopEvent(identifier)
	for i = #self.ActiveEvents, 1, -1 do
		local active = self.ActiveEvents[i]
		if active:matches(identifier) then
			active:destroy()

			if not active.finished then
				self:SendMessage(active.storage, active.definition.Messages.Finish)
			end

			table.remove(self.ActiveEvents, i)
			break
		end
	end
end

CreatureEventService.Definition = Definition

return CreatureEventService
