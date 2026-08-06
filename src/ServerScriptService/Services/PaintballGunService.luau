local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local HttpService = game:GetService("HttpService")
local PaintballConfig = require(ReplicatedStorage.Config.PaintballConfig)

local PaintballGunService = Knit.CreateService({
	Name = "PaintballGunService",
	Client = {
		-- Client fires to server; server echoes to all clients.
		PaintballFired = Knit.CreateSignal(),
		-- Client reports a hit; server validates and echoes impact to all clients.
		PaintballHit = Knit.CreateSignal(),
		PaintballImpacted = Knit.CreateSignal(),
		-- Client reports aim direction; server relays it to other clients for arm replication.
		AimUpdated = Knit.CreateSignal(),
	},
})

export type PaintballArgs = PaintballConfig.PaintballArgs
export type PaintballHitInfo = PaintballConfig.PaintballHitInfo
export type PaintballImpactInfo = PaintballConfig.PaintballImpactInfo

-- Anti-exploit / rate-limit state, keyed by Player.
local lastFire: { [Player]: number } = {}
local lastHit: { [Player]: number } = {}
local lastAim: { [Player]: number } = {}

-- Active shots we have validated and broadcasted; hits must match one of these.
local activeShots: { [string]: { origin: Vector3, direction: Vector3, at: number, color: Color3 } } = {}

local function findRigPart(character: Model?, names: { string }): BasePart?
	if not character then
		return nil
	end
	for _, name in ipairs(names) do
		local part = character:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart", true)
end

local function getRigRoot(character: Model?): BasePart?
	return findRigPart(character, { "HumanoidRootPart", "Torso", "LowerTorso", "UpperTorso" })
end

local function getRigAimPart(character: Model?): BasePart?
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		return findRigPart(character, { "Torso", "HumanoidRootPart", "Head" })
	end

	return findRigPart(character, { "HumanoidRootPart", "UpperTorso", "LowerTorso", "Torso", "Head" })
end

function PaintballGunService:KnitStart()
	self:_connectSignals()

	Players.PlayerRemoving:Connect(function(player: Player)
		lastFire[player] = nil
		lastHit[player] = nil
		lastAim[player] = nil
	end)
end

function PaintballGunService:_connectSignals()
	self.Client.PaintballFired:Connect(function(player: Player, args: any)
		self:_onFire(player, args)
	end)

	self.Client.PaintballHit:Connect(function(player: Player, hitInfo: any)
		self:_onHit(player, hitInfo)
	end)

	self.Client.AimUpdated:Connect(function(player: Player, direction: any)
		self:_onAimUpdated(player, direction)
	end)
end

export type AimPacket = {
	direction: Vector3,
	equipped: boolean,
}

-- Validate a client's aim packet and relay it to all other clients.
function PaintballGunService:_onAimUpdated(player: Player, packet: any)
	if typeof(packet) == "string" then
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, packet)
		if not ok then
			return
		end
		packet = decoded
	end
	if typeof(packet) ~= "table" then
		return
	end

	local equipped = packet.equipped == true

	-- Unequip packets don't need a direction; forward them immediately so remote clients reset.
	if not equipped then
		self.Client.AimUpdated:FireAll(player, { equipped = false })
		return
	end

	local direction: Vector3?
	local rawDir = packet.direction
	if typeof(rawDir) == "Vector3" then
		direction = rawDir
	elseif typeof(rawDir) == "table" then
		local x, y, z = tonumber(rawDir.x), tonumber(rawDir.y), tonumber(rawDir.z)
		if x and y and z then
			direction = Vector3.new(x, y, z)
		end
	end
	if not direction or direction.Magnitude < 1e-3 then
		return
	end
	if not self:_playerHasGun(player) then
		return
	end

	local now = os.clock()
	if lastAim[player] and (now - lastAim[player]) < 0.05 then
		return
	end
	lastAim[player] = now

	local clean: AimPacket = {
		direction = direction.Unit,
		equipped = true,
	}
	self.Client.AimUpdated:FireAll(player, clean)
end

-- Validate a client fire request, record the shot, and echo it to all clients.
function PaintballGunService:_onFire(player: Player, rawArgs: any)
	if typeof(rawArgs) ~= "table" then
		return
	end
	if not self:_playerHasGun(player) then
		return
	end

	local now = os.clock()
	if lastFire[player] and (now - lastFire[player]) < PaintballConfig.FireRate then
		return
	end

	-- Whitelist the fields we actually trust from the client.
	local origin = rawArgs.origin
	local direction = rawArgs.direction
	local t0 = rawArgs.t0
	local shotId = rawArgs.shotId
	local color = rawArgs.color

	if typeof(origin) ~= "Vector3"
		or typeof(direction) ~= "Vector3"
		or typeof(t0) ~= "number"
		or typeof(shotId) ~= "string"
		or typeof(color) ~= "Color3"
	then
		return
	end
	if direction.Magnitude < 1e-3 or direction.Magnitude ~= direction.Magnitude then
		return
	end
	direction = direction.Unit

	-- The reported muzzle must be close to the player's root; this blocks spoofed origins.
	local root = getRigRoot(player.Character)
	if not root or (origin - root.Position).Magnitude > PaintballConfig.MaxShotOriginDelta then
		return
	end

	lastFire[player] = now
	activeShots[shotId] = { origin = origin, direction = direction, at = now, color = color }

	-- Drop stale shot records after the hit window expires.
	task.delay(PaintballConfig.HitWindow, function()
		activeShots[shotId] = nil
	end)

	local clean: PaintballArgs = {
		origin = origin,
		direction = direction,
		t0 = t0,
		shotId = shotId,
		sender = player,
		color = color,
	}

	self.Client.PaintballFired:FireAll(clean)
end

-- Validate a client-reported hit and apply damage if it lines up with a recent shot.
function PaintballGunService:_onHit(player: Player, rawHitInfo: any)
	if typeof(rawHitInfo) ~= "table" then
		return
	end
	if not self:_playerHasGun(player) then
		return
	end

	local now = os.clock()
	if lastHit[player] and (now - lastHit[player]) < PaintballConfig.HitCooldown then
		return
	end

	local shotId = rawHitInfo.shotId
	local hitPart = rawHitInfo.hitPart
	local normal = rawHitInfo.normal

	if typeof(shotId) ~= "string"
		or typeof(hitPart) ~= "Instance"
		or not hitPart:IsA("BasePart")
	then
		return
	end

	local shot = activeShots[shotId]
	if not shot or (now - shot.at) > PaintballConfig.HitWindow then
		return
	end

	local targetChar = hitPart:FindFirstAncestorOfClass("Model")
	if not targetChar then
		return
	end

	-- Paintballs only damage boss targets, not other players.
	if not self:_isBossTarget(targetChar) then
		return
	end
	print(`[PaintballGun] boss hit registered on {targetChar.Name}`)

	local targetRoot = getRigAimPart(targetChar)
	if not targetRoot then
		return
	end

	local targetHum = targetChar:FindFirstChildWhichIsA("Humanoid", true)
	if targetHum and targetHum.Health <= 0 then
		return
	end

	-- Path validation: the victim must be near the straight line from origin to aim point.
	local rel = targetRoot.Position - shot.origin
	local along = rel:Dot(shot.direction)
	if along < -5 or along > PaintballConfig.HitMaxTravel then
		return
	end

	local lateral = (rel - shot.direction * along).Magnitude
	if lateral > PaintballConfig.HitPathTolerance then
		return
	end

	if not self:_hasLineOfSight(shot.origin, player.Character, targetRoot, targetChar) then
		return
	end

	lastHit[player] = now
	activeShots[shotId] = nil

	-- Apply damage. Humanoid bosses take direct health damage; custom rig bosses
	-- are handled through BossService so the server can track death and cleanup.
	local damage = PaintballConfig.Damage
	if targetHum then
		targetHum.Health = math.max(0, targetHum.Health - damage)
		print(`[PaintballGun] hit humanoid boss {targetChar.Name} for {damage}`)
	else
		local bossService = Knit.GetService("BossService")
		bossService:DamageBoss(targetChar, damage, player)
		print(`[PaintballGun] hit custom rig boss {targetChar.Name} for {damage}`)
	end

	local impact: PaintballImpactInfo = {
		position = hitPart.Position,
		normal = if typeof(normal) == "Vector3" then normal else Vector3.yAxis,
		target = targetChar,
		hitPart = hitPart,
		color = shot.color,
	}
	self.Client.PaintballImpacted:FireAll(impact)
end

-- Simple LOS check: ray from origin to the target's HRP, ignoring the attacker.
function PaintballGunService:_isBossTarget(targetChar: Model): boolean
	-- The boss model (or any ancestor) should be tagged "Boss" or have an IsBoss attribute.
	local current: Instance? = targetChar
	while current do
		if CollectionService:HasTag(current, "Boss") then
			return true
		end
		if current:GetAttribute("IsBoss") == true then
			return true
		end
		current = current.Parent
	end
	return false
end

function PaintballGunService:_hasLineOfSight(origin: Vector3, attackerChar: Model?, targetRoot: BasePart, targetChar: Model): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if attackerChar then { attackerChar } else {}
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, targetRoot.Position - origin, params)
	if not result then
		return true
	end
	-- The ray may hit the target's rig directly, or a child of the target model.
	return result.Instance == targetRoot
		or targetRoot:IsDescendantOf(result.Instance)
		or targetChar:IsAncestorOf(result.Instance)
end

-- True if the player currently has a Tool tagged "Paintball" in their character or backpack.
function PaintballGunService:_playerHasGun(player: Player): boolean
	if not player or not player.Parent then
		return false
	end

	for _, tool in ipairs(CollectionService:GetTagged("Paintball")) do
		if tool:IsA("Tool") then
			local parent = tool.Parent
			if parent == player.Character then
				return true
			end
			if parent and parent:IsA("Backpack") and parent.Parent == player then
				return true
			end
			local backpack = parent and parent:FindFirstAncestorOfClass("Backpack")
			if backpack and backpack.Parent == player then
				return true
			end
		end
	end

	return false
end

return PaintballGunService
