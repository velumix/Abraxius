local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)
local BossConfig = require(ReplicatedStorage.Config.BossConfig)
local MapManager = _G.MapManager
local CoinSpawner = require(script.Parent.Parent.CoinSpawner)
local PaintballGunGiver = require(script.Parent.Parent.Modules.PaintballGunGiver)
local ModifierUtils = require(script.Parent.Parent.Modules.ModifierUtils)

local RagdollService = nil :: any

local BossService = Knit.CreateService({
	Name = "BossService",
	BossDiedSignal = Signal.new(),
	Client = {
		BossSpawned = Knit.CreateSignal(),
		BossDied = Knit.CreateSignal(),
		SlamImpact = Knit.CreateSignal(),
		BossDamaged = Knit.CreateSignal(),
		BossHealthChanged = Knit.CreateSignal(),
		BossEventEnded = Knit.CreateSignal(),
	},
})

BossService.roundTimeOverride = nil

function BossService:SetRoundTimeOverride(duration: number?)
	self.roundTimeOverride = duration
end

function BossService:GetRoundTimeOverride(): number?
	return self.roundTimeOverride
end

function BossService:ClearRoundTimeOverride()
	self.roundTimeOverride = nil
end

function BossService:KnitStart()
	local ok, err = pcall(function()
		RagdollService = Knit.GetService("RagdollService")
	end)
	if not ok then
		warn(`[BossService] failed to get RagdollService: {err}`)
	end
end

local activeBosses: { [Model]: any } = {}
local storedPaintballs: { [Model]: Tool? } = {}
local combinedMaxHealth: number = 0

function BossService:_updateCombinedHealth()
	local totalHealth = 0
	local count = 0
	for _, component in pairs(activeBosses) do
		totalHealth += component._currentHealth
		count += 1
	end
	self.Client.BossHealthChanged:FireAll({
		health = totalHealth,
		maxHealth = combinedMaxHealth,
		count = count,
	})
end

local BossComponent = Component.new({
	Tag = "Boss",
	Ancestors = { Workspace },
})

function BossComponent:Construct()
	self._trove = Trove.new()
	self._rig = nil :: BasePart?
	self._rigHalfHeight = 0

	self._animator = nil :: Animator?
	self._walkTrack = nil :: AnimationTrack?
	self._slamTrack = nil :: AnimationTrack?
	self._isSlamming = false
	self._nextSlam = 0
	self._moveTarget = nil :: Vector3?
	self._moveHeartbeat = nil
	self._currentHealth = 0
	self._maxHealth = 0
	self._running = false
	self._def = nil :: any
	self._behavior = "boss" :: "boss" | "minion"
	self._isPathfinding = false
	self._lastSlamPos = nil :: Vector3?
	self._attackers = {} :: { [Player]: boolean }
	self._outline = nil :: Highlight?
	self._shakeEndTime = 0
	self._shakeMagnitude = 0.35
end

function BossComponent:Start()
	local model = self.Instance :: Model

	local animController = model:FindFirstChildOfClass("AnimationController")
	if not animController then
		warn("[BossService] Boss is missing an AnimationController:", model.Name)
		return
	end

	local rig = model.PrimaryPart or model:FindFirstChildOfClass("BasePart") :: BasePart?
	if not rig then
		warn("[BossService] Boss is missing a PrimaryPart:", model.Name)
		return
	end

	local bossName = model:GetAttribute("BossName") or model.Name
	local def = BossConfig.Get(bossName)
	if not def then
		return
	end

	self._rig = rig
	self._rigHalfHeight = rig.Size.Y / 2
	self._def = def
	self._running = true
	self._maxHealth = model:GetAttribute("MaxHealth") or def.health
	self._currentHealth = model:GetAttribute("Health") or self._maxHealth
	combinedMaxHealth += self._maxHealth
	self._nextSlam = os.clock() + (def.slamCooldown or 4)
	self._behavior = if bossName == "PaintMinion" then "minion" else "boss"
	model:SetAttribute("BossBehavior", self._behavior)

	model:SetAttribute("Health", self._currentHealth)
	model:SetAttribute("MaxHealth", self._maxHealth)

	local animator = animController:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animController
	end
	self._animator = animator

	local animsFolder = model:FindFirstChild("Animations") :: Folder?
	if animsFolder then
		local walkAnim = animsFolder:FindFirstChild("Walk") :: Animation?
		if walkAnim then
			self._walkTrack = animator:LoadAnimation(walkAnim)
			self._walkTrack.Looped = true
		end

		local slamAnim = animsFolder:FindFirstChild("Slam") :: Animation?
		if slamAnim and self._behavior == "boss" then
			self._slamTrack = animator:LoadAnimation(slamAnim)
		end
	end

	activeBosses[model] = self

	-- Faint outline so players can spot the monster through walls / in dark maps.
	local outline = Instance.new("Highlight")
	outline.Name = "BossOutline"
	outline.Adornee = model
	outline.FillTransparency = 0.9
	outline.OutlineTransparency = 0.3
	outline.OutlineColor = if self._behavior == "minion"
		then Color3.fromRGB(255, 180, 80)
		else Color3.fromRGB(255, 80, 80)
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Parent = model
	self._outline = outline
	self._trove:Add(outline)

	self:_placeOnGround()

	self._trove:Add(task.spawn(function()
		while self._running do
			if self._behavior == "boss" then
				self:_bossTick()
			else
				self:_minionTick()
			end
			task.wait(def.tickRate)
		end
	end))

	BossService:_updateCombinedHealth()
end

function BossComponent:Stop()
	self._running = false
	self:_stopMoving()
	activeBosses[self.Instance] = nil
	self._trove:Destroy()
end

--#region Health bar (driven by client ScreenGui)
-- The boss/minion health is shown on a ScreenGui (PaintBossHPBar) that appears
-- when the local player damages a monster and updates each time they damage one.
--#endregion

--#region Ground / raycast helpers

function BossComponent:_mapRayParams(): RaycastParams?
	local activeMap = MapManager.getActiveMap()
	if not activeMap then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { activeMap }
	return params
end

function BossComponent:_groundYAt(x: number, z: number, fromY: number?): number?
	local params = self:_mapRayParams()
	if not params then
		return nil
	end

	local rig = self._rig
	local startY = fromY or (rig and rig.Position.Y + 10 or 50)
	local result = Workspace:Raycast(Vector3.new(x, startY, z), Vector3.new(0, -100, 0), params)
	if not result then
		return nil
	end
	return result.Position.Y
end

function BossComponent:_placeOnGround()
	local rig = self._rig
	if not rig then
		return
	end

	local groundY = self:_groundYAt(rig.Position.X, rig.Position.Z, rig.Position.Y + 5)
	if not groundY then
		return
	end

	local newCenter = Vector3.new(rig.Position.X, groundY + self._rigHalfHeight, rig.Position.Z)
	local lookTarget = newCenter + rig.CFrame.LookVector
	lookTarget = Vector3.new(lookTarget.X, newCenter.Y, lookTarget.Z)
	if (lookTarget - newCenter).Magnitude < 0.001 then
		lookTarget = newCenter + Vector3.new(0, 0, -1)
	end
	rig.CFrame = CFrame.new(newCenter, lookTarget)
end

--#endregion

--#region Shared movement

function BossComponent:_setWalkAnimation(playing: boolean)
	if not self._walkTrack then
		return
	end
	if playing and not self._walkTrack.IsPlaying then
		self._walkTrack:Play()
	elseif not playing and self._walkTrack.IsPlaying then
		self._walkTrack:Stop()
	end
end

function BossComponent:_moveRigTo(newCenter: Vector3, lookTarget: Vector3)
	local rig = self._rig
	if not rig then
		return
	end

	-- Apply hit-shake as an offset so it works even while pathfinding.
	local now = os.clock()
	if now < self._shakeEndTime then
		local elapsed = self._shakeEndTime - now
		local progress = math.clamp(1 - (elapsed / 0.15), 0, 1)
		local magnitude = self._shakeMagnitude * (1 - progress)
		newCenter += Vector3.new(
			math.random() * magnitude * 2 - magnitude,
			math.random() * magnitude * 2 - magnitude,
			math.random() * magnitude * 2 - magnitude
		)
	end

	local flatLook = Vector3.new(lookTarget.X, newCenter.Y, lookTarget.Z)
	if (flatLook - newCenter).Magnitude < 0.001 then
		flatLook = newCenter + Vector3.new(0, 0, -1)
	end
	rig.CFrame = CFrame.new(newCenter, flatLook)
end

--#endregion

--#region Boss behavior

function BossComponent:_bossTick()
	if not self._running or self._isSlamming then
		return
	end

	local now = os.clock()
	if now >= self._nextSlam then
		self:_slam()
		return
	end

	if self._isPathfinding then
		return
	end

	if not self._moveTarget then
		self:_pickRoamTarget()
	end
	if not self._moveTarget then
		return
	end

	self._isPathfinding = true
	local target = self._moveTarget
	task.spawn(function()
		self:_pathfindTo(target)
		self._isPathfinding = false
		self._moveTarget = nil
	end)
end

function BossComponent:_pickRoamTarget()
	local groundPos = MapManager.getCoinSpawnPosition(0)
	if groundPos then
		self._moveTarget = groundPos
	else
		local rig = self._rig
		if rig then
			local angle = math.random() * math.pi * 2
			local distance = math.random(10, 25)
			local target = rig.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			self._moveTarget = target
		end
	end
end

function BossComponent:_slam()
	if self._isSlamming then
		return
	end
	self._isSlamming = true

	self._moveTarget = nil
	self:_setWalkAnimation(false)

	if self._slamTrack then
		self._slamTrack:Play()
	end

	local slamLength = if self._slamTrack then self._slamTrack.Length else 1
	local soundDelay = slamLength * (1 / 3)
	local impactDelay = math.max(slamLength * 0.8, (self._def.slamWindup or 0.4) + 0.1)

	task.delay(soundDelay, function()
		if not self._running then
			return
		end
		local rig = self._rig
		local slamSound = rig and rig:FindFirstChild("Slam") :: Sound?
		if slamSound and slamSound:IsA("Sound") then
			if not slamSound.IsLoaded then
				slamSound.Loaded:Wait()
			end
			slamSound:Play()
		end
	end)

	task.delay(impactDelay, function()
		if not self._running then
			return
		end
		self:_applySlamKnockback()
		self:_createSlamEffect()
	end)

	task.delay(math.max(slamLength, 0.6), function()
		if not self._running then
			return
		end
		self._isSlamming = false
		self._nextSlam = os.clock() + (self._def.slamCooldown or 4)
	end)
end

local function waitForCharacterLanding(character: Model, timeout: number): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local start = os.clock()
	while os.clock() - start < timeout do
		if humanoid.FloorMaterial ~= Enum.Material.Air then
			return true
		end

		local velY = root.AssemblyLinearVelocity.Y
		if velY > -2 and velY < 2 then
			local result = Workspace:Raycast(root.Position, Vector3.new(0, -5, 0), params)
			if result then
				return true
			end
		end

		task.wait(0.1)
	end

	return false
end

local function unequipPaintball(character: Model): Tool?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local equippedTool = character:FindFirstChildOfClass("Tool")

	-- Only unequip if the paintball gun is currently equipped.
	if equippedTool and equippedTool.Name == "Paintball Gun" and humanoid then
		humanoid:UnequipTools()
		return equippedTool
	end

	-- Otherwise just cache whatever paintball is in the backpack so it can be restored.
	local player = Players:GetPlayerFromCharacter(character)
	local backpack = player and player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return nil
	end

	for _, child in ipairs(backpack:GetChildren()) do
		if child:IsA("Tool") and child.Name == "Paintball Gun" then
			return child
		end
	end
	return nil
end

local function restorePaintball(character: Model, storedTool: Tool?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return
	end

	-- Only restore the paintball the player actually had. If it was stripped by
	-- event cleanup, the event's own restore logic will handle their loadout.
	if storedTool and storedTool.Parent then
		humanoid:EquipTool(storedTool)
	end
end

function BossComponent:_applySlamKnockback()
	if not self._rig then
		return
	end

	local slamPos = self._rig.Position
	self._lastSlamPos = slamPos
	local radius = self._def.slamRadius or 25
	local knockback = self._def.slamKnockback or 80
	local upward = self._def.slamUpward or 40

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if not character then
			continue
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			continue
		end

		local dist = (root.Position - slamPos).Magnitude
		if dist > radius then
			continue
		end

		print(`[BossService] slam hit {player.Name}`)

		local dir = (root.Position - slamPos).Unit
		if dir.Magnitude < 0.001 then
			dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5).Unit
		end
		dir = Vector3.new(dir.X, 0, dir.Z).Unit

		-- Boss slam ragdolls and tosses affected players. A counter handles overlapping slams.
		-- A per-character session token prevents stale async recovery tasks from a previous
		-- slam cycle from trying to "get up" the character again.
		local stunCount = character:GetAttribute("BossSlamStuns") or 0
		local slamSession = character:GetAttribute("BossSlamSession") or 0
		if stunCount == 0 then
			slamSession += 1
			character:SetAttribute("BossSlamSession", slamSession)
		end
		character:SetAttribute("BossSlamStuns", stunCount + 1)
		local releaseSession = slamSession

		if stunCount == 0 then
			storedPaintballs[character] = unequipPaintball(character)

			if RagdollService then
				RagdollService:ActivateRagdoll(character)
			else
				warn(`[BossService] RagdollService not available for {player.Name}`)
			end
		end

		root.AssemblyLinearVelocity = (dir * knockback) + Vector3.new(0, upward, 0)

		task.spawn(function()
			-- Wait until the player lands, then keep them ragdolled for 3 more seconds.
			-- Small initial delay prevents the pre-fling ground contact from counting as landed.
			task.wait(0.15)
			waitForCharacterLanding(character, 3)
			task.wait(3)

			if not character or not character.Parent then
				return
			end

			if (character:GetAttribute("BossSlamSession") or 0) ~= releaseSession then
				return
			end

			local remaining = math.max(0, (character:GetAttribute("BossSlamStuns") or 1) - 1)
			character:SetAttribute("BossSlamStuns", remaining)
			if remaining > 0 then
				return
			end

			-- Invalidate any same-session stale callbacks before unragdolling.
			character:SetAttribute("BossSlamSession", releaseSession + 1)

			local currentHumanoid = character:FindFirstChildOfClass("Humanoid")
			if currentHumanoid and currentHumanoid:GetState() ~= Enum.HumanoidStateType.Dead then
				print(`[BossService] deactivating ragdoll for {player.Name}`)
				if RagdollService then
					RagdollService:DeactivateRagdoll(character)
				end
			end

			restorePaintball(character, storedPaintballs[character])
			storedPaintballs[character] = nil
		end)
	end

	BossService.Client.SlamImpact:FireAll(slamPos)
end

function BossComponent:_createSlamEffect()
	local rig = self._rig
	if not rig then
		return
	end

	local origin = self._lastSlamPos or rig.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.Instance }

	local result = Workspace:Raycast(origin, Vector3.new(0, -1, 0) * 50, params)
	if not result then
		return
	end

	local hitPos = result.Position
	local hitInstance = result.Instance
	local foundTexture = hitInstance:FindFirstChildWhichIsA("Texture")

	local vfxParticle = ReplicatedStorage:FindFirstChild("Assets", true)
		and ReplicatedStorage.Assets:FindFirstChild("Effects", true)
		and ReplicatedStorage.Assets.Effects:FindFirstChild("Particles", true)
		and ReplicatedStorage.Assets.Effects.Particles:FindFirstChild("JumpParticle") :: ParticleEmitter?
	if vfxParticle then
		local vfxPart = Instance.new("Part")
		vfxPart.Position = hitPos + Vector3.new(0, 0.5, 0)
		vfxPart.Anchored = true
		vfxPart.CanCollide = false
		vfxPart.CanQuery = false
		vfxPart.Transparency = 1
		vfxPart.Size = Vector3.new(4, 1, 4)
		vfxPart.Parent = Workspace

		local emitter = vfxParticle:Clone()
		emitter.Parent = vfxPart
		emitter:Emit(30)

		local sound = emitter:FindFirstChildWhichIsA("Sound")
		if sound then
			sound:Play()
		end
		Debris:AddItem(vfxPart, 5)
	end

	local numberOfParts = 16
	local radius = (self._def.slamRadius or 25) * 0.4

	for i = 1, numberOfParts do
		local angle = math.rad((i / numberOfParts) * 360)
		local offset = Vector3.new(math.cos(angle) * radius, 5, math.sin(angle) * radius)
		local groundResult = Workspace:Raycast(hitPos + offset, Vector3.new(0, -1, 0) * 15, params)
		if not groundResult then
			continue
		end

		local material = groundResult.Instance.Material == Enum.Material.Plastic
			and Enum.Material.SmoothPlastic
			or groundResult.Instance.Material

		local smashPart = Instance.new("Part")
		smashPart.Size = Vector3.new(1.2, 1.2, 1.2)
		smashPart.Anchored = true
		smashPart.CanCollide = false
		smashPart.CanQuery = false
		smashPart.Material = material
		smashPart.MaterialVariant = groundResult.Instance.MaterialVariant
		smashPart.Color = groundResult.Instance.Color
		smashPart.CFrame = CFrame.new(groundResult.Position + Vector3.new(0, -3, 0))
			* CFrame.Angles(
				math.rad(math.random(0, 360)),
				math.rad(math.random(0, 360)),
				math.rad(math.random(0, 360))
			)
		smashPart.Parent = Workspace

		if foundTexture then
			self:_texturePart(smashPart, foundTexture)
		end

		TweenService:Create(smashPart, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
			Position = groundResult.Position + Vector3.new(0, 0.5, 0),
		}):Play()

		task.delay(2, function()
			if smashPart and smashPart.Parent then
				TweenService:Create(smashPart, TweenInfo.new(0.25, Enum.EasingStyle.Back), {
					Position = groundResult.Position + Vector3.new(0, -3, 0),
					Transparency = 1,
				}):Play()
			end
		end)

		Debris:AddItem(smashPart, 3)
	end
end

function BossComponent:_texturePart(part: BasePart, texture: Texture)
	for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
		local cloned = texture:Clone()
		cloned.Face = face
		cloned.Parent = part
	end
end

--#endregion

--#region Minion behavior (pathfinding wander)

function BossComponent:_minionTick()
	if not self._running or self._isPathfinding or self._isSlamming then
		return
	end

	local target = MapManager.getCoinSpawnPosition(0)
	if not target then
		return
	end

	self._isPathfinding = true
	task.spawn(function()
		self:_pathfindTo(target)
		self._isPathfinding = false
	end)
end

function BossComponent:_pathfindTo(targetPos: Vector3)
	local rig = self._rig
	if not rig then
		return
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = math.max(2, self._rigHalfHeight * 0.6),
		AgentHeight = rig.Size.Y,
		AgentCanJump = true,
		AgentCanClimb = false,
	})

	local success = pcall(function()
		path:ComputeAsync(rig.Position, targetPos)
	end)

	if not success or path.Status ~= Enum.PathStatus.Success then
		return
	end

	local waypoints = path:GetWaypoints()
	if #waypoints == 0 then
		return
	end

	for i, waypoint in ipairs(waypoints) do
		if not self._running or self._isSlamming then
			break
		end
		self:_moveToWaypoint(waypoint.Position)
		if i < #waypoints then
			task.wait(0.05)
		end
	end

	self:_setWalkAnimation(false)
end

function BossComponent:_moveToWaypoint(waypointPos: Vector3)
	local rig = self._rig
	if not rig then
		return
	end

	while self._running and not self._isSlamming do
		local currentPos = rig.Position
		local offset = Vector3.new(waypointPos.X - currentPos.X, 0, waypointPos.Z - currentPos.Z)
		local distance = offset.Magnitude
		if distance < 2 then
			break
		end

		local direction = offset.Unit
		local step = direction * math.min(self._def.walkSpeed * RunService.Heartbeat:Wait(), distance)
		local newCenter = currentPos + step

		local groundY = self:_groundYAt(newCenter.X, newCenter.Z, newCenter.Y + 5)
		if groundY then
			newCenter = Vector3.new(newCenter.X, groundY + self._rigHalfHeight, newCenter.Z)
		end

		self:_moveRigTo(newCenter, waypointPos)
		self:_setWalkAnimation(true)
	end
end

--#endregion

--#region Damage / death

function BossComponent:TakeDamage(amount: number, attacker: Player?)
	if not self._running or self._currentHealth <= 0 then
		return
	end
	self._currentHealth = math.max(0, self._currentHealth - amount)
	self.Instance:SetAttribute("Health", self._currentHealth)
	if attacker and attacker:IsA("Player") then
		self._attackers[attacker] = true
		BossService.Client.BossDamaged:Fire(attacker, {
			name = self.Instance:GetAttribute("BossName"),
			displayName = self._def.displayName or "Boss",
			health = self._currentHealth,
			maxHealth = self._maxHealth,
			behavior = self._behavior,
			model = self.Instance,
		})
	end

	BossService:_updateCombinedHealth()
	self:_hitFeedback()

	if self._currentHealth <= 0 then
		self:_onDied(attacker)
	end
end

function BossComponent:_hitFeedback()
	local rig = self._rig
	if not rig then
		return
	end

	-- Flash the outline bright so the hit reads clearly through walls.
	local outline = self._outline
	if outline then
		local originalColor = outline.OutlineColor
		local originalTransparency = outline.OutlineTransparency
		outline.OutlineColor = Color3.fromRGB(255, 255, 255)
		outline.OutlineTransparency = 0.1
		task.delay(0.12, function()
			if outline and outline.Parent then
				outline.OutlineColor = originalColor
				outline.OutlineTransparency = originalTransparency
			end
		end)
	end

	-- Trigger positional shake. The movement code applies this as an offset,
	-- so the shake works even while the monster is pathfinding.
	self._shakeEndTime = os.clock() + 0.15
end

function BossComponent:_onDied(killer: Player?)
	if not self._running then
		return
	end
	self._running = false
	self:_stopMoving()
	self:_setWalkAnimation(false)
	if self._slamTrack and self._slamTrack.IsPlaying then
		self._slamTrack:Stop()
	end

	local model = self.Instance
	local rig = self._rig

	-- Burst of collectible coins on death, arranged in a circle around the corpse.
	if rig then
		local deathPos = rig.Position
		local coinCount = if self._behavior == "minion" then 18 else 36
		local radius = 8
		local startPos = deathPos + Vector3.new(0, 3, 0)
		for i = 1, coinCount do
			local angle = (i / coinCount) * math.pi * 2
			local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local landingPos = deathPos + offset
			local groundY = self:_groundYAt(landingPos.X, landingPos.Z, landingPos.Y + 10)
			if groundY then
				landingPos = Vector3.new(landingPos.X, groundY + 2.5, landingPos.Z)
			end
			local controlPos = (startPos + landingPos) / 2 + Vector3.new(0, 8, 0)
			CoinSpawner.spawnBezierCoin(startPos, landingPos, controlPos)
		end
	end
	if rig then
		rig.Anchored = false
		rig.CanCollide = false

		local up = 0.6
		local force = if self._behavior == "minion" then 55 else 45
		local flingDir = Vector3.new(
			math.random() * 2 - 1,
			up,
			math.random() * 2 - 1
		).Unit
		rig.AssemblyLinearVelocity = flingDir * force
		rig.AssemblyAngularVelocity = Vector3.new(
			math.random() * 8 - 4,
			math.random() * 8 - 4,
			math.random() * 8 - 4
		)
	end

	task.delay(1.5, function()
		if model and model.Parent then
			model:Destroy()
		end
	end)

	local reward = self._def.deathReward or 0
	if reward > 0 then
		local dataService = Knit.GetService("DataService")
		for attacker in pairs(self._attackers) do
			if attacker and attacker.Parent then
				dataService:AddCoins(attacker, reward, "BossKill")
			end
		end
	end

	local fireworkReward = self._def.fireworkReward or 0
	if fireworkReward > 0 then
		local coinService = Knit.GetService("CoinService")
		for attacker in pairs(self._attackers) do
			if attacker and attacker.Parent then
				coinService:AwardFireworks(attacker, fireworkReward, "BossKill")
			end
		end
	end

	BossService:_onBossDied(model)
end

function BossComponent:_stopMoving()
	self._moveTarget = nil
	self._isPathfinding = false
end

--#endregion

local function getRandomSpawnCFrame(): CFrame?
	local cf = MapManager.getPlayerSpawnCFrame()
	if cf then
		return cf
	end
	local pos = MapManager.getCoinSpawnPosition(0)
	if pos then
		return CFrame.new(pos)
	end
	return nil
end

function BossService:Spawn(bossName: string, optionalCF: CFrame?)
	local def = BossConfig.Get(bossName)
	if not def then
		return "Unknown boss: " .. bossName
	end

	local template = ReplicatedStorage.Assets.Bosses:FindFirstChild(bossName) :: Model?
	if not template then
		return "Boss template not found: " .. bossName
	end

	if not MapManager.isLoaded() then
		return "No active map loaded."
	end

	local spawnCF = optionalCF or getRandomSpawnCFrame()
	if not spawnCF then
		return "Could not find a spawn position."
	end

	local clone: Model = template:Clone()
	clone.Name = bossName

	local animController = clone:FindFirstChildOfClass("AnimationController")
	if not animController then
		clone:Destroy()
		return "Boss template is missing an AnimationController."
	end

	local rootPart = clone.PrimaryPart or clone:FindFirstChildOfClass("BasePart") :: BasePart?
	if not rootPart then
		clone:Destroy()
		return "Boss template is missing a PrimaryPart."
	end

	local groundPos = spawnCF.Position
	local halfHeight = rootPart.Size.Y / 2
	print(`[BossService] Spawning {bossName} at groundPos={groundPos}, halfHeight={halfHeight}`)
	rootPart.Anchored = true
	rootPart.CanCollide = false
	rootPart.CanQuery = true
	rootPart.CFrame = CFrame.new(groundPos + Vector3.new(0, halfHeight, 0))
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)

	CollectionService:AddTag(clone, "Boss")
	clone:SetAttribute("IsBoss", true)
	clone:SetAttribute("BossName", bossName)

	local maxHealth = def.health
	if def.healthPerPlayer then
		maxHealth = def.healthPerPlayer * #Players:GetPlayers()
	end
	clone:SetAttribute("Health", maxHealth)
	clone:SetAttribute("MaxHealth", maxHealth)

	clone.Parent = Workspace
	print(`[BossService] {bossName} parented to Workspace`)

	self.Client.BossSpawned:FireAll({
		name = bossName,
		displayName = def.displayName,
		health = maxHealth,
		maxHealth = maxHealth,
		behavior = if bossName == "PaintMinion" then "minion" else "boss",
	})

	return "Spawned " .. def.displayName, clone
end

function BossService:SpawnAt(bossName: string, cf: CFrame)
	return self:Spawn(bossName, cf)
end

function BossService:DamageBoss(model: Model, amount: number, attacker: Player?)
	local component = activeBosses[model]
	if component then
		component:TakeDamage(amount, attacker)
	end
end

function BossService:_onBossDied(model: Model)
	activeBosses[model] = nil
	local payload = {
		name = model:GetAttribute("BossName"),
		model = model,
		behavior = model:GetAttribute("BossBehavior") or "boss",
	}
	self.BossDiedSignal:Fire(payload)
	self.Client.BossDied:FireAll(payload)
	self:_updateCombinedHealth()
	task.delay(5, function()
		if model and model.Parent then
			model:Destroy()
		end
	end)
end

function BossService:EndEvent()
	self.Client.BossEventEnded:FireAll()
end

function BossService:Clear()
	local models = {}
	for model in pairs(activeBosses) do
		table.insert(models, model)
	end
	for _, model in ipairs(models) do
		if model and model.Parent then
			model:Destroy()
		end
	end
	table.clear(activeBosses)
	combinedMaxHealth = 0
end

return BossService
