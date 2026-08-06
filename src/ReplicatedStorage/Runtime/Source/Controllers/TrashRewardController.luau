local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Assets = ReplicatedStorage.Assets
local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)

local TrashEvent = Mince:GetEvent("TrashEvent")
local TrashCollected = TrashEvent:Extend("Collected")

local TrashRewardController = {
	Name = "TrashRewardController",
}

function TrashRewardController:Setup()
	self.Connections = {}
	self.CoinModel = nil
end

function TrashRewardController:GameStart()
	local treasuresFolder = Assets:FindFirstChild("Tresures")
	if treasuresFolder then
		self.CoinModel = treasuresFolder:FindFirstChild("CoinModel")
	end

	table.insert(self.Connections, TrashCollected.Event:Connect(function(trashPosition, currencyAmount)
		self:OnTrashCollected(trashPosition, currencyAmount)
	end))
end

function TrashRewardController:OnTrashCollected(trashPosition, currencyAmount)
	if typeof(trashPosition) ~= "Vector3" then
		return
	end
	if not self.CoinModel then
		return
	end
	if not Player.Character or not Player.Character.PrimaryPart then
		return
	end

	local amount = math.max(1, math.floor(tonumber(currencyAmount) or 1))
	for i = 1, amount do
		task.wait(0.05)

		local coin = self.CoinModel:Clone()
		coin.Parent = workspace

		local angle = (i / amount) * math.pi * 2
		local radius = 2.5
		local randomOffset = Vector3.new(
			math.cos(angle) * radius + math.random(-1, 1),
			math.random(2, 4),
			math.sin(angle) * radius + math.random(-1, 1)
		)

		local startPos = trashPosition + randomOffset
		coin:PivotTo(CFrame.new(startPos))

		task.spawn(function()
			self:AnimateCoin(coin, startPos)
		end)
	end
end

function TrashRewardController:AnimateCoin(coin, startPos)
	local duration = 0.8
	local startTime = tick()
	local peakHeight = startPos.Y + math.random(3, 6)

	while tick() - startTime < duration do
		if not coin or not coin.Parent then
			break
		end
		if not Player.Character or not Player.Character.PrimaryPart then
			break
		end

		local elapsed = tick() - startTime
		local alpha = elapsed / duration
		local currentTargetPos = Player.Character.PrimaryPart.Position

		local currentX = startPos.X + (currentTargetPos.X - startPos.X) * alpha
		local currentZ = startPos.Z + (currentTargetPos.Z - startPos.Z) * alpha

		local currentY
		if alpha < 0.3 then
			local upAlpha = alpha / 0.3
			currentY = startPos.Y + (peakHeight - startPos.Y) * upAlpha
		else
			local downAlpha = (alpha - 0.3) / 0.7
			currentY = peakHeight + (currentTargetPos.Y - peakHeight) * downAlpha
		end

		local rotation = CFrame.Angles(0, elapsed * 15, 0)
		coin:PivotTo(CFrame.new(currentX, currentY, currentZ) * rotation)

		task.wait()
	end

	if coin and coin.Parent then
		self:PoofCoin(coin)
	end
end

function TrashRewardController:PoofCoin(coin)
	local poofDuration = 0.15
	local startSize = coin:GetScale()
	local startTime = tick()

	while tick() - startTime < poofDuration do
		local alpha = (tick() - startTime) / poofDuration
		local scale = startSize * (1 - alpha)

		if coin and coin.Parent then
			coin:ScaleTo(math.max(scale, 0.01))
		else
			break
		end

		task.wait()
	end

	if coin and coin.Parent then
		coin:Destroy()
	end
end

return TrashRewardController
