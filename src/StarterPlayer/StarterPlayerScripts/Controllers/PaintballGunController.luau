local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Component = require(ReplicatedStorage.Packages.Component)
local Input = require(ReplicatedStorage.Packages.Input)
local PreferredInput = require(ReplicatedStorage.Packages.Input).PreferredInput
local FastCast = require(ReplicatedStorage.Packages.FastCastRedux)

local PaintballConfig = require(ReplicatedStorage.Config.PaintballConfig)
local GamepadConfig = require(ReplicatedStorage.GamepadConfig)

local Client = Players.LocalPlayer

local CUSTOM_MOUSE_ICON = "rbxassetid://9524023207"
local DEFAULT_MOUSE_ICON = ""
local AIM_RETICLE_SIZE = 54
local RAGDOLL_RECOVERY_STABLE_TIME = 0.25
local UPRIGHT_DOT_THRESHOLD = 0.7

local function setBackpackVisible(visible: boolean)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, visible)
	end)
end

export type PaintballArgs = PaintballConfig.PaintballArgs
export type PaintballHitInfo = PaintballConfig.PaintballHitInfo
export type PaintballImpactInfo = PaintballConfig.PaintballImpactInfo

export type RemoteAimState = {
	current: Vector3,
	target: Vector3,
	equipped: boolean,
	receivedAt: number,
}

type TargetMotionState = {
	position: Vector3,
	sampledAt: number,
	velocity: Vector3,
}

-- Sleitnick Input gives us one object per input scheme; we only instantiate what we need.
type MouseInput = {
	LeftDown: { Connect: (self: any, callback: (processed: boolean) -> ()) -> RBXScriptConnection },
	LeftUp: { Connect: (self: any, callback: (processed: boolean) -> ()) -> RBXScriptConnection },
	Raycast: (self: MouseInput, params: RaycastParams, distance: number?) -> RaycastResult?,
	Project: (self: MouseInput, distance: number?) -> Vector3,
	Destroy: (self: MouseInput) -> (),
}

type GamepadInput = {
	ButtonDown: { Connect: (self: any, callback: (button: Enum.KeyCode, processed: boolean) -> ()) -> RBXScriptConnection },
	ButtonUp: { Connect: (self: any, callback: (button: Enum.KeyCode, processed: boolean) -> ()) -> RBXScriptConnection },
	Destroy: (self: GamepadInput) -> (),
}

type TouchInput = {
	TouchTap: { Connect: (self: any, callback: (positions: { Vector2 }, processed: boolean) -> ()) -> RBXScriptConnection },
	Destroy: (self: TouchInput) -> (),
}

-- Component instance type: the class adds these fields/methods to every tagged Tool.
export type PaintballGunComponentInstance = {
	Instance: Tool,
	Owner: Player?,
	Equipped: boolean,
	IsLocal: (self: PaintballGunComponentInstance) -> boolean,
	GetOwner: (self: PaintballGunComponentInstance) -> Player?,
	GetHandle: (self: PaintballGunComponentInstance) -> BasePart?,
	GetMuzzleCFrame: (self: PaintballGunComponentInstance) -> CFrame?,
}

-- Sleitnick Component: automatically starts/stops for every Tool tagged "Paintball".
local PaintballGunComponent = Component.new({
	Tag = "Paintball",
	Ancestors = { workspace, Players },
})

function PaintballGunComponent:Construct()
	self._trove = Trove.new()
	self.Owner = nil :: Player?
	self.Equipped = false
end

function PaintballGunComponent:Start()
	local instance = self.Instance
	if not instance:IsA("Tool") then
		warn(`[PaintballGunComponent] tagged instance {instance:GetFullName()} is not a Tool`)
		return
	end

	self:_resolveOwner()
	self:_watchParent()
	self:_watchEquipped()
end

function PaintballGunComponent:Stop()
	self._trove:Destroy()
	self.Owner = nil
	self.Equipped = false
end

-- Resolve who owns this tool based on its current parent (character or backpack).
function PaintballGunComponent:_resolveOwner()
	local inst = self.Instance
	local parent = inst.Parent
	local owner: Player? = nil

	if parent then
		if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
			owner = Players:GetPlayerFromCharacter(parent)
		elseif parent:IsA("Backpack") then
			owner = parent:FindFirstAncestorOfClass("Player")
		else
			local backpack = parent:FindFirstAncestorOfClass("Backpack")
			if backpack then
				owner = backpack:FindFirstAncestorOfClass("Player")
			end
		end
	end

	self.Owner = owner
end

function PaintballGunComponent:_watchParent()
	self._trove:Add(self.Instance.AncestryChanged:Connect(function()
		self:_resolveOwner()
	end))
end

function PaintballGunComponent:_watchEquipped()
	local tool = self.Instance :: Tool

	local function updateEquipped()
		self.Equipped = tool.Parent ~= nil
			and tool.Parent:IsA("Model")
			and tool.Parent:FindFirstChildOfClass("Humanoid") ~= nil
	end

	self._trove:Add(tool.Equipped:Connect(updateEquipped))
	self._trove:Add(tool.Unequipped:Connect(updateEquipped))
	updateEquipped()
end

function PaintballGunComponent:IsLocal(): boolean
	return self.Owner == Client
end

function PaintballGunComponent:GetOwner(): Player?
	return self.Owner
end

function PaintballGunComponent:GetHandle(): BasePart?
	return self.Instance:FindFirstChild("Handle") :: BasePart?
end

-- Muzzle CFrame: prefer a "Muzzle" Attachment, otherwise use the front of the Handle.
function PaintballGunComponent:GetMuzzleCFrame(): CFrame?
	local handle = self:GetHandle()
	if not handle then
		return nil
	end

	local nozzle = handle:FindFirstChild("Nozzle") :: Attachment?
	if nozzle then
		return nozzle.WorldCFrame
	end

	return handle.CFrame * CFrame.new(0, 0, -handle.Size.Z / 2)
end

local PaintballGunController = Knit.CreateController({
	Name = "PaintballGunController",
})

export type PaintballGunController = typeof(PaintballGunController)

function PaintballGunController:KnitInit() end

function PaintballGunController:KnitStart()
	self.service = Knit.GetService("PaintballGunService")
	self.localComponent = nil :: PaintballGunComponentInstance?
	self.localTrove = nil
	self.aimTrove = nil
	self.equipped = false
	self.firing = false
	self._autoFireConn = nil
	self.lastFire = 0
	self.cosmeticTemplates = {}
	self._lastAimSent = 0
	self._lastAimDir = nil :: Vector3?
	self.remoteAims = {} :: { [Player]: RemoteAimState }
	self._ragdolled = false
	self._recoveringFromRagdoll = false
	self._ragdollRecoveryToken = 0
	self._lastAutoAimTarget = nil :: Vector3?
	self._lastAutoAimModel = nil :: Model?
	self._smoothedAutoAimTarget = nil :: Vector3?
	self._autoFireLockModel = nil :: Model?
	self._autoFireLockSince = 0
	self._autoFireLockLastSeen = 0
	self._targetMotion = {} :: { [Model]: TargetMotionState }
	self._impactShakes = {} :: { [Model]: { token: number, lastOffset: CFrame } }

	self:_createLockMarker()

	-- One input object per scheme; they live as long as the controller does.
	self.mouse = Input.Mouse.new() :: MouseInput
	self.gamepad = Input.Gamepad.new() :: GamepadInput
	self.touch = Input.Touch.new() :: TouchInput

	self.caster = FastCast.new()
	self.caster.LengthChanged:Connect(function(cast, lastPoint, dir, len, velocity, cosmetic)
		self:_onFastCastLengthChanged(cast, lastPoint, dir, len, velocity, cosmetic)
	end)
	self.caster.RayHit:Connect(function(cast, result, velocity, cosmetic)
		self:_onFastCastHit(cast, result, velocity, cosmetic)
	end)
	self.caster.CastTerminating:Connect(function(cast)
		self:_onFastCastTerminated(cast)
	end)

	self:_watchComponents()
	self:_listenServer()
end

function PaintballGunController:_watchComponents()
	-- Watch for this player's paintball Tools being added/removed.
	PaintballGunComponent.Started:Connect(function(component: PaintballGunComponentInstance)
		if component:IsLocal() then
			self:_mountLocal(component)
		end
	end)

	PaintballGunComponent.Stopped:Connect(function(component: PaintballGunComponentInstance)
		if self.localComponent == component then
			self:_unmountLocal()
		end
	end)

	-- Mount immediately if a tagged Tool already exists (e.g. late controller load).
	for _, component in ipairs(PaintballGunComponent:GetAll() :: { PaintballGunComponentInstance }) do
		if component:IsLocal() then
			self:_mountLocal(component)
		end
	end
end

local function getJointBaseCFrame(joint: any): CFrame?
	if joint:IsA("Motor6D") then
		local part0 = joint.Part0
		if part0 then
			return part0.CFrame * joint.C0
		end
		return nil
	end
	if joint:IsA("AnimationConstraint") then
		local att0 = joint.Attachment0
		return att0 and att0.WorldCFrame
	end
	return nil
end

local function isAimJoint(instance: Instance?): boolean
	return instance ~= nil and (instance:IsA("Motor6D") or instance:IsA("AnimationConstraint"))
end

local function findBasePart(character: Model, names: { string }): BasePart?
	for _, name in ipairs(names) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return character.PrimaryPart or character:FindFirstChildWhichIsA("BasePart")
end

local function findAimJoint(character: Model, jointNames: { string }, parentNames: { string }): any?
	for _, parentName in ipairs(parentNames) do
		local parent = character:FindFirstChild(parentName)
		if parent then
			for _, jointName in ipairs(jointNames) do
				local joint = parent:FindFirstChild(jointName)
				if isAimJoint(joint) then
					return joint
				end
			end
		end
	end

	for _, jointName in ipairs(jointNames) do
		local joint = character:FindFirstChild(jointName, true)
		if isAimJoint(joint) then
			return joint
		end
	end

	return nil
end

local function getRigType(character: Model): Enum.HumanoidRigType?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.RigType or nil
end

local function getAimShoulderOffset(_rigType: Enum.HumanoidRigType?): CFrame
	return CFrame.Angles(math.pi / 2, 0, 0)
end

local function getJointAimPosition(joint: any?, fallbackPart: BasePart?): Vector3?
	if joint and joint:IsA("Motor6D") then
		local part0 = joint.Part0
		if part0 then
			return (part0.CFrame * joint.C0).Position
		end
	elseif joint and joint:IsA("AnimationConstraint") then
		local att0 = joint.Attachment0
		if att0 then
			return att0.WorldPosition
		end
	end
	return fallbackPart and fallbackPart.Position or nil
end

local function solveMotorTransform(motor: Motor6D, desiredPart1CFrame: CFrame): CFrame?
	local part0 = motor.Part0
	if not part0 then
		return nil
	end

	return motor.C0:Inverse() * part0.CFrame:Inverse() * desiredPart1CFrame * motor.C1
end

local function cframeWithYAxis(position: Vector3, yAxis: Vector3, rightHint: Vector3, fallbackHint: Vector3): CFrame
	local y = yAxis.Unit
	local x = rightHint - y * rightHint:Dot(y)
	if x.Magnitude < 1e-3 then
		x = fallbackHint - y * fallbackHint:Dot(y)
	end
	if x.Magnitude < 1e-3 then
		x = math.abs(y:Dot(Vector3.yAxis)) < 0.99 and y:Cross(Vector3.yAxis) or y:Cross(Vector3.xAxis)
	end

	x = x.Unit
	local z = x:Cross(y).Unit
	x = y:Cross(z).Unit
	return CFrame.fromMatrix(position, x, y, z)
end

local function applyR6AimToMotor(motor: any?, desiredPart1CFrame: CFrame)
	if motor and motor:IsA("Motor6D") then
		local transform = solveMotorTransform(motor, desiredPart1CFrame)
		if transform then
			motor.Transform = transform
		end
	end
end

local function resolveAimRig(character: Model): (any?, any?, BasePart?, Enum.HumanoidRigType?)
	local rigType = getRigType(character)

	if rigType == Enum.HumanoidRigType.R6 then
		return findAimJoint(character, { "Right Shoulder", "RightShoulder" }, { "Torso", "Right Arm" }),
			findAimJoint(character, { "Neck" }, { "Torso", "Head" }),
			findBasePart(character, { "Right Arm", "Torso", "HumanoidRootPart" }),
			rigType
	end

	return findAimJoint(character, { "RightShoulder", "Right Shoulder" }, { "RightUpperArm", "UpperTorso", "Torso", "Right Arm" }),
		findAimJoint(character, { "Neck" }, { "Head", "UpperTorso", "Torso" }),
		findBasePart(character, { "RightUpperArm", "RightHand", "Right Arm", "UpperTorso", "Torso", "HumanoidRootPart" }),
		rigType
end

local function applyAimToCharacter(character: Model, aimDir: Vector3)
	local shoulder, neck, _, rigType = resolveAimRig(character)
	if rigType == Enum.HumanoidRigType.R6 then
		if shoulder and shoulder:IsA("Motor6D") and shoulder.Part1 then
			local part0 = shoulder.Part0
			local part1 = shoulder.Part1
			local desiredArmCFrame = cframeWithYAxis(
				part1.Position,
				-aimDir,
				part0 and part0.CFrame.RightVector or Vector3.xAxis,
				part0 and part0.CFrame.LookVector or Vector3.zAxis
			)
			applyR6AimToMotor(shoulder, desiredArmCFrame)
		end

		if neck and neck:IsA("Motor6D") and neck.Part1 then
			local part0 = neck.Part0
			local part1 = neck.Part1
			local upHint = part0 and part0.CFrame.UpVector or Vector3.yAxis
			local desiredHeadCFrame = CFrame.lookAt(part1.Position, part1.Position + aimDir, upHint)
			applyR6AimToMotor(neck, desiredHeadCFrame)
		end
		return
	end

	if shoulder and (shoulder:IsA("Motor6D") or shoulder:IsA("AnimationConstraint")) then
		local shoulderCF = getJointBaseCFrame(shoulder)
		if shoulderCF then
			local localAim = shoulderCF:VectorToObjectSpace(aimDir)
			shoulder.Transform = CFrame.lookAt(Vector3.zero, localAim, shoulderCF.UpVector) * getAimShoulderOffset(rigType)
		end
	end

	if neck and (neck:IsA("Motor6D") or neck:IsA("AnimationConstraint")) then
		local neckCF = getJointBaseCFrame(neck)
		if neckCF then
			local localHeadAim = neckCF:VectorToObjectSpace(aimDir)
			neck.Transform = CFrame.lookAt(Vector3.zero, localHeadAim, neckCF.UpVector)
		end
	end
end

local function resetAimOnCharacter(character: Model)
	local shoulder, neck = resolveAimRig(character)
	if shoulder and (shoulder:IsA("Motor6D") or shoulder:IsA("AnimationConstraint")) then
		shoulder.Transform = CFrame.identity
	end

	if neck and (neck:IsA("Motor6D") or neck:IsA("AnimationConstraint")) then
		neck.Transform = CFrame.identity
	end
end

function PaintballGunController:_listenServer()
	-- Server validated and broadcasted a remote shot: render it (skip our own local prediction).
	self.service.PaintballFired:Connect(function(args: PaintballArgs)
		if args.sender == Client then
			return
		end
		self:_spawnProjectile(args, false)
	end)

	-- Server accepted a hit: show a impact splat for everyone.
	self.service.PaintballImpacted:Connect(function(info: PaintballImpactInfo)
		self:_spawnImpact(info)
		if info.target then
			self:_shakeImpactTarget(info.target)
		end
	end)

	-- Server relayed another player's aim packet: store the target so we can lerp to it every Stepped.
	self.service.AimUpdated:Connect(function(player: Player, packet: any)
		if player == Client or not player.Character then
			return
		end
		if typeof(packet) ~= "table" then
			return
		end

		local equipped = packet.equipped == true

		-- Unequip packets don't carry a direction; reset immediately.
		if not equipped then
			resetAimOnCharacter(player.Character)
			self.remoteAims[player] = nil
			return
		end

		local rawDir = packet.direction
		if typeof(rawDir) ~= "Vector3" then
			return
		end
		local direction = rawDir.Unit
		if direction.Magnitude < 1e-3 then
			return
		end

		local existing = self.remoteAims[player]
		if existing then
			existing.target = direction
			existing.equipped = equipped
			existing.receivedAt = os.clock()
		else
			self.remoteAims[player] = {
				current = direction,
				target = direction,
				equipped = equipped,
				receivedAt = os.clock(),
			}
		end
	end)

	RunService.Stepped:Connect(function(_time: number, dt: number)
		self:_updateRemoteAims(dt)
	end)
end

function PaintballGunController:_mountLocal(component: PaintballGunComponentInstance)
	self:_unmountLocal()

	self.localComponent = component
	self.localTrove = Trove.new()
	self.toolOriginalGrip = component.Instance.Grip
	self:_createAimReticle()

	local tool = component.Instance :: Tool

	local function updateEquipped()
		local wasEquipped = self.equipped
		self.equipped = (tool.Parent == Client.Character)
		if self.equipped ~= wasEquipped then
			self:_setMouseIcon(self.equipped)
			if self.equipped then
				if not self:_isPaintballDisabled() then
					self:_startArmAim()
					self:_observePreferredInput()
				end
			else
				self:_stopArmAim()
				self:_stopInputObserver()
				self:_replicateAim(Vector3.zero, false)
			end
		end
	end

	self.localTrove:Add(tool.Equipped:Connect(updateEquipped))
	self.localTrove:Add(tool.Unequipped:Connect(updateEquipped))
	updateEquipped()

	local char = Client.Character
	if char then
		self._ragdollConn = char:GetAttributeChangedSignal("Ragdolled"):Connect(function()
			self:_onRagdollChanged()
		end)
		self:_onRagdollChanged()
	end

	self.firing = false
	self.localTrove:Add(tool.Activated:Connect(function()
		if not self.equipped or self:_isPaintballDisabled() then
			return
		end
		self.firing = true
		self:_startAutoFire()
	end))
	self.localTrove:Add(tool.Deactivated:Connect(function()
		self.firing = false
	end))

	self:_bindInputs()

	setBackpackVisible(false)
end

function PaintballGunController:_unmountLocal()
	self._ragdollRecoveryToken += 1
	self._recoveringFromRagdoll = false
	self:_stopArmAim()
	self:_stopInputObserver()
	self:_replicateAim(Vector3.zero, false)
	self.firing = false
	if self._autoFireConn then
		self._autoFireConn:Disconnect()
		self._autoFireConn = nil
	end
	if self._ragdollConn then
		self._ragdollConn:Disconnect()
		self._ragdollConn = nil
	end
	if self.localTrove then
		self.localTrove:Destroy()
		self.localTrove = nil
	end
	self:_destroyAimReticle()
	self.localComponent = nil
	self.toolOriginalGrip = nil
	self.equipped = false
	self._lastAutoAimTarget = nil
	self._lastAutoAimModel = nil
	self._smoothedAutoAimTarget = nil
	self._autoFireLockModel = nil
	self._autoFireLockSince = 0
	self._autoFireLockLastSeen = 0
	table.clear(self._targetMotion)
	self:_setMouseIcon(false)
	setBackpackVisible(true)
end

function PaintballGunController:_setMouseIcon(equipped: boolean)
	local usesMouseCursor = PreferredInput.get() == Enum.PreferredInput.KeyboardAndMouse
	UserInputService.MouseIcon = if equipped and not self:_isPaintballDisabled() and usesMouseCursor then CUSTOM_MOUSE_ICON else DEFAULT_MOUSE_ICON
	self:_updateAimReticle()
end

function PaintballGunController:_updateInputLock()
	if not self.equipped or self:_isPaintballDisabled() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		self:_updateAimReticle()
		return
	end
	if PreferredInput.get() == Enum.PreferredInput.KeyboardAndMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	self:_setMouseIcon(self.equipped)
	self:_updateAimReticle()
end

function PaintballGunController:_observePreferredInput()
	self:_stopInputObserver()
	self._inputObserver = PreferredInput.observe(function()
		self:_updateInputLock()
	end)
end

function PaintballGunController:_stopInputObserver()
	if self._inputObserver then
		pcall(self._inputObserver)
		self._inputObserver = nil
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	self:_updateAimReticle()
end

-- Hook up mouse, gamepad, and touch fire inputs. The actual fire loop is driven by
-- Tool.Activated/Deactivated so holding the button fires continuously; we just track
-- the held state here for input schemes that don't map cleanly to Tool events.
function PaintballGunController:_bindInputs()
	self.localTrove:Add(self.mouse.LeftDown:Connect(function(processed: boolean)
		if not processed and self.equipped and not self:_isPaintballDisabled() then
			self.firing = true
			self:_startAutoFire()
		end
	end))
	self.localTrove:Add(self.mouse.LeftUp:Connect(function(_processed: boolean)
		self.firing = false
	end))

	self.localTrove:Add(self.gamepad.ButtonDown:Connect(function(button: Enum.KeyCode, processed: boolean)
		if button == GamepadConfig.Keys.PaintballFire and not processed and self.equipped and not self:_isPaintballDisabled() then
			self.firing = true
			self:_startAutoFire()
		end
	end))
	self.localTrove:Add(self.gamepad.ButtonUp:Connect(function(button: Enum.KeyCode, _processed: boolean)
		if button == GamepadConfig.Keys.PaintballFire then
			self.firing = false
		end
	end))

	self.localTrove:Add(self.touch.TouchTap:Connect(function(_positions: { Vector2 }, processed: boolean)
		if not processed and self.equipped and not self:_isPaintballDisabled() then
			self:_tryFire()
		end
	end))
end

function PaintballGunController:_startAutoFire()
	if self._autoFireConn then
		return
	end
	self._autoFireConn = RunService.Heartbeat:Connect(function()
		if not self.firing or not self.equipped or not self.localComponent then
			if self._autoFireConn then
				self._autoFireConn:Disconnect()
				self._autoFireConn = nil
			end
			return
		end
		self:_tryFire()
	end)
end

local BODY_ROTATION_THRESHOLD = math.rad(15)
local HRP_ROTATION_LERP = 18
local HRP_MOVEMENT_LERP = 8

local PAINTBALL_COLORS: { [string]: Color3 } = {
	Blue = Color3.fromRGB(0, 100, 255),
	Red = Color3.fromRGB(255, 50, 50),
	Green = Color3.fromRGB(50, 255, 50),
	Yellow = Color3.fromRGB(255, 255, 0),
}

local SPLAT_IMAGES = {
	"rbxassetid://93227468890011",
	"rbxassetid://123703338284102",
}

local IMPACT_SHAKE_DURATION = 0.18
local IMPACT_SHAKE_MAGNITUDE = 0.45
local IMPACT_SHAKE_ROLL = math.rad(2.5)

local function colorFromAttribute(value: any): Color3
	if typeof(value) == "Color3" then
		return value
	end
	if typeof(value) == "string" then
		return PAINTBALL_COLORS[value] or PaintballConfig.ProjectileColor
	end
	return PaintballConfig.ProjectileColor
end

function PaintballGunController:_startArmAim()
	if self.aimTrove then
		return
	end
	if self:_isPaintballDisabled() then
		return
	end

	local char = Client.Character
	if not char then
		return
	end

	local shoulder, neck, aimPart, rigType = resolveAimRig(char)
	if not shoulder then
		return
	end

	self.armShoulder = shoulder
	self.armOriginalTransform = shoulder.Transform
	self.neck = neck
	self.neckOriginalTransform = neck and neck.Transform
	self.armAimPart = aimPart
	self.rigType = rigType

	self.hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	self.humanoid = char:FindFirstChildOfClass("Humanoid")
	if self.humanoid then
		self.autoRotateOriginal = self.humanoid.AutoRotate
		self.humanoid.AutoRotate = false
	end

	if self.hrp then
		local _, yaw = self.hrp.CFrame:ToOrientation()
		self.currentHrpYaw = yaw
		self.targetHrpYaw = yaw

		local gyro = Instance.new("BodyGyro")
		gyro.Name = "PaintballAimGyro"
		gyro.P = 5000
		gyro.D = 50
		gyro.MaxTorque = Vector3.new(0, 50000, 0)
		gyro.CFrame = self.hrp.CFrame
		gyro.Parent = self.hrp
		self._aimGyro = gyro
	end

	self.aimTrove = Trove.new()
	self.aimTrove:Add(RunService.Stepped:Connect(function(_time: number, dt: number)
		self:_updateArmAim(dt)
	end))

	self.aimTrove:Add(function()
		if self.armShoulder and self.armOriginalTransform then
			self.armShoulder.Transform = self.armOriginalTransform
		end
		self.armShoulder = nil
		self.armOriginalTransform = nil
		self.armAimPart = nil
		self.rigType = nil

		if self.neck and self.neckOriginalTransform then
			self.neck.Transform = self.neckOriginalTransform
		end
		self.neck = nil
		self.neckOriginalTransform = nil

		if self._aimGyro then
			self._aimGyro:Destroy()
			self._aimGyro = nil
		end
		if self.humanoid and self.autoRotateOriginal ~= nil then
			self.humanoid.AutoRotate = self.autoRotateOriginal
		end
		self.autoRotateOriginal = nil
		self.humanoid = nil
		self.hrp = nil
		self.currentHrpYaw = nil
		self.targetHrpYaw = nil
	end)
end

function PaintballGunController:_stopArmAim()
	if self.lockHighlight then
		self.lockHighlight.Enabled = false
	end
	if self.aimTrove then
		self.aimTrove:Destroy()
		self.aimTrove = nil
	end
	self._lastAutoAimTarget = nil
	self._lastAutoAimModel = nil
	self._smoothedAutoAimTarget = nil
	self._autoFireLockModel = nil
	self._autoFireLockSince = 0
	self._autoFireLockLastSeen = 0
end

function PaintballGunController:_createLockMarker()
	local highlight = Instance.new("Highlight")
	highlight.Name = "PaintballLockHighlight"
	highlight.FillColor = Color3.fromRGB(255, 50, 50)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = Client:WaitForChild("PlayerGui")

	self.lockHighlight = highlight
end

function PaintballGunController:_createAimReticle()
	if self.aimReticleGui then
		return
	end

	local playerGui = Client:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "PaintballAimReticle"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.Enabled = false
	gui.Parent = playerGui

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.Image = CUSTOM_MOUSE_ICON
	icon.ImageTransparency = 0.05
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromOffset(AIM_RETICLE_SIZE, AIM_RETICLE_SIZE)
	icon.Parent = gui

	self.aimReticleGui = gui
end

function PaintballGunController:_destroyAimReticle()
	if self.aimReticleGui then
		self.aimReticleGui:Destroy()
		self.aimReticleGui = nil
	end
end

function PaintballGunController:_updateAimReticle()
	if not self.aimReticleGui then
		return
	end

	self.aimReticleGui.Enabled = self.equipped
		and not self:_isPaintballDisabled()
		and PreferredInput.get() ~= Enum.PreferredInput.KeyboardAndMouse
end

function PaintballGunController:_updateLockMarker()
	if not self.lockHighlight then
		return
	end

	local model = self._lastAutoAimModel
	if not model or not model.Parent then
		self.lockHighlight.Enabled = false
		return
	end

	if self.lockHighlight.Adornee ~= model then
		self.lockHighlight.Adornee = model
	end
	self.lockHighlight.Enabled = true
end

function PaintballGunController:_shakeImpactTarget(target: Model)
	if not target or not target.Parent then
		return
	end

	local root = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart")
	if not root then
		return
	end

	local existing = self._impactShakes[target]
	local token = (existing and existing.token or 0) + 1
	self._impactShakes[target] = {
		token = token,
		lastOffset = CFrame.identity,
	}

	task.spawn(function()
		local startedAt = os.clock()
		while target.Parent and self._impactShakes[target] and self._impactShakes[target].token == token do
			local elapsed = os.clock() - startedAt
			local progress = math.clamp(elapsed / IMPACT_SHAKE_DURATION, 0, 1)
			if progress >= 1 then
				break
			end

			local state = self._impactShakes[target]
			local currentPivot = target:GetPivot()
			local basePivot = currentPivot * state.lastOffset:Inverse()
			local falloff = 1 - progress
			local offset = Vector3.new(
				(math.random() * 2 - 1) * IMPACT_SHAKE_MAGNITUDE * falloff,
				(math.random() * 2 - 1) * IMPACT_SHAKE_MAGNITUDE * 0.45 * falloff,
				(math.random() * 2 - 1) * IMPACT_SHAKE_MAGNITUDE * falloff
			)
			local angle = (math.random() * 2 - 1) * IMPACT_SHAKE_ROLL * falloff
			local offsetCFrame = CFrame.new(offset) * CFrame.Angles(0, 0, angle)

			target:PivotTo(basePivot * offsetCFrame)
			state.lastOffset = offsetCFrame
			RunService.RenderStepped:Wait()
		end

		local state = self._impactShakes[target]
		if target.Parent and state and state.token == token then
			target:PivotTo(target:GetPivot() * state.lastOffset:Inverse())
			self._impactShakes[target] = nil
		end
	end)
end

function PaintballGunController:_updateCharacterOrientation(aimDir: Vector3, dt: number)
	if not self.hrp or not self._aimGyro or not self.humanoid then
		return
	end

	local flatAim = Vector3.new(aimDir.X, 0, aimDir.Z)
	if flatAim.Magnitude < 1e-3 then
		return
	end
	flatAim = flatAim.Unit

	local moveDir = self.humanoid.MoveDirection
	local flatMove = Vector3.new(moveDir.X, 0, moveDir.Z)
	local isMoving = flatMove.Magnitude > 0.1

	local aimYaw = math.atan2(flatAim.X, flatAim.Z) + math.pi

	local useMovementDirection = false
	local targetDir = flatAim
	local targetYaw = aimYaw

	-- While moving and the aim is within the aim cone (±15° from MoveDirection),
	-- slowly center the body toward where the player is walking. Outside that cone, aim wins.
	if isMoving then
		flatMove = flatMove.Unit
		local aimMoveAngle = math.abs(math.atan2(flatAim:Cross(flatMove).Y, flatAim:Dot(flatMove)))
		if aimMoveAngle < BODY_ROTATION_THRESHOLD then
			useMovementDirection = true
			targetDir = flatMove
			targetYaw = math.atan2(flatMove.X, flatMove.Z) + math.pi
		end
	end

	self.targetHrpYaw = targetYaw

	local diff = self.targetHrpYaw - self.currentHrpYaw
	while diff > math.pi do
		diff -= math.pi * 2
	end
	while diff < -math.pi do
		diff += math.pi * 2
	end

	local look = self.hrp.CFrame.LookVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	if flatForward.Magnitude < 1e-3 then
		flatForward = Vector3.new(0, 0, 1)
	else
		flatForward = flatForward.Unit
	end
	local signedAngle = math.atan2(flatForward:Cross(targetDir).Y, flatForward:Dot(targetDir))
	local absAngle = math.abs(signedAngle)
	local overshoot = math.clamp((absAngle - BODY_ROTATION_THRESHOLD) / math.rad(20), 0, 1)
	local lerp = if useMovementDirection then HRP_MOVEMENT_LERP else HRP_ROTATION_LERP
	local alpha = 1 - math.exp(-lerp * overshoot * dt)

	self.currentHrpYaw += diff * alpha
	self._aimGyro.CFrame = CFrame.Angles(0, self.currentHrpYaw, 0)
end

function PaintballGunController:_onRagdollChanged()
	local char = Client.Character
	local isRagdolled = char and char:GetAttribute("Ragdolled") == true
	if isRagdolled == self._ragdolled then
		return
	end

	self._ragdolled = isRagdolled
	if isRagdolled then
		self._ragdollRecoveryToken += 1
		self._recoveringFromRagdoll = false
		self.firing = false
		self:_stopArmAim()
		self:_stopInputObserver()
		self:_setMouseIcon(false)
	else
		self:_beginRagdollRecovery()
	end
end

function PaintballGunController:_isPaintballDisabled(): boolean
	return self._ragdolled == true or self._recoveringFromRagdoll == true
end

function PaintballGunController:_isCharacterRecovered(): boolean
	local char = Client.Character
	if not char then
		return false
	end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not hrp then
		return false
	end
	if char:GetAttribute("Ragdolled") == true or humanoid.PlatformStand then
		return false
	end

	local state = humanoid:GetState()
	if
		state == Enum.HumanoidStateType.Ragdoll
		or state == Enum.HumanoidStateType.FallingDown
		or state == Enum.HumanoidStateType.GettingUp
		or state == Enum.HumanoidStateType.Physics
		or state == Enum.HumanoidStateType.Freefall
	then
		return false
	end
	if humanoid.FloorMaterial == Enum.Material.Air then
		return false
	end

	return hrp.CFrame.UpVector:Dot(Vector3.yAxis) >= UPRIGHT_DOT_THRESHOLD
end

function PaintballGunController:_beginRagdollRecovery()
	self._ragdollRecoveryToken += 1
	local token = self._ragdollRecoveryToken
	self._recoveringFromRagdoll = true
	self.firing = false
	self:_stopArmAim()
	self:_stopInputObserver()
	self:_setMouseIcon(false)

	task.spawn(function()
		local stableSince: number? = nil
		while token == self._ragdollRecoveryToken do
			if self._ragdolled then
				return
			end
			if self:_isCharacterRecovered() then
				stableSince = stableSince or os.clock()
				if os.clock() - stableSince >= RAGDOLL_RECOVERY_STABLE_TIME then
					break
				end
			else
				stableSince = nil
			end
			task.wait()
		end

		if token ~= self._ragdollRecoveryToken or self._ragdolled then
			return
		end

		self._recoveringFromRagdoll = false
		if self.equipped then
			self:_startArmAim()
			self:_setMouseIcon(true)
			self:_observePreferredInput()
		else
			self:_setMouseIcon(false)
		end
	end)
end

function PaintballGunController:_updateArmAim(dt: number)
	if not self.equipped or not self.armShoulder or self:_isPaintballDisabled() then
		return
	end

	local shoulder = self.armShoulder

	local aimPoint = self:_getAimPoint(dt)
	local shoulderPos = getJointAimPosition(shoulder, self.armAimPart)
	if not shoulderPos then
		return
	end
	local aimDir = (aimPoint - shoulderPos).Unit

	self:_updateCharacterOrientation(aimDir, dt)

	local char = Client.Character
	if char then
		applyAimToCharacter(char, aimDir)
	end
	self:_updateLockMarker()

	if
		self:_shouldAutoFireOnLock()
		and self._lastAutoAimModel
		and self:_isAutoFireLockStable(self._lastAutoAimModel)
		and self:_canAutoFireAt(self._lastAutoAimTarget :: Vector3, self._lastAutoAimModel)
	then
		self:_tryFire()
	end

	self:_replicateAim(aimDir, true)

	local tool = self.localComponent and self.localComponent.Instance :: Tool
	if tool and self.toolOriginalGrip then
		tool.Grip = self.toolOriginalGrip * CFrame.Angles(math.rad(8), math.rad(-4), 0)
	end
end

function PaintballGunController:_replicateAim(aimDir: Vector3, equipped: boolean)
	local now = os.clock()
	if now - self._lastAimSent < 0.15 then
		return
	end
	self._lastAimSent = now
	self._lastAimDir = if equipped then aimDir else nil

	local packet = {
		direction = { x = aimDir.X, y = aimDir.Y, z = aimDir.Z },
		equipped = equipped,
	}
	self.service.AimUpdated:Fire(HttpService:JSONEncode(packet))
end

local function slerpDirection(from: Vector3, to: Vector3, t: number): Vector3
	local dot = math.clamp(from:Dot(to), -1, 1)
	if dot > 0.9999 then
		return to
	end
	local theta = math.acos(dot) * t
	local rel = (to - from * dot).Unit
	return from * math.cos(theta) + rel * math.sin(theta)
end

function PaintballGunController:_updateRemoteAims(dt: number)
	local now = os.clock()
	for player, state in pairs(self.remoteAims) do
		local character = player.Character
		if not player.Parent or not character or (now - state.receivedAt) > 0.6 then
			if character then
				resetAimOnCharacter(character)
			end
			self.remoteAims[player] = nil
			continue
		end

		if not state.equipped then
			resetAimOnCharacter(character)
			self.remoteAims[player] = nil
			continue
		end

		-- Smoothly interpolate the aim direction toward the latest server target.
		state.current = slerpDirection(state.current, state.target, math.min(dt * 15, 1))
		applyAimToCharacter(character, state.current)
	end
end

function PaintballGunController:_getAimRay(): Ray?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end

	-- Mouse players aim with the cursor; gamepad/touch players aim from the screen center.
	if PreferredInput.get() == Enum.PreferredInput.KeyboardAndMouse then
		return self.mouse:GetRay()
	end

	local viewport = camera.ViewportSize
	return camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
end

function PaintballGunController:_shouldAutoFireOnLock(): boolean
	if PaintballConfig.AutoFireOnLock == false then
		return false
	end

	local preferred = PreferredInput.get()
	if preferred == Enum.PreferredInput.KeyboardAndMouse then
		if PaintballConfig.AutoFireOnLockKeyboardMouse ~= nil then
			return PaintballConfig.AutoFireOnLockKeyboardMouse == true
		end
	elseif preferred == Enum.PreferredInput.Gamepad then
		if PaintballConfig.AutoFireOnLockGamepad ~= nil then
			return PaintballConfig.AutoFireOnLockGamepad == true
		end
	elseif preferred == Enum.PreferredInput.Touch then
		if PaintballConfig.AutoFireOnLockTouch ~= nil then
			return PaintballConfig.AutoFireOnLockTouch == true
		end
	end

	return true
end

function PaintballGunController:_updateAutoFireLockState(currentModel: Model?)
	local now = os.clock()
	if currentModel and currentModel.Parent then
		if self._autoFireLockModel ~= currentModel then
			self._autoFireLockModel = currentModel
			self._autoFireLockSince = now
		end
		self._autoFireLockLastSeen = now
		return
	end

	if self._autoFireLockModel then
		local grace = PaintballConfig.AutoFireLockReleaseGrace or 0
		if (now - self._autoFireLockLastSeen) > grace then
			self._autoFireLockModel = nil
			self._autoFireLockSince = 0
			self._autoFireLockLastSeen = 0
		end
	end
end

function PaintballGunController:_isAutoFireLockStable(model: Model): boolean
	if not model or self._autoFireLockModel ~= model then
		return false
	end
	local hold = PaintballConfig.AutoFireLockAcquireTime or 0
	return (os.clock() - self._autoFireLockSince) >= hold
end

function PaintballGunController:_canAutoFireAt(targetPos: Vector3, targetModel: Model): boolean
	local component = self.localComponent
	if not component then
		return false
	end
	local muzzleCF = component:GetMuzzleCFrame()
	if not muzzleCF then
		return false
	end

	local origin = muzzleCF.Position
	local direction = targetPos - origin
	local dist = direction.Magnitude
	if dist < 1 or dist > PaintballConfig.AutoAimMaxDistance then
		return false
	end

	if PaintballConfig.AutoFireRequiresClearShot == false then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local filter: { Instance } = { targetModel }
	local char = Client.Character
	if char then
		table.insert(filter, char)
	end
	params.FilterDescendantsInstances = filter

	local result = Workspace:Raycast(origin, direction, params)
	if not result then
		return true
	end
	return result.Instance:IsDescendantOf(targetModel) == true
end

function PaintballGunController:_getAimPoint(dt: number?): Vector3
	local ray = self:_getAimRay()
	if ray then
		local prevModel = self._lastAutoAimModel
		local autoTarget, autoModel = self:_getAutoAimTarget(ray.Origin, ray.Direction)
		self._lastAutoAimTarget = autoTarget
		self._lastAutoAimModel = autoModel
		self:_updateAutoFireLockState(autoModel)
		if autoTarget then
			local lerpRate = PaintballConfig.AutoAimTargetLerp or 12
			local stepDt = math.max(0, dt or (1 / 60))
			if autoModel ~= prevModel or not self._smoothedAutoAimTarget then
				self._smoothedAutoAimTarget = autoTarget
			else
				local alpha = 1 - math.exp(-lerpRate * stepDt)
				self._smoothedAutoAimTarget = self._smoothedAutoAimTarget:Lerp(autoTarget, math.clamp(alpha, 0, 1))
			end
			return self._smoothedAutoAimTarget
		end

		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		local char = Client.Character
		if char then
			params.FilterDescendantsInstances = { char }
		end
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
		if result then
			self._smoothedAutoAimTarget = nil
			return result.Position
		end
		self._smoothedAutoAimTarget = nil
		return ray.Origin + ray.Direction * 1000
	end

	self._lastAutoAimTarget = nil
	self._lastAutoAimModel = nil
	self._smoothedAutoAimTarget = nil
	self:_updateAutoFireLockState(nil)

	-- Fallback for the rare case there is no camera.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local char = Client.Character
	if char then
		params.FilterDescendantsInstances = { char }
	end
	local result = self.mouse:Raycast(params, 1000)
	return if result then result.Position else self.mouse:Project(1000)
end

function PaintballGunController:_tryFire()
	if self:_isPaintballDisabled() then
		return
	end
	local component = self.localComponent
	if not component then
		return
	end

	local now = os.clock()
	if now - self.lastFire < PaintballConfig.FireRate then
		return
	end
	self.lastFire = now

	local muzzleCF = component:GetMuzzleCFrame()
	if not muzzleCF then
		return
	end

	local handle = component:GetHandle()
	local nozzle = handle and handle:FindFirstChild("Nozzle") :: Attachment?
	local smoke = nozzle and nozzle:FindFirstChild("Smoke") :: ParticleEmitter?
	if smoke then
		smoke:Emit(1)
	end

	local fireSound = handle and handle:FindFirstChild("Fire") :: Sound?
	if fireSound then
		fireSound:Play()
	end

	local direction = self:_getAimDirection(muzzleCF.Position)
	if not direction then
		return
	end

	local toolColor = colorFromAttribute(component.Instance:GetAttribute("Color"))

	local args: PaintballArgs = {
		origin = muzzleCF.Position,
		direction = direction,
		t0 = workspace:GetServerTimeNow(),
		shotId = `{Client.UserId}_{now}`,
		sender = nil,
		color = toolColor,
	}

	-- Predict the shot locally, then tell the server to validate and echo it.
	self:_spawnProjectile(args, true)
	self.service.PaintballFired:Fire(args)
end

function PaintballGunController:_getAimDirection(origin: Vector3): Vector3?
	local target = self:_getAimPoint()
	local direction = target - origin
	if direction.Magnitude < 1e-3 then
		direction = Workspace.CurrentCamera.CFrame.LookVector
	end
	return direction.Unit
end

function PaintballGunController:_estimateTargetVelocity(target: Model): Vector3
	local now = os.clock()
	-- The boss root is anchored and moved with CFrames, so AssemblyLinearVelocity remains zero.
	-- Model pivot motion gives us the replicated movement without torso animation bobbing.
	local position = target:GetPivot().Position
	local state = self._targetMotion[target]
	if not state then
		self._targetMotion[target] = {
			position = position,
			sampledAt = now,
			velocity = Vector3.zero,
		}
		return Vector3.zero
	end

	local elapsed = now - state.sampledAt
	local displacement = position - state.position
	if elapsed > 0 and displacement.Magnitude >= 0.01 then
		local measured = displacement / elapsed
		local maxSpeed = PaintballConfig.AutoAimMaxTargetSpeed or 60
		if measured.Magnitude > maxSpeed then
			measured = measured.Unit * maxSpeed
		end
		local response = PaintballConfig.AutoAimVelocityResponse or 14
		local alpha = 1 - math.exp(-response * elapsed)
		state.velocity = state.velocity:Lerp(measured, math.clamp(alpha, 0, 1))
		state.position = position
		state.sampledAt = now
	elseif elapsed >= (PaintballConfig.AutoAimVelocityMemory or 0.18) then
		state.velocity = Vector3.zero
		state.position = position
		state.sampledAt = now
	end

	return state.velocity
end

function PaintballGunController:_predictTargetPosition(origin: Vector3, targetPos: Vector3, target: Model): Vector3
	if PaintballConfig.AutoAimPredictionEnabled == false then
		return targetPos
	end

	local projectileSpeed = PaintballConfig.ProjectileSpeed
	if projectileSpeed <= 0 then
		return targetPos
	end

	local velocity = self:_estimateTargetVelocity(target)
	if velocity.Magnitude < 0.05 then
		return targetPos
	end

	-- Solve |offset + velocity * t| = projectileSpeed * t and use the earliest
	-- positive intercept. Paintballs have no acceleration, so no gravity term is needed.
	local offset = targetPos - origin
	local a = velocity:Dot(velocity) - projectileSpeed * projectileSpeed
	local b = 2 * offset:Dot(velocity)
	local c = offset:Dot(offset)
	local interceptTime: number? = nil

	if math.abs(a) < 1e-4 then
		if math.abs(b) > 1e-4 then
			local t = -c / b
			if t > 0 then
				interceptTime = t
			end
		end
	else
		local discriminant = b * b - 4 * a * c
		if discriminant >= 0 then
			local root = math.sqrt(discriminant)
			local t1 = (-b - root) / (2 * a)
			local t2 = (-b + root) / (2 * a)
			if t1 > 0 and t2 > 0 then
				interceptTime = math.min(t1, t2)
			elseif t1 > 0 then
				interceptTime = t1
			elseif t2 > 0 then
				interceptTime = t2
			end
		end
	end

	local leadTime = interceptTime or (offset.Magnitude / projectileSpeed)
	leadTime = math.min(leadTime, PaintballConfig.AutoAimMaxLeadTime or 1.5)
	return targetPos + velocity * leadTime
end

-- Target-assist: if a boss/minion is within AutoAimAngle of the view direction, return its aim point and model.
function PaintballGunController:_getAutoAimTarget(origin: Vector3, lookDir: Vector3): (Vector3?, Model?)
	local maxAngle = math.rad(PaintballConfig.AutoAimAngle or 15)
	local maxDist = PaintballConfig.AutoAimMaxDistance or 400
	local requireLos = PaintballConfig.AutoAimRequiresLineOfSight ~= false

	local bestTarget: Vector3? = nil
	local bestModel: Model? = nil
	local bestAngle = math.huge
	local char = Client.Character

	for _, boss in ipairs(CollectionService:GetTagged("Boss")) do
		if not boss or not boss.Parent then
			continue
		end

		local targetPos = self:_getBossAimPoint(boss)
		local toTarget = targetPos - origin
		local dist = toTarget.Magnitude
		if dist < 1 or dist > maxDist then
			continue
		end

		local angle = math.acos(math.clamp(lookDir:Dot(toTarget.Unit), -1, 1))
		if angle >= maxAngle or angle >= bestAngle then
			continue
		end

		-- Only lock on if the target is actually visible from the camera.
		local camera = Workspace.CurrentCamera
		local _, onScreen = camera:WorldToViewportPoint(targetPos)
		if not onScreen then
			continue
		end

		if requireLos then
			local filter: { Instance } = { boss }
			if char then
				table.insert(filter, char)
			end
			local obscuring = camera:GetPartsObscuringTarget({ targetPos }, filter)
			if #obscuring > 0 then
				continue
			end
		end

		bestAngle = angle
		bestTarget = self:_predictTargetPosition(origin, targetPos, boss)
		bestModel = boss
	end

	-- Stickiness: keep the current locked target unless it leaves a wider cone,
	-- so the lock doesn't bounce between two close targets every frame.
	local stickyModel = self._lastAutoAimModel
	if stickyModel and stickyModel.Parent and bestModel and bestModel ~= stickyModel then
		local stickyPos = self:_getBossAimPoint(stickyModel)
		local toSticky = stickyPos - origin
		local stickyDist = toSticky.Magnitude
		local stickyAngle = math.acos(math.clamp(lookDir:Dot(toSticky.Unit), -1, 1))
		local stickyMaxAngle = maxAngle * (PaintballConfig.AutoAimStickiness or 1.5)
		if stickyDist >= 1 and stickyDist <= maxDist and stickyAngle < stickyMaxAngle then
			local cam = Workspace.CurrentCamera
			if cam then
				local _, onScreen = cam:WorldToViewportPoint(stickyPos)
				if onScreen then
					local keep = true
					if requireLos then
						local filter: { Instance } = { stickyModel }
						if char then
							table.insert(filter, char)
						end
						local obscuring = cam:GetPartsObscuringTarget({ stickyPos }, filter)
						keep = #obscuring == 0
					end
					if keep then
						return self:_predictTargetPosition(origin, stickyPos, stickyModel), stickyModel
					end
				end
			end
		end
	end

	return bestTarget, bestModel
end

function PaintballGunController:_getBossAimPoint(boss: Model): Vector3
	local humanoid = boss:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
		local torso = boss:FindFirstChild("Torso")
		if torso and torso:IsA("BasePart") then
			return torso.Position
		end
		local head = boss:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head.Position
		end
	end

	-- Humanoid / R15-style characters: aim at the upper body so the marker sits
	-- on the model instead of under it.
	local upperTorso = boss:FindFirstChild("UpperTorso")
	if upperTorso and upperTorso:IsA("BasePart") then
		return upperTorso.Position
	end
	local lowerTorso = boss:FindFirstChild("LowerTorso")
	if lowerTorso and lowerTorso:IsA("BasePart") then
		return lowerTorso.Position
	end
	local head = boss:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local torso = boss:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		return torso.Position
	end

	-- Non-humanoid bosses (carts, props, etc.): use the top-center of the
	-- model's bounding box so the marker isn't clipped under the base.
	local cf, size = boss:GetBoundingBox()
	return (cf * CFrame.new(0, size.Y * 0.5, 0)).Position
end

function PaintballGunController:_getCosmeticBulletTemplate(color: Color3): BasePart
	if not self.cosmeticTemplates[color] then
		local part = Instance.new("Part")
		part.Name = "PaintballProjectile"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.one * (PaintballConfig.ProjectileRadius * 2)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		self.cosmeticTemplates[color] = part
	end
	return self.cosmeticTemplates[color]
end

function PaintballGunController:_onFastCastLengthChanged(_cast, lastPoint: Vector3, dir: Vector3, _len: number, _velocity: Vector3, cosmetic: Instance?)
	if cosmetic and cosmetic:IsA("BasePart") then
		cosmetic.CFrame = CFrame.new(lastPoint, lastPoint + dir)
	end
end

function PaintballGunController:_onFastCastHit(cast, result: RaycastResult, _velocity: Vector3, cosmetic: Instance?)
	local data = cast.UserData
	if cosmetic then
		cosmetic:Destroy()
	end

	if result then
		local info: PaintballImpactInfo = {
			position = result.Position,
			normal = result.Normal,
			target = result.Instance:FindFirstAncestorOfClass("Model"),
			hitPart = result.Instance,
			color = data.args.color,
		}
		self:_spawnImpact(info)

		if data.isLocalShot then
			self:_onLocalHit(data.args, result)
		end
	end
end

function PaintballGunController:_onFastCastTerminated(cast)
	local cosmetic = cast.RayInfo and cast.RayInfo.CosmeticBulletObject
	if cosmetic then
		cosmetic:Destroy()
	end
end

-- Simulate a flying paintball with FastCast.
function PaintballGunController:_spawnProjectile(args: PaintballArgs, isLocalShot: boolean)
	local origin = args.origin
	local direction = args.direction
	if typeof(direction) ~= "Vector3" then
		return
	end
	direction = direction.Unit

	local container = Workspace:FindFirstChild("PaintballProjectiles")
	if not container then
		container = Instance.new("Folder")
		container.Name = "PaintballProjectiles"
		container.Parent = Workspace
	end

	local ignoreList: { Instance } = { container }
	if isLocalShot then
		local char = Client.Character
		if char then
			table.insert(ignoreList, char)
		end
	elseif args.sender and args.sender.Character then
		table.insert(ignoreList, args.sender.Character)
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams.FilterDescendantsInstances = ignoreList

	local behavior = FastCast.newBehavior()
	behavior.RaycastParams = rayParams
	behavior.MaxDistance = PaintballConfig.ProjectileMaxDistance
	behavior.Acceleration = Vector3.new()
	behavior.CosmeticBulletTemplate = self:_getCosmeticBulletTemplate(args.color or PaintballConfig.ProjectileColor)
	behavior.CosmeticBulletContainer = container

	local cast = self.caster:Fire(origin, direction * PaintballConfig.ProjectileMaxDistance, PaintballConfig.ProjectileSpeed, behavior)
	cast.UserData = { args = args, isLocalShot = isLocalShot }
end

function PaintballGunController:_onLocalHit(args: PaintballArgs, raycastResult: RaycastResult)
	local hitPart = raycastResult.Instance
	local hitInfo: PaintballHitInfo = {
		shotId = args.shotId,
		hitPart = hitPart,
		normal = raycastResult.Normal,
	}
	self.service.PaintballHit:Fire(hitInfo)
end

function PaintballGunController:_spawnImpact(info: PaintballImpactInfo)
	local position = info.position
	local normal = info.normal
	local hitPart = info.hitPart
	if typeof(position) ~= "Vector3" or typeof(normal) ~= "Vector3" then
		return
	end

	local color = info.color or PaintballConfig.ProjectileColor

	local up = normal
	local right = if math.abs(up:Dot(Vector3.yAxis)) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local tangent = (right - up * right:Dot(up)).Unit

	local model = Instance.new("Model")
	model.Name = "PaintballSplat"

	local splat = Instance.new("Part")
	splat.Name = "SplatPart"
	splat.Size = Vector3.new(1.2, 0.05, 1.2)
	splat.Color = color
	splat.Transparency = 1
	splat.Anchored = false
	splat.CanCollide = false
	splat.CanTouch = false
	splat.CanQuery = false
	splat.Parent = model

	local texture = Instance.new("Texture")
	texture.Texture = SPLAT_IMAGES[math.random(1, #SPLAT_IMAGES)]
	texture.Color3 = color
	texture.Face = Enum.NormalId.Top
	texture.StudsPerTileU = 1.2
	texture.StudsPerTileV = 1.2
	texture.Parent = splat

	model.PrimaryPart = splat
	model:PivotTo(CFrame.fromMatrix(position + up * 0.025, tangent, up))
	model:ScaleTo(0.001)
	model.Parent = Workspace

	if hitPart and hitPart:IsA("BasePart") then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = splat
		weld.Part1 = hitPart
		weld.Parent = splat
	end

	local hitSound = Instance.new("Sound")
	hitSound.SoundId = "rbxassetid://117404476273393"
	hitSound.RollOffMode = Enum.RollOffMode.InverseTapered
	hitSound.RollOffMinDistance = 10
	hitSound.RollOffMaxDistance = 5000
	hitSound.Parent = splat
	hitSound:Play()

	local scale = Instance.new("NumberValue")
	scale.Value = 0.001
	scale.Parent = model
	scale.Changed:Connect(function(value: number)
		if model and model.Parent then
			model:ScaleTo(value)
		end
	end)

	TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 1 }):Play()

	task.delay(6, function()
		if model and model.Parent then
			local shrink = TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 0.001 })
			shrink:Play()
			shrink.Completed:Wait()
			if model and model.Parent then
				model:Destroy()
			end
		end
	end)
end

return PaintballGunController :: PaintballGunController
