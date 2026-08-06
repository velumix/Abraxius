local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local CoinAnimatorController = Knit.CreateController({
	Name = "CoinAnimatorController",
})

export type CoinAnimatorController = typeof(CoinAnimatorController)

local COINS_FOLDER_NAME = "SpawnedCoins"
local BOB_AMPLITUDE = 0.5
local BOB_SPEED = 2
local SPIN_SPEED = 90

function CoinAnimatorController:KnitStart()
	local coinsFolder = Workspace:WaitForChild(COINS_FOLDER_NAME)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local spinAngle = math.rad((t * SPIN_SPEED) % 360)

		for _, coin in ipairs(coinsFolder:GetChildren()) do
			if coin:IsA("BasePart") and not coin:GetAttribute("Falling") then
				local baseY = coin:GetAttribute("BaseY") or coin.Position.Y
				local phase = coin:GetAttribute("Phase") or 0
				local bobY = baseY + math.sin(t * BOB_SPEED + phase) * BOB_AMPLITUDE
				local pos = coin.Position

				coin.CFrame = CFrame.new(pos.X, bobY, pos.Z) * CFrame.Angles(0, spinAngle, 0)
			end
		end
	end)
end

return CoinAnimatorController :: CoinAnimatorController
