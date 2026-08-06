local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local PhenomenonService = {
	Name = "PhenomenonService",

	Config = {
		SlotDuration = 600,
		SlotsPerHour = 6,
		HoursAhead = 4,

		RarityRules = {
			Mythical = 1,
			Legendary = 1,
			Epic = 2,
			Rare = 2,
		},

		DefaultSubject = {
			Name = "Unknown Anomaly",
			Rarity = "Rare",
			AssetName = "",
			ScanId = "",
		},
	},

	Timeline = {},
	Active = {},
	ManifestedSlots = {},
	ManifestRetryAt = {},
	Registry = {},
	Pools = {},

	SpawnFolder = nil,
	SpawnPoints = {},
}

local RARITY_PRIORITY = {
	Mythical = 5,
	Legendary = 4,
	Epic = 3,
	Rare = 2,
	Uncommon = 1,
}

local SYNCHRONIZED_LOOPED_ATTRIBUTE = "SynchronizedAnimationLooped"

local function utcNow()
	return os.time(os.date("!*t"))
end

local function getSlotStartTime(timestamp, slotDuration)
	return timestamp - (timestamp % slotDuration)
end

local function deepCopy(source)
	if typeof(source) ~= "table" then
		return source
	end
	local target = {}
	for key, value in pairs(source) do
		target[key] = deepCopy(value)
	end
	return target
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

local PhenomenonDefinition = {}
PhenomenonDefinition.__index = PhenomenonDefinition

function PhenomenonDefinition.new(data)
	local self = setmetatable({}, PhenomenonDefinition)

	self.Id = data.Id or data.Identifier or data.Name or "Unknown"
	self.Name = data.Name or "Unknown Phenomenon"
	self.Rarity = data.Rarity or "Rare"
	self.Description = data.Description or ""
	self.ScanId = data.ScanId or data.Id or ""

	self.AssetName = data.AssetName or data.CreatureName or ""
	self.AnimationLoops = data.AnimationLoops or 1
	self.SpawnOffset = data.SpawnOffset
	self.SpawnRotation = data.SpawnRotation
	self.PreservePosition = data.PreservePosition or false
	self.UseSpawnPoints = data.UseSpawnPoints
	if self.UseSpawnPoints == nil then
		self.UseSpawnPoints = not self.PreservePosition
	end
	self.DespawnDelay = data.DespawnDelay or 2

	local messages = data.Messages or {}
	self.Messages = {
		Start = messages.Start or messages.start or (self.Name .. " has manifested!"),
		Finish = messages.Finish or messages.finish or (self.Name .. " has vanished."),
	}

	if typeof(self.Messages.Start) == "string" then
		self.Messages.Start = { text = self.Messages.Start, duration = 8 }
	end
	if typeof(self.Messages.Finish) == "string" then
		self.Messages.Finish = { text = self.Messages.Finish, duration = 6 }
	end

	return self
end

local ActivePhenomenon = {}
ActivePhenomenon.__index = ActivePhenomenon

function ActivePhenomenon.new(service, definition, slotData)
	local self = setmetatable({}, ActivePhenomenon)

	self._service = service
	self.Definition = definition
	self.StartTime = slotData.StartTime
	self.EndTime = slotData.EndTime
	self.SlotIndex = slotData.SlotIndex

	self._model = nil
	self._track = nil
	self._connections = {}
	self._finished = false
	self._cancelled = false

	return self
end

function ActivePhenomenon:Start()
	if self._finished or self._cancelled then
		return false, "Phenomenon is no longer active"
	end

	local spawnPoint = self:_getSpawnPoint()
	if not spawnPoint and self.Definition.UseSpawnPoints then
		return false, "No compatible spawn point is available"
	end
	self._spawnPoint = spawnPoint

	local asset = self:_getAsset()
	if not asset then
		return false, string.format("Asset '%s' was not found", tostring(self.Definition.AssetName))
	end

	self._model = asset:Clone()
	self._model:SetAttribute(SYNCHRONIZED_LOOPED_ATTRIBUTE, self.Definition.AnimationLoops > 1)
	self._model.Parent = self._service.SpawnFolder

	if spawnPoint then
		local cf = self:_getSpawnCFrame(spawnPoint)
		self._model:PivotTo(cf)
	end

	local primaryPart = self._model:FindFirstChildWhichIsA("BasePart", true)
	if primaryPart and self.Definition.ScanId ~= "" then
		primaryPart:SetAttribute("_fishId", self.Definition.ScanId)
	end

	if not self:_setupAnimation() then
		self:_cleanup()
		return false, "The creature animation could not be loaded"
	end

	self:_sendMessage(self.Definition.Messages.Start)
	self:_trackAnalytics("started")
	self:_awardAchievement()

	return true
end

function ActivePhenomenon:_getSpawnPoint()
	if not self.Definition.UseSpawnPoints then
		return nil
	end

	local points = self._service.SpawnPoints
	if #points == 0 then
		return nil
	end

	local available = {}
	for _, point in ipairs(points) do
		if point and point.Parent then
			local inUse = false
			for _, active in ipairs(self._service.Active or {}) do
				if active ~= self and active._spawnPoint == point then
					inUse = true
					break
				end
			end

			if not inUse then
				local requiredId = point:GetAttribute("EventCreatureId")
				local requiredRarity = point:GetAttribute("EventRarity")

				local matchesId = not requiredId or requiredId == self.Definition.Id
				local matchesRarity = not requiredRarity or requiredRarity == self.Definition.Rarity

				if matchesId and matchesRarity then
					table.insert(available, point)
				end
			end
		end
	end

	if #available == 0 then
		return nil
	end
	return available[Random.new(os.clock()):NextInteger(1, #available)]
end

function ActivePhenomenon:_getSpawnCFrame(spawnPoint)
	local baseCF
	if spawnPoint:IsA("BasePart") then
		baseCF = spawnPoint.CFrame
	elseif spawnPoint:IsA("Model") then
		baseCF = spawnPoint:GetPivot()
	else
		baseCF = CFrame.new()
	end

	if self.Definition.SpawnOffset then
		baseCF = baseCF * CFrame.new(self.Definition.SpawnOffset)
	end

	if self.Definition.SpawnRotation then
		local rot = self.Definition.SpawnRotation
		baseCF = baseCF * CFrame.Angles(math.rad(rot.X or 0), math.rad(rot.Y or 0), math.rad(rot.Z or 0))
	end

	return baseCF
end

function ActivePhenomenon:_getAsset()
	local assetName = self.Definition.AssetName
	if not assetName or assetName == "" then
		return nil
	end

	local folders = self._service.AssetFolders
	for _, folder in ipairs(folders or {}) do
		local asset = folder:FindFirstChild(assetName)
		if asset then
			return asset
		end
	end

	return nil
end

function ActivePhenomenon:_setupAnimation()
	if not self._model then
		return false
	end

	local animation = self._model:FindFirstChildWhichIsA("Animation", true)
	if not animation then
		return true
	end
	if not hasValidAnimationId(animation) then
		return true
	end

	local speed = self._model:GetAttribute("AnimationSpeed") or animation:GetAttribute("Speed") or 1
	if typeof(speed) ~= "number" or speed ~= speed or speed <= 0 or speed == math.huge then
		speed = 1
	end

	local animator = self:_getAnimator()
	if not animator then
		return false
	end

	local success, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)

	if not success or not track then
		return false
	end

	self._track = track
	track.Looped = false

	local loopsRemaining = self.Definition.AnimationLoops or 1

	self._connections.trackStopped = track.Stopped:Connect(function()
		loopsRemaining = loopsRemaining - 1
		if loopsRemaining > 0 and not self._cancelled then
			track:Play(0, 0, speed)
		else
			self:_scheduleDespawn()
		end
	end)

	track:Play(0, 0, speed)
	return true
end

function ActivePhenomenon:_getAnimator()
	if not self._model then
		return nil
	end

	local humanoid = self._model:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		local animator = humanoid:FindFirstChildWhichIsA("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end
		return animator
	end

	local controller = self._model:FindFirstChildWhichIsA("AnimationController", true)
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Name = "Animator"
		controller.Parent = self._model
	end

	local animator = controller:FindFirstChildWhichIsA("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = controller
	end

	return animator
end

function ActivePhenomenon:_scheduleDespawn()
	local delayTime = self.Definition.DespawnDelay or 0
	if delayTime > 0 then
		task.delay(delayTime, function()
			if not self._cancelled then
				self:Complete()
			end
		end)
	else
		self:Complete()
	end
end

function ActivePhenomenon:_sendMessage(messageData)
	if not messageData or not messageData.text then
		return
	end

	local Notice = Mince:Get("CreatureEventNotice")
	if Notice and Notice.Broadcast then
		local ok, err = pcall(function()
			Notice:Broadcast(messageData.text, messageData.duration, messageData.sound, messageData.color)
		end)
		if not ok then
			warn("[PhenomenonService] Failed to send creature notice:", err)
		end
	end
end

function ActivePhenomenon:_trackAnalytics(status)
	local Analytics = Mince:Get("AnalyticsServer")
	if Analytics and Analytics.TrackCreatureEvent then
		local ok, err = pcall(function()
			Analytics:TrackCreatureEvent(status, self.Definition)
		end)
		if not ok then
			warn("[PhenomenonService] Failed to track creature event:", err)
		end
	end
end

function ActivePhenomenon:_awardAchievement()
	local AchievementService = Mince:Get("AchievementService")
	if not AchievementService then
		return
	end

	if (RARITY_PRIORITY[self.Definition.Rarity] or 0) >= 2 then
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = pcall(function()
				AchievementService:RecordStat(player, "RareEvent", 1)
			end)
			if not ok then
				warn("[PhenomenonService] Failed to award creature-event progress:", err)
			end
		end
	end
end

function ActivePhenomenon:Complete()
	if self._finished then
		return
	end
	self._finished = true

	self:_sendMessage(self.Definition.Messages.Finish)
	self:_trackAnalytics("finished")
	self:_cleanup()

	for i, active in ipairs(self._service.Active or {}) do
		if active == self then
			table.remove(self._service.Active, i)
			break
		end
	end
end

function ActivePhenomenon:_cleanup()
	self._cancelled = true

	for _, conn in pairs(self._connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	self._connections = {}

	if self._track then
		pcall(function()
			self._track:Stop()
		end)
	end

	if self._model and self._model.Parent then
		pcall(function()
			for _, part in ipairs(self._model:GetDescendants()) do
				if part:IsA("BasePart") then
					TweenService:Create(part, TweenInfo.new(2), {
						Transparency = 1,
					}):Play()
				end
			end
		end)

		task.delay(2, function()
			if self._model and self._model.Parent then
				self._model:Destroy()
			end
		end)
	end
end

function PhenomenonService:Setup()
	self.Random = Random.new(os.clock())

	self.Active = {}
	self.Timeline = {}
	self.ManifestedSlots = {}
	self.ManifestRetryAt = {}
	self.Registry = {}
	self.Pools = {
		Mythical = {},
		Legendary = {},
		Epic = {},
		Rare = {},
		Uncommon = {},
	}

	self.SpawnFolder = Workspace:FindFirstChild("GlobalEventCreatures")
	if not self.SpawnFolder then
		self.SpawnFolder = Instance.new("Folder")
		self.SpawnFolder.Name = "GlobalEventCreatures"
		self.SpawnFolder.Parent = Workspace
	end

	self:_loadAssetFolders()
	self:_trackSpawnPoints()
	self:_loadDefinitions()
	self:_setupRemotes()
	self:_regenerateTimeline()
end

function PhenomenonService:_loadAssetFolders()
	self.AssetFolders = {}

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder then
		local preferred = { "EventAnimals", "FishModels" }
		for _, name in ipairs(preferred) do
			local folder = assetsFolder:FindFirstChild(name)
			if folder then
				table.insert(self.AssetFolders, folder)
			end
		end
	end
end

function PhenomenonService:_trackSpawnPoints()
	self.SpawnPoints = {}
	self.SpawnPointLookup = {}

	for _, instance in ipairs(CollectionService:GetTagged("EventCreatureSpawn")) do
		self:_addSpawnPoint(instance)
	end

	CollectionService:GetInstanceAddedSignal("EventCreatureSpawn"):Connect(function(instance)
		self:_addSpawnPoint(instance)
	end)

	CollectionService:GetInstanceRemovedSignal("EventCreatureSpawn"):Connect(function(instance)
		self:_removeSpawnPoint(instance)
	end)
end

function PhenomenonService:_addSpawnPoint(instance)
	if not instance or self.SpawnPointLookup[instance] then
		return
	end

	self.SpawnPointLookup[instance] = true
	table.insert(self.SpawnPoints, instance)
end

function PhenomenonService:_removeSpawnPoint(instance)
	if not instance or not self.SpawnPointLookup[instance] then
		return
	end

	self.SpawnPointLookup[instance] = nil

	for i, point in ipairs(self.SpawnPoints) do
		if point == instance then
			table.remove(self.SpawnPoints, i)
			break
		end
	end
end

function PhenomenonService:_loadDefinitions()
	local Manager = ServerScriptService.Runtime.Source.Systems:FindFirstChild("EventManager")
	if Manager then
		local folder = Manager:FindFirstChild("Events")
		if folder then
			for _, module in ipairs(folder:GetChildren()) do
				if module:IsA("ModuleScript") then
					self:_registerModule(module)
				end
			end
		end
	end

	if Mince.Config and Mince.Config.Shared and Mince.Config.Shared.EventConfig then
		local config = Mince.Config.Shared.EventConfig
		if config.Events then
			for _, data in ipairs(config.Events) do
				self:_register(data)
			end
		end
	end
end

function PhenomenonService:_registerModule(module)
	local success, result = pcall(require, module)
	if not success then
		return
	end

	local data = result
	if result.Definition then
		data = result.Definition
	end

	self:_register(data, module.Name)
end

function PhenomenonService:_register(data, sourceName)
	if not data or data.Disabled then
		return
	end

	local definition = PhenomenonDefinition.new(data)
	definition.Source = sourceName

	self.Registry[definition.Id] = definition

	local pool = self.Pools[definition.Rarity]
	if pool then
		table.insert(pool, definition.Id)
	else
		table.insert(self.Pools.Rare, definition.Id)
	end
end

function PhenomenonService:_setupRemotes()
	self.Remote = Mince:GetEvent("Phenomena")

	self.Remote.Timeline = self.Remote:Extend("Timeline")
	self.Remote.Timeline.Event:Connect(function(player)
		self.Remote.Timeline:Fire(player, {
			Timeline = self:_getClientTimeline(),
			ServerTimeUTC = utcNow(),
		})
	end)

	self.Remote.Registry = self.Remote:Extend("Registry")
	self.Remote.Registry.Event:Connect(function(player)
		self.Remote.Registry:Fire(player, self:_getClientRegistry())
	end)
end

function PhenomenonService:_regenerateTimeline()
	local now = utcNow()
	local slotDuration = self.Config.SlotDuration
	local hoursAhead = self.Config.HoursAhead
	local existingSlots = {}
	local newTimeline = {}

	for _, hourBlock in ipairs(self.Timeline or {}) do
		for _, slot in ipairs(hourBlock.Phenomena or {}) do
			existingSlots[slot.StartTime] = slot.Data
		end
	end

	local currentSlotStart = getSlotStartTime(now, slotDuration)

	for hourOffset = 0, hoursAhead - 1 do
		local hourStart = currentSlotStart + (hourOffset * 3600)
		local phenomena = self:_generateHour(hourStart)

		for _, slot in ipairs(phenomena) do
			local existingData = existingSlots[slot.StartTime]
			if existingData then
				slot.Data = deepCopy(existingData)
			end
		end

		if #phenomena > 0 then
			table.insert(newTimeline, {
				HourStartTime = hourStart,
				Phenomena = phenomena,
			})
		end
	end

	self.Timeline = newTimeline
	self:_broadcastTimeline()
end

function PhenomenonService:_generateHour(hourStart)
	local slotDuration = self.Config.SlotDuration
	local slotsPerHour = self.Config.SlotsPerHour
	local rules = self.Config.RarityRules

	local picks = {}
	local fallbackPools = {}

	for rarity, pool in pairs(self.Pools) do
		if pool and #pool > 0 then
			table.insert(fallbackPools, { Rarity = rarity, Pool = pool })
		end
	end

	for rarity, count in pairs(rules) do
		local pool = self.Pools[rarity]
		if pool and #pool > 0 then
			for _ = 1, count do
				table.insert(picks, { Rarity = rarity, Pool = pool })
			end
		end
	end

	if #picks == 0 then
		for rarity, pool in pairs(self.Pools) do
			if #pool > 0 then
				table.insert(picks, { Rarity = rarity, Pool = pool })
				break
			end
		end
	end

	if #picks == 0 then
		for _ = 1, slotsPerHour do
			table.insert(picks, { Rarity = "Rare", Fallback = true })
		end
	end

	while #picks < slotsPerHour do
		if #fallbackPools > 0 then
			table.insert(picks, fallbackPools[self.Random:NextInteger(1, #fallbackPools)])
		else
			table.insert(picks, { Rarity = "Rare", Fallback = true })
		end
	end

	for i = #picks, 2, -1 do
		local j = self.Random:NextInteger(1, i)
		picks[i], picks[j] = picks[j], picks[i]
	end

	local phenomena = {}
	local usedIds = {}

	for slotIndex = 0, slotsPerHour - 1 do
		local pick = picks[slotIndex + 1]
		if not pick then
			continue
		end

		local definition = nil

		if pick.Fallback then
			definition = PhenomenonDefinition.new({
				Id = "fallback_" .. tostring(slotIndex),
				Name = "Unknown Anomaly",
				Rarity = "Rare",
				Description = "Readings indicate something unusual approaching...",
			})
		else
			local pool = pick.Pool
			local attempts = 0
			local chosenId = nil

			while attempts < 10 and not chosenId do
				local candidate = pool[self.Random:NextInteger(1, #pool)]
				if not usedIds[candidate] then
					chosenId = candidate
				end
				attempts = attempts + 1
			end

			if not chosenId and #pool > 0 then
				chosenId = pool[1]
			end

			if chosenId then
				usedIds[chosenId] = true
				definition = self.Registry[chosenId]
			end
		end

		if definition then
			table.insert(phenomena, {
				Slot = slotIndex,
				StartTime = hourStart + (slotIndex * slotDuration),
				EndTime = hourStart + ((slotIndex + 1) * slotDuration),
				Data = {
					Id = definition.Id,
					Name = definition.Name,
					Rarity = definition.Rarity,
					Description = definition.Description,
					ScanId = definition.ScanId,
				},
			})
		end
	end

	return phenomena
end

function PhenomenonService:GameStart()
	self.Enabled = true

	task.spawn(function()
		while self.Enabled do
			task.wait(1)

			if #Players:GetPlayers() > 0 then
				local ok, err = pcall(function()
					self:_update()
				end)
				if not ok then
					warn("[PhenomenonService] Update error:", err)
				end
			end
		end
	end)

	task.spawn(function()
		while self.Enabled do
			task.wait(600)

			if #Players:GetPlayers() > 0 then
				local ok, err = pcall(function()
					self:_regenerateTimeline()
				end)
				if not ok then
					warn("[PhenomenonService] Timeline regeneration error:", err)
				end
			end
		end
	end)
end

function PhenomenonService:_update()
	local now = utcNow()
	local slotDuration = self.Config.SlotDuration

	for slotStart in pairs(self.ManifestedSlots) do
		if now >= slotStart + slotDuration then
			self.ManifestedSlots[slotStart] = nil
		end
	end

	for slotStart in pairs(self.ManifestRetryAt) do
		if now >= slotStart + slotDuration then
			self.ManifestRetryAt[slotStart] = nil
		end
	end

	local lastBlock = self.Timeline[#self.Timeline]
	if lastBlock then
		local timelineEnd = lastBlock.HourStartTime + 3600
		if now > timelineEnd - 1800 then
			self:_regenerateTimeline()
		end
	end

	for _, hourBlock in ipairs(self.Timeline) do
		if hourBlock.Phenomena then
			for _, slot in ipairs(hourBlock.Phenomena) do
				if now >= slot.StartTime and now < slot.EndTime then
					self:_maybeManifest(slot)
				end
			end
		end
	end

	for i = #self.Active, 1, -1 do
		local active = self.Active[i]
		if now >= active.EndTime and not active._finished then
			active:Complete()
		end
	end
end

function PhenomenonService:_maybeManifest(slotData)
	if self.ManifestedSlots[slotData.StartTime] then
		return
	end

	local now = utcNow()
	local retryAt = self.ManifestRetryAt[slotData.StartTime]
	if retryAt and now < retryAt then
		return
	end

	for _, active in ipairs(self.Active) do
		if active.StartTime == slotData.StartTime then
			return
		end
	end

	local definition = self.Registry[slotData.Data.Id]
	if not definition then
		for _, def in pairs(self.Registry) do
			if def.Rarity == slotData.Data.Rarity then
				definition = def
				break
			end
		end
	end

	if not definition then
		definition = PhenomenonDefinition.new(slotData.Data)
	end

	local phenomenon = ActivePhenomenon.new(self, definition, slotData)
	table.insert(self.Active, phenomenon)

	local callOk, started, reason = pcall(function()
		return phenomenon:Start()
	end)
	if not callOk then
		reason = started
		started = false
		pcall(function()
			phenomenon:_cleanup()
		end)
	end

	if started then
		self.ManifestedSlots[slotData.StartTime] = definition.Id
		self.ManifestRetryAt[slotData.StartTime] = nil
	else
		for i, active in ipairs(self.Active) do
			if active == phenomenon then
				table.remove(self.Active, i)
				break
			end
		end

		self.ManifestRetryAt[slotData.StartTime] = now + 30
		warn(
			string.format(
				"[PhenomenonService] Failed to manifest '%s' for slot %d: %s",
				tostring(definition.Id),
				slotData.StartTime,
				tostring(reason or "unknown error")
			)
		)
	end
end

function PhenomenonService:_getClientTimeline()
	return self.Timeline
end

function PhenomenonService:_getClientRegistry()
	local registry = {}
	for id, def in pairs(self.Registry) do
		registry[id] = {
			Id = def.Id,
			Name = def.Name,
			Rarity = def.Rarity,
			Description = def.Description,
			ScanId = def.ScanId,
		}
	end
	return registry
end

function PhenomenonService:_broadcastTimeline()
	if not self.Remote or not self.Remote.Timeline then
		return
	end

	self.Remote.Timeline:FireAll({
		Timeline = self:_getClientTimeline(),
		ServerTimeUTC = utcNow(),
	})
end

function PhenomenonService:GetTimeline()
	return self.Timeline
end

function PhenomenonService:GetCurrent()
	local now = utcNow()

	for _, active in ipairs(self.Active) do
		if now >= active.StartTime and now < active.EndTime and not active._finished then
			return {
				Id = active.Definition.Id,
				Name = active.Definition.Name,
				Rarity = active.Definition.Rarity,
				StartTime = active.StartTime,
				EndTime = active.EndTime,
			}
		end
	end

	return nil
end

function PhenomenonService:GetUpcoming(count)
	count = count or 5
	local now = utcNow()
	local upcoming = {}

	for _, hourBlock in ipairs(self.Timeline) do
		if hourBlock.Phenomena then
			for _, slot in ipairs(hourBlock.Phenomena) do
				if slot.EndTime > now and #upcoming < count then
					table.insert(upcoming, slot)
				end
			end
		end
	end

	return upcoming
end

function PhenomenonService:ForceManifestation(id)
	local definition = self.Registry[id]
	if not definition then
		return false
	end

	local now = utcNow()
	local slotData = {
		SlotIndex = 0,
		StartTime = now,
		EndTime = now + self.Config.SlotDuration,
	}

	local phenomenon = ActivePhenomenon.new(self, definition, slotData)
	table.insert(self.Active, phenomenon)

	return phenomenon:Start()
end

return PhenomenonService
