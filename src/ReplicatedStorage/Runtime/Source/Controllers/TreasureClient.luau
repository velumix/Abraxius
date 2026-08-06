local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Assets = ReplicatedStorage.Assets
local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local UI = require(Modules.UI)

local TreasureEvent = Mince:GetEvent("TreasureEvent")
local TreasureOpened = TreasureEvent:Extend("Opened")
local RequestCollectedData = TreasureEvent:Extend("RequestCollectedData")
local SendCollectedData = TreasureEvent:Extend("SendCollectedData")

local TreasureClient = Mince.Component {
	Tag = "Treasure",
}

local TreasureHandler = {
	Name = "TreasureHandler",
}

local function Vector3ToKey(vector)
	return string.format("%.2f,%.2f,%.2f", vector.X, vector.Y, vector.Z)
end

local function GetTreasurePosition(instance)
	if not instance then
		return nil
	end

	if instance:IsA("Model") then
		return instance:GetPivot().Position
	elseif instance:IsA("BasePart") then
		return instance.Position
	end
	return nil
end

function TreasureHandler:Setup()

end

function TreasureHandler:GameStart()
	self.CoinModel = Assets.Tresures.CoinModel
	self.CollectedTreasures = {}

	TreasureOpened.Event:Connect(function(chestModel, chestInstance, chestPosition, currencyAmount)
		if chestPosition then
			local key = Vector3ToKey(chestPosition)
			self.CollectedTreasures[key] = true
		end
		self:SpawnCoins(chestModel, chestInstance, chestPosition, currencyAmount)
	end)

	SendCollectedData.Event:Connect(function(collectedKeys)
		local cache = {}
		if type(collectedKeys) == "table" then
			for _, key in ipairs(collectedKeys) do
				if type(key) == "string" then
					cache[key] = true
				end
			end
		end
		self.CollectedTreasures = cache
		self:HideCollectedChests()
	end)

	task.wait(1)
	RequestCollectedData:Fire()
end

function TreasureHandler:HideCollectedChests()
	local collectedKeys = self.CollectedTreasures or {}
	for _, component in pairs(TreasureClient.Registry) do
		component:CheckIfCollected()
	end
end

function TreasureClient:Construct()
	self.Model = self.Instance
	self:CheckIfCollected()
end

function TreasureClient:CheckIfCollected()
	local position = GetTreasurePosition(self.Instance)
	if not position then
		return
	end

	local key = Vector3ToKey(position)
	if TreasureHandler.CollectedTreasures and TreasureHandler.CollectedTreasures[key] then
		if self.Model then
			self.Model.Parent = nil
		end
	end
end

function TreasureHandler:SpawnCoins(chestModel, chestInstance, chestPosition, currencyAmount)
	local numCoins = math.floor(currencyAmount / 10)

	if not Player.Character or not Player.Character.PrimaryPart then
		return
	end

	UI.Notify(string.format("You found %d coins!", currencyAmount), {
		Duration = 3,
	})

	for i = 1, numCoins do
		task.wait(0.05)

		local coin = self.CoinModel:Clone()
		coin.Parent = workspace
		local angle = (i / numCoins) * math.pi * 2
		local radius = 3
		local randomOffset = Vector3.new(
			math.cos(angle) * radius + math.random(-1, 1),
			math.random(2, 4),
			math.sin(angle) * radius + math.random(-1, 1)
		)

		local startPos = chestPosition + randomOffset
		coin:PivotTo(CFrame.new(startPos))

		task.spawn(function()
			self:AnimateCoin(coin, startPos)
		end)
	end

	if chestModel and chestModel.Parent then
		task.wait(0.3)
		self:VanishChest(chestModel)
	end
end

function TreasureHandler:VanishChest(chestModel)
	local vanishDuration = 0.5
	local startTime = tick()
	local startSize = chestModel:GetScale()

	while tick() - startTime < vanishDuration do
		local alpha = (tick() - startTime) / vanishDuration
		local scale = startSize * (1 - alpha)

		if chestModel and chestModel.Parent then
			chestModel:ScaleTo(math.max(scale, 0.01))

			for _, part in pairs(chestModel:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "Hitbox" then
					part.Transparency = alpha
				end
			end
		else
			break
		end

		task.wait()
	end

	if chestModel and chestModel.Parent then
		chestModel:Destroy()
	end
end

function TreasureHandler:AnimateCoin(coin, startPos)
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

function TreasureHandler:PoofCoin(coin)
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

return TreasureHandler
