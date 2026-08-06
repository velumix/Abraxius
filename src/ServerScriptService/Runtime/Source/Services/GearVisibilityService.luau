local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)
local Trove = require(Modules.Trove)

local CollectionService = game:GetService("CollectionService")

local LEGS = {
	"RightUpperLeg", "RightLowerLeg", "RightFoot",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
	"Right Leg", "Left Leg"
}

local GearVisibilityService = {
	Name = "GearVisibilityService",
	PlayerTroves = {},
	OriginalTransparency = {},
	OriginalEnabled = {},
	HiddenJackets = {},
	_updates = {},
}

function GearVisibilityService:ScheduleUpdate(player)
	if self._updates[player] then return end
	self._updates[player] = true
	task.defer(function()
		self._updates[player] = nil
		self:UpdatePlayerGearVisibility(player)
	end)
end

function GearVisibilityService:SetAccessoryVisibility(accessory, visible, isSwimming)
	local isTail = accessory:IsA("Model") and CollectionService:HasTag(accessory, "Tail")

	for _, descendant in ipairs(accessory:GetDescendants()) do
		if descendant:GetAttribute("GearVisibilityIgnore") == true then
			continue
		end
		local isValidType = false
		if isTail then
			isValidType = descendant:IsA("MeshPart")
		else
			isValidType = descendant:IsA("BasePart") or descendant:IsA("MeshPart") or descendant:IsA("UnionOperation")
		end

		if isValidType then
			if not visible then
				if self.OriginalTransparency[descendant] == nil then
					self.OriginalTransparency[descendant] = descendant.Transparency
				end
				descendant.Transparency = 1
			else
				local original = self.OriginalTransparency[descendant]
				if original ~= nil then
					descendant.Transparency = original
					self.OriginalTransparency[descendant] = nil
				else
					descendant.Transparency = 0
				end
			end
		elseif descendant:IsA("Decal") then
			if not visible then
				if self.OriginalTransparency[descendant] == nil then
					self.OriginalTransparency[descendant] = descendant.Transparency
				end
				descendant.Transparency = 1
			else
				local original = self.OriginalTransparency[descendant]
				if original ~= nil then
					descendant.Transparency = original
					self.OriginalTransparency[descendant] = nil
				else
					descendant.Transparency = 0
				end
			end
		elseif descendant:IsA("ParticleEmitter") then
			local shouldBeVisible = visible
			if accessory.Name == "Regulator" then
				shouldBeVisible = visible and isSwimming
			end

			if not shouldBeVisible then
				if self.OriginalEnabled[descendant] == nil then
					self.OriginalEnabled[descendant] = descendant.Enabled
				end
				descendant.Enabled = false
			else
				local original = self.OriginalEnabled[descendant]
				if original ~= nil then
					descendant.Enabled = original
					self.OriginalEnabled[descendant] = nil
				end
			end
		end
	end
end

function GearVisibilityService:SetLegVisibility(character, visible)
	for _, partName in ipairs(LEGS) do
		local part = character:FindFirstChild(partName)
		if part and (part:IsA("BasePart") or part:IsA("MeshPart")) then
			if not visible then
				if self.OriginalTransparency[part] == nil then
					self.OriginalTransparency[part] = part.Transparency
				end
				part.Transparency = 1
			else
				local original = self.OriginalTransparency[part]
				if original ~= nil then
					part.Transparency = original
					self.OriginalTransparency[part] = nil
				end
			end
		end
	end
end

function GearVisibilityService:UpdatePlayerGearVisibility(player)
	local character = player.Character
	if not character then return end

	local showIndoors = player:GetAttribute("ShowGearInObservatory")
	local swimming = player:GetAttribute("Swimming")
	local shouldShow = (showIndoors == true) or (swimming == true)

	local hasTail = false
	local jackets = {}

	for _, child in ipairs(character:GetChildren()) do
		local isGear = false
		local isTail = false

		if child:IsA("Accessory") then
			if child:GetAttribute("GearItem") == true then
				isGear = true
			elseif child.AccessoryType == Enum.AccessoryType.Jacket then
				table.insert(jackets, child)
			end
		elseif child:IsA("Model") and CollectionService:HasTag(child, "Tail") then
			isGear = true
			isTail = true
		end

		if isGear then
			local visible = shouldShow

			if isTail then
				if hasTail then
					visible = false
				else
					hasTail = true
				end
			end
			self:SetAccessoryVisibility(child, visible, swimming)
		end
	end

	local tailVisible = shouldShow and hasTail
	self:SetLegVisibility(character, not tailVisible)

	self.HiddenJackets[character] = self.HiddenJackets[character] or {}
	local hidden = self.HiddenJackets[character]

	if tailVisible then
		for _, jacket in ipairs(jackets) do
			jacket.Parent = nil
			table.insert(hidden, jacket)
		end
	else
		for i = #hidden, 1, -1 do
			local jacket = hidden[i]
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:AddAccessory(jacket)
			else
				jacket.Parent = character
			end
			table.remove(hidden, i)
		end
	end
end

function GearVisibilityService:OnCharacterAdded(player, character)
	local characterTrove = Trove.new()

	characterTrove:Add(function()
		if self.HiddenJackets[character] then
			for _, jacket in ipairs(self.HiddenJackets[character]) do
				jacket:Destroy()
			end
			self.HiddenJackets[character] = nil
		end
	end)

	local function onChildChanged(child)
		local isGear = false
		if child:IsA("Accessory") then
			if child:GetAttribute("GearItem") == true then
				isGear = true
			elseif child.AccessoryType == Enum.AccessoryType.Jacket then
				isGear = true
			end
		elseif child:IsA("Model") and CollectionService:HasTag(child, "Tail") then
			isGear = true
		end

		if isGear then
			self:ScheduleUpdate(player)
		end
	end

	characterTrove:Connect(character.ChildAdded, onChildChanged)
	characterTrove:Connect(character.ChildRemoved, onChildChanged)

	characterTrove:Connect(character.AncestryChanged, function()
		if not character.Parent then
			characterTrove:Destroy()
		end
	end)

	self:ScheduleUpdate(player)
end

function GearVisibilityService:OnPlayerAdded(player)
	local playerTrove = Trove.new()
	self.PlayerTroves[player] = playerTrove

	playerTrove:Connect(player:GetAttributeChangedSignal("ShowGearInObservatory"), function()
		self:ScheduleUpdate(player)
	end)

	playerTrove:Connect(player:GetAttributeChangedSignal("Swimming"), function()
		self:ScheduleUpdate(player)
	end)

	playerTrove:Connect(player.CharacterAdded, function(character)
		self:OnCharacterAdded(player, character)
	end)

	if player.Character then
		self:OnCharacterAdded(player, player.Character)
	end
end

function GearVisibilityService:Setup()
	local gearComm = Mince:GetEvent("GearVisibilityEvents")

	self.SetShowGearRequest = gearComm:Extend("SetShowGearRequest")
	self.SetShowGearRequest.Event:Connect(function(player, value)
		player:SetAttribute("ShowGearInObservatory", value)
	end)

	for _, player in ipairs(game.Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end

	game.Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)

	game.Players.PlayerRemoving:Connect(function(player)
		if self.PlayerTroves[player] then
			self.PlayerTroves[player]:Destroy()
			self.PlayerTroves[player] = nil
		end
	end)
end

function GearVisibilityService:GameStart()
end

return GearVisibilityService
