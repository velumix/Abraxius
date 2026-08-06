local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CameraShaker = require(ReplicatedStorage.Packages.CameraShaker)

local HugeSizeController = Knit.CreateController({
	Name = "HugeSizeController",
})

function HugeSizeController:KnitStart()
	local ok, err = pcall(function()
		local player = Players.LocalPlayer
		local camera = workspace.CurrentCamera

		local camShake = CameraShaker.new(Enum.RenderPriority.Camera.Value + 1, function(shakeCf: CFrame)
			camera.CFrame *= shakeCf
		end)
		camShake:Start()

		local hugeScale = 1
		local isMoving = false

		local function updateScale()
			hugeScale = tonumber(player:GetAttribute("HugeSizeScale")) or 1
		end
		updateScale()
		player:GetAttributeChangedSignal("HugeSizeScale"):Connect(updateScale)

		local function onCharacterAdded(character: Model)
			local humanoid = character:WaitForChild("Humanoid", 5)
			if not humanoid then
				return
			end
			humanoid.Running:Connect(function(speed: number)
				isMoving = speed > 0.5
			end)
		end
		if player.Character then
			onCharacterAdded(player.Character)
		end
		player.CharacterAdded:Connect(onCharacterAdded)

		local STEP_INTERVAL = 0.35
		local timeSinceStep = 0
		RunService.RenderStepped:Connect(function(dt: number)
			if hugeScale <= 1 or not isMoving then
				timeSinceStep = 0
				return
			end

			timeSinceStep += dt
			if timeSinceStep >= STEP_INTERVAL then
				timeSinceStep = 0
				-- One quick footstep bump, scaled slightly by size.
				local magnitude = math.clamp(0.25 * hugeScale, 0.25, 1.25)
				camShake:ShakeOnce(magnitude, 2.5, 0, 0.12)
			end
		end)
	end)
	if not ok then
		warn("[HugeSizeController] KnitStart failed: " .. tostring(err))
	end
end

return HugeSizeController
