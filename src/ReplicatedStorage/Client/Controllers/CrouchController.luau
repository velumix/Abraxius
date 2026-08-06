--!strict
-- @author Velumix
-- @version 0.0.1
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Modules.Knit) :: typeof(require(ReplicatedStorage.Modules.Knit.KnitClient))
local Trove = require(ReplicatedStorage.Modules.Trove)

local LOCAL_PLAYER = Players.LocalPlayer
local ACTION_NAME = "CharacterCrouch"

local CrouchController = Knit.CreateController({
	Name = "CrouchController",
})

CrouchController._trove = Trove.new()
CrouchController._characterTrove = nil
CrouchController._setCrouched = nil

function CrouchController:_setupCharacter(character: Model)
	if self._characterTrove then
		self._characterTrove:Destroy()
	end
	local trove = Trove.new()
	self._characterTrove = trove
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local torso = character:WaitForChild("UpperTorso") :: BasePart
	local controls = {}

	for _, side in { "Left", "Right" } do
		local upperLeg = character:WaitForChild(`{side}UpperLeg`) :: BasePart
		local foot = character:WaitForChild(`{side}Foot`) :: BasePart
		local target = Instance.new("Attachment")
		target.Name = `{side}CrouchTarget`
		target.CFrame = root.CFrame:ToObjectSpace(foot.CFrame) + Vector3.new(0, 0.55, 0.15)
		target.Parent = root
		trove:Add(target)
		local pole = Instance.new("Attachment")
		pole.Name = `{side}CrouchPole`
		pole.Position = Vector3.new(if side == "Left" then -0.45 else 0.45, -1, -2.5)
		pole.Parent = torso
		trove:Add(pole)
		local ik = Instance.new("IKControl")
		ik.Name = `{side}CrouchIK`
		ik.Type = Enum.IKControlType.Transform
		ik.ChainRoot = upperLeg
		ik.EndEffector = foot
		ik.Target = target
		ik.Pole = pole
		ik.SmoothTime = 0.08
		ik.Weight = 0
		ik.Enabled = false
		ik.Parent = humanoid
		trove:Add(ik)
		table.insert(controls, ik)
	end

	local originalHipHeight = humanoid.HipHeight
	local originalWalkSpeed = humanoid.WalkSpeed
	local function setCrouched(enabled: boolean)
		local active = enabled and humanoid.Health > 0
		humanoid.HipHeight = if active then math.max(0, originalHipHeight - 0.75) else originalHipHeight
		humanoid.WalkSpeed = if active then math.min(originalWalkSpeed, 9) else originalWalkSpeed
		for _, ik in controls do
			ik.Enabled = active
			ik.Weight = if active then 1 else 0
		end
	end
	self._setCrouched = setCrouched
	trove:Add(function()
		setCrouched(false)
		if self._setCrouched == setCrouched then
			self._setCrouched = nil
		end
	end)
	trove:Add(humanoid.Died:Connect(function()
		setCrouched(false)
	end))
end

function CrouchController:KnitStart()
	ContextActionService:BindActionAtPriority(ACTION_NAME, function(_, inputState)
		if self._setCrouched then
			if inputState == Enum.UserInputState.Begin then
				self._setCrouched(true)
			elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
				self._setCrouched(false)
			end
		end
		return Enum.ContextActionResult.Sink
	end, false, 2500, Enum.KeyCode.C)
	self._trove:Add(function()
		ContextActionService:UnbindAction(ACTION_NAME)
	end)
	self._trove:Add(LOCAL_PLAYER.CharacterAdded:Connect(function(character)
		self:_setupCharacter(character)
	end))
	if LOCAL_PLAYER.Character then
		self:_setupCharacter(LOCAL_PLAYER.Character)
	end
end

function CrouchController:Destroy()
	if self._characterTrove then
		self._characterTrove:Destroy()
		self._characterTrove = nil
	end
	self._trove:Destroy()
end

return CrouchController
