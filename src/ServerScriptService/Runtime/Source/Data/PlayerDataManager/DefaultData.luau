return {

	Settings = {
		GraphicsQuality = 2,
		MusicVol = 0.5,
		SFXVol = 0.5,
		Caustics = false,
		CausticsSpeed = 0.5,
		Shadows = true,
		ShowNotifications = true,
		HeadMovementEnabled = true,
		ShowTrash = true,
		ShowGearInObservatory = false,
		FirstTimeChallengeCompleted = false
	},

	Statistics = {
		EventsParticipated = 0,
		CreaturesScanned = 0,
		AreasExplored = 0,
		PlaytimeMilestones = 0,
		CurrencyMilestones = 0,
		Scanned = 0,
		MinigamesWon = 0,
		DiveCount = 0,
		TrashCollected = 0,
	},

	Currency = {
		Balance = 0,
		TotalEarned = 0,
		TotalSpent = 0,
		LastIncomeTime = 0,
		IncomeStreak = 0,
		Sources = {
			PassiveIncome = 0,
			EventRewards = 0,
			ScanningRewards = 0,
			ExplorationRewards = 0,
			["Debris Cleanup"] = 0,
		}
	},

	EcoPoints = {
		Balance = 0,
		TotalEarned = 0,
		TotalSpent = 0,
		Sources = {}
	},

	AnalyticsTracking = {
		InterfaceRecords = {}
	}, 


	CollectedTrash = {},

	Discoveries = {},

	ZoneVisits = {},

	Achievements = {
		Progress = {},
		Unlocked = {},
		Claimed = {},
	},

	CollectedTreasures = {
		Items = {},
		LastResetDate = 0,
	},

	OwnedItems = {
		["Black Dive Mask"] = {
			Owned = true,
			Equipped = true,
			Category = "Gear",
			Slot = "DiveMask",
			Granted = true,
		},
		["Starter Diving Set"] = {
			Owned = true,
			Equipped = true,
			Category = "Gear",
			Slot = "Harness",
			Granted = true,
		},
	},

	Tipjar = {
		Ledger = {
			totalReceived = 0,
			donors = {},
			recent = {},
		},
		ListingVisibility = {
			hidden = {},
			version = 0,
			updatedAt = 0,
		},
	},

	TotalPlayTime = 0,
	SessionLength = 0,

	FirstOpen = true,
	__version = "initial"

}