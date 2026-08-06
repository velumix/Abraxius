local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Mince = require(ReplicatedStorage.Modules.Mince)

local CurrencyService = Mince:Get("CurrencyService")
local PlayerDataManager = Mince:Get("PlayerDataManager")

local HITBOX_PADDING = Vector3.new(2, 1, 2)

local function GetTodayDate()
	local utc = DateTime.now():ToUniversalTime()
	return utc.Year * 10000 + utc.Month * 100 + utc.Day
end

local function Vector3ToKey(vector)
	return string.format("%.2f,%.2f,%.2f", vector.X, vector.Y, vector.Z)
end

local function KeyToVector3(key)
	local x, y, z = string.match(key, "([^,]+),([^,]+),([^,]+)")
	if x and y and z then
		return Vector3.new(tonumber(x), tonumber(y), tonumber(z))
	end
	return nil
end

local TreasureService = {
	Name = "TreasureService",
	TreasureEvent = nil,
	TreasureOpened = nil,
	SessionCollected = {},
	_Vector3ToKey = Vector3ToKey,
	_KeyToVector3 = KeyToVector3,
}

function TreasureService:GameStart()
	self.TreasureEvent = Mince:GetEvent("TreasureEvent")
	self.TreasureOpened = self.TreasureEvent:Extend("Opened")
	self.RequestCollectedData = self.TreasureEvent:Extend("RequestCollectedData")
	self.SendCollectedData = self.TreasureEvent:Extend("SendCollectedData")
	self.SessionCollected = {}

	self.RequestCollectedData.Event:Connect(function(player)
		self:SendCollectedTreasures(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self.SessionCollected[player] = nil
	end)
end

function TreasureService:_CheckAndResetTreasures(player)
	local profile = PlayerDataManager:GetProfileData(player)
	if not profile then
		return
	end

	local today = GetTodayDate()
	local treasureData = profile.CollectedTreasures

	if treasureData.LastResetDate ~= today then
		treasureData.Items = {}
		treasureData.LastResetDate = today
	end
end

function TreasureService:_GetChestPosition(chestInstance)
	if typeof(chestInstance) == "Instance" then
		if chestInstance:IsA("Model") then
			return chestInstance:GetPivot().Position
		elseif chestInstance:IsA("BasePart") then
			return chestInstance.Position
		end
	end
	return nil
end

function TreasureService:SendCollectedTreasures(player)
	self:_CheckAndResetTreasures(player)

	local profile = PlayerDataManager:GetProfileData(player)
	if not profile then
		return
	end

	local collectedKeys = {}
	local treasureData = profile.CollectedTreasures

	for key, _ in pairs(treasureData.Items or {}) do
		table.insert(collectedKeys, key)
	end

	self.SendCollectedData:Fire(player, collectedKeys)
end

function TreasureService:HasCollectedChest(player, chestInstance)
	self:_CheckAndResetTreasures(player)

	local profile = PlayerDataManager:GetProfileData(player)
	if not profile then
		return false
	end

	local chestPosition = self:_GetChestPosition(chestInstance)
	if not chestPosition then
		return false
	end

	local key = Vector3ToKey(chestPosition)
	return profile.CollectedTreasures.Items[key] == true
end

function TreasureService:MarkChestCollected(player, chestInstance)
	local profile = PlayerDataManager:GetProfileData(player)
	if not profile then
		return
	end

	local chestPosition = self:_GetChestPosition(chestInstance)
	if not chestPosition then
		return
	end

	local key = Vector3ToKey(chestPosition)
	profile.CollectedTreasures.Items[key] = true

	if not self.SessionCollected[player] then
		self.SessionCollected[player] = {}
	end
	self.SessionCollected[player][chestInstance] = true

	self:SendCollectedTreasures(player)
end

local TreasureServer = Mince.Component {
	Tag = "Treasure",
}

function TreasureServer:Construct()
	self.Model = self.Instance
	self.OpenedPlayers = {}
	self.CreatedHitbox = false

	self.RewardsModule = self.Model:FindFirstChild("Rewards")

	self.Rewards = {
		Currency = 150,
		UniqueId = self.Model.Name
	}

	if self.RewardsModule and self.RewardsModule:IsA("ModuleScript") then
		local success, result = pcall(function()
			return require(self.RewardsModule)
		end)
		if success and type(result) == "table" then
			self.Rewards = result
			if not self.Rewards.UniqueId then
				self.Rewards.UniqueId = self.Model.Name
			end
		else
			warn("Failed to load rewards module for " .. self.Model.Name .. ", using defaults")
		end
	end

	local hitbox = self:GetHitbox()
	self.ClickTarget = hitbox or self:GetFallbackPart()

	self.ClickDetector = Instance.new("ClickDetector")
	local activationDistance = 32
	if hitbox and hitbox:IsA("BasePart") then
		local size = hitbox.Size
		activationDistance = math.max(activationDistance, math.max(size.X, size.Y, size.Z) * 0.75)
	end
	self.ClickDetector.MaxActivationDistance = activationDistance
	if self.ClickTarget then
		self.ClickDetector.Parent = self.ClickTarget
	else
		warn("TreasureServer could not resolve a click target for", self.Instance:GetFullName())
	end

	self.ClickConnection = self.ClickDetector.MouseClick:Connect(function(player)
		self:OpenChest(player)
	end)
end

function TreasureServer:GetHitbox()
	local instance = self.Instance
	local hitbox

	if instance:IsA("Model") then
		hitbox = instance:FindFirstChild("Hitbox")
		if hitbox and not hitbox:IsA("BasePart") then
			hitbox = nil
		end
	end

	if not hitbox then
		hitbox = self:CreateHitbox()
	end

	if not hitbox then
		return nil
	end

	local shouldConfigure = self.CreatedHitbox or (hitbox.Name == "Hitbox" and hitbox.Parent == instance)
	self:ConfigureHitbox(hitbox, shouldConfigure)

	self.Hitbox = hitbox
	return hitbox
end

function TreasureServer:CreateHitbox()
	local cf, size = self:GetBoundingInfo()
	if not cf or not size then
		return nil
	end

	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = size + HITBOX_PADDING
	hitbox.CFrame = cf
	hitbox.Anchored = true
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Massless = true
	hitbox.CastShadow = false
	hitbox.Parent = self.Instance
	self.CreatedHitbox = true

	local rootPart = self:GetFallbackPart()
	if rootPart and rootPart ~= hitbox and not rootPart.Anchored then
		hitbox.Anchored = false
		hitbox.CFrame = rootPart.CFrame
		local weld = Instance.new("WeldConstraint")
		weld.Name = "HitboxWeld"
		weld.Part0 = hitbox
		weld.Part1 = rootPart
		weld.Parent = hitbox
	end

	return hitbox
end

function TreasureServer:ConfigureHitbox(hitbox, makeInvisible)
	if not makeInvisible then
		return
	end

	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Transparency = 1
	hitbox.Massless = true
	hitbox.CastShadow = false

	if self.CreatedHitbox then
		local cf, size = self:GetBoundingInfo()
		if cf and size then
			hitbox.Size = size + HITBOX_PADDING
			hitbox.CFrame = cf
		end
	end
end

function TreasureServer:GetFallbackPart()
	if self.Instance:IsA("BasePart") then
		return self.Instance
	end

	if self.Instance.PrimaryPart then
		return self.Instance.PrimaryPart
	end

	if self.Instance:IsA("Model") then
		local primary = self.Instance:FindFirstChildWhichIsA("BasePart", true)
		if primary then
			return primary
		end
	end

	return nil
end

function TreasureServer:GetBoundingInfo()
	if self.Instance:IsA("BasePart") then
		return self.Instance.CFrame, self.Instance.Size
	end

	if self.Instance:IsA("Model") then
		local success, cf, size = pcall(self.Instance.GetBoundingBox, self.Instance)
		if success then
			return cf, size
		end
	end

	return nil, nil
end

function TreasureServer:OpenChest(player)
	if self.OpenedPlayers[player] then
		return
	end

	if TreasureService:HasCollectedChest(player, self.Instance) then
		self.OpenedPlayers[player] = true
		return
	end

	self.OpenedPlayers[player] = true

	TreasureService:MarkChestCollected(player, self.Instance)

	local chestPosition = self.Model:GetPivot().Position
	TreasureService.TreasureOpened:Fire(player, self.Model, self.Instance, chestPosition, self.Rewards.Currency or 150)

	self:GiveRewards(player)
end

function TreasureServer:GiveRewards(player)
	if self.Rewards.Currency and self.Rewards.Currency > 0 then
		CurrencyService:GiveCurrency(player, self.Rewards.Currency, "TreasureChest")
	end
end

function TreasureServer:Destruct()
	if self.ClickConnection then
		self.ClickConnection:Disconnect()
	end

	if self.ClickDetector then
		self.ClickDetector:Destroy()
	end

	if self.CreatedHitbox and self.Hitbox then
		self.Hitbox:Destroy()
	end
end

return TreasureService
