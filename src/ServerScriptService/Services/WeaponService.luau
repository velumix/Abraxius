--!strict
-- @author Velumix
-- @version 0.0.1
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local StarterPack = game:GetService("StarterPack")

local Knit = require(ReplicatedStorage.Modules.Knit)
local FastCast = require(ReplicatedStorage.Modules.FastCast)
local Signal = require(ReplicatedStorage.Modules.Signal)
local Trove = require(ReplicatedStorage.Modules.Trove)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)
local WeaponComponent = require(ServerScriptService.Components.WeaponComponent)
local NetGuard = require(ServerScriptService.NetGuard)

local WeaponService = Knit.CreateService({
	Name = "WeaponService",
	Client = {
		WeaponEquipped = Knit.CreateSignal(),
		WeaponActivated = Knit.CreateSignal(),
		WeaponAction = Knit.CreateSignal(),
		WeaponImpact = Knit.CreateSignal(),
		CharacterDied = Knit.CreateSignal(),
	},
})

WeaponService.WeaponEquipped = Signal.new()
WeaponService.WeaponActivated = Signal.new()
WeaponService.WeaponAction = Signal.new()
WeaponService.CharacterHit = Signal.new()
WeaponService._trove = Trove.new()
WeaponService._lastFire = {} :: { [Player]: number }
WeaponService._npcLastFire = {} :: { [Model]: number }
WeaponService._caster = FastCast.new()
WeaponService._projectileFolder = nil :: Folder?
WeaponService._bulletTemplate = nil :: Part?
local activeHitReactions = setmetatable({}, { __mode = "k" })
local RAGDOLL_COLLISION_GROUP = "Ragdoll"
local RAGDOLL_HAND_COLLISION_GROUP = "RagdollHands"
local BODY_PARTS = table.freeze({
	Head = true,
	UpperTorso = true,
	LowerTorso = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
})

pcall(function()
	PhysicsService:RegisterCollisionGroup(RAGDOLL_COLLISION_GROUP)
end)
pcall(function()
	PhysicsService:RegisterCollisionGroup(RAGDOLL_HAND_COLLISION_GROUP)
end)
PhysicsService:CollisionGroupSetCollidable(RAGDOLL_COLLISION_GROUP, RAGDOLL_COLLISION_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(RAGDOLL_HAND_COLLISION_GROUP, RAGDOLL_HAND_COLLISION_GROUP, false)
PhysicsService:CollisionGroupSetCollidable(RAGDOLL_HAND_COLLISION_GROUP, RAGDOLL_COLLISION_GROUP, true)

local function addRagdollCollider(bodyPart: BasePart)
	local collider = Instance.new("Part")
	collider.Name = `RagdollCollider_{bodyPart.Name}`
	collider.Size = Vector3.new(
		math.max(bodyPart.Size.X * 0.72, 0.28),
		math.max(bodyPart.Size.Y * 0.82, 0.28),
		math.max(bodyPart.Size.Z * 0.72, 0.28)
	)
	collider.Shape = if bodyPart.Name == "Head" then Enum.PartType.Ball else Enum.PartType.Block
	collider.CFrame = bodyPart.CFrame
	collider.Transparency = 1
	collider.Massless = true
	collider.CanCollide = true
	collider.CanQuery = false
	collider.CanTouch = false
	local isHand = bodyPart.Name == "LeftHand" or bodyPart.Name == "RightHand"
	collider.CollisionGroup = if isHand then RAGDOLL_HAND_COLLISION_GROUP else RAGDOLL_COLLISION_GROUP
	collider.Parent = bodyPart.Parent
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = bodyPart
	weld.Part1 = collider
	weld.Parent = collider
end

local function createProjectileObjects(): (Folder, Part)
	local existing = workspace:FindFirstChild("WeaponProjectiles")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "WeaponProjectiles"
	folder.Parent = workspace
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local bullets = assets:WaitForChild("Bullets")
	local source = bullets:WaitForChild("Bullet")
	assert(source:IsA("Part"), "ReplicatedStorage.Assets.Bullets.Bullet must be a Part")
	local bullet = source:Clone()
	bullet.Anchored = true
	bullet.CanCollide = false
	bullet.CanQuery = false
	bullet.CanTouch = false
	bullet.CastShadow = false
	return folder, bullet
end

local function findLimbMotor(character: Model, hitPart: BasePart): Motor6D?
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part1 == hitPart then
			return descendant
		end
	end
	return nil
end

local function findLimbAnimationConstraint(character: Model, hitPart: BasePart): AnimationConstraint?
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("IKControl") then
			descendant.Weight = 0
			descendant.Enabled = false
		elseif descendant:IsA("AnimationConstraint") then
			local attachment = descendant.Attachment1
			if attachment and attachment.Parent == hitPart then
				return descendant
			end
		end
	end
	return nil
end

local function ragdollCharacter(character: Model, humanoid: Humanoid)
	if character:GetAttribute("WeaponRagdolled") then
		return
	end
	character:SetAttribute("WeaponRagdolled", true)
	humanoid.MaxHealth = 0
	humanoid.Health = 0
	humanoid.HealthChanged:Connect(function(health)
		if character:GetAttribute("WeaponRagdolled") and health > 0 then
			warn("[WeaponDebug][Server] Rejected healing on dead ragdoll", character:GetFullName(), health)
			humanoid.Health = 0
		end
	end)
	humanoid.AutoRotate = false
	humanoid.EvaluateStateMachine = false
	local animationConstraintCount = 0
	local motorCount = 0
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("IKControl") then
			descendant.Weight = 0
			descendant.Enabled = false
		elseif descendant:IsA("Animator") then
			for _, track in descendant:GetPlayingAnimationTracks() do
				track:Stop(0)
			end
		elseif descendant:IsA("BaseScript") and descendant.Name == "Animate" then
			descendant.Enabled = false
		elseif descendant:IsA("AnimationConstraint") then
			animationConstraintCount += 1
			descendant.IsKinematic = false
			descendant.AngularStrength = 0
			descendant.LinearStrength = 0
			descendant.MaxForce = 0
			descendant.MaxTorque = 0
		elseif descendant:IsA("BallSocketConstraint") then
			descendant.MaxFrictionTorque = 1.5
		elseif descendant:IsA("Motor6D") then
			motorCount += 1
			local part0 = descendant.Part0
			local part1 = descendant.Part1
			if part0 and part1 and descendant.Name ~= "RightGrip" then
				local attachment0 = Instance.new("Attachment")
				attachment0.Name = `WeaponRagdoll_{descendant.Name}_0`
				attachment0.CFrame = descendant.C0
				attachment0.Parent = part0
				local attachment1 = Instance.new("Attachment")
				attachment1.Name = `WeaponRagdoll_{descendant.Name}_1`
				attachment1.CFrame = descendant.C1
				attachment1.Parent = part1
				local socket = Instance.new("BallSocketConstraint")
				socket.Name = `WeaponRagdoll_{descendant.Name}`
				socket.Attachment0 = attachment0
				socket.Attachment1 = attachment1
				socket.LimitsEnabled = true
				socket.UpperAngle = if descendant.Name == "Neck" then 35 else 65
				socket.TwistLimitsEnabled = true
				socket.TwistLowerAngle = -45
				socket.TwistUpperAngle = 45
				socket.MaxFrictionTorque = 1.5
				socket.Parent = part0
			end
			descendant.Enabled = false
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			local canSetOwnership = descendant:CanSetNetworkOwnership()
			if canSetOwnership then
				descendant:SetNetworkOwner(nil)
			end
		end
	end
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and BODY_PARTS[child.Name] then
			local isHand = child.Name == "LeftHand" or child.Name == "RightHand"
			child.CollisionGroup = if isHand then RAGDOLL_HAND_COLLISION_GROUP else RAGDOLL_COLLISION_GROUP
			child.AssemblyLinearVelocity += Vector3.new(0, 4.5, 0)
			addRagdollCollider(child)
		end
	end
	print(
		"[WeaponDebug][Server] Character ragdoll",
		character:GetFullName(),
		"animationConstraints",
		animationConstraintCount,
		"motors",
		motorCount
	)
end

local function ensureDeathRagdoll(character: Model, humanoid: Humanoid, weaponService)
	if character:GetAttribute("WeaponRagdollConfigured") then
		return
	end
	character:SetAttribute("WeaponRagdollConfigured", true)
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.Died:Connect(function()
		ragdollCharacter(character, humanoid)
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			weaponService.Client.CharacterDied:Fire(player, character)
			print("[WeaponDebug][Server] CharacterDied camera signal", player.Name)
		end
	end)
end

local function reactToHit(character: Model, hitPart: BasePart, velocity: Vector3)
	if
		velocity.X ~= velocity.X
		or velocity.Y ~= velocity.Y
		or velocity.Z ~= velocity.Z
		or math.abs(velocity.X) == math.huge
		or math.abs(velocity.Y) == math.huge
		or math.abs(velocity.Z) == math.huge
		or velocity.Magnitude < 0.001
	then
		warn("[WeaponDebug][Server] Rejected non-finite hit reaction velocity", velocity)
		return
	end
	local direction = velocity.Unit
	local usesInvertedJointBasis = hitPart.Name == "UpperTorso"
		or hitPart.Name == "LowerTorso"
		or hitPart.Name == "Head"
	local motor = findLimbMotor(character, hitPart)
	if motor and motor.Part0 then
		if activeHitReactions[motor] then
			return
		end
		activeHitReactions[motor] = true
		local worldAxis = direction:Cross(Vector3.new(0, 1, 0))
		if worldAxis.Magnitude < 0.01 then
			worldAxis = motor.Part0.CFrame.RightVector
		end
		if usesInvertedJointBasis then
			worldAxis = -worldAxis
		end
		local localAxis = motor.Part0.CFrame:VectorToObjectSpace(worldAxis.Unit)
		local originalTransform = motor.Transform
		task.spawn(function()
			local started = os.clock()
			local duration = 0.28
			while motor.Parent and os.clock() - started < duration do
				local alpha = (os.clock() - started) / duration
				local envelope = math.sin(alpha * math.pi) * (1 - alpha * 0.35)
				motor.Transform = originalTransform * CFrame.fromAxisAngle(localAxis, math.rad(18) * envelope)
				RunService.Heartbeat:Wait()
			end
			if motor.Parent then
				motor.Transform = originalTransform
			end
			activeHitReactions[motor] = nil
		end)
		print("[WeaponDebug][Server] Motor6D hit reaction", motor:GetFullName(), hitPart.Name)
		return
	end

	local animationConstraint = findLimbAnimationConstraint(character, hitPart)
	if animationConstraint then
		if activeHitReactions[animationConstraint] then
			return
		end
		activeHitReactions[animationConstraint] = true
		local worldAxis = direction:Cross(Vector3.new(0, 1, 0))
		if worldAxis.Magnitude < 0.01 then
			worldAxis = hitPart.CFrame.RightVector
		end
		if usesInvertedJointBasis then
			worldAxis = -worldAxis
		end
		local originalKinematic = animationConstraint.IsKinematic
		local originalTransform = animationConstraint.Transform
		local originalAngularStrength = animationConstraint.AngularStrength
		local originalMaxTorque = animationConstraint.MaxTorque
		local ballSocket = hitPart:FindFirstChild(`{animationConstraint.Name}BallSocket`)
		local originalFriction = if ballSocket and ballSocket:IsA("BallSocketConstraint")
			then ballSocket.MaxFrictionTorque
			else nil
		local canSetOwnership = hitPart:CanSetNetworkOwnership()
		if canSetOwnership then
			hitPart:SetNetworkOwner(nil)
		end
		animationConstraint.IsKinematic = false
		animationConstraint.AngularStrength = 0
		animationConstraint.MaxTorque = 0
		if ballSocket and ballSocket:IsA("BallSocketConstraint") then
			ballSocket.MaxFrictionTorque = 0
		end
		local mass = math.max(hitPart.AssemblyMass, 0.1)
		hitPart:ApplyImpulse(direction * mass * 9)
		hitPart:ApplyAngularImpulse(worldAxis.Unit * mass * 12)
		hitPart.AssemblyLinearVelocity = direction * 10
		hitPart.AssemblyAngularVelocity = worldAxis.Unit * 14
		task.delay(0.2, function()
			if animationConstraint.Parent and not character:GetAttribute("WeaponRagdolled") then
				animationConstraint.Transform = originalTransform
			end
			local started = os.clock()
			local recoveryDuration = 0.35
			while
				animationConstraint.Parent
				and not character:GetAttribute("WeaponRagdolled")
				and os.clock() - started < recoveryDuration
			do
				local linearAlpha = math.clamp((os.clock() - started) / recoveryDuration, 0, 1)
				local alpha = linearAlpha * linearAlpha * (3 - 2 * linearAlpha)
				animationConstraint.AngularStrength = originalAngularStrength * alpha
				animationConstraint.MaxTorque = originalMaxTorque * alpha
				if ballSocket and ballSocket.Parent and originalFriction ~= nil then
					ballSocket.MaxFrictionTorque = originalFriction * alpha
				end
				RunService.Heartbeat:Wait()
			end
			if animationConstraint.Parent and not character:GetAttribute("WeaponRagdolled") then
				animationConstraint.AngularStrength = originalAngularStrength
				animationConstraint.MaxTorque = originalMaxTorque
				animationConstraint.IsKinematic = originalKinematic
			end
			if
				ballSocket
				and ballSocket.Parent
				and originalFriction ~= nil
				and not character:GetAttribute("WeaponRagdolled")
			then
				ballSocket.MaxFrictionTorque = originalFriction
			end
			activeHitReactions[animationConstraint] = nil
		end)
		print(
			"[WeaponDebug][Server] Dynamic AnimationConstraint hit reaction",
			animationConstraint:GetFullName(),
			hitPart.Name,
			"mass",
			mass
		)
		return
	end

	-- Last-resort fallback for physical rigs without an animatable joint.
	local mass = math.max(hitPart.AssemblyMass, 0.1)
	local angularAxis = direction:Cross(Vector3.new(0, 1, 0))
	if angularAxis.Magnitude < 0.01 then
		angularAxis = hitPart.CFrame.RightVector
	end
	if usesInvertedJointBasis then
		angularAxis = -angularAxis
	end
	hitPart:ApplyImpulse(direction * mass * 5)
	hitPart:ApplyAngularImpulse(angularAxis.Unit * mass * 4)
	print("[WeaponDebug][Server] Physics hit reaction", hitPart:GetFullName(), "mass", mass)
end

local function configureM45()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local pistols = assets and assets:FindFirstChild("Pistols")
	local source = pistols and pistols:FindFirstChild("M45")
	if not source or not source:IsA("Tool") then
		warn("[WeaponService] ReplicatedStorage.Assets.Pistols.M45 was not found")
		return
	end
	source:SetAttribute("WeaponType", WeaponDefinitions.Types.Firearm)
	source:SetAttribute("Damage", 15)
	source:SetAttribute("FireRate", 0.25)
	source:SetAttribute("Range", 500)
	source:SetAttribute("BulletSpeed", 650)
	source:SetAttribute("BulletGravity", 0.12)
	local legacy = source:FindFirstChild("ClientHandler")
	if legacy and legacy:IsA("LocalScript") then
		legacy.Enabled = false
	end
	for _, descendant in source:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.Massless = true
		end
	end
	CollectionService:AddTag(source, WeaponDefinitions.Tag)
	if not StarterPack:FindFirstChild(source.Name) then
		local tool = source:Clone()
		CollectionService:AddTag(tool, WeaponDefinitions.Tag)
		tool.Parent = StarterPack
	end
	for _, player in Players:GetPlayers() do
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack and not backpack:FindFirstChild(source.Name) then
			local tool = source:Clone()
			CollectionService:AddTag(tool, WeaponDefinitions.Tag)
			tool.Parent = backpack
		end
	end
end

NetGuard.Define("Weapon.Action", {
	RateLimit = { Requests = 20, Window = 1 },
	AllowedTypes = { Instance = true },
	Validate = function(_player, tool, action)
		return typeof(tool) == "Instance"
			and tool:IsA("Tool")
			and (action == WeaponDefinitions.Actions.BlockStart or action == WeaponDefinitions.Actions.BlockEnd),
			"INVALID_WEAPON_ACTION"
	end,
})

NetGuard.Define("Weapon.Fire", {
	RateLimit = { Requests = 15, Window = 1 },
	AllowedTypes = { Instance = true, Vector3 = true },
	Validate = function(_player, tool, target)
		return typeof(tool) == "Instance"
			and tool:IsA("Tool")
			and typeof(target) == "Vector3"
			and target.X == target.X
			and target.Y == target.Y
			and target.Z == target.Z
			and math.abs(target.X) < math.huge
			and math.abs(target.Y) < math.huge
			and math.abs(target.Z) < math.huge,
			"INVALID_FIRE_REQUEST"
	end,
})

function WeaponService:GetComponent(tool: Tool)
	return WeaponComponent:FromInstance(tool)
end

function WeaponService:_acceptAction(player: Player, tool: Tool, action: string): (boolean, string?)
	local component = WeaponComponent:FromInstance(tool)
	if not component or tool.Parent ~= player.Character or Players:GetPlayerFromCharacter(tool.Parent) ~= player then
		return false, "WEAPON_NOT_EQUIPPED"
	end
	self.WeaponAction:Fire(player, tool, action)
	self.Client.WeaponAction:Fire(player, tool, action)
	return true, nil
end

function WeaponService.Client:RequestAction(player: Player, tool: Tool, action: string)
	local allowed, reason = NetGuard.Check(player, "Weapon.Action", tool, action)
	if not allowed then
		return false, reason
	end
	return self.Server:_acceptAction(player, tool, action)
end

function WeaponService.Client:RequestFire(player: Player, tool: Tool, target: Vector3)
	print("[WeaponDebug][Server] RequestFire", player.Name, tool:GetFullName(), "target", target)
	local allowed, reason = NetGuard.Check(player, "Weapon.Fire", tool, target)
	if not allowed then
		warn("[WeaponDebug][Server] NetGuard rejected", reason)
		return false, reason
	end
	if not WeaponDefinitions.IsFirearm(tool) or tool.Parent ~= player.Character then
		warn("[WeaponDebug][Server] Weapon not equipped or not a firearm")
		return false, "WEAPON_NOT_EQUIPPED"
	end
	local muzzle = tool:FindFirstChild("Muzzle", true)
	if not muzzle or not muzzle:IsA("BasePart") then
		warn("[WeaponDebug][Server] Muzzle missing")
		return false, "MUZZLE_MISSING"
	end
	local now = os.clock()
	local fireRate = math.max(tool:GetAttribute("FireRate") or 0.25, 0.08)
	if now - (self.Server._lastFire[player] or 0) < fireRate then
		warn("[WeaponDebug][Server] Fire cooldown rejected")
		return false, "FIRE_COOLDOWN"
	end
	self.Server._lastFire[player] = now
	local origin = muzzle.Position
	local offset = target - origin
	if offset.Magnitude < 0.001 then
		warn("[WeaponDebug][Server] Invalid zero-length aim")
		return false, "INVALID_AIM"
	end
	local range = math.clamp(tool:GetAttribute("Range") or 500, 1, 1000)
	local bulletSpeed = math.clamp(tool:GetAttribute("BulletSpeed") or 650, 50, 2000)
	local gravityScale = math.clamp(tool:GetAttribute("BulletGravity") or 0.12, 0, 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model, self.Server._projectileFolder :: Folder }
	local behavior = FastCast.newBehavior()
	behavior.RaycastParams = params
	behavior.MaxDistance = range
	behavior.Acceleration = Vector3.new(0, -workspace.Gravity * gravityScale, 0)
	behavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Always
	behavior.HighFidelitySegmentSize = 1
	behavior.CosmeticBulletTemplate = self.Server._bulletTemplate
	behavior.CosmeticBulletContainer = self.Server._projectileFolder
	local cast = self.Server._caster:Fire(origin, offset.Unit, bulletSpeed, behavior)
	print("[WeaponDebug][Server] FastCast launched", "origin", origin, "speed", bulletSpeed, "range", range)
	cast.UserData.Player = player
	cast.UserData.ShooterModel = player.Character
	cast.UserData.Damage = math.clamp(tool:GetAttribute("Damage") or 15, 0, 100)
	local clientHandler = tool:FindFirstChild("ClientHandler")
	cast.UserData.ImpactModule = clientHandler and clientHandler:FindFirstChild("Impact")
	return true, nil
end

function WeaponService:FireNPC(character: Model, tool: Tool, target: Vector3): (boolean, string?)
	if tool.Parent ~= character or character:GetAttribute("WeaponRagdolled") then
		return false, "NPC_WEAPON_NOT_EQUIPPED"
	end
	local muzzle = tool:FindFirstChild("Muzzle", true)
	if not muzzle or not muzzle:IsA("BasePart") then
		return false, "MUZZLE_MISSING"
	end
	local now = os.clock()
	local fireRate = math.max(tool:GetAttribute("NPCFireRate") or 0.75, 0.3)
	if now - (self._npcLastFire[character] or 0) < fireRate then
		return false, "FIRE_COOLDOWN"
	end
	self._npcLastFire[character] = now
	local offset = target - muzzle.Position
	if offset.Magnitude < 0.001 then
		return false, "INVALID_AIM"
	end
	local behavior = FastCast.newBehavior()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, self._projectileFolder :: Folder }
	behavior.RaycastParams = params
	behavior.MaxDistance = math.clamp(tool:GetAttribute("Range") or 500, 1, 1000)
	behavior.Acceleration = Vector3.new(0, -workspace.Gravity * 0.12, 0)
	behavior.HighFidelityBehavior = FastCast.HighFidelityBehavior.Always
	behavior.HighFidelitySegmentSize = 1
	behavior.CosmeticBulletTemplate = self._bulletTemplate
	behavior.CosmeticBulletContainer = self._projectileFolder
	local speed = math.clamp(tool:GetAttribute("BulletSpeed") or 650, 50, 2000)
	local cast = self._caster:Fire(muzzle.Position, offset.Unit, speed, behavior)
	cast.UserData.Player = nil
	cast.UserData.ShooterModel = character
	cast.UserData.Damage = math.clamp(tool:GetAttribute("NPCDamage") or 8, 0, 50)
	cast.UserData.ImpactModule = nil
	print("[WeaponDebug][Server] NPC FastCast launched", character:GetFullName(), target)
	return true, nil
end

function WeaponService:KnitStart()
	self._projectileFolder, self._bulletTemplate = createProjectileObjects()
	self._trove:Add(
		self._caster.LengthChanged:Connect(
			function(_cast, lastPoint, direction, displacement, _velocity, cosmeticBullet)
				if cosmeticBullet and cosmeticBullet:IsA("BasePart") then
					local position = lastPoint + direction * displacement
					cosmeticBullet.CFrame = CFrame.lookAt(position, position + direction)
				end
			end
		)
	)
	self._trove:Add(self._caster.RayHit:Connect(function(cast, result, segmentVelocity)
		if not result then
			warn("[WeaponDebug][Server] RayHit fired without a result")
			return
		end
		print("[WeaponDebug][Server] RayHit", result.Instance:GetFullName(), "position", result.Position)
		local model = result.Instance:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		local player = cast.UserData.Player
		local impactData = nil
		local impactModule = cast.UserData.ImpactModule
		if impactModule and impactModule:IsA("ModuleScript") and player then
			local loaded, module = pcall(require, impactModule)
			if loaded and type(module.GetData) == "function" then
				local classified, data = pcall(module.GetData, module, player, result.Instance)
				if classified then
					impactData = data
				end
			end
		end
		local impactColor = if humanoid
			then Color3.fromRGB(130, 0, 0)
			elseif impactData and typeof(impactData.Color) == "Color3" then impactData.Color
			else result.Instance.Color
		self.Client.WeaponImpact:FireAll(result.Position, result.Normal, humanoid ~= nil, impactColor)
		print("[WeaponDebug][Server] WeaponImpact broadcast", humanoid ~= nil, impactColor)
		local shooterModel = cast.UserData.ShooterModel
		if humanoid and humanoid.Health > 0 and model ~= shooterModel and not model:GetAttribute("WeaponRagdolled") then
			ensureDeathRagdoll(model, humanoid, self)
			local reactionPart = result.Instance
			if reactionPart.Name == "HumanoidRootPart" then
				local upperTorso = model:FindFirstChild("UpperTorso")
				if upperTorso and upperTorso:IsA("BasePart") then
					reactionPart = upperTorso
				end
			end
			reactToHit(model, reactionPart, segmentVelocity)
			if player then
				self.CharacterHit:Fire(player, model, reactionPart, cast.UserData.Damage)
			end
			humanoid:TakeDamage(cast.UserData.Damage)
		end
	end))
	self._trove:Add(self._caster.CastTerminating:Connect(function(cast)
		print("[WeaponDebug][Server] CastTerminating", cast.StateInfo.TotalRuntime, cast.StateInfo.DistanceCovered)
		local cosmeticBullet = cast.RayInfo.CosmeticBulletObject
		if cosmeticBullet then
			cosmeticBullet:Destroy()
		end
	end))
	configureM45()
	self._trove:Add(WeaponComponent.EquippedChanged:Connect(function(component, player, equipped)
		if player then
			self.WeaponEquipped:Fire(player, component.Instance, equipped)
			self.Client.WeaponEquipped:Fire(player, component.Instance, equipped)
		end
	end))
	self._trove:Add(WeaponComponent.Activated:Connect(function(component, player)
		-- This is the server-authoritative seam for cooldown, hitbox, stamina,
		-- and damage logic. The Tool and ownership have already been validated.
		self.WeaponActivated:Fire(player, component.Instance)
		self.Client.WeaponActivated:Fire(player, component.Instance)
	end))
end

function WeaponService:Destroy()
	table.clear(self._lastFire)
	table.clear(self._npcLastFire)
	if self._projectileFolder then
		self._projectileFolder:Destroy()
	end
	self._trove:Destroy()
	self.WeaponEquipped:Destroy()
	self.WeaponActivated:Destroy()
	self.WeaponAction:Destroy()
	self.CharacterHit:Destroy()
end

return WeaponService
