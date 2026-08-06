local SoundService = game:GetService("SoundService")

local masterGroup = SoundService:WaitForChild("Master")
local musicGroup = masterGroup:WaitForChild("Music")
local merchantMusicGroup = masterGroup:FindFirstChild("MerchantMusic")
if not merchantMusicGroup then
	merchantMusicGroup = Instance.new("SoundGroup")
	merchantMusicGroup.Name = "MerchantMusic"
	merchantMusicGroup.Parent = masterGroup
end
merchantMusicGroup.Volume = musicGroup.Volume

local ids = {
	UI = {
		ButtonHover = "rbxassetid://3199281218",
		ClickDown = "rbxassetid://6052547234",
		ClickUp = "rbxassetid://6052547865",
		Notification = "rbxassetid://421058925",
		SystemError = "rbxassetid://95806568566568",
		Info = "rbxassetid://17582299860",
		Success = "rbxassetid://97881181065416",
		Warning = "rbxassetid://124951621656853",
		Error = "rbxassetid://2865228231",
		Click = "rbxassetid://116902184912832",
		Open = "rbxassetid://6586979979",
		Close = "rbxassetid://17481582653",
		Hover = "rbxasset://sounds/switch.wav",
	},
	Ambience = {
		UnderWater = "rbxassetid://12365407721",
	},
	Music = {
		AquariumAmbient = {
			"rbxassetid://9043887091",
			"rbxassetid://9048045656",
			"rbxassetid://9044539308",
			"rbxassetid://1840745119",
			"rbxassetid://1839202236",
			"rbxassetid://1836078630",
			"rbxassetid://9046862941",
			"rbxassetid://9046865270",
			"rbxassetid://9047105533",
			"rbxassetid://9047104411",
			"rbxassetid://1845491059",
		},
		OpenOcean = {
			"rbxassetid://9042041852",
			"rbxassetid://1844431363",
		},
		Exhibits = "rbxassetid://1845146229",
		Spawn = "rbxassetid://9042042278",
		Tunnel = "rbxassetid://9042042428",
		Jellyfish = "rbxassetid://1836406623",
		Intro = "rbxassetid://96536010267513",
		Merchant = "rbxassetid://114220861100501",
	},
	Gameplay = {
		Beg = {
			Activate = "rbxassetid://88794684592123",
			Toss = "rbxassetid://2690828999",
			ImpactPrimary = "rbxassetid://9118700728",
			ImpactSecondary = "rbxassetid://535690488",
		},
	},
	Footsteps = {
		Dirt = "rbxassetid://178054124",
		Wood = "rbxassetid://177940988",
		Concrete = "rbxassetid://277067660",
		Grass = "rbxassetid://4776173570",
		Metal = "rbxassetid://4790537991",
		Sand = "rbxassetid://4777003964",
		Fabric = "rbxassetid://4776951843",
		Gravel = "rbxassetid://4776998555",
		Marble = "rbxassetid://4776962643",
	},
}

local areas = {
	DefaultSettings = {
		Volume = 0.5,
		FadeTime = 2,
		CrossfadeTime = 1,
		PlayOrder = "Sequential",
		Loop = false,
		Priority = 1,
	},
	Aquarium_Ambient = {
		Tracks = ids.Music.AquariumAmbient,
		Settings = {
			Volume = 0.4,
			FadeTime = 3,
			PlayOrder = "Shuffle",
		},
	},
	OpenOcean = {
		Tracks = ids.Music.OpenOcean,
		Settings = {
			Volume = 0.6,
			FadeTime = 2.5,
			Loop = true,
		},
	},
	Exhibits = {
		Tracks = { ids.Music.Exhibits },
		Settings = {
			Volume = 0.3,
			FadeTime = 4,
			CrossfadeTime = 2,
			PlayOrder = "Sequential",
			Loop = true,
		},
	},
	Spawn = {
		Tracks = { ids.Music.Spawn },
		Settings = {
			Volume = 0.3,
			FadeTime = 4,
			CrossfadeTime = 2,
			PlayOrder = "Sequential",
			Loop = true,
		},
	},
	Tunnel = {
		Tracks = { ids.Music.Tunnel },
		Settings = {
			Volume = 0.3,
			FadeTime = 4,
			CrossfadeTime = 2,
			PlayOrder = "Sequential",
			Loop = true,
		},
	},
	Jellyfish = {
		Tracks = { ids.Music.Jellyfish },
		Settings = {
			Volume = 0.3,
			FadeTime = 4,
			CrossfadeTime = 2,
			PlayOrder = "Sequential",
			Loop = true,
		},
	},
	Intro = {
		Tracks = { ids.Music.Intro },
		Settings = {
			Volume = 0.7,
			FadeTime = 1,
			CrossfadeTime = 0.5,
			Priority = 2,
			Loop = false,
		},
	},
	UnderWater = {
		Tracks = { ids.Ambience.UnderWater },
		Settings = {
			Volume = 0.3,
			FadeTime = 4,
			CrossfadeTime = 2,
			PlayOrder = "Sequential",
			Loop = true,
		},
	},
}

return {
	Ids = ids,
	Areas = areas,
	Defaults = {
		UIVolume = 0.4,
	},
	SoundGroups = {
		["Master"] = masterGroup,
		["SFX"] = masterGroup.SFX,
		["Music"] = musicGroup,
		["MerchantMusic"] = merchantMusicGroup,
	},

	Effects = {},
	Sources = {
		SFX = {
			ButtonHover = { ids.UI.ButtonHover },
			ClickDown = { ids.UI.ClickDown },
			ClickUp = { ids.UI.ClickUp },
			NotifSound = { ids.UI.Notification },
			Error = { ids.UI.SystemError },

			UnderWater = {
				Sound = { ids.Ambience.UnderWater },
				Stack = "atmosphere",
			},
		},
		Music = {
			IntroMusic = {
				Sound = { ids.Music.Intro },
				Stack = "Music",
				Volume = 2,
			},
			OpenOcean = {
				Sound = { ids.Music.OpenOcean[1] },
				Stack = "Music",
				Volume = 2,
			},
		},
		MerchantMusic = {
			Merchant = {
				Sound = { ids.Music.Merchant },
				Stack = "Merchant",
				Volume = 0.7,
				IgnoreStack = true,
			},
		},
	},
}

-- Sound.Shuffle : Random but same sound cannot be played twice
-- Sound.Random  : Plays it randomly
-- Sound.Volume

-- Track.Volume
-- Track.FadeIn
-- Track.FadeOut
-- Track.IgnoreEffects
-- Track.IgnoreStack
-- Track.ResetOnStop
-- Track.Volume DEF : 0.5
-- Track.Stack  DEF : "Default"
