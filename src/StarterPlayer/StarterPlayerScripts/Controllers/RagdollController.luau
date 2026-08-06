local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)

local RagdollController = Knit.CreateController({
	Name = "RagdollController",
})

local localPlayer = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local function updateCameraSubject(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if character:GetAttribute("Ragdolled") == true then
		local head = character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			camera.CameraSubject = head
		end
	else
		if humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
			camera.CameraSubject = humanoid
		end
	end
end

local function watchCharacter(character: Model)
	local conn = character:GetAttributeChangedSignal("Ragdolled"):Connect(function()
		updateCameraSubject(character)
	end)
	character.Destroying:Connect(function()
		conn:Disconnect()
	end)
	updateCameraSubject(character)
end

function RagdollController:KnitStart()
	local ok, err = pcall(function()
		if localPlayer.Character then
			watchCharacter(localPlayer.Character)
		end

		localPlayer.CharacterAdded:Connect(function(character: Model)
			watchCharacter(character)
		end)
	end)

	if not ok then
		warn(`[RagdollController] KnitStart failed: {err}`)
	end
end

return RagdollController
