local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Mince = require(ReplicatedStorage.Modules.Mince)
local StoreItems = require(ReplicatedStorage.Runtime.Config.StoreItems)
local SpeedBoostService = require(ServerStorage.Modules.Services.SpeedBoostService)

local DEFAULT_GEAR = {
	["Black Dive Mask"] = {
		Slot = "DiveMask",
		Category = "Gear",
	},
	["Starter Diving Set"] = {
		Slot = "Harness",
		Category = "Gear",
	},
}

local BASE_GEAR_STATS = {
	OxygenCapacity = 30,
	OxygenEfficiency = 0.5,
	MaxDepth = 50,
	SwimSpeed = 1.0,
	UnderwaterRegen = false,
}

local DefaultGearService = {
	Name = "DefaultGearService",
}

local function calculateStats(ownedItems)
	local stats = {
		OxygenCapacity = BASE_GEAR_STATS.OxygenCapacity,
		OxygenEfficiency = BASE_GEAR_STATS.OxygenEfficiency,
		MaxDepth = BASE_GEAR_STATS.MaxDepth,
		SwimSpeed = BASE_GEAR_STATS.SwimSpeed,
		UnderwaterRegen = BASE_GEAR_STATS.UnderwaterRegen,
	}

	for itemName, itemState in pairs(ownedItems or {}) do
		if itemState.Equipped then
			local itemData = StoreItems.Categories.Gear[itemName]
			if itemData and itemData.Stats then
				local itemStats = itemData.Stats
				stats.OxygenCapacity = stats.OxygenCapacity + (itemStats.OxygenCapacity or 0)
				stats.OxygenEfficiency = stats.OxygenEfficiency + (itemStats.OxygenEfficiency or 0)
				stats.MaxDepth = stats.MaxDepth + (itemStats.MaxDepth or 0)
				stats.SwimSpeed = stats.SwimSpeed + (itemStats.SwimSpeed or 0)
				if itemStats.UnderwaterRegen then
					stats.UnderwaterRegen = true
				end
			end
		end
	end

	return stats
end

local function applyCharacterStats(player, stats)
	local character = player.Character
	if not character then
		return
	end

	character:SetAttribute("MaxOxygen", stats.OxygenCapacity)

	local currentOxygen = character:GetAttribute("Oxygen") or 0
	if currentOxygen < stats.OxygenCapacity then
		character:SetAttribute("Oxygen", stats.OxygenCapacity)
	else
		character:SetAttribute("Oxygen", math.min(currentOxygen, stats.OxygenCapacity))
	end

	local baseDepletion = 1
	character:SetAttribute("OxygenDepletionRate", baseDepletion / stats.OxygenEfficiency)
	character:SetAttribute("UnderwaterRegen", stats.UnderwaterRegen == true)
	player:SetAttribute("MaxDepth", stats.MaxDepth)
	SpeedBoostService:SetBase(player, stats.SwimSpeed)
end

function DefaultGearService:EnsureDefaultGear(profileData)
	profileData.OwnedItems = profileData.OwnedItems or {}
	local ownedItems = profileData.OwnedItems
	local modified = false

	local equippedBySlot = {}
	for itemName, state in pairs(ownedItems) do
		if state and state.Equipped and state.Slot then
			equippedBySlot[state.Slot] = itemName
		end
	end

	for itemName, defaults in pairs(DEFAULT_GEAR) do
		local state = ownedItems[itemName]
		if not state then
			state = {
				Owned = true,
				Equipped = false,
				Category = defaults.Category,
				Slot = defaults.Slot,
				Granted = true,
			}
			ownedItems[itemName] = state
			modified = true
		else
			if state.Owned ~= true then
				state.Owned = true
				modified = true
			end

			if state.Category ~= defaults.Category then
				state.Category = defaults.Category
				modified = true
			end

			if state.Slot ~= defaults.Slot then
				state.Slot = defaults.Slot
				modified = true
			end
		end

		local slot = defaults.Slot
		local currentEquipped = slot and equippedBySlot[slot] or nil
		if not currentEquipped or currentEquipped == itemName then
			if not state.Equipped then
				state.Equipped = true
				modified = true
			end
			equippedBySlot[slot] = itemName
		end
	end

	return modified
end

function DefaultGearService:Setup()
	local PlayerDataManager = Mince:Get("PlayerDataManager")
	local KitService = Mince:Get("KitService")

	local function onProfileLoaded(player, profile)
		if not profile or not profile.Data then
			return
		end

		local ownedItems = profile.Data.OwnedItems
		local modified = self:EnsureDefaultGear(profile.Data)

		local stats = calculateStats(profile.Data.OwnedItems)
		profile.Data.GearStats = stats
		if modified then
			PlayerDataManager:UpdatePlayer(player, "OwnedItems")
		end
		applyCharacterStats(player, stats)

		if player.Character then
			KitService:BuildAndEquipKit(player, profile.Data.OwnedItems)
		end
	end

	PlayerDataManager.ProfileLoaded:Connect(onProfileLoaded)

	for _, player in ipairs(Players:GetPlayers()) do
		local profile = PlayerDataManager.Profiles and PlayerDataManager.Profiles[player]
		if profile then
			onProfileLoaded(player, profile)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			local profile = PlayerDataManager:GetProfile(player)
			if profile and profile.Data then
				local stats = calculateStats(profile.Data.OwnedItems)
				profile.Data.GearStats = stats
				applyCharacterStats(player, stats)

				if profile.Data.OwnedItems then
					KitService:BuildAndEquipKit(player, profile.Data.OwnedItems)
				end
			end
		end)
	end)
end

return DefaultGearService
