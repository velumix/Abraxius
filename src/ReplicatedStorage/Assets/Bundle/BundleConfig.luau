return {
	DisplayCycleSeconds = 12,
	Bundles = {
		[1] = {
			Order = 1,
			Name = "Frozen Legends Bundle",
			Icon = "",
			AccentColor = Color3.fromRGB(90, 190, 255),
			PriceText = "NOT CONFIGURED",
			ProductId = 0, -- replace with this experience's developer product id
			StockEventId = "PAINT_BUNDLE_FROZEN", -- provision this id in SparkMod stock_items
			KnifeId = "frozenseer",
			Items = {
				{ Type = "Knife", Id = "frozenseer", Name = "Frozen Seer" },
				{ Type = "Kill Effect", Id = "frozen", Name = "Frozen" },
				{ Type = "Pose", Id = "ononeknee", Name = "On One Knee" },
			},
		},
		[2] = {
			Order = 2,
			Name = "Cosmic Hunter Bundle",
			Icon = "",
			AccentColor = Color3.fromRGB(135, 85, 255),
			PriceText = "NOT CONFIGURED",
			ProductId = 0, -- replace with this experience's developer product id
			StockEventId = "PAINT_BUNDLE_COSMIC", -- provision this id in SparkMod stock_items
			KnifeId = "galaxyseer",
			Items = {
				{ Type = "Knife", Id = "galaxyseer", Name = "Galaxy Seer" },
				{ Type = "Kill Effect", Id = "electrocute", Name = "Electrocute" },
				{ Type = "Pose", Id = "star", Name = "Star" },
			},
		},
		[3] = {
			Order = 3,
			Name = "Valentine Stalker Bundle",
			Icon = "",
			AccentColor = Color3.fromRGB(255, 90, 155),
			PriceText = "NOT CONFIGURED",
			ProductId = 0, -- replace with this experience's developer product id
			StockEventId = "PAINT_BUNDLE_VALENTINE", -- provision this id in SparkMod stock_items
			KnifeId = "roseflare",
			Items = {
				{ Type = "Knife", Id = "roseflare", Name = "Roseflare" },
				{ Type = "Kill Effect", Id = "confetti", Name = "Confetti" },
				{ Type = "Pose", Id = "sit", Name = "Sit" },
			},
		},
	},
}
