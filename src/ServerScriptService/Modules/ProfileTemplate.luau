local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PoseConfig = require(ReplicatedStorage.PoseConfig)

return {
	SchemaVersion = 3,
	Migration = { FromLegacy = false, At = 0, Sources = {} },

	Coins = { Coins = 300, VIPCoinsGranted = false },
	Fireworks = 0, -- limited-time 4th of July event currency
	FireworkCrateSpins = 0, -- purchased/free 4th of July crate rolls
	Levels = { Level = 1, XP = 0 },
	Stats = { Wins = 0, TimePlayed = 0 },

	Inventory = {
		Weapons = {},
		FavoriteWeapons = {},
		KillEffects = {},
		Poses = {},
		Bundles = {},
		Titles = {},
	},
	Equipped = {
		Weapon = "",
		KillEffect = "",
		Poses = { table.unpack(PoseConfig.DEFAULT_EQUIPPED) },
		Title = "",
	},
	GrantedReceipts = {},
	-- Durable audit records keyed by PurchaseId.
	ReceiptLedger = {},

	StarterPack = { ExpiresAt = 0, Purchased = false },

	Quests = { Deadline = 0, Quests = {} },
	DailyRewards = { Streak = 0, LastClaim = 0 },
	RedeemedCodes = {},
	Flags = {},
	CustomTaunt = { SoundId = "" },

	ColoringBooks = {},
	ColoringBookRewards = {},
}
