local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

-- R15 joint limits. The actual rig is built dynamically from the character's Motor6Ds/AnimationConstraints
-- so we don't depend on a hardcoded rig module being present in the place.
type Limits = {
	UpperAngle: number,
	TwistUpperAngle: number,
	TwistLowerAngle: number,
}

local RAGDOLL_LIMITS: { [string]: Limits } = {
	Root = { UpperAngle = 20, TwistUpperAngle = 30, TwistLowerAngle = 0 },
	Waist = { UpperAngle = 20, TwistUpperAngle = 30, TwistLowerAngle = -10 },
	Neck = { UpperAngle = 45, TwistUpperAngle = 30, TwistLowerAngle = -30 },

	RightShoulder = { UpperAngle = 90, TwistUpperAngle = 160, TwistLowerAngle = -70 },
	RightElbow = { UpperAngle = 0, TwistUpperAngle = 95, TwistLowerAngle = -5 },
	RightWrist = { UpperAngle = 10, TwistUpperAngle = 5, TwistLowerAngle = -45 },

	LeftShoulder = { UpperAngle = 90, TwistUpperAngle = 160, TwistLowerAngle = -70 },
	LeftElbow = { UpperAngle = 0, TwistUpperAngle = 95, TwistLowerAngle = -5 },
	LeftWrist = { UpperAngle = 10, TwistUpperAngle = 5, TwistLowerAngle = -45 },

	RightHip = { UpperAngle = 60, TwistUpperAngle = 45, TwistLowerAngle = -45 },
	RightKnee = { UpperAngle = 0, TwistUpperAngle = 5, TwistLowerAngle = -80 },
	RightAnkle = { UpperAngle = 10, TwistUpperAngle = 5, TwistLowerAngle = -45 },

	LeftHip = { UpperAngle = 60, TwistUpperAngle = 45, TwistLowerAngle = -45 },
	LeftKnee = { UpperAngle = 0, TwistUpperAngle = 5, TwistLowerAngle = -80 },
	LeftAnkle = { UpperAngle = 10, TwistUpperAngle = 5, TwistLowerAngle = -45 },
}

local DEFAULT_LIMITS: Limits = { UpperAngle = 45, TwistUpperAngle = 45, TwistLowerAngle = -45 }
local R6_COLLIDING_LIMBS = {
	["Left Arm"] = true,
	["Right Arm"] = true,
	["Left Leg"] = true,
	["Right Leg"] = true,
}

local RagdollService = Knit.CreateService({
	Name = "RagdollService",
	Client = {
		-- Server -> client notification of ragdoll activation/deactivation.
		ActivateRagdoll = Knit.CreateSignal(),
		DeactivateRagdoll = Knit.CreateSignal(),
	},
})

type StoredJoint = {
	joint: Motor6D | AnimationConstraint,
	originalEnabled: boolean,
}

type ActiveRagdoll = {
	character: Model,
	player: Player?,
	humanoid: Humanoid,
	hrp: BasePart,
	animate: LocalScript?,
	joints: { StoredJoint },
	sockets: { BallSocketConstraint },
	weld: Weld?,
	colliders: { BasePart },
	limbCanCollide: { [BasePart]: boolean },
	originalBreakJointsOnDeath: boolean,
	originalAutoRotate: boolean,
	originalPlatformStand: boolean,
	originalAnimateEnabled: boolean,
	originalCanCollide: boolean,
	originalOwner: Player?,
}

local activeRagdolls: { [Model]: ActiveRagdoll } = {}

local function getPlayerFromCharacter(character: Model): Player?
	return Players:GetPlayerFromCharacter(character)
end

local function setServerOwnership(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and not hrp.Anchored then
		pcall(function()
			hrp:SetNetworkOwner(nil)
		end)
	end

	-- Also claim ownership of any parts that have split off into separate assemblies
	-- (accessories, tools, etc.) so the server simulates the entire ragdoll.
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(nil)
			end)
		end
	end
end

local function returnOwnershipToPlayer(character: Model, player: Player?)
	if not player or not player.Parent then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if hrp and not hrp.Anchored then
		pcall(function()
			hrp:SetNetworkOwner(player)
		end)
	end

	-- Return any separate assemblies (accessories, tools) as well.
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and not descendant.Anchored then
			pcall(function()
				descendant:SetNetworkOwner(player)
			end)
		end
	end
end

local function createBallSocket(jointName: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame, limits: { UpperAngle: number, TwistUpperAngle: number, TwistLowerAngle: number }): BallSocketConstraint
	local socket = Instance.new("BallSocketConstraint")
	socket.Name = jointName .. "BallSocket"
	socket.Enabled = true
	socket.LimitsEnabled = true
	socket.TwistLimitsEnabled = true
	socket.UpperAngle = limits.UpperAngle
	socket.TwistUpperAngle = limits.TwistUpperAngle
	socket.TwistLowerAngle = limits.TwistLowerAngle

	local att0 = Instance.new("Attachment")
	att0.Name = "RagdollA0"
	att0.CFrame = c0
	att0.Parent = part0

	local att1 = Instance.new("Attachment")
	att1.Name = "RagdollA1"
	att1.CFrame = c1
	att1.Parent = part1

	socket.Attachment0 = att0
	socket.Attachment1 = att1
	socket.Parent = part1

	return socket
end

local function storeOriginalCanCollide(store: { [BasePart]: boolean }, part: BasePart)
	if store[part] == nil then
		store[part] = part.CanCollide
	end
end

local function forceR6LimbCollision(character: Model, humanoid: Humanoid, store: { [BasePart]: boolean })
	if humanoid.RigType ~= Enum.HumanoidRigType.R6 then
		return
	end

	for limbName in pairs(R6_COLLIDING_LIMBS) do
		local limb = character:FindFirstChild(limbName)
		if limb and limb:IsA("BasePart") then
			storeOriginalCanCollide(store, limb)
			limb.CanCollide = true
		end
	end
end

-- Small/thin R15 parts (hands/feet) can tunnel through the ground at ragdoll speeds.
-- Adding a slightly larger invisible collider welded to them prevents that.
local function createLimbCollider(part: BasePart): BasePart
	local collider = Instance.new("Part")
	collider.Name = "RagdollCollider"

	local size = part.Size * 1.6
	size = Vector3.new(
		math.max(size.X, 1.2),
		math.max(size.Y, 0.6),
		math.max(size.Z, 1.2)
	)
	collider.Size = size
	collider.CFrame = part.CFrame
	collider.Anchored = false
	collider.CanCollide = true
	collider.CanQuery = false
	collider.CanTouch = false
	collider.Transparency = 1
	collider.CastShadow = false
	collider.Parent = part

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = collider
	weld.Parent = collider

	return collider
end

local LIMB_COLLIDER_NAMES = { "RightHand", "LeftHand", "RightFoot", "LeftFoot" }

function RagdollService:ActivateRagdoll(character: Model)
	if activeRagdolls[character] then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not hrp then
		warn(`[RagdollService] cannot ragdoll {character.Name}: missing humanoid/hrp`)
		return
	end

	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return
	end

	print(`[RagdollService] activating manual ragdoll for {character.Name}`)

	local player = getPlayerFromCharacter(character)
	local animate = character:FindFirstChild("Animate") :: LocalScript?
	local originalAnimateEnabled = false
	if animate then
		originalAnimateEnabled = animate.Enabled
	end

	setServerOwnership(character)

	local joints: { StoredJoint } = {}
	local sockets: { BallSocketConstraint } = {}
	local colliders: { BasePart } = {}
	local limbCanCollide: { [BasePart]: boolean } = {}

	-- Build the ragdoll dynamically from the character's actual joints.
	for _, joint in ipairs(character:GetDescendants()) do
		if not joint:IsA("Motor6D") and not joint:IsA("AnimationConstraint") then
			continue
		end

		local limits = RAGDOLL_LIMITS[joint.Name] or DEFAULT_LIMITS

		local part0: BasePart?
		local part1: BasePart?
		local c0: CFrame
		local c1: CFrame

		if joint:IsA("Motor6D") then
			part0 = joint.Part0
			part1 = joint.Part1
			c0 = joint.C0
			c1 = joint.C1
		else
			local att0 = joint.Attachment0
			local att1 = joint.Attachment1
			if not att0 or not att1 then
				continue
			end
			part0 = att0.Parent :: BasePart?
			part1 = att1.Parent :: BasePart?
			c0 = att0.CFrame
			c1 = att1.CFrame
		end

		if not part0 or not part1 then
			continue
		end

		local stored: StoredJoint = {
			joint = joint,
			originalEnabled = joint.Enabled,
		}
		table.insert(joints, stored)

		storeOriginalCanCollide(limbCanCollide, part0)
		storeOriginalCanCollide(limbCanCollide, part1)
		part0.CanCollide = true
		part1.CanCollide = true

		joint.Enabled = false
		local socket = createBallSocket(joint.Name, part0, part1, c0, c1, limits)
		table.insert(sockets, socket)
	end

	if #joints == 0 then
		warn(`[RagdollService] no ragdoll joints found for {character.Name}`)
		returnOwnershipToPlayer(character, player)
		return
	end

	-- Add enlarged invisible colliders to hands and feet so they don't tunnel through
	-- terrain when the ragdoll is flung at high speed.
	for _, name in ipairs(LIMB_COLLIDER_NAMES) do
		local part = character:FindFirstChild(name) :: BasePart?
		if part then
			table.insert(colliders, createLimbCollider(part))
		end
	end

	-- Make sure every body part collides (hands, feet, head, limbs) so the ragdoll can
	-- bounce and tumble off the environment instead of ghosting through it.
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and child ~= hrp then
			storeOriginalCanCollide(limbCanCollide, child)
			child.CanCollide = true
		end
	end
	forceR6LimbCollision(character, humanoid, limbCanCollide)

	-- Keep the root part tied to the upper torso so the whole body is one physics chain.
	local upperTorso = character:FindFirstChild("UpperTorso") :: BasePart?
	local weld: Weld?
	if hrp and upperTorso then
		weld = Instance.new("Weld")
		weld.Part0 = hrp
		weld.Part1 = upperTorso
		weld.Parent = hrp
	end

	local originalBreakJointsOnDeath = humanoid.BreakJointsOnDeath
	humanoid.BreakJointsOnDeath = false

	local originalAutoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false

	local originalPlatformStand = humanoid.PlatformStand
	humanoid.PlatformStand = true

	local originalCanCollide = hrp.CanCollide
	hrp.CanCollide = false

	if animate then
		animate.Enabled = false
	end

	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
	humanoid:ChangeState(Enum.HumanoidStateType.Ragdoll)

	character:SetAttribute("Ragdolled", true)

	activeRagdolls[character] = {
		character = character,
		player = player,
		humanoid = humanoid,
		hrp = hrp,
		animate = animate,
		joints = joints,
		sockets = sockets,
		weld = weld,
		colliders = colliders,
		limbCanCollide = limbCanCollide,
		originalBreakJointsOnDeath = originalBreakJointsOnDeath,
		originalAutoRotate = originalAutoRotate,
		originalPlatformStand = originalPlatformStand,
		originalAnimateEnabled = originalAnimateEnabled,
		originalCanCollide = originalCanCollide,
		originalOwner = player,
	}

	self.Client.ActivateRagdoll:FireAll(character)
end

function RagdollService:DeactivateRagdoll(character: Model)
	local data = activeRagdolls[character]
	if not data then
		return
	end

	print(`[RagdollService] deactivating manual ragdoll for {character.Name}`)
	activeRagdolls[character] = nil

	for _, socket in ipairs(data.sockets) do
		pcall(function()
			local att0 = socket.Attachment0
			local att1 = socket.Attachment1
			socket:Destroy()
			if att0 then
				att0:Destroy()
			end
			if att1 then
				att1:Destroy()
			end
		end)
	end

	for _, stored in ipairs(data.joints) do
		pcall(function()
			stored.joint.Enabled = stored.originalEnabled
		end)
	end

	for limb, original in pairs(data.limbCanCollide) do
		pcall(function()
			limb.CanCollide = original
		end)
	end

	if data.weld then
		pcall(function()
			data.weld:Destroy()
		end)
	end

	for _, collider in ipairs(data.colliders) do
		pcall(function()
			collider:Destroy()
		end)
	end

	local humanoid = data.humanoid
	if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
		humanoid.BreakJointsOnDeath = data.originalBreakJointsOnDeath
		humanoid.AutoRotate = data.originalAutoRotate
		humanoid.PlatformStand = data.originalPlatformStand
		data.hrp.CanCollide = data.originalCanCollide
		-- Re-enable GettingUp, but do not force a state transition.
		-- Let Humanoid recover naturally to avoid double-recovery behavior.
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
	end

	local animate = data.animate
	if animate and animate.Parent then
		pcall(function()
			animate.Enabled = data.originalAnimateEnabled
		end)
	end

	returnOwnershipToPlayer(character, data.player)
	character:SetAttribute("Ragdolled", false)

	self.Client.DeactivateRagdoll:FireAll(character)
end

function RagdollService:KnitStart()
	local ok, err = pcall(function()
		-- Clean up if a ragdolled character is destroyed mid-ragdoll.
		local function onCharacterRemoving(character: Model)
			if activeRagdolls[character] then
				activeRagdolls[character] = nil
			end
		end

		workspace.DescendantRemoving:Connect(function(descendant)
			if descendant:IsA("Model") and activeRagdolls[descendant] then
				onCharacterRemoving(descendant)
			end
		end)
	end)

	if not ok then
		warn(`[RagdollService] KnitStart failed: {err}`)
	end
end

return RagdollService
