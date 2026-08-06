local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local FireworkEventConfig = require(ReplicatedStorage.Config.FireworkEventConfig)
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)
local MapManager = require(ServerScriptService:WaitForChild("MapManager"))

local FireworkEventService = Knit.CreateService({
	Name = "FireworkEventService",
	Client = {},
})

local EVENT_ACTIVE = false

-- ========== State ==========

local activeTrove = nil
local vfxFolder = nil
local lightingEffects = {}
local spawnLoops = {}
local activeTweens = {}
local templateSoundAnchors: {[Model]: BasePart} = {}
local cachedLighting = {
	atmosphere = nil,
	sky = nil,
	clouds = nil,
	postEffects = {},
	properties = {},
}
local cacheFolder = nil
local cleanupThread = nil
local rainWatching = false
local rainWatcherThread = nil

local LIGHTING_PROPERTIES_TO_CACHE = {
	"ClockTime",
	"Ambient",
	"OutdoorAmbient",
	"Brightness",
	"GlobalShadows",
	"ShadowSoftness",
	"GeographicLatitude",
}

-- ========== Asset & Utility ==========

local function getAssetRoot()
	local path = FireworkEventConfig.ASSET_ROOT:split(".")
	local root = game
	for _, name in ipairs(path) do
		root = root:FindFirstChild(name)
		if not root then
			warn(`[FireworkEventService] missing asset: {name}`)
			return nil
		end
	end
	return root
end

local function cancelTweens()
	for _, tween in ipairs(activeTweens) do
		pcall(function()
			tween:Cancel()
		end)
	end
	table.clear(activeTweens)
	if cleanupThread then
		pcall(task.cancel, cleanupThread)
		cleanupThread = nil
	end
end

local function clearLightingEffects()
	for _, effect in ipairs(lightingEffects) do
		pcall(function()
			effect:Destroy()
		end)
	end
	table.clear(lightingEffects)
end

local function tweenObject(obj, goal, duration)
	local tween = TweenService:Create(
		obj,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		goal
	)
	table.insert(activeTweens, tween)
	tween:Play()
	tween.Completed:Connect(function()
		for i, t in ipairs(activeTweens) do
			if t == tween then
				table.remove(activeTweens, i)
				break
			end
		end
	end)
	return tween
end

-- ========== Lighting ==========

local function cacheCurrentLighting()
	if cacheFolder then
		cacheFolder:Destroy()
		cacheFolder = nil
	end

	cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "FireworkEventLightingCache"
	cacheFolder.Parent = game:GetService("ServerStorage")

	for _, prop in ipairs(LIGHTING_PROPERTIES_TO_CACHE) do
		cachedLighting.properties[prop] = Lighting[prop]
	end

	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Atmosphere") then
			cachedLighting.atmosphere = child
			child.Parent = cacheFolder
		elseif child:IsA("Sky") then
			cachedLighting.sky = child
			child.Parent = cacheFolder
		elseif child:IsA("Clouds") then
			cachedLighting.clouds = child
			child.Parent = cacheFolder
		elseif child:IsA("PostEffect") then
			table.insert(cachedLighting.postEffects, {
				effect = child,
				enabled = child.Enabled,
			})
			child.Enabled = false
		end
	end
end

local function finalizeRestore()
	clearLightingEffects()

	for _, data in ipairs(cachedLighting.postEffects) do
		pcall(function()
			data.effect.Enabled = data.enabled
		end)
	end
	table.clear(cachedLighting.postEffects)

	local function restoreInstance(inst)
		if inst and inst.Parent then
			inst.Parent = Lighting
		end
	end
	restoreInstance(cachedLighting.atmosphere)
	restoreInstance(cachedLighting.sky)
	restoreInstance(cachedLighting.clouds)
	cachedLighting.atmosphere = nil
	cachedLighting.sky = nil
	cachedLighting.clouds = nil

	if cacheFolder then
		cacheFolder:Destroy()
		cacheFolder = nil
	end

	activeTrove = nil
end

local function restoreCurrentLighting()
	cancelTweens()

	local duration = FireworkEventConfig.TRANSITION_DURATION

	local lightingGoal = {}
	for _, prop in ipairs(LIGHTING_PROPERTIES_TO_CACHE) do
		local original = cachedLighting.properties[prop]
		if original ~= nil then
			lightingGoal[prop] = original
		end
	end
	local mainTween = tweenObject(Lighting, lightingGoal, duration)

	local originalAtmosphere = cachedLighting.atmosphere
	local cloneAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if originalAtmosphere and cloneAtmosphere then
		local atmGoal = {
			Density = originalAtmosphere.Density,
			Offset = originalAtmosphere.Offset,
			Color = originalAtmosphere.Color,
			Decay = originalAtmosphere.Decay,
			Glare = originalAtmosphere.Glare,
			Haze = originalAtmosphere.Haze,
		}
		tweenObject(cloneAtmosphere, atmGoal, duration)
	end

	cleanupThread = task.delay(duration + 0.1, function()
		cleanupThread = nil
		finalizeRestore()
	end)

	return mainTween
end

local function applySunsetOverrides()
	cancelTweens()

	local sunset = FireworkEventConfig.SUNSET_LIGHTING
	local lightingGoal = {
		ClockTime = sunset.ClockTime,
		Ambient = sunset.Ambient,
		OutdoorAmbient = sunset.OutdoorAmbient,
		Brightness = sunset.Brightness,
		ShadowSoftness = sunset.ShadowSoftness,
	}
	-- Booleans can't be tweened; set instantly.
	Lighting.GlobalShadows = sunset.GlobalShadows
	tweenObject(Lighting, lightingGoal, FireworkEventConfig.TRANSITION_DURATION)

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		local atmGoal = {}
		for prop, value in pairs(FireworkEventConfig.SUNSET_ATMOSPHERE) do
			atmGoal[prop] = value
		end
		tweenObject(atmosphere, atmGoal, FireworkEventConfig.TRANSITION_DURATION)
	end
end

local function applyLighting(assetRoot, shouldCache: boolean)
	local lightingFolder = assetRoot:FindFirstChild("Lighting")
	if not lightingFolder then
		return
	end

	cancelTweens()

	if shouldCache then
		cacheCurrentLighting()
	end
	clearLightingEffects()

	for _, child in ipairs(lightingFolder:GetChildren()) do
		local clone = child:Clone()
		if clone then
			clone.Name = child.Name .. "_FireworkEvent"
			clone.Parent = Lighting
			table.insert(lightingEffects, clone)
		end
	end

	applySunsetOverrides()
end

-- ========== Position Helpers ==========

local function getMapCenter(): Vector3
	-- Try the legacy "Map" model first, then the active round map, then fall back to origin.
	local base = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("ActiveMap")
	if base and base:IsA("Model") then
		local primary = base.PrimaryPart
		if primary then
			return primary.Position
		end
		local cf = base:GetBoundingBox()
		return cf.Position
	end
	return Vector3.new(0, 0, 0)
end

local exclusionCenter: Vector3? = nil

local function updateExclusionCenter()
	local custom = Workspace:FindFirstChild("CustomMapSpawn")
	exclusionCenter = if custom and custom:IsA("BasePart") then custom.Position else nil
end

local function getLobbySpawnInfo(): (Vector3?, number?)
	-- LobbySpawn parts form the equator ring around the spawn.
	local lobbyPositions = {}
	for _, child in ipairs(Workspace:GetDescendants()) do
		if child.Name == "LobbySpawn" and child:IsA("BasePart") then
			table.insert(lobbyPositions, child.Position)
		end
	end
	if #lobbyPositions == 0 then
		return nil, nil
	end

	local sum = Vector3.zero
	for _, pos in ipairs(lobbyPositions) do
		sum += pos
	end
	local center = sum / #lobbyPositions

	local radiusSum = 0
	for _, pos in ipairs(lobbyPositions) do
		radiusSum += (pos - center).Magnitude
	end
	local avgRadius = radiusSum / #lobbyPositions

	return center, avgRadius
end

local function getFallbackCenter(): Vector3
	-- Fall back to the active map's player spawn points.
	if MapManager.isLoaded() then
		local cf = MapManager.getPlayerSpawnCFrame()
		if cf then
			return cf.Position
		end
	end
	return getMapCenter()
end

local function randomRingPosition(center: Vector3, heightMin: number, heightMax: number, ringRadius: number): Vector3
	local angle = math.random() * math.pi * 2
	-- Keep bursts in a ring around the spawn (70%-130% of the lobby-spawn radius).
	local radius = ringRadius * (0.7 + math.random() * 0.6)
	local height = heightMin + math.random() * (heightMax - heightMin)
	return center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
end

local function randomBurstPosition(center: Vector3, heightMin: number, heightMax: number, ringRadius: number): Vector3
	if not exclusionCenter then
		return randomRingPosition(center, heightMin, heightMax, ringRadius)
	end

	local excludeDir = (exclusionCenter - center).Unit
	excludeDir = Vector3.new(excludeDir.X, 0, excludeDir.Z).Unit

	for _ = 1, 12 do
		local pos = randomRingPosition(center, heightMin, heightMax, ringRadius)
		local flatDir = (Vector3.new(pos.X, center.Y, pos.Z) - center).Unit
		-- Reject anything on the north side (the side pointing toward the excluded position).
		if flatDir:Dot(excludeDir) <= 0 then
			return pos
		end
	end

	-- Fallback: force the point to the opposite (south) side of the ring.
	local awayDir = -excludeDir
	local radius = ringRadius * (0.7 + math.random() * 0.6)
	local height = heightMin + math.random() * (heightMax - heightMin)
	return center + awayDir * radius + Vector3.new(0, height, 0)
end

local function randomPosition(center: Vector3, heightMin: number, heightMax: number, radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local dist = math.random() * radius
	local height = heightMin + math.random() * (heightMax - heightMin)
	return center + Vector3.new(math.cos(angle) * dist, height, math.sin(angle) * dist)
end

local function makeMapRayParams()
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Include
	local map = Workspace:FindFirstChild("Map") or Workspace:FindFirstChild("ActiveMap")
	p.FilterDescendantsInstances = map and { map } or {}
	return p
end

local function getLaunchPosition(center: Vector3, x: number, z: number): Vector3
	-- Raycast down to the ground but ignore lobby spawn parts so rockets don't
	-- pop out of the spawn pads.
	local origin = Vector3.new(x, center.Y + 200, z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local exclude = {}
	for _, child in ipairs(Workspace:GetDescendants()) do
		if child.Name == "LobbySpawn" and child:IsA("BasePart") then
			table.insert(exclude, child)
		end
	end
	params.FilterDescendantsInstances = exclude

	local hit = Workspace:Raycast(origin, Vector3.new(0, -400, 0), params)
	if hit then
		return hit.Position
	end
	return Vector3.new(x, center.Y, z)
end

-- ========== Audio ==========

local function playSound(sound: Sound?)
	if not sound then
		return
	end

	if sound.IsLoaded then
		local ok, err = pcall(function()
			sound:Play()
		end)
		if not ok then
			warn(`[FireworkEventService] Play() failed for {sound.SoundId}: {err}`)
		end
	else
		local conn = nil
		conn = sound.Loaded:Once(function()
			conn = nil
			pcall(function()
				sound:Play()
			end)
		end)
		-- If the sound never loads, clean up the connection after a reasonable timeout.
		task.delay(10, function()
			if conn then
				pcall(function()
					conn:Disconnect()
				end)
			end
		end)
	end
end

local function createSoundAnchorForTemplate(template: Model): BasePart
	local anchor = Instance.new("Part")
	anchor.Name = "FireworkSoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = template:GetPivot()
	anchor.Parent = Workspace

	local explosionSound = Instance.new("Sound")
	explosionSound.Name = "ExplosionSound"
	explosionSound.SoundId = `rbxassetid://{FireworkEventConfig.SOUND_IDS.Explosion}`
	explosionSound.Volume = FireworkEventConfig.SOUND_VOLUME.Explosion
	explosionSound.RollOffMode = Enum.RollOffMode.InverseTapered
	explosionSound.RollOffMinDistance = FireworkEventConfig.SOUND_ROLLOFF.MinDistance
	explosionSound.RollOffMaxDistance = FireworkEventConfig.SOUND_ROLLOFF.MaxDistance
	explosionSound.Parent = anchor

	return anchor
end

local function createLaunchSoundAnchor(position: Vector3): BasePart
	local anchor = Instance.new("Part")
	anchor.Name = "FireworkLaunchSoundAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace

	local launchSound = Instance.new("Sound")
	launchSound.Name = "LaunchSound"
	launchSound.SoundId = `rbxassetid://{FireworkEventConfig.SOUND_IDS.Launch}`
	launchSound.Volume = FireworkEventConfig.SOUND_VOLUME.Launch
	launchSound.RollOffMode = Enum.RollOffMode.InverseTapered
	launchSound.RollOffMinDistance = FireworkEventConfig.SOUND_ROLLOFF.MinDistance
	launchSound.RollOffMaxDistance = FireworkEventConfig.SOUND_ROLLOFF.MaxDistance
	launchSound.Parent = anchor

	return anchor
end

-- ========== VFX ==========

local function emitFromModel(model: Model, defaultCount: number)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ParticleEmitter") then
			-- Particle emitters can opt out or override their emit count/delay
			-- via attributes, so each firework template can be tuned individually.
			if descendant:GetAttribute("FireworkEnabled") == false then
				continue
			end

			local countAttr = descendant:GetAttribute("FireworkEmitCount")
			local count = if type(countAttr) == "number" then countAttr else defaultCount

			local delayAttr = descendant:GetAttribute("FireworkEmitDelay")
			local delay = if type(delayAttr) == "number" then delayAttr else 0

			local function doEmit()
				pcall(function()
					descendant:Emit(count)
				end)
			end

			if delay > 0 then
				task.delay(delay, doEmit)
			else
				doEmit()
			end
		end
	end
end

local function getRandomTemplate(): Model?
	if not vfxFolder then
		return nil
	end
	local templates = FireworkEventConfig.TEMPLATES
	local name = templates[math.random(1, #templates)]
	return vfxFolder:FindFirstChild(name) :: Model?
end

local function createRocket(launchPos: Vector3, burstPos: Vector3): BasePart
	local rocket = Instance.new("Part")
	rocket.Name = "FireworkRocket"
	rocket.Anchored = true
	rocket.CanCollide = false
	rocket.CanQuery = false
	rocket.CanTouch = false
	rocket.Transparency = 0.2
	rocket.Size = Vector3.new(0.4, 0.4, 1.8)
	rocket.Color = Color3.fromRGB(255, 240, 200)
	rocket.Material = Enum.Material.Neon
	rocket.CFrame = CFrame.lookAt(launchPos, burstPos)
	rocket.Parent = Workspace

	local attach0 = Instance.new("Attachment")
	attach0.Position = Vector3.new(0, 0, 0.6)
	attach0.Parent = rocket
	local attach1 = Instance.new("Attachment")
	attach1.Position = Vector3.new(0, 0, -0.6)
	attach1.Parent = rocket

	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 220, 150))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Lifetime = 0.25
	trail.WidthScale = NumberSequence.new(0.15)
	trail.Attachment0 = attach0
	trail.Attachment1 = attach1
	trail.Parent = rocket

	return rocket
end

local function burstAt(model: Model, position: Vector3, emitCount: number, isFirework: boolean)
	model:PivotTo(CFrame.new(position))

	local anchor = templateSoundAnchors[model]
	if anchor then
		anchor.CFrame = CFrame.new(position)
	end

	local explosionDelay = isFirework and 0.15 or 0
	task.delay(explosionDelay, function()
		if anchor and anchor.Parent then
			anchor.CFrame = CFrame.new(position)
			local explosionSound = anchor:FindFirstChild("ExplosionSound") :: Sound
			playSound(explosionSound)
		end
	end)

	emitFromModel(model, emitCount)
end

local function launchFirework(center: Vector3, heightRange: {Min: number, Max: number}, emitCount: number, spawnRadius: number)
	local burstPos = randomBurstPosition(center, heightRange.Min, heightRange.Max, spawnRadius)
	local template = getRandomTemplate()
	if not template then
		return
	end

	local angle = math.random() * math.pi * 2
	local dist = math.random() * FireworkEventConfig.SPAWN_RADIUS
	local launchX = center.X + math.cos(angle) * dist
	local launchZ = center.Z + math.sin(angle) * dist
	local launchPos = getLaunchPosition(center, launchX, launchZ)

	local rocket = createRocket(launchPos, burstPos)
	local soundAnchor = createLaunchSoundAnchor(launchPos)
	playSound(soundAnchor:FindFirstChild("LaunchSound") :: Sound)

	local flyDistance = (burstPos - launchPos).Magnitude
	local flyDuration = math.clamp(flyDistance / FireworkEventConfig.LAUNCH_SPEED, 0.5, 1.8)

	local tween = TweenService:Create(
		rocket,
		TweenInfo.new(flyDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = burstPos }
	)
	tween:Play()

	tween.Completed:Connect(function()
		if rocket and rocket.Parent then
			rocket:Destroy()
		end
		if soundAnchor and soundAnchor.Parent then
			soundAnchor:Destroy()
		end

		burstAt(template, burstPos, emitCount, true)

		-- Play the lingering Sparkfall effect at the same burst point.
		local sparkfall = vfxFolder and vfxFolder:FindFirstChild(FireworkEventConfig.SPARKFALL_TEMPLATE) :: Model
		if sparkfall then
			task.delay(FireworkEventConfig.SPARKFALL_DELAY, function()
				burstAt(sparkfall, burstPos, FireworkEventConfig.SPARKFALL_EMIT_COUNT, false)
			end)
		end
	end)
end

-- ========== Spawn Loops ==========

local function startFireworkLoop(
	center: Vector3,
	interval: number,
	heightRange: {Min: number, Max: number},
	emitCount: number,
	spawnRadius: number
)
	local running = true
	local function loop()
		while running do
			launchFirework(center, heightRange, emitCount, spawnRadius)
			task.wait(interval + (math.random() - 0.5) * 0.2)
		end
	end
	local thread = task.spawn(loop)
	return function()
		running = false
		pcall(task.cancel, thread)
	end
end

local function startSpawnLoop(
	center: Vector3,
	interval: number,
	heightRange: {Min: number, Max: number},
	emitCount: number,
	isFirework: boolean,
	spawnRadius: number
)
	local running = true
	local function loop()
		while running do
			local template = getRandomTemplate()
			if template then
				local pos = randomBurstPosition(center, heightRange.Min, heightRange.Max, spawnRadius)
				burstAt(template, pos, emitCount, isFirework)
			end
			task.wait(interval + (math.random() - 0.5) * 0.3)
		end
	end
	local thread = task.spawn(loop)
	return function()
		running = false
		pcall(task.cancel, thread)
	end
end

local function setupVfxFolder(assetRoot)
	local existing = Workspace:FindFirstChild(FireworkEventConfig.VFX_FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	-- Clean up any leftover sound anchors from a previous run.
	for _, anchor in pairs(templateSoundAnchors) do
		pcall(function()
			anchor:Destroy()
		end)
	end
	table.clear(templateSoundAnchors)

	local source = assetRoot:FindFirstChild("Vfx")
	if not source then
		warn("[FireworkEventService] missing Vfx folder")
		return nil
	end

	vfxFolder = source:Clone()
	vfxFolder.Name = FireworkEventConfig.VFX_FOLDER_NAME
	vfxFolder.Parent = Workspace

	for _, child in ipairs(vfxFolder:GetChildren()) do
		if child:IsA("Model") then
			templateSoundAnchors[child] = createSoundAnchorForTemplate(child)
		end
	end

	return vfxFolder
end

-- ========== Public API ==========

function FireworkEventService:Start(duration: number)
	if not EVENT_ACTIVE then
		self:Stop()
		return false
	end
	self:Stop()

	local assetRoot = getAssetRoot()
	if not assetRoot then
		warn("[FireworkEventService] could not find firework asset root")
		return
	end

	activeTrove = {}
	local shouldCache = (cacheFolder == nil)
	applyLighting(assetRoot, shouldCache)
	setupVfxFolder(assetRoot)

	local center = select(1, getLobbySpawnInfo())
	if not center then
		center = getFallbackCenter()
	end
	local spawnRadius = FireworkEventConfig.SPAWN_RADIUS
	updateExclusionCenter()

	local stopFireworks = startFireworkLoop(
		center,
		FireworkEventConfig.FIREWORK_INTERVAL,
		FireworkEventConfig.FIREWORK_HEIGHT,
		FireworkEventConfig.FIREWORK_EMIT_COUNT,
		spawnRadius
	)
	local stopSparklers = startSpawnLoop(
		center,
		FireworkEventConfig.SPARKLER_INTERVAL,
		FireworkEventConfig.SPARKLER_HEIGHT,
		FireworkEventConfig.SPARKLER_EMIT_COUNT,
		false,
		spawnRadius
	)

	table.insert(spawnLoops, stopFireworks)
	table.insert(spawnLoops, stopSparklers)

	-- If a round is already active (or starts while the event is running), also rain
	-- firework currency onto the map.
	rainWatching = true
	rainWatcherThread = task.spawn(function()
		local fireworkRainService = Knit.GetService("FireworkRainService")
		while rainWatching do
			local shouldRun = ModifierUtils.anyInRound()
			local isRunning = fireworkRainService:IsRunning()
			if shouldRun and not isRunning then
				fireworkRainService:Start(300)
			elseif not shouldRun and isRunning then
				fireworkRainService:Stop()
			end
			task.wait(0.5)
		end
		-- Make sure rain stops when the watcher is shut down.
		pcall(function()
			fireworkRainService:Stop()
		end)
	end)

	if duration and duration > 0 then
		task.delay(duration, function()
			self:Stop()
		end)
	end
end

function FireworkEventService:Stop()
	rainWatching = false
	rainWatcherThread = nil

	cancelTweens()
	for _, stopFn in ipairs(spawnLoops) do
		pcall(stopFn)
	end
	table.clear(spawnLoops)

	if vfxFolder and vfxFolder.Parent then
		pcall(function()
			vfxFolder:Destroy()
		end)
	end
	vfxFolder = nil

	for _, anchor in pairs(templateSoundAnchors) do
		pcall(function()
			anchor:Destroy()
		end)
	end
	table.clear(templateSoundAnchors)

	-- Stop any active firework-currency rain.
	pcall(function()
		Knit.GetService("FireworkRainService"):Stop()
	end)

	-- Clean up any in-flight rockets and launch sound anchors.
	for _, name in ipairs({ "FireworkRocket", "FireworkLaunchSoundAnchor" }) do
		local leftover = Workspace:FindFirstChild(name)
		while leftover do
			pcall(function()
				leftover:Destroy()
			end)
			leftover = Workspace:FindFirstChild(name)
		end
	end

	if cacheFolder then
		restoreCurrentLighting()
	else
		activeTrove = nil
	end
end

function FireworkEventService:KnitStart()
end

return FireworkEventService
