local Items = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = ReplicatedStorage.Assets
local Gear = Assets.Gear
local Tools = Assets.Tools
local Cosmetics = Assets.Cosmetics
local Rarities = require(script.Parent.Shared.Rarities)

Items.DefaultRarity = "Common"
Items.Rarities = Rarities

local StarterPackPass = {
	Name = "Starter Pack",
	GamepassId = 1699543975,
	EntitlementAttribute = "StarterPackPass",
}

local MermaidPackPass = {
	Name = "Mermaid Pack",
	GamepassId = 1701874580,
	EntitlementAttribute = "MermaidPackPass",
}

local function getGearFolder()
	if Gear then
		return Gear
	end
	local assets = Assets or ReplicatedStorage:FindFirstChild("Assets")
	local gearFolder = assets:FindFirstChild("Gear")
	return gearFolder
end

local function getAttachmentName(slot)
	if slot == "DiveMask" then
		return "FaceFrontAttachment"
	end
	if slot == "Harness" then
		return "BodyFrontAttachment"
	end
	return "BodyFrontAttachment"
end

local function createDummyAccessory(itemName, slot)
	local gearFolder = getGearFolder()
	if not gearFolder then
		return nil
	end

	local accessory = Instance.new("Accessory")
	accessory.Name = itemName

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle:SetAttribute("GearVisibilityIgnore", true)
	handle.CanCollide = false
	handle.Anchored = false
	handle.Massless = true
	handle.Parent = accessory

	local attachment = Instance.new("Attachment")
	attachment.Name = getAttachmentName(slot)
	attachment.Parent = handle

	accessory.Parent = gearFolder
	return accessory
end

local function getGearAccessory(itemName, slot)
	local gearFolder = getGearFolder()
	if not gearFolder then
		return nil
	end

	local item = gearFolder:FindFirstChild(itemName)
	if item then
		return item
	end

	return createDummyAccessory(itemName, slot)
end

local function getToolsFolder()
	if Tools then
		return Tools
	end
	local assets = Assets or ReplicatedStorage:FindFirstChild("Assets")
	local toolsFolder = assets:FindFirstChild("Tools")
	return toolsFolder
end

local function createDummyTool(itemName)
	local toolsFolder = getToolsFolder()
	if not toolsFolder then
		return nil
	end

	local tool = Instance.new("Tool")
	tool.Name = itemName
	tool.RequiresHandle = false
	tool.CanBeDropped = false

	tool.Parent = toolsFolder
	return tool
end

local function getToolItem(itemName)
	local toolsFolder = getToolsFolder()
	if not toolsFolder then
		return nil
	end

	local item = toolsFolder:FindFirstChild(itemName)
	if item and item:IsA("Tool") then
		return item
	end

	return createDummyTool(itemName)
end

Items.Categories = {
	["Gear"] = {

		["Pink Dive Mask"] = {
			Rarity = "Uncommon",
			SortOrder = 10,
			Price = 100,
			Object = Gear["Pink Dive Mask"],
			Slot = "DiveMask",
			Stats = {},
			Description = "Clear underwater vision",
		},

		["Green Dive Mask"] = {
			Rarity = "Uncommon",
			SortOrder = 10,
			Price = 100,
			Object = Gear["Green Dive Mask"],
			Slot = "DiveMask",
			Stats = {},
			Description = "Clear underwater vision",
		},

		["Blue Dive Mask"] = {
			Rarity = "Uncommon",
			SortOrder = 10,
			Price = 100,
			Object = Gear["Blue Dive Mask"],
			Slot = "DiveMask",
			Stats = {},
			Description = "Clear underwater vision",
		},

		["White Dive Mask"] = {
			Rarity = "Uncommon",
			SortOrder = 10,
			Price = 100,
			Object = Gear["White Dive Mask"],
			Slot = "DiveMask",
			Stats = {},
			Description = "Clear underwater vision",
		},

		["Black Dive Mask"] = {
			Rarity = "Uncommon",
			SortOrder = 10,
			Price = 100,
			Object = Gear["Black Dive Mask"],
			Slot = "DiveMask",
			Stats = {},
			Description = "Clear underwater vision",
		},

		["Mermaid Eyes"] = {
			Rarity = "Epic",
			SortOrder = 15,
			Price = 0,
			HideOnEquip = true,
			Gamepass = MermaidPackPass,
			Object = getGearAccessory("MermaidEyes", "DiveMask"),
			Slot = "DiveMask",
			Stats = {},
			Description = "See clearly underwater without a mask",
		},

		["Starter Diving Set"] = {
			Rarity = "Common",
			SortOrder = 30,
			Price = 0,
			Object = {
				Harness = Gear["Basic Harness"],
				Tank = Gear["Small Oxygen Tank"],
			},
			Slot = "Harness",
			AutoEquips = { "Regulator" },
			Stats = {
				OxygenCapacity = 50,
				OxygenEfficiency = 1,
			},
			Description = "+50 air capacity",
		},

		["Mermaid Lungs"] = {
			Rarity = "Legendary",
			SortOrder = 35,
			Price = 0,
			HideOnEquip = true,
			Gamepass = MermaidPackPass,
			Object = getGearAccessory("MermaidLungs", "Harness"),
			Slot = "Harness",
			Stats = {
				UnderwaterRegen = true,
			},
			Description = "Breathe underwater without oxygen",
		},

		["Explorer Set"] = {
			Rarity = "Legendary",
			SortOrder = 30,
			Price = 0,
			Gamepass = "Explorer",
			Object = {
				Harness = Gear["RB80Harness"],
				Tank = Gear["RB80"],
			},
			Slot = "Harness",
			AutoEquips = { "RB80Loop" },
			Stats = {
				OxygenCapacity = 5000,
				OxygenEfficiency = 1,
			},
			Description = "The RB80 rebreather providing massive air capacity for extended deep-sea expeditions. +5000 Air Capacity.",
		},

		["JacketBCD"] = {
			Rarity = "Rare",
			SortOrder = 32,
			Price = 0,
			Gamepass = StarterPackPass,
			Object = Gear["JacketBCD"],
			Slot = "Harness",
			Stats = {
				OxygenCapacity = 500,
				OxygenEfficiency = 1,
			},
			Description = "+500 air capacity",
		},

		["SnorkelMask"] = {
			Rarity = "Uncommon",
			SortOrder = 33,
			Price = 0,
			Gamepass = StarterPackPass,
			Object = Gear["SnorkelMask"],
			Slot = "DiveMask",
			Stats = {},
			Description = "Starter pack snorkel mask.",
		},

		["Jointed Fins"] = {
			Rarity = "Rare",
			SortOrder = 34,
			Price = 0,
			Gamepass = StarterPackPass,
			Object = {
				Left = Gear["Jointed Left Fin"],
				Right = Gear["Jointed Right Fin"],
			},
			Slot = "Fins",
			Stats = {
				SwimSpeed = 0.3,
			},
			Description = "+30% swim speed",
		},

		["Basic Diving Set"] = {
			Rarity = "Uncommon",
			SortOrder = 30,
			Price = 500,
			Object = {
				Harness = Gear["Basic Harness"],
				Tank = Gear["Basic Oxygen Tank"],
			},
			Slot = "Harness",
			AutoEquips = { "Regulator" },
			Stats = {
				OxygenCapacity = 200,
				OxygenEfficiency = 0.8,
			},
			Description = "+200 air capacity and has poor efficiency.",
		},

		["Cave Sidemount Set"] = {
			Rarity = "Rare",
			SortOrder = 30,
			Price = 900,
			Object = {
				Harness = Gear["SidemountTanks"],
				Tank = Gear["SidemouontHarness"],
			},
			Slot = "Harness",
			AutoEquips = { "Regulator" },
			Stats = {
				OxygenCapacity = 500,
				OxygenEfficiency = 1,
			},
			Description = "+500 air capacity, streamlined configuration for overhead environments.",
		},

		["Military Rebreather Set"] = {
			Rarity = "Epic",
			SortOrder = 30,
			Price = 4500,
			Object = {
				Harness = Gear["ChestRebreather"],
				Tank = Gear["RebreatherMask"],
			},
			Slot = "Harness",
			Stats = {
				OxygenCapacity = 2000,
				OxygenEfficiency = 1.2,
			},
			Description = "+2000 air capacity, used by military divers for special types of diving.",
		},

		["Double Tanks"] = {
			Rarity = "Rare",
			SortOrder = 30,
			Price = 1200,
			Object = {
				Harness = Gear["DoubleTanks"],
			},
			Slot = "Harness",
			AutoEquips = { "Regulator" },
			Stats = {
				OxygenCapacity = 1000,
				OxygenEfficiency = 1,
			},
			Description = "+1000 air capacity, used by military divers for special types of diving.",
		},

		["Regulator"] = {
			Rarity = "Common",
			Price = 0,
			Object = Gear["Regulator"],
			Slot = "Regulator",
			Hidden = true,
			Stats = {},
			Description = "Breathing device",
		},

		["RB80Loop"] = {
			Rarity = "Epic",
			Price = 1500,
			Object = Gear["RB80Loop"],
			Slot = "Regulator",
			Hidden = true,
			Stats = {},
			Description = "Breathing device",
		},

		["Basic Fins"] = {
			Rarity = "Common",
			SortOrder = 20,
			Price = 150,
			Object = {
				Left = Gear["Basic Left Fin"],
				Right = Gear["Basic Right Fin"],
			},
			Slot = "Fins",
			Stats = {
				SwimSpeed = 0.2,
			},
			Description = "+20% swim speed",
		},

		["Purple Mermaid Tail"] = {
			Rarity = "Epic",
			SortOrder = 20,
			Price = 0,
			Gamepass = MermaidPackPass,
			Object = Gear["PurpleMermaidTail"],
			Slot = "Fins",
			Stats = {
				SwimSpeed = 1,
			},
			Description = "+100% swim speed",
		},

		["Blacktip Reef Shark Tail"] = {
			Rarity = "Epic",
			SortOrder = 20,
			Price = 0,
			Gamepass = MermaidPackPass,
			Object = Gear["BlacktipTail"],
			Slot = "Fins",
			Stats = {
				SwimSpeed = 1,
			},
			Description = "+100% swim speed",
		},

		["Pink Mermaid Tail"] = {
			Rarity = "Legendary",
			SortOrder = 20,
			Price = 20000,
			Object = Gear["PinkMermaidTail"],
			Slot = "Fins",
			Stats = {
				SwimSpeed = 1,
			},
			Description = "+100% swim speed",
		},

		["Flame Mermaid Tail"] = {
			Rarity = "Epic",
			SortOrder = 20,
			Price = 0,
			Gamepass = MermaidPackPass,
			Object = Gear["FlameMermaidTail"],
			Slot = "Fins",
			Stats = {
				SwimSpeed = 1,
			},
			Description = "+100% swim speed",
		},

		["Deep Blue Mermaid Tail"] = {
			Rarity = "Epic",
			SortOrder = 20,
			Price = 0,
			Gamepass = MermaidPackPass,

			Object = Gear["DeepBlueMermaidTail"],
			Slot = "Fins",
			Stats = {
				SwimSpeed = 1,
			},
			Description = "+100% swim speed",
		},

		["Pearl Mermaid Tail"] = {
			Rarity = "Epic",
			SortOrder = 20,
			Price = 0,
			Gamepass = MermaidPackPass,
			Object = Gear["PearlMermaidTail"],
			Slot = "Fins",
			Stats = {
				SwimSpeed = 1,
			},
			Description = "+100% swim speed",
		},

		["Black Mermaid Tail"] = { --(admin only)
			Rarity = "Mythical",
			SortOrder = 20,
			Price = 9999999,
			Object = Gear["BlackMermaidTail"],
			Slot = "Fins",
			Hidden = true,
			Stats = {
				SwimSpeed = 4,
			},
			Description = "+400% swim speed",
		},
	},
	["Cosmetics"] = {

		--[[["Grey Mermaid Tail"] = {
			SortOrder = 20,
			Price = 2000,
			--Gamepass = MermaidPackPass,

			Object = Gear["GreyMermaidTail"],
			Slot = "Fins",
			Stats = {
				SwimSpeed = 1,
			},
			Description = "+100% swim speed"
		},]]

		["Marine Fish & Sea Creature Encyclopedia"] = {
			Rarity = "Uncommon",
			SortOrder = 10,
			Price = 25,
			Object = Cosmetics and Cosmetics:FindFirstChild("Marine Fish & Sea Creature Encyclopedia", true),
			RobuxAssetId = 13550170787,
			Slot = "Hat",
			Description = "Wear the Marine Fish & Sea Creature Encyclopedia on your head.",
			ShortDescription = "Marine encyclopedia hat",
		},

		["Greatest Hammer"] = {
			Rarity = "Uncommon",
			SortOrder = 20,
			Price = 25,
			Object = Cosmetics and Cosmetics:FindFirstChild("Greatest Hammer", true),
			RobuxAssetId = 12385336324,
			Slot = "Hat",
			Description = "A hammerhead shark head to crown your underwater Journey.",
			ShortDescription = "Greatest hammerhead look",
		},

		["Cetacean Trio"] = {
			Rarity = "Rare",
			SortOrder = 30,
			Price = 25,
			Object = Cosmetics and Cosmetics:FindFirstChild("Cetacean Trio", true),
			RobuxAssetId = 13015361566,
			Slot = "Hat",
			Description = "A playful whale trio that swims with you everywhere.",
			ShortDescription = "Hawaiian Dynamic Trio of whales!",
		},

		["HEXANCHUS!!!!!"] = {
			Rarity = "Rare",
			SortOrder = 40,
			Price = 25,
			Object = Cosmetics and Cosmetics:FindFirstChild("HEXANCHUS!!!!!", true),
			RobuxAssetId = 13032440197,
			Slot = "Hat",
			Description = "Channel deep‑sea cow shark vibes with the HEXANCHUS headpiece.",
			ShortDescription = "Bluntnose Cow shark head",
		},

		["Emperor Shrimp Plush"] = {
			Rarity = "Uncommon",
			SortOrder = 30,
			Price = 20,
			Object = Cosmetics and Cosmetics:FindFirstChild("Emperor Shrimp Plush", true),
			Slot = "Plushie",
			Description = "A tiny emperor shrimp plushie you can hold.",
			ShortDescription = "Emperor shrimp plushie",
			Stats = {},
		},

		["Humphead Wrasse"] = {
			Rarity = "Rare",
			SortOrder = 30,
			Price = 60,
			Object = Cosmetics and Cosmetics:FindFirstChild("Humphead Wrasse Plush", true),
			Slot = "Plushie",
			Description = "A humphead wrasse plushie you can hold.",
			ShortDescription = "Humphead wrasse plushie",
			Stats = {},
		},

		["Pelagic Thresher Shark Plush"] = {
			Rarity = "Epic",
			SortOrder = 30,
			Price = 100,
			Object = Cosmetics and Cosmetics:FindFirstChild("Pelagic Thresher Shark Plush", true),
			Slot = "Plushie",
			RobuxAssetId = 18796571778,
			Description = "A pelagic thresher shark plushie you can hold.",
			ShortDescription = "Thresher shark plushie",
			Stats = {},
		},

		["Sea Bunny Plush"] = {
			Rarity = "Uncommon",
			SortOrder = 30,
			Price = 40,
			Object = Cosmetics and Cosmetics:FindFirstChild("Sea Bunny Plush", true),
			Slot = "Plushie",
			Description = "A sea bunny plushie you can hold.",
			ShortDescription = "Sea bunny plushie",
			Stats = {},
		},

		["Whale Shark Plush"] = {
			Rarity = "Epic",
			SortOrder = 30,
			Price = 100,
			Object = Cosmetics and Cosmetics:FindFirstChild("Whale Shark Plush", true),
			Slot = "Plushie",
			RobuxAssetId = 126954305655138,
			Description = "A whale shark plushie you can hold.",
			ShortDescription = "Whale shark plushie",
			Stats = {},
		},

		["Humpback Whale Plush"] = {
			Rarity = "Epic",
			SortOrder = 30,
			Price = 100,
			Object = Cosmetics and Cosmetics:FindFirstChild("Humpback Whale Plush", true),
			Slot = "Plushie",
			Description = "A humpback whale plushie you can hold.",
			ShortDescription = "Humpback whale plushie",
			Stats = {},
		},
	},

	["Tools"] = {
		["Flashlight"] = {
			Rarity = "Common",
			SortOrder = 5,
			Price = 0,
			Object = getToolItem("Flashlight"),
			Slot = "Tool",
			Hidden = true,
			Description = "Toggleable underwater flashlight",
			ShortDescription = "Flashlight",
			Stats = {},
		},

		["Scud"] = {
			Rarity = "Uncommon",
			SortOrder = 10,
			Price = 0,
			Object = Tools and Tools:FindFirstChild("Scud", true),
			Slot = "Tool",
			RobuxAssetId = 6657534906,
			Description = "The AUEX Scud is a compact DPV that provides a slight boost to your swimming speed while submerged. Perfect for beginner divers.",
			ShortDescription = "Slight motorized swim boost",
			Stats = {
				SwimSpeed = 0.3,
			},
		},

		["Seeker"] = {
			Rarity = "Rare",
			SortOrder = 10,
			Price = 5000,
			Object = Tools and Tools:FindFirstChild("Seeker", true),
			Slot = "Tool",
			Description = "The AUEX Seeker is a compact DPV that provides a moderate boost to your swimming speed while submerged.",
			ShortDescription = "Motorized swim boost",
			Stats = {
				SwimSpeed = 0.5,
			},
		},

		["Explorer"] = {
			Rarity = "Epic",
			SortOrder = 10,
			Gamepass = "Explorer",
			Price = 0,
			Object = Tools and Tools:FindFirstChild("Explorer", true),
			Slot = "Tool",
			Description = "The AUEX Explorer is a high-performance DPV that offers a significant boost to your swimming speed, ideal for extended underwater exploration.",
			ShortDescription = "High-performance swim boost",
			Stats = {
				SwimSpeed = 0.7,
			},
		},

		["Expedition"] = {
			Rarity = "Legendary",
			SortOrder = 10,
			Price = 20000,
			Object = Tools and Tools:FindFirstChild("Expedition", true),
			Slot = "Tool",
			Description = "The AUEX Expedition is a high-performance Dual Motor DPV that offers an boost to your swimming speed, perfect for deep-sea exploration.",
			ShortDescription = "Advanced motorized swim boost",
			Stats = {
				SwimSpeed = 0.75,
			},
		},

		["TipJar"] = {
			Rarity = "Uncommon",
			SortOrder = 20,
			Price = 500,
			Object = Tools and Tools:FindFirstChild("TipJar", true),
			Slot = "Tool",
			Description = "A Normal Tip jar to collect tips from players.",
			ShortDescription = "Collect tips",
			Stats = {},
		},

		["Kitty TipJar"] = {
			Rarity = "Rare",
			SortOrder = 20,
			Price = 1500,
			Object = Tools and Tools:FindFirstChild("Kitty TipJar", true),
			Slot = "Tool",
			Description = "A cute kitty-themed jar to collect tips from players.",
			ShortDescription = "Collect more tips",
			Stats = {},
		},

		["Golden TipJar"] = {
			Rarity = "Epic",
			SortOrder = 20,
			Price = 6500,
			Object = Tools and Tools:FindFirstChild("Golden TipJar", true),
			Slot = "Tool",
			Description = "A shiny golden jar to collect tips from players.",
			ShortDescription = "Collect more tips",
			Stats = {},
		},
	},
}

Items.ByName = {}

for categoryName, categoryItems in pairs(Items.Categories) do
	for itemName, itemData in pairs(categoryItems) do
		assert(type(itemData.Rarity) == "string", string.format("Store item %q is missing Rarity", itemName))
		assert(
			Rarities[itemData.Rarity],
			string.format("Store item %q has unknown rarity %q", itemName, itemData.Rarity)
		)
		assert(not Items.ByName[itemName], string.format("Store item name %q is duplicated", itemName))

		Items.ByName[itemName] = {
			Category = categoryName,
			Data = itemData,
		}
	end
end

function Items.GetItem(itemName)
	local entry = Items.ByName[itemName]
	if not entry then
		return nil
	end

	return entry.Data, entry.Category
end

function Items.GetRarity(itemOrName)
	local itemData = itemOrName
	if type(itemOrName) == "string" then
		itemData = Items.GetItem(itemOrName)
	end

	local rarityName = itemData and itemData.Rarity or Items.DefaultRarity
	return Rarities[rarityName], rarityName
end

return Items
