local ICONS = {
	Default = "rbxassetid://13655042488",
	Discovery = "rbxassetid://13655043413",
	Economy = "rbxassetid://12932650415",
	Playtime = "rbxassetid://12932650415",
}

return {
	Categories = {
		Core = {
			Name = "Core Progression",
			Icon = ICONS.Playtime,
			Color = Color3.fromRGB(0, 170, 255),
		},
		Research = {
			Name = "Marine Research",
			Icon = ICONS.Discovery,
			Color = Color3.fromRGB(255, 170, 0),
		},
		Community = {
			Name = "Community & Support",
			Icon = ICONS.Economy,
			Color = Color3.fromRGB(120, 250, 160),
		},
	},

	Achievements = {
		debris_cleanup = {
			name = "Debris Cleanup",
			description = "Clean up your first piece of ocean debris.",
			category = "Core",
			order = 60,
			tracker = {
				type = "stat",
				key = "TrashCollected",
				target = 1,
			},
			rewards = {
				currency = 10,
			},
			icon = ICONS.Economy,
		},

		cleanup_crew = {
			name = "Cleanup Crew",
			description = "Clean up 25 pieces of ocean debris.",
			category = "Core",
			prerequisite = "debris_cleanup",
			order = 61,
			tracker = {
				type = "stat",
				key = "TrashCollected",
				target = 25,
			},
			rewards = {
				currency = 100,
			},
			icon = ICONS.Economy,
		},

		trash_tracker = {
			name = "Trash Tracker",
			description = "Clean up 100 pieces of ocean debris.",
			category = "Core",
			prerequisite = "cleanup_crew",
			order = 62,
			tracker = {
				type = "stat",
				key = "TrashCollected",
				target = 100,
			},
			rewards = {
				currency = 250,
			},
			icon = ICONS.Economy,
		},

		ocean_janitor = {
			name = "Ocean Janitor",
			description = "Clean up 1,000 pieces of ocean debris.",
			category = "Core",
			prerequisite = "trash_tracker",
			order = 63,
			tracker = {
				type = "stat",
				key = "TrashCollected",
				target = 1000,
			},
			rewards = {
				currency = 1000,
			},
			icon = ICONS.Economy,
		},

		debris_legend = {
			name = "Debris Legend",
			description = "Clean up 10,000 pieces of ocean debris.",
			category = "Core",
			prerequisite = "ocean_janitor",
			order = 64,
			tracker = {
				type = "stat",
				key = "TrashCollected",
				target = 10000,
			},
			rewards = {
				currency = 5000,
			},
			icon = ICONS.Economy,
		},

		first_dive = {
			name = "First Dive",
			description = "Enter the ocean for the first time.",
			category = "Core",
			order = 10,
			tracker = {
				type = "stat",
				key = "DiveCount",
				target = 1,
			},
			rewards = {
				currency = 50,
			},
			icon = ICONS.Playtime,
			badgeId = 1502931124601730,
		},

		intro_biologist = {
			name = "Intro Biologist",
			description = "Scan 5 unique fish.",
			category = "Research",
			tracker = {
				type = "discovery_total",
				target = 5,
			},
			rewards = {
				currency = 100,
			},
			icon = ICONS.Discovery,
		},

		first_gear = {
			name = "First Gear!",
			description = "Purchase your first piece of gear.",
			category = "Core",
			order = 20,
			tracker = {
				type = "stat",
				key = "PurchasesMade",
				target = 1,
			},
			rewards = {
				currency = 100,
			},
			icon = ICONS.Economy,
		},

		scanned_three = {
			name = "Scanned!",
			description = "Scan 25 unique fish.",
			category = "Research",
			prerequisite = "intro_biologist",
			tracker = {
				type = "discovery_total",
				target = 25,
			},
			rewards = {
				currency = 250,
			},
			icon = ICONS.Discovery,
		},

		marine_collector = {
			name = "Marine Collector",
			description = "Scan 100 unique fish.",
			category = "Research",
			prerequisite = "scanned_three",
			tracker = {
				type = "discovery_total",
				target = 100,
			},
			rewards = {
				currency = 750,
			},
			icon = ICONS.Discovery,
		},

		scan_stalwart = {
			name = "Scan Stalwart",
			description = "Complete 1,000 scans.",
			category = "Research",
			prerequisite = "marine_collector",
			tracker = {
				type = "stat",
				key = "Scanned",
				target = 1000,
			},
			rewards = {
				currency = 3000,
			},
			icon = ICONS.Discovery,
		},

		scan_legend = {
			name = "Scan Legend",
			description = "Complete 10,000 scans.",
			category = "Research",
			prerequisite = "scan_stalwart",
			tracker = {
				type = "stat",
				key = "Scanned",
				target = 10000,
			},
			rewards = {
				currency = 20000,
			},
			icon = ICONS.Discovery,
		},

		expert_marine_scientist = {
			name = "Expert Marine Scientist",
			description = "Fill out the entire encyclopedia.",
			category = "Research",
			prerequisite = "marine_collector",
			tracker = {
				type = "stat",
				key = "EncyclopediaComplete",
				target = 1,
			},
			rewards = {
				currency = 5000,
			},
			icon = ICONS.Discovery,
		},

		natural_phenomenon = {
			name = "Natural Phenomenon",
			description = "Discover your first event creature!",
			category = "Research",
			tracker = {
				type = "stat",
				key = "EventCreaturesFound",
				target = 1,
			},
			rewards = {
				currency = 500,
			},
			icon = ICONS.Discovery,
		},

		cave_diver = {
			name = "Cave Diver",
			description = "Reach the cave section.",
			category = "Core",
			prerequisite = "first_dive",
			order = 30,
			tracker = {
				type = "stat",
				key = "CaveVisits",
				target = 1,
			},
			rewards = {
				currency = 150,
			},
			icon = ICONS.Playtime,
		},

		making_waves = {
			name = "Making Waves",
			description = "Dive for 2 minutes",
			category = "Core",
			prerequisite = "first_dive",
			order = 40,
			tracker = {
				type = "playtime",
				target = 120,
			},
			rewards = {
				currency = 125,
			},
			icon = ICONS.Playtime,
		},

		aquarium_host = {
			name = "Aquarium Host",
			description = "Go to all sections of the aquarium",
			category = "Core",
			prerequisite = "first_dive",
			order = 50,
			tracker = {
				type = "stat",
				key = "AquariumSectionsVisited",
				target = 4,
			},
			rewards = {
				currency = 250,
			},
			icon = ICONS.Playtime,
		},

		team_researcher = {
			name = "Team Researcher",
			description = "Help complete a community challenge",
			category = "Community",
			tracker = {
				type = "stat",
				key = "CommunityChallengesCompleted",
				target = 1,
			},
			rewards = {
				currency = 300,
			},
			icon = ICONS.Economy,
		},

		outfitted = {
			name = "Outfitted",
			description = "Equip a cosmetic",
			category = "Community",
			tracker = {
				type = "stat",
				key = "CosmeticsEquipped",
				target = 1,
			},
			rewards = {
				currency = 100,
			},
			icon = ICONS.Economy,
		},

		supporter_of_the_sea = {
			name = "Supporter of the Sea",
			description = "Make your first donation.",
			category = "Community",
			tracker = {
				type = "stat",
				key = "DonationsMade",
				target = 1,
			},
			rewards = {
				currency = 200,
			},
			icon = ICONS.Economy,
		},

		conservationist = {
			name = "Conservationist",
			description = "Spend 1 hour in the experience.",
			category = "Core",
			prerequisite = "making_waves",
			order = 70,
			tracker = {
				type = "playtime",
				target = 3600,
			},
			rewards = {
				currency = 500,
			},
			icon = ICONS.Playtime,
		},

		ocean_guardian = {
			name = "Ocean Guardian",
			description = "Earn every achievement in game",
			category = "Core",
			prerequisite = "conservationist",
			order = 999,
			tracker = {
				type = "achievement_count",
				target = 26,
				excludeSelf = true,
			},
			rewards = {
				currency = 2000,
			},
			icon = ICONS.Playtime,
		},

		meet_developers = {
			name = "Meet the developers",
			description = "Meet a developer in-game.",
			category = "Community",
			tracker = {
				type = "stat",
				key = "MetDeveloper",
				target = 1,
			},
			rewards = {
				currency = 500,
			},
			icon = ICONS.Economy,
			badgeId = 742991464414464,
		},

		master_explorer = {
			name = "Master Explorer",
			description = "Discover all the secrets of the ocean.",
			category = "Research",
			tracker = {
				type = "stat",
				key = "MasterExplorer",
				target = 1,
			},
			rewards = {
				currency = 10000,
			},
			icon = ICONS.Discovery,
			badgeId = 2357600728566299,
		},

		rare_event = {
			name = "Rare Event",
			description = "Witness a rare event.",
			category = "Research",
			tracker = {
				type = "stat",
				key = "RareEvent",
				target = 1,
			},
			rewards = {
				currency = 750,
			},
			icon = ICONS.Discovery,
			badgeId = 3918212000587114,
		},

	},
}
