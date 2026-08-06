--!strict
-- @author Velumix
-- @version 0.0.1
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Component = require(ReplicatedStorage.Modules.Component)
local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))
local Trove = require(ReplicatedStorage.Modules.Trove)
local WeaponDefinitions = require(ReplicatedStorage.Shared.WeaponDefinitions)

local LOCAL_PLAYER = Players.LocalPlayer
local MOUSE = LOCAL_PLAYER:GetMouse()
local ATTACK_DURATION = 0.52
local RECOIL_FREQUENCY = 15
local RECOIL_DAMPING = 6.5
local SHOULDER_CAMERA_OFFSET = Vector3.new(2.1, 0.75, 0)
local VERTICAL_AIM_YAW_DEADZONE = 0.1
local MAX_SHOULDER_AIM_PITCH = math.rad(82)

local function createCrosshair(): (ScreenGui, { [string]: Frame })
	local gui = Instance.new("ScreenGui")
	gui.Name = "WeaponCrosshair"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100

	local center = Instance.new("Frame")
	center.Name = "Center"
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.5)
	center.Size = UDim2.fromOffset(1, 1)
	center.BackgroundTransparency = 1
	center.Parent = gui

	local bars = {}
	bars.Center = center
	for _, name in { "Left", "Right", "Top", "Bottom" } do
		local bar = Instance.new("Frame")
		bar.Name = name
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = Color3.new(1, 1, 1)
		bar.Parent = center
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.new(0, 0, 0)
		stroke.Thickness = 1
		stroke.Parent = bar
		bars[name] = bar
	end
	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromOffset(0, 0)
	dot.Size = UDim2.fromOffset(3, 3)
	dot.BorderSizePixel = 0
	dot.BackgroundColor3 = Color3.new(1, 1, 1)
	dot.Parent = center
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot
	return gui, bars
end

local POSES = {
	Idle = CFrame.Angles(math.rad(-48), math.rad(8), math.rad(28)),
	Block = CFrame.Angles(math.rad(-78), math.rad(-8), math.rad(52)),
}

local ATTACKS = {
	{
		Windup = CFrame.Angles(math.rad(-42), math.rad(-38), math.rad(58)),
		Strike = CFrame.Angles(math.rad(-52), math.rad(48), math.rad(-32)),
	},
	{
		Windup = CFrame.Angles(math.rad(-72), math.rad(-24), math.rad(44)),
		Strike = CFrame.Angles(math.rad(-34), math.rad(34), math.rad(-52)),
	},
}

local WeaponComponent = Component.new({
	Tag = WeaponDefinitions.Tag,
	Ancestors = { workspace, Players },
	Extensions = {
		{
			ShouldConstruct = function(component)
				local tool = component.Instance
				return tool:IsA("Tool") and (tool:IsDescendantOf(LOCAL_PLAYER) or tool:IsDescendantOf(workspace))
			end,
		},
	},
})
WeaponComponent.RenderPriority = Enum.RenderPriority.Camera.Value + 1

local function smoothstep(alpha: number): number
	local x = math.clamp(alpha, 0, 1)
	return x * x * (3 - 2 * x)
end

function WeaponComponent:Construct()
	self._trove = Trove.new()
	self._equipTrove = nil
	self._rightShoulder = nil
	self._pose = POSES.Idle
	self._state = "Unequipped"
	self._stateStarted = 0
	self._attackIndex = 0
	self._attack = ATTACKS[1]
	self.IsEquipped = false
	self._baseGrip = nil
	self._recoil = Vector3.zero
	self._recoilVelocity = Vector3.zero
	self._crosshairOffset = Vector2.zero
	self._cameraHandle = nil
	self._firearmHumanoid = nil
	self._firearmRoot = nil
	self._firearmTorso = nil
	self._firearmArmParts = nil
	self._firearmShoulderC0 = nil
	self._firearmTracks = nil
	self._isReloading = false
	self._lastLocalFire = 0
	self._crosshairBars = nil
	self._movementBloom = 0
	self._isAiming = false
	self._aimParams = nil
end

function WeaponComponent:_makeIK(
	humanoid: Humanoid,
	name: string,
	upperArm: BasePart,
	endEffector: Instance,
	target: Attachment,
	pole: Attachment,
	trove
)
	local existing = humanoid:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local ik = Instance.new("IKControl")
	ik.Name = name
	ik.Type = Enum.IKControlType.Transform
	ik.ChainRoot = upperArm
	ik.EndEffector = endEffector
	ik.Target = target
	ik.Pole = pole
	ik.SmoothTime = 0.035
	ik.Weight = 1
	ik.Parent = humanoid
	trove:Add(ik)
end

function WeaponComponent:_setupRig(character: Model, humanoid: Humanoid, trove): boolean
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return false
	end
	local torso = character:FindFirstChild("UpperTorso") :: BasePart?
	local rightUpper = character:FindFirstChild("RightUpperArm") :: BasePart?
	local leftUpper = character:FindFirstChild("LeftUpperArm") :: BasePart?
	local leftHand = character:FindFirstChild("LeftHand") :: BasePart?
	local handle = self.Instance:FindFirstChild("Handle") :: BasePart?
	local rightShoulder = rightUpper and rightUpper:FindFirstChild("RightShoulder") :: Motor6D?
	if
		not (
			torso
			and rightUpper
			and rightShoulder
			and rightShoulder:IsA("Motor6D")
			and leftUpper
			and leftHand
			and handle
		)
	then
		return false
	end
	local leftGrip = leftHand:FindFirstChild("LeftGripAttachment") :: Attachment?
	if not leftGrip then
		return false
	end
	self._rightShoulder = rightShoulder
	trove:Add(function()
		if rightShoulder.Parent then
			rightShoulder.Transform = CFrame.identity
		end
	end)

	local grip = WeaponDefinitions.FindOffHandGrip(self.Instance)
	if not grip then
		grip = Instance.new("Attachment")
		grip.Name = WeaponDefinitions.OffHandGripName
		grip.CFrame = WeaponDefinitions.GetOffHandGripCFrame(self.Instance, handle)
		grip.Parent = handle
		trove:Add(grip)
	end
	local leftPole = Instance.new("Attachment")
	leftPole.Position = Vector3.new(-2, -0.35, -0.8)
	leftPole.Parent = torso
	trove:Add(leftPole)
	self:_makeIK(humanoid, "WeaponLeftArmIK", leftUpper, leftGrip, grip, leftPole, trove)
	return true
end

function WeaponComponent:_setState(state: string)
	self._state = state
	self._stateStarted = os.clock()
end

function WeaponComponent:_requestBlock(action: string)
	local service = Knit.GetService("WeaponService")
	service:RequestAction(self.Instance, action):catch(warn)
end

function WeaponComponent:_equip()
	if self.IsEquipped or self.Instance.Parent ~= LOCAL_PLAYER.Character then
		return
	end
	local character = self.Instance.Parent :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local trove = Trove.new()
	if WeaponDefinitions.IsFirearm(self.Instance) then
		local root = character:FindFirstChild("HumanoidRootPart")
		local torso = character:FindFirstChild("UpperTorso")
		local rightUpperArm = character:FindFirstChild("RightUpperArm")
		local rightShoulder = rightUpperArm and rightUpperArm:FindFirstChild("RightShoulder")
		if
			not root
			or not root:IsA("BasePart")
			or not torso
			or not torso:IsA("BasePart")
			or not rightShoulder
			or not rightShoulder:IsA("Motor6D")
		then
			trove:Destroy()
			return
		end
		self._equipTrove = trove
		self.IsEquipped = true
		self._rightShoulder = rightShoulder
		self._firearmHumanoid = humanoid
		self._firearmRoot = root
		self._firearmTorso = torso
		local originalShoulderC0 = rightShoulder.C0
		self._firearmShoulderC0 = originalShoulderC0
		self._firearmArmParts = {
			character:FindFirstChild("RightUpperArm"),
			character:FindFirstChild("RightLowerArm"),
			character:FindFirstChild("RightHand"),
		}
		self._firearmTracks = {}
		local animations = self.Instance:FindFirstChild("Animations")
		local animationController = Knit.GetController("AnimationController")
		if animations then
			self._firearmTracks = animationController:LoadFolder(humanoid, animations, {
				Group = "EquippedWeapon",
				Priority = Enum.AnimationPriority.Action,
			})
		end
		local idleTrack = self._firearmTracks.Idle
		if idleTrack then
			idleTrack.Looped = true
			animationController:PlayTrack(idleTrack, { FadeTime = 0.15 })
		end
		local aimTrack = self._firearmTracks.Aiming
		if aimTrack then
			aimTrack.Looped = true
		end
		local aimAction = "EquippedFirearmAim"
		ContextActionService:BindActionAtPriority(aimAction, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				self._isAiming = true
				if aimTrack then
					animationController:PlayTrack(aimTrack, { FadeTime = 0.1 })
				end
			elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
				self._isAiming = false
				if aimTrack then
					animationController:StopTrack(aimTrack, 0.1)
				end
			end
			return Enum.ContextActionResult.Sink
		end, true, 3000, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
		local reloadAction = "EquippedFirearmReload"
		ContextActionService:BindActionAtPriority(reloadAction, function(_, inputState)
			if inputState == Enum.UserInputState.Begin and not self._isReloading then
				local reloadTrack = self._firearmTracks and self._firearmTracks.Reload
				local mag = self.Instance:FindFirstChild("Mag", true)
				local slide = self.Instance:FindFirstChild("Slide", true)
				local slideBack = self.Instance:FindFirstChild("SlideBack", true)
				if
					mag
					and mag:IsA("BasePart")
					and slide
					and slide:IsA("BasePart")
					and slideBack
					and slideBack:IsA("BasePart")
				then
					self._isReloading = true
					local droppedMag = mag:Clone()
					local rounds = droppedMag:FindFirstChild("9mmBullet")
					if rounds then
						rounds:Destroy()
					end
					for _, child in droppedMag:GetChildren() do
						if child:IsA("WeldConstraint") then
							child:Destroy()
						end
					end
					droppedMag.Anchored = false
					droppedMag.CanCollide = true
					droppedMag.Massless = false
					droppedMag.CFrame = mag.CFrame
					droppedMag.Parent = workspace
					droppedMag.AssemblyLinearVelocity = mag.CFrame.UpVector * -7
						+ mag.CFrame.RightVector * 2
						+ mag.AssemblyLinearVelocity
					droppedMag.AssemblyAngularVelocity = Vector3.new(2, 4, 3)
					Debris:AddItem(droppedMag, 5)
					mag.Transparency = 1
					slide.Transparency = 1
					slideBack.Transparency = 0
					if reloadTrack then
						animationController:PlayTrack(reloadTrack, { FadeTime = 0.08 })
					end
					task.spawn(function()
						if reloadTrack then
							reloadTrack.Stopped:Wait()
						else
							task.wait(1.5)
						end
						if self.IsEquipped and mag.Parent then
							mag.Transparency = 0
							slide.Transparency = 0
							slideBack.Transparency = 1
						end
						self._isReloading = false
					end)
				end
			end
			return Enum.ContextActionResult.Sink
		end, true, 3000, Enum.KeyCode.R, Enum.KeyCode.ButtonX)
		local loadedTracks = self._firearmTracks
		trove:Add(function()
			ContextActionService:UnbindAction(aimAction)
			self._isAiming = false
			ContextActionService:UnbindAction(reloadAction)
			for _, track in loadedTracks do
				animationController:StopTrack(track, 0.1)
			end
			local pistol = self.Instance:FindFirstChild("Pistol")
			local mag = pistol and pistol:FindFirstChild("Mag")
			local slide = pistol and pistol:FindFirstChild("Slide")
			local slideBack = pistol and pistol:FindFirstChild("SlideBack")
			if mag and mag:IsA("BasePart") then
				mag.Transparency = 0
			end
			if slide and slide:IsA("BasePart") then
				slide.Transparency = 0
			end
			if slideBack and slideBack:IsA("BasePart") then
				slideBack.Transparency = 1
			end
		end)
		local previousAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
		trove:Add(function()
			humanoid.AutoRotate = if humanoid.Health > 0 then previousAutoRotate else false
			rightShoulder.C0 = originalShoulderC0
			rightShoulder.Transform = CFrame.identity
		end)
		self._baseGrip = self.Instance.Grip
		self._recoil = Vector3.zero
		self._recoilVelocity = Vector3.zero
		self._crosshairOffset = Vector2.zero
		self._lastLocalFire = 0
		self._movementBloom = 0
		self._isAiming = false
		local cameraController = Knit.GetController("CameraController")
		local cameraHandle = cameraController:Push("EquippedWeapon", {
			Priority = 100,
			Owner = self.Instance,
			MouseBehavior = Enum.MouseBehavior.LockCenter,
			MouseIconEnabled = false,
			CameraOffsetSubject = humanoid,
			CameraOffsetAdditive = true,
			CameraOffsetSpeed = 18,
			CameraOffset = function(camera)
				local zoomDistance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
				return if zoomDistance < 1 then Vector3.zero else SHOULDER_CAMERA_OFFSET
			end,
		})
		self._cameraHandle = cameraHandle
		trove:Add(cameraHandle)
		local crosshair, crosshairBars = createCrosshair()
		crosshair.Parent = LOCAL_PLAYER:WaitForChild("PlayerGui")
		self._crosshairBars = crosshairBars
		local aimParams = RaycastParams.new()
		aimParams.FilterType = Enum.RaycastFilterType.Exclude
		aimParams.FilterDescendantsInstances = { character, self.Instance }
		self._aimParams = aimParams
		trove:Add(crosshair)
		self:_setState("Idle")
		return
	end
	if not self:_setupRig(character, humanoid, trove) then
		trove:Destroy()
		return
	end
	self._equipTrove = trove
	self.IsEquipped = true
	self._pose = POSES.Idle
	self:_setState("Idle")

	local actionName = "EquippedWeaponBlock"
	ContextActionService:BindActionAtPriority(actionName, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and self._state ~= "Attack" then
			self:_setState("Block")
			self:_requestBlock(WeaponDefinitions.Actions.BlockStart)
		elseif inputState == Enum.UserInputState.End and self._state == "Block" then
			self:_setState("Idle")
			self:_requestBlock(WeaponDefinitions.Actions.BlockEnd)
		end
		return Enum.ContextActionResult.Sink
	end, true, 3000, Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
	trove:Add(function()
		ContextActionService:UnbindAction(actionName)
	end)
end

function WeaponComponent:_unequip()
	if not self.IsEquipped then
		return
	end
	if self._state == "Block" then
		self:_requestBlock(WeaponDefinitions.Actions.BlockEnd)
	end
	self.IsEquipped = false
	if self._baseGrip then
		self.Instance.Grip = self._baseGrip
	end
	self._baseGrip = nil
	self._recoil = Vector3.zero
	self._recoilVelocity = Vector3.zero
	self._crosshairOffset = Vector2.zero
	self._cameraHandle = nil
	self._firearmHumanoid = nil
	self._firearmRoot = nil
	self._firearmTorso = nil
	self._firearmArmParts = nil
	self._firearmShoulderC0 = nil
	self._firearmTracks = nil
	self._isReloading = false
	self._lastLocalFire = 0
	self._crosshairBars = nil
	self._movementBloom = 0
	self._isAiming = false
	self._aimParams = nil
	self._state = "Unequipped"
	self._rightShoulder = nil
	if self._equipTrove then
		self._equipTrove:Destroy()
		self._equipTrove = nil
	end
end

function WeaponComponent:Start()
	local tool = self.Instance :: Tool
	self._trove:Add(tool.Equipped:Connect(function()
		self:_equip()
	end))
	self._trove:Add(tool.Unequipped:Connect(function()
		self:_unequip()
	end))
	self._trove:Add(tool.Activated:Connect(function()
		if self.IsEquipped and self._state ~= "Attack" then
			if WeaponDefinitions.IsFirearm(tool) then
				if self._isReloading then
					return
				end
				local now = os.clock()
				local fireRate = math.max(tool:GetAttribute("FireRate") or 0.25, 0.08)
				if now - self._lastLocalFire < fireRate then
					return
				end
				self._lastLocalFire = now
				local shootTrack = self._firearmTracks and self._firearmTracks.Shoot
				if shootTrack then
					shootTrack:Stop(0)
					shootTrack:Play(0.02)
				end
				local service = Knit.GetService("WeaponService")
				local camera = workspace.CurrentCamera
				local target = MOUSE.Hit.Position
				if camera then
					local crosshairPoint = camera.ViewportSize * 0.5 + self._crosshairOffset
					local crosshairRay = camera:ViewportPointToRay(crosshairPoint.X, crosshairPoint.Y)
					local recoilBloom = math.clamp(self._recoil.Magnitude * 2.5, 0, 0.9)
					local spreadDegrees = if self._isAiming
						then 0.12 + self._movementBloom * 0.35 + recoilBloom * 0.5
						else 1.1 + self._movementBloom * 0.9 + recoilBloom
					local spreadPitch = math.rad(math.random() * 2 - 1) * spreadDegrees
					local spreadYaw = math.rad(math.random() * 2 - 1) * spreadDegrees
					local rayFrame = CFrame.lookAt(crosshairRay.Origin, crosshairRay.Origin + crosshairRay.Direction)
					local direction = (rayFrame * CFrame.Angles(spreadPitch, spreadYaw, 0)).LookVector
					local aimParams = RaycastParams.new()
					aimParams.FilterType = Enum.RaycastFilterType.Exclude
					aimParams.FilterDescendantsInstances = { LOCAL_PLAYER.Character :: Model, tool }
					local cameraHit = workspace:Raycast(camera.CFrame.Position, direction * 1000, aimParams)
					target = if cameraHit then cameraHit.Position else camera.CFrame.Position + direction * 1000
				end
				print("[WeaponDebug][Client] Activated", tool:GetFullName(), "target", target)
				service
					:RequestFire(tool, target)
					:andThen(function(accepted, reason)
						print("[WeaponDebug][Client] Server response", accepted, reason)
					end)
					:catch(function(err)
						warn("[WeaponDebug][Client] RequestFire failed", err)
					end)
				self._recoilVelocity += Vector3.new(
					math.rad(math.random(-260, 260) / 10),
					math.rad(math.random(-650, 650) / 10),
					math.rad(math.random(1250, 1550) / 10)
				)
				local muzzle = tool:FindFirstChild("Muzzle", true)
				if muzzle and muzzle:IsA("BasePart") then
					local flash = muzzle:FindFirstChild("MuzzleFlash")
					local smoke = muzzle:FindFirstChild("Smoke")
					if flash and flash:IsA("ParticleEmitter") then
						flash:Emit(1)
					end
					if smoke and smoke:IsA("ParticleEmitter") then
						smoke:Emit(1)
					end
				end
				local slide = tool:FindFirstChild("Slide", true)
				local slideBack = tool:FindFirstChild("SlideBack", true)
				if slide and slide:IsA("BasePart") and slideBack and slideBack:IsA("BasePart") then
					slide.Transparency = 1
					slideBack.Transparency = 0
					task.delay(0.05, function()
						if slide.Parent and slideBack.Parent then
							slide.Transparency = 0
							slideBack.Transparency = 1
						end
					end)
				end
				local eject = slide and slide:FindFirstChild("Eject")
				local pistolAssets = ReplicatedStorage.Assets:FindFirstChild("Pistols")
				local m45Asset = pistolAssets and pistolAssets:FindFirstChild("M45")
				local pistol = m45Asset and m45Asset:FindFirstChild("Pistol")
				local mag = pistol and pistol:FindFirstChild("Mag")
				local cartridge = mag and mag:FindFirstChild("9mmBullet")
				local shellTemplate = cartridge and cartridge:FindFirstChild("9mmShell")
				if eject and eject:IsA("Attachment") and shellTemplate and shellTemplate:IsA("BasePart") then
					local character = tool.Parent
					local root = character and character:FindFirstChild("HumanoidRootPart")
					local ejectDirection = if root and root:IsA("BasePart")
						then root.CFrame.RightVector
						else eject.WorldAxis
					print(
						"[WeaponDebug][Client] Ejecting shell",
						shellTemplate:GetFullName(),
						"from",
						eject:GetFullName()
					)
					local shell = shellTemplate:Clone()
					for _, child in shell:GetChildren() do
						if child:IsA("WeldConstraint") then
							child:Destroy()
						end
					end
					shell.Anchored = false
					shell.CanCollide = true
					shell.Massless = false
					shell.CFrame = eject.WorldCFrame + ejectDirection * 0.18
					shell.Parent = workspace
					shell.AssemblyLinearVelocity = ejectDirection * 20 + Vector3.yAxis * 8
					shell.AssemblyAngularVelocity =
						Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
					Debris:AddItem(shell, 4)
					print(
						"[WeaponDebug][Client] Shell spawned",
						shell:GetFullName(),
						"position",
						shell.Position,
						"velocity",
						shell.AssemblyLinearVelocity,
						"anchored",
						shell.Anchored
					)
				else
					warn(
						"[WeaponDebug][Client] Shell eject lookup failed",
						"slide",
						slide,
						"eject",
						eject,
						"assetMag",
						mag,
						"cartridge",
						cartridge,
						"shell",
						shellTemplate
					)
				end
				local sounds = tool:FindFirstChild("Sounds", true)
				local fireSound = sounds and sounds:FindFirstChild("Fire")
				if fireSound and fireSound:IsA("Sound") then
					fireSound:Play()
				end
				return
			end
			if self._state == "Block" then
				self:_requestBlock(WeaponDefinitions.Actions.BlockEnd)
			end
			self._attackIndex = self._attackIndex % #ATTACKS + 1
			self._attack = ATTACKS[self._attackIndex]
			self:_setState("Attack")
		end
	end))
	if tool.Parent == LOCAL_PLAYER.Character then
		self:_equip()
	end
end

function WeaponComponent:RenderSteppedUpdate(_dt: number)
	if WeaponDefinitions.IsFirearm(self.Instance) then
		local humanoid = self._firearmHumanoid
		if humanoid and humanoid.Health <= 0 then
			self:_unequip()
			return
		end
		if not self.IsEquipped or not self._baseGrip then
			return
		end
		local dt = math.min(_dt, 1 / 30)
		local root = self._firearmRoot
		local horizontalSpeed = if root
			then Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			else 0
		local targetMovementBloom = math.clamp(horizontalSpeed / 16, 0, 1)
		self._movementBloom += (targetMovementBloom - self._movementBloom) * math.min(dt * 10, 1)
		local acceleration = -self._recoil * (RECOIL_FREQUENCY * RECOIL_FREQUENCY)
			- self._recoilVelocity * RECOIL_DAMPING
		self._recoilVelocity += acceleration * dt
		self._recoil += self._recoilVelocity * dt

		local pitch = self._recoil.Z
		local yaw = self._recoil.Y
		local roll = self._recoil.X
		local maxWander = if self._isAiming then 34 else 68
		local rawOffset = Vector2.new(yaw * 110 + roll * 35, -pitch * 120)
		self._crosshairOffset = if rawOffset.Magnitude > maxWander then rawOffset.Unit * maxWander else rawOffset
		local camera = workspace.CurrentCamera
		if camera then
			local crosshairPoint = camera.ViewportSize * 0.5 + self._crosshairOffset
			local aimRay = camera:ViewportPointToRay(crosshairPoint.X, crosshairPoint.Y)
			local aimParams = self._aimParams
			local aimHit = if aimParams
				then workspace:Raycast(aimRay.Origin, aimRay.Direction * 1000, aimParams)
				else nil
			local aimPoint = if aimHit then aimHit.Position else aimRay.Origin + aimRay.Direction * 1000
			local flatAimDirection = Vector3.new(aimRay.Direction.X, 0, aimRay.Direction.Z)
			local hasStableAimYaw = flatAimDirection.Magnitude >= VERTICAL_AIM_YAW_DEADZONE
			if root then
				if hasStableAimYaw then
					root.CFrame = CFrame.lookAt(root.Position, root.Position + flatAimDirection.Unit)
				end
			end
			local shoulder = self._rightShoulder
			local shoulderC0 = self._firearmShoulderC0
			local torso = self._firearmTorso
			if shoulder and shoulderC0 and torso then
				local shoulderWorld = torso.CFrame * shoulderC0
				local shoulderOffset = aimPoint - shoulderWorld.Position
				if shoulderOffset.Magnitude > 0.001 then
					local torsoLook = torso.CFrame:VectorToObjectSpace(shoulderOffset.Unit)
					local aimPitch = math.clamp(
						math.asin(math.clamp(torsoLook.Y, -1, 1)),
						-MAX_SHOULDER_AIM_PITCH,
						MAX_SHOULDER_AIM_PITCH
					)
					local aimYaw = if hasStableAimYaw then math.atan2(-torsoLook.X, -torsoLook.Z) else 0
					shoulder.Transform = CFrame.identity
					shoulder.C0 = shoulderC0 * CFrame.Angles(aimPitch, aimYaw, 0)
				end
			end
			local zoomDistance = (camera.CFrame.Position - camera.Focus.Position).Magnitude
			local firstPerson = zoomDistance < 1
			if firstPerson and self._firearmArmParts then
				for _, part in self._firearmArmParts do
					if part and part:IsA("BasePart") then
						part.LocalTransparencyModifier = 0
					end
				end
			end
		end

		local kick = math.clamp(math.abs(pitch) * 1.7, 0, 0.8)
		local sideKick = math.clamp(yaw * 1.1 + roll * 0.4, -0.38, 0.38)
		self.Instance.Grip = self._baseGrip
			* CFrame.new(sideKick, math.sin(pitch * 14) * kick * 0.3, kick)
			* CFrame.Angles(-pitch * 1.65, yaw * 0.72, roll * 1.15)
		local bars = self._crosshairBars
		if bars then
			bars.Center.Position = UDim2.new(0.5, self._crosshairOffset.X, 0.5, self._crosshairOffset.Y)
			local stanceGap = if self._isAiming then 5 else 13
			local movementGap = self._movementBloom * (if self._isAiming then 6 else 12)
			local recoilGap = math.clamp(self._recoil.Magnitude * (if self._isAiming then 18 else 28), 0, 14)
			local gap = stanceGap + movementGap + recoilGap
			bars.Left.Size = UDim2.fromOffset(9, 2)
			bars.Left.Position = UDim2.fromOffset(-gap - 4.5, 0)
			bars.Right.Size = UDim2.fromOffset(9, 2)
			bars.Right.Position = UDim2.fromOffset(gap + 4.5, 0)
			bars.Top.Size = UDim2.fromOffset(2, 9)
			bars.Top.Position = UDim2.fromOffset(0, -gap - 4.5)
			bars.Bottom.Size = UDim2.fromOffset(2, 9)
			bars.Bottom.Position = UDim2.fromOffset(0, gap + 4.5)
		end
		return
	end
	local rightShoulder = self._rightShoulder
	if not self.IsEquipped or not rightShoulder then
		return
	end
	local desired = POSES.Idle
	if self._state == "Block" then
		desired = POSES.Block
	elseif self._state == "Attack" then
		local attack = self._attack
		local elapsed = os.clock() - self._stateStarted
		local alpha = elapsed / ATTACK_DURATION
		if alpha < 0.28 then
			desired = POSES.Idle:Lerp(attack.Windup, smoothstep(alpha / 0.28))
		elseif alpha < 0.68 then
			desired = attack.Windup:Lerp(attack.Strike, smoothstep((alpha - 0.28) / 0.4))
		elseif alpha < 1 then
			desired = attack.Strike:Lerp(POSES.Idle, smoothstep((alpha - 0.68) / 0.32))
		else
			self:_setState("Idle")
			desired = POSES.Idle
		end
	end
	self._pose = self._pose:Lerp(desired, 0.32)
	rightShoulder.Transform = self._pose
end

function WeaponComponent:Stop()
	self:_unequip()
	self._trove:Destroy()
end

return WeaponComponent
