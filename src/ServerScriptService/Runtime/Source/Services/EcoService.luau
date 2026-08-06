local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local DebrisConfig = require(ReplicatedStorage.Runtime.Config.Shared.Debris)

local MAP_CENTER = Vector3.new(-60, 50, 250)
local TRASH_SPAWN_TAG = "TrashSpawns"
local TRASH_SPAWN_SIZE = 5

local EcoService = {
	Name = "EcoService",
	TrashFolder = nil,
	LastSpawn = 0,
	SpawnAnchorParts = {},
	SpawnAnchorsDirty = true,
}

function EcoService:Setup()
	self.CurrencyService = Mince:Get("CurrencyService")

	self.TrashFolder = Instance.new("Folder")
	self.TrashFolder.Name = "OceanDebris"
	self.TrashFolder.Parent = workspace

	CollectionService:GetInstanceAddedSignal(TRASH_SPAWN_TAG):Connect(function()
		self.SpawnAnchorsDirty = true
	end)

	CollectionService:GetInstanceRemovedSignal(TRASH_SPAWN_TAG):Connect(function()
		self.SpawnAnchorsDirty = true
	end)

	RunService.Heartbeat:Connect(function()
		self:Update()
	end)
end

function EcoService:RefreshSpawnAnchors()
	if not self.SpawnAnchorsDirty then
		return
	end

	self.SpawnAnchorsDirty = false
	self.SpawnAnchorParts = {}

	local taggedInstances = CollectionService:GetTagged(TRASH_SPAWN_TAG)
	for _, instance in ipairs(taggedInstances) do
		if instance:IsA("BasePart") then
			table.insert(self.SpawnAnchorParts, instance)
		else
			for _, descendant in ipairs(instance:GetDescendants()) do
				if descendant:IsA("BasePart") then
					table.insert(self.SpawnAnchorParts, descendant)
				end
			end
		end
	end
end

function EcoService:GetSpawnAnchor()
	self:RefreshSpawnAnchors()
	local anchors = self.SpawnAnchorParts
	if #anchors == 0 then
		return nil
	end
	return anchors[math.random(1, #anchors)]
end

function EcoService:Update()
	local now = tick()
	if now - self.LastSpawn > DebrisConfig.SpawnSettings.SpawnInterval then
		self.LastSpawn = now
		self:SpawnBatch()
	end
end

function EcoService:SpawnBatch()
	local count = #self.TrashFolder:GetChildren()
	if count >= DebrisConfig.SpawnSettings.MaxItems then return end

	for i = 1, DebrisConfig.SpawnSettings.SpawnBatchSize do
		self:SpawnSingleItem()
	end
end

function EcoService:SpawnSingleItem()
	local anchor = self:GetSpawnAnchor()
	local rayOrigin
	local rayDirection = Vector3.new(0, -200, 0)

	if anchor and anchor.Parent then
		local halfSize = TRASH_SPAWN_SIZE * 0.5
		local offsetX = (math.random() * 2 - 1) * halfSize
		local offsetZ = (math.random() * 2 - 1) * halfSize
		local offset = anchor.CFrame.RightVector * offsetX + anchor.CFrame.LookVector * offsetZ
		local startY = anchor.Position.Y + 50
		rayOrigin = anchor.Position + offset + Vector3.new(0, startY - anchor.Position.Y, 0)
	else
		local range = 100
		local x = MAP_CENTER.X + math.random(-range, range)
		local z = MAP_CENTER.Z + math.random(-range, range)
		local startY = MAP_CENTER.Y
		rayOrigin = Vector3.new(x, startY, z)
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {self.TrashFolder, game.Players:GetPlayers()}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if rayResult and (rayResult.Instance:IsA("Terrain") or (rayResult.Instance:IsA("BasePart") and rayResult.Instance.CanCollide)) then
		self:CreateTrashItem(rayResult.Position + Vector3.new(0, 0.5, 0), rayResult.Normal)
	end
end

function EcoService:CreateTrashItem(position, normal)
	local template = self:PickRandomItem()
	if not template then return end

	local itemInstance = template:Clone()

	local randomRotation = CFrame.Angles(math.random() * math.pi, math.random() * math.pi, math.random() * math.pi)
	local targetCFrame = CFrame.new(position) * randomRotation

	itemInstance:PivotTo(targetCFrame)

	if itemInstance:IsA("Model") then
		for _, desc in pairs(itemInstance:GetDescendants()) do
			if desc:IsA("BasePart") then
				desc.Anchored = true
				desc.CanCollide = false
			end
		end
	elseif itemInstance:IsA("BasePart") then
		itemInstance.Anchored = true
		itemInstance.CanCollide = false
	end

	itemInstance.Parent = self.TrashFolder

	itemInstance:SetAttribute("Points", 1)

	CollectionService:AddTag(itemInstance, "Trash")
end

function EcoService:PickRandomItem()
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then return nil end

	local trashAssets = assets:FindFirstChild("Trash")
	if not trashAssets then return nil end

	local items = trashAssets:GetChildren()
	if #items == 0 then return nil end

	return items[math.random(1, #items)]
end

return EcoService
