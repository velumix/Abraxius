-- CoinSpawner: MM2-style coins that spawn around the map walkable area during a round.
-- Walking into one grants +1 coin (server-authoritative). Coins clear when the round ends.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local CoinSpawner = {}

local Knit = require(game:GetService("ReplicatedStorage"):WaitForChild("Packages"):WaitForChild("Knit"))
local function svc(n) local ok, s = pcall(function() return Knit.GetService(n) end) return ok and s or nil end
local _coin
local function coinSvc() if not _coin then _coin = svc("CoinService") end return _coin end

-- per-map coin/firework spawn split (4th of July event)
local MapCurrencyConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("MapCurrencyConfig"))

-- MapManager provides coin spawn points on the active map (any flat ground). Required lazily
-- so load order between the ServerScriptService modules doesn't matter.
local MapManager = nil
local function getMapManager()
	if not MapManager then
		MapManager = require(script.Parent:WaitForChild("MapManager"))
	end
	return MapManager
end

-- remote to tell the collecting client to play the pickup sound locally
local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("GameRemotes")
local CoinCollected = Remotes:FindFirstChild("CoinCollected")
if not CoinCollected then
	CoinCollected = Instance.new("RemoteEvent")
	CoinCollected.Name = "CoinCollected"
	CoinCollected.Parent = Remotes
end

-- ===== CONFIG =====
local CONFIG = {
	COIN_VALUE = 1,          -- coins granted per pickup
	FIREWORK_VALUE = 1,      -- fireworks granted per firework pickup (4th of July event currency)
	MAX_COINS = 60,          -- max map coins on the map at once (death-burst coins are exempt)
	-- Spawning is split into two phases so coins aren't constantly popping in (which spiked perf on
	-- low-end mobile from all the per-coin lights/particles). At round start we FILL toward the cap,
	-- then switch to a slow TRICKLE that only gently replaces collected/expired coins.
	INITIAL_FILL_RATIO = 0.85, -- fill to ~85% of MAX_COINS at round start
	INITIAL_FILL_GAP = 0.06,   -- small gap between each initial-fill spawn (spreads the load over ~2s
	                           -- instead of one big frame spike)
	SPAWN_INTERVAL = 3.5,    -- seconds between trickle spawns (was 2) — far fewer visible spawn events
	SPAWN_PER_TICK = 1,      -- trickle adds just 1 coin per interval (was 3) — no batch pop-ins
	LIFETIME = 30,           -- (UNUSED) coins no longer expire on a timer; they persist for the whole
	                         -- round and only leave when collected, when displaced at the cap, or at round end
	HOVER_HEIGHT = 3,        -- studs above the ground a coin's float CENTER sits
	BOB_AMPLITUDE = 0.5,     -- how far up/down it bobs from the center
	BOB_SPEED = 2,           -- bobs per ... (radians/sec multiplier)
	SPIN_SPEED = 90,         -- degrees/sec the coin spins
	MIN_FALL_DURATION = 1,   -- shortest coin fall; prevents low-ceiling coins from just popping in
	MAX_FALL_DURATION = 3,   -- longest coin fall
	MAX_SURFACE_RISE = 8,    -- reject spots whose ground is >this far above the base surface
	                         -- (so coins land on the floor / low props, not rooftops/treetops)

	-- the round walkable area (Map1). X/Z bounds + the ground surface to drop coins onto.
	-- Map1 ground sits at ~Y=-12.5; structures rise well above, so RAY_TOP starts high and
	-- MAX_SURFACE_RISE keeps coins on the ground/low props rather than rooftops.
	AREA_CENTER = Vector3.new(401, -12.5, 194),  -- Map1 ground center
	AREA_HALF_X = 130,       -- half the map width (X), inset from the ~145 extent
	AREA_HALF_Z = 125,       -- half the map depth (Z), inset from the ~137 extent
	RAY_TOP = 130,           -- start the downward ray well above (structures reach ~Y104)
	RAY_LENGTH = 160,        -- how far down to look for ground
}
CoinSpawner.CONFIG = CONFIG

export type CoinSpawner = {
	CONFIG: typeof(CONFIG),
	spawnCoinAt: (position: Vector3?, value: number?) -> (),
	spawnFlyingCoin: (origin: Vector3?, velocity: Vector3?, trailColor: Color3?) -> BasePart?,
	spawnFallingCoin: (startPosition: Vector3?, landingPosition: Vector3?, value: number?, isFirework: boolean?) -> BasePart?,
	spawnBezierCoin: (startPosition: Vector3?, landingPosition: Vector3?, controlPosition: Vector3?, value: number?, isFirework: boolean?) -> BasePart?,
	setupPickup: (coin: BasePart) -> (),
	collectCoin: (player: Player, coin: BasePart, source: string) -> (),
	start: () -> (),
	stop: () -> (),
}

-- container for all spawned coins
local folder = Workspace:FindFirstChild("SpawnedCoins")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "SpawnedCoins"
	folder.Parent = Workspace
end

local running = false
local coinCount = 0

-- remove the oldest non-rain, non-burst coin to make room for a new map coin.
-- Death-burst coins (boss/minion drops) and rain coins are never removed.
local function removeOldestCoin(): boolean
	for _, c in ipairs(folder:GetChildren()) do
		if c:IsA("BasePart") and not c:GetAttribute("RainCoin") and not c:GetAttribute("DeathBurstCoin") then
			coinCount = math.max(0, coinCount - 1)
			c:Destroy()
			return true
		end
	end
	return false
end

-- raycast params: ignore players + existing coins, hit only the map
local function makeRayParams()
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	local filter = { folder }
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then table.insert(filter, plr.Character) end
	end
	p.FilterDescendantsInstances = filter
	return p
end

-- build a single coin part
-- the coin mesh template in ServerStorage (the MeshPart you imported, named "Coin")
local coinTemplate = ServerStorage:FindFirstChild("Coin")
-- optional real firework model; falls back to a tinted-coin placeholder until firework art exists
local fireworkTemplate = ServerStorage:FindFirstChild("Firework")

-- build a single pickup (coin, or a firework when isFirework is true) from the mesh template
local function makeCoin(position, isFirework)
	local coin
	local template = (isFirework and fireworkTemplate) or coinTemplate
	if template and template:IsA("BasePart") then
		coin = template:Clone()
	else
		-- fallback if the template is missing
		coin = Instance.new("Part")
		coin.Shape = Enum.PartType.Cylinder
		coin.Size = Vector3.new(0.3, 2, 2)
		coin.Color = isFirework and Color3.fromRGB(220, 40, 60) or Color3.fromRGB(255, 200, 50)
	end
	-- Keep the instance Name "Coin" for BOTH currencies so the existing client float/bob animator
	-- (which drives everything in Workspace.SpawnedCoins) also animates fireworks. The currency is
	-- distinguished by the CurrencyType attribute, not the name.
	coin.Name = "Coin"
	coin.Anchored = true
	coin.CanCollide = false
	coin.CanQuery = false  -- coins must not block raycasts (e.g. thrown knives pass through them)
	-- the mesh stands upright at identity (thin axis = Z), so just place it at the float center
	coin.CFrame = CFrame.new(position)
	-- remember the float center so the bob can oscillate around it, plus a random phase
	coin:SetAttribute("BaseY", position.Y)
	coin:SetAttribute("Phase", math.random() * math.pi * 2)
	coin:SetAttribute("CurrencyType", isFirework and "Firework" or "Coin")
	-- placeholder tint so firework pickups read differently until a real ServerStorage.Firework exists
	if isFirework and not (fireworkTemplate and fireworkTemplate:IsA("BasePart")) then
		coin.Color = Color3.fromRGB(220, 40, 60)
	end
	coin.Parent = folder

	-- a subtle glow. Kept cheap for mobile: small Range (light cost scales with range — a smaller
	-- radius lights far fewer pixels) and Shadows OFF (a shadow-casting light is far more expensive
	-- than a non-shadow one, and a coin's glow doesn't need to cast shadows). With up to MAX_COINS
	-- of these on screen, these two settings are the difference that matters on low-end devices.
	local light = Instance.new("PointLight")
	light.Color = isFirework and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(255, 210, 80)
	light.Range = 3.5
	light.Brightness = 1
	light.Shadows = false
	light.Parent = coin

	return coin
end

-- Play the coin pickup sound as a 3D positional sound at a world position, so NEARBY players
-- (including the seeker) can hear it with distance falloff — collecting coins becomes an audible
-- risk. A short-lived anchored emitter part carries the sound, then cleans itself up.
local function playPickupSoundAt(position)
	local template = game:GetService("SoundService"):FindFirstChild("Coin")
	if not template then return end
	local emitter = Instance.new("Part")
	emitter.Name = "CoinSoundEmitter"
	emitter.Anchored = true
	emitter.CanCollide = false
	emitter.CanQuery = false
	emitter.CanTouch = false
	emitter.Transparency = 1
	emitter.Size = Vector3.new(1, 1, 1)
	emitter.CFrame = CFrame.new(position)
	emitter.Parent = Workspace

	local sound = template:Clone()
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10    -- full volume within 10 studs
	sound.RollOffMaxDistance = 160   -- inaudible beyond ~160 studs (2x the old 80-stud range)
	-- route through the SFX SoundGroup so the Settings SFX slider controls coin-pickup volume (per-client)
	do
		local sfx = game:GetService("SoundService"):FindFirstChild("SFX")
		if sfx then sound.SoundGroup = sfx end
	end
	sound.Parent = emitter
	sound:Play()
	sound.Ended:Connect(function() emitter:Destroy() end)
	-- safety cleanup in case Ended doesn't fire
	task.delay((sound.TimeLength > 0 and sound.TimeLength or 2) + 0.5, function()
		if emitter and emitter.Parent then emitter:Destroy() end
	end)
end

-- server-authoritative collection used by normal pickups and by Knit services (e.g. CoinRainService).
function CoinSpawner.collectCoin(player: Player, coin: BasePart, source: string)
	local currencyType = coin:GetAttribute("CurrencyType")
	local value = tonumber(coin:GetAttribute("CoinValue"))
	if currencyType == "Firework" then
		value = value or CONFIG.FIREWORK_VALUE
		coinSvc():AwardFireworks(player, value, source)
	else
		value = value or CONFIG.COIN_VALUE
		coinSvc():Award(player, value, source)
	end
	playPickupSoundAt(coin.Position)
	CoinCollected:FireClient(player, coin.Position, value, currencyType or "Coin")
	if not coin:GetAttribute("RainCoin") and not coin:GetAttribute("DeathBurstCoin") then
		coinCount = math.max(0, coinCount - 1)
	end
	coin:Destroy()
end

-- award + remove a coin when a player touches it
function CoinSpawner.setupPickup(coin: BasePart)
	local collected = false
	coin.Touched:Connect(function(hit)
		if collected then return end
		local char = hit:FindFirstAncestorOfClass("Model")
		if not char then return end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end
		-- only living players collect
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		collected = true
		CoinSpawner.collectCoin(player, coin, "map coin")
	end)
end

-- public: spawn a single coin at an exact position (used by chaos buttons / scripted drops)
function CoinSpawner.spawnCoinAt(position: Vector3?, value: number?): ()
	if not position then return end
	if coinCount >= CONFIG.MAX_COINS then
		if not removeOldestCoin() then
			return
		end
	end
	local coin = makeCoin(position)
	coin:SetAttribute("CoinValue", value or CONFIG.COIN_VALUE)
	coinCount += 1
	CoinSpawner.setupPickup(coin)
end

-- public: spawn a coin that flies through the air from an origin with a velocity impulse,
-- then anchors after it lands. Used by chaos-button coin bursts.
function CoinSpawner.spawnFlyingCoin(origin: Vector3?, velocity: Vector3?, trailColor: Color3?): BasePart?
	if not origin then return end
	if coinCount >= CONFIG.MAX_COINS then
		if not removeOldestCoin() then
			return nil
		end
	end

	local coin = makeCoin(origin)
	coin.Anchored = false
	coin:SetAttribute("CoinValue", CONFIG.COIN_VALUE)

	-- trail
	local attach0 = Instance.new("Attachment")
	attach0.Position = Vector3.new(0, 0, 0.2)
	attach0.Parent = coin
	local attach1 = Instance.new("Attachment")
	attach1.Position = Vector3.new(0, 0, -0.2)
	attach1.Parent = coin
	local trail = Instance.new("Trail")
	trail.Color = ColorSequence.new(trailColor or Color3.fromRGB(255, 210, 80))
	trail.Transparency = NumberSequence.new(0, 1)
	trail.Lifetime = 0.25
	trail.WidthScale = NumberSequence.new(0.3)
	trail.Attachment0 = attach0
	trail.Attachment1 = attach1
	trail.Parent = coin

	-- impulse
	local impulse = velocity or Vector3.new(0, 30, 0)
	coin:ApplyImpulse(coin.AssemblyMass * impulse)

	coinCount += 1
	CoinSpawner.setupPickup(coin)

	-- anchor once the arc settles
	task.delay(1.5, function()
		if coin and coin.Parent then
			local finalPos = coin.Position
			coin.Anchored = true
			coin:SetAttribute("BaseY", finalPos.Y)
			coin.CFrame = CFrame.new(finalPos)
			for _, child in ipairs(coin:GetChildren()) do
				if child:IsA("Trail") then
					child.Enabled = false
					task.delay(child.Lifetime + 0.1, function()
						if child and child.Parent then child:Destroy() end
					end)
				end
			end
		end
	end)

	return coin
end

-- find a valid ground spot inside the area, return a position to float the coin at (or nil)
local function findSpawnPos()
	-- delegate to MapManager: a random flat-ground spot anywhere on the active map. Returns nil
	-- if it couldn't find a good spot this attempt (steep surface / gap) — spawnOne just skips.
	return getMapManager().getCoinSpawnPosition(CONFIG.HOVER_HEIGHT)
end

local function spawnOne()
	-- If we're at the cap, make room by removing the oldest non-rain coin.
	if coinCount >= CONFIG.MAX_COINS then
		if not removeOldestCoin() then
			return
		end
	end
	local pos = findSpawnPos()
	if not pos then return end
	-- roll coin vs firework from the active map's split (default 60/40, 4th-of-July map 20/80)
	local mm = getMapManager()
	local mapName = mm.getActiveMapName and mm.getActiveMapName() or nil
	local isFirework = (MapCurrencyConfig.rollType(mapName) == "Firework")
	local coin = makeCoin(pos, isFirework)
	coinCount += 1
	CoinSpawner.setupPickup(coin)
	-- (no auto-despawn timer: pickups last the whole round; see the cap logic above)
end

-- Client-side float/bob animation is handled by CoinAnimatorController.

-- public: spawn a coin at startPosition and tween it down to landingPosition.
-- Used by the CoinRain admin abuse command. The coin stays anchored during the fall so the
-- descent is controlled and upright; the client animator takes over once it lands.
function CoinSpawner.spawnFallingCoin(startPosition: Vector3?, landingPosition: Vector3?, value: number?, isFirework: boolean?): BasePart?
	if not startPosition or not landingPosition then return end

	local FALL_SPEED = 40 -- studs per second
	local duration = math.clamp(
		(startPosition - landingPosition).Magnitude / FALL_SPEED,
		CONFIG.MIN_FALL_DURATION,
		CONFIG.MAX_FALL_DURATION
	)

	local coin = makeCoin(startPosition, isFirework)
	coin:SetAttribute("CoinValue", value or (isFirework and CONFIG.FIREWORK_VALUE or CONFIG.COIN_VALUE))
	coin:SetAttribute("Falling", true)
	coin:SetAttribute("RainCoin", true)
	coin.Anchored = true
	coin.CanCollide = false

	CoinSpawner.setupPickup(coin)

	local TweenService = game:GetService("TweenService")
	local tween = TweenService:Create(
		coin,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ Position = landingPosition }
	)
	tween.Parent = coin
	tween:Play()

	tween.Completed:Connect(function()
		if coin and coin.Parent then
			coin:SetAttribute("BaseY", landingPosition.Y)
			coin:SetAttribute("Falling", false)
			coin.CFrame = CFrame.new(landingPosition)
		end
	end)

	return coin
end

-- public: spawn a coin at startPosition and follow a quadratic Bezier curve to landingPosition,
-- arcing through controlPosition. Used for boss/minion death coin bursts.
function CoinSpawner.spawnBezierCoin(startPosition: Vector3?, landingPosition: Vector3?, controlPosition: Vector3?, value: number?, isFirework: boolean?): BasePart?
	if not startPosition or not landingPosition or not controlPosition then return end

	-- Death-burst coins (boss/minion drops) are exempt from the map coin cap so a
	-- big fight doesn't steal slots from the ambient map spawns.
	local FALL_SPEED = 70
	local straightDist = (startPosition - landingPosition).Magnitude
	local arcDist = (controlPosition - (startPosition + landingPosition) / 2).Magnitude
	local duration = math.clamp(
		(straightDist + arcDist) / FALL_SPEED,
		CONFIG.MIN_FALL_DURATION,
		CONFIG.MAX_FALL_DURATION
	)

	local coin = makeCoin(startPosition, isFirework)
	coin:SetAttribute("CoinValue", value or (isFirework and CONFIG.FIREWORK_VALUE or CONFIG.COIN_VALUE))
	coin:SetAttribute("Falling", true)
	coin:SetAttribute("DeathBurstCoin", true)
	coin.Anchored = true
	coin.CanCollide = false

	CoinSpawner.setupPickup(coin)

	local TweenService = game:GetService("TweenService")
	local progress = Instance.new("NumberValue")
	progress.Value = 0
	progress.Parent = coin

	local function updatePosition(t: number)
		local u = 1 - t
		coin.Position = (u * u * startPosition)
			+ (2 * u * t * controlPosition)
			+ (t * t * landingPosition)
	end

	updatePosition(0)

	local conn = progress.Changed:Connect(updatePosition)

	local tween = TweenService:Create(
		progress,
		TweenInfo.new(duration, Enum.EasingStyle.Quad),
		{ Value = 1 }
	)
	tween.Parent = coin
	tween:Play()

	tween.Completed:Connect(function()
		if conn then conn:Disconnect() end
		if progress and progress.Parent then progress:Destroy() end
		if coin and coin.Parent then
			coin:SetAttribute("BaseY", landingPosition.Y)
			coin:SetAttribute("Falling", false)
			coin.CFrame = CFrame.new(landingPosition)
		end
	end)

	return coin
end

-- ===== public: start / stop (called by the round loop) =====
function CoinSpawner.start(): ()
	if running then return end
	running = true
	task.spawn(function()
		-- Phase 1: initial fill — quickly populate the map toward the cap so the round starts looking
		-- full, but spread the spawns out with a tiny gap so we never create a big batch in one frame.
		local target = math.floor(CONFIG.MAX_COINS * (CONFIG.INITIAL_FILL_RATIO or 1))
		while running and coinCount < target do
			spawnOne()
			task.wait(CONFIG.INITIAL_FILL_GAP or 0.06)
		end

		-- Phase 2: gentle trickle — slowly top up coins that were COLLECTED, back toward the cap. Coins no
		-- longer expire, so this only refills picked-up coins; once at the cap it adds nothing (it does NOT
		-- churn existing coins). Only 1 per interval so players rarely see a spawn and there's no spike.
		while running do
			task.wait(CONFIG.SPAWN_INTERVAL)
			if not running then break end
			for _ = 1, CONFIG.SPAWN_PER_TICK do
				if not running then break end
				if coinCount < CONFIG.MAX_COINS then  -- only refill below the cap; never churn existing coins
					spawnOne()
				end
			end
		end
	end)
end

function CoinSpawner.stop(): ()
	running = false
	for _, c in ipairs(folder:GetChildren()) do c:Destroy() end
	coinCount = 0
end

return CoinSpawner :: CoinSpawner
