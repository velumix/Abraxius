--!strict
-- @author Velumix
-- @version 0.0.1b
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))
local Trove = require(ReplicatedStorage.Modules.Trove)

local LOCAL_PLAYER = Players.LocalPlayer

type CameraHandle = {
	Destroy: (self: CameraHandle) -> (),
}

local DeathCameraController = Knit.CreateController({
	Name = "DeathCameraController",
})

DeathCameraController._trove = Trove.new()
DeathCameraController._deathHandle = nil :: CameraHandle?

function DeathCameraController:_stopDeathCamera(_character: Model?)
	local handle: CameraHandle? = self._deathHandle
	self._deathHandle = nil
	if handle then
		handle:Destroy()
	end
end

function DeathCameraController:_startDeathCamera(character: Model)
	self:_stopDeathCamera(nil)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("IKControl") then
			descendant.Weight = 0
			descendant.Enabled = false
		end
	end
	local started = os.clock()
	self._deathHandle = self._camera:Push("DeathCamera", {
		Priority = 1000,
		Owner = character,
		CameraType = Enum.CameraType.Scriptable,
		MouseBehavior = Enum.MouseBehavior.Default,
		MouseIconEnabled = true,
		Update = function(camera: Camera, dt: number): { CFrame: CFrame?, Focus: CFrame?, FieldOfView: number? }?
			if not character.Parent then
				return nil
			end
			local torso = character:FindFirstChild("UpperTorso")
			local root = character:FindFirstChild("HumanoidRootPart")
			local focusPart = if torso and torso:IsA("BasePart")
				then torso
				elseif root and root:IsA("BasePart") then root
				else nil
			if not focusPart then
				return nil
			end
			local focus = focusPart.Position + Vector3.new(0, 0.65, 0)
			local angle = (os.clock() - started) * 0.16
			local offset = Vector3.new(math.sin(angle) * 7.5, 5.25, math.cos(angle) * 7.5)
			local desired = CFrame.lookAt(focus + offset, focus)
			local alpha = 1 - math.exp(-dt * 4.5)
			return {
				CFrame = camera.CFrame:Lerp(desired, alpha),
				Focus = CFrame.new(focus),
			}
		end,
	})
end

function DeathCameraController:_watchCharacter(character: Model)
	self:_stopDeathCamera(character)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	self._trove:Add(humanoid.Died:Connect(function()
		self:_startDeathCamera(character)
	end))
end

function DeathCameraController:KnitStart()
	local weaponService = Knit.GetService("WeaponService")
	self._trove:Add(weaponService.CharacterDied:Connect(function(character)
		if character == LOCAL_PLAYER.Character then
			print("[DeathCamera] Authoritative death signal received")
			self:_startDeathCamera(character)
		end
	end))
	self._trove:Add(LOCAL_PLAYER.CharacterAdded:Connect(function(character)
		self:_watchCharacter(character)
	end))
	if LOCAL_PLAYER.Character then
		self:_watchCharacter(LOCAL_PLAYER.Character)
	end
end

function DeathCameraController:KnitInit()
	self._camera = Knit.GetController("CameraController")
end

function DeathCameraController:Destroy()
	self:_stopDeathCamera(nil)
	self._trove:Destroy()
end

return DeathCameraController
