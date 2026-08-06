local ColoringBookConfig = {}

ColoringBookConfig.ENABLED = true

ColoringBookConfig.FOLDER_NAME = "ColoringBook"

ColoringBookConfig.CLICK_DISTANCE = 24

ColoringBookConfig.DEFAULT_PAGE_REWARD = 100

ColoringBookConfig.REWARDS = {}

function ColoringBookConfig.getPageReward(mapName, pageId)
	local perMap = ColoringBookConfig.REWARDS[mapName]
	if perMap and perMap[pageId] ~= nil then
		return perMap[pageId]
	end
	
	return ColoringBookConfig.DEFAULT_PAGE_REWARD
end

ColoringBookConfig.ICONS = {
	Default = {
		parts = {
			"rbxassetid://79441882784357",
			"rbxassetid://109031754654995",
			"rbxassetid://125456353581925",
			"rbxassetid://99985445406875",
			"rbxassetid://86494908753037",
		},
		complete = "rbxassetid://118466142534244",
	},
	["Night Shift"] = {
		parts = {
			"rbxassetid://132638362598163",
			"rbxassetid://110087649412652",
			"rbxassetid://121822885783372",
			"rbxassetid://90155936303118",
			"rbxassetid://112683904334508",
		},
		complete = "rbxassetid://102951622867384",
	},
	["Grocery Store"] = {
		parts = {
			"rbxassetid://105668524431508",
			"rbxassetid://105643243900539",
			"rbxassetid://90547097632643",
			"rbxassetid://139309053118814",
			"rbxassetid://121445378582903",
		},
		complete = "rbxassetid://75998003075364",
	},
	["Oversized PC"] = {
		parts = {
			"rbxassetid://76703708087828",
			"rbxassetid://129651951156166",
			"rbxassetid://72961612522380",
			"rbxassetid://106749973706149",
			"rbxassetid://83087591997395",
		},
		complete = "rbxassetid://107319633388961",
	},
	["Party Hall"] = {
		parts = {
			"rbxassetid://115650974785313",
			"rbxassetid://98415538923565",
			"rbxassetid://103794143783525",
			"rbxassetid://83097622135769",
			"rbxassetid://130063670836110",
		},
		complete = "rbxassetid://113861383955981",
	},
	["School"] = {
		parts = {
			"rbxassetid://137079102478254",
			"rbxassetid://106568440591033",
			"rbxassetid://118757535138191",
			"rbxassetid://108630408845518",
			"rbxassetid://108698569139388",
		},
		complete = "rbxassetid://88071652244703",
	},
	["Island"] = {
		parts = {
			"rbxassetid://86075516850831",
			"rbxassetid://79546684315557",
			"rbxassetid://95114752199021",
			"rbxassetid://97589996253636",
			"rbxassetid://135523055392085",
		},
		complete = "rbxassetid://84033971631835",
	},
	["City"] = {
		parts = {
			"rbxassetid://130806233608297",
			"rbxassetid://115296299865514",
			"rbxassetid://135176872559807",
			"rbxassetid://85895120188454",
			"rbxassetid://108287084503155",
		},
		complete = "rbxassetid://103988934857737",
	},
	["Back Rooms"] = {
		parts = {
			"rbxassetid://126815388761257",
			"rbxassetid://135438761008691",
			"rbxassetid://128265168894798",
			"rbxassetid://82855035046555",
			"rbxassetid://102846342144991",
		},
		complete = "rbxassetid://73320311240181",
	},
	["Military Farm"] = {
		parts = {
			"rbxassetid://82837115817052",
			"rbxassetid://77817545250598",
			"rbxassetid://120605015978984",
			"rbxassetid://105864972882727",
			"rbxassetid://131975338465655",
		},
		complete = "rbxassetid://124489053366957",
	},
	["Pyramids"] = {
		parts = {
			"rbxassetid://116798456373942",
			"rbxassetid://83132059504360",
			"rbxassetid://118940977469888",
			"rbxassetid://132788324317648",
			"rbxassetid://87248908271718",
		},
		complete = "rbxassetid://101894947520660",
	},
}

function ColoringBookConfig.getIcons(mapName)
	return ColoringBookConfig.ICONS[mapName] or ColoringBookConfig.ICONS.Default
end

ColoringBookConfig.MAP_REWARDS = {
	["Back Rooms"] = {
		first = { kind = "killEffect", id = "haunteddoor", name = "Haunted Door" },
	},
	["City"] = {
		first = { kind = "killEffect", id = "crushedbuilding", name = "Crushed Building" },
	},
	["Grocery Store"] = {
		first = { kind = "knife", id = "shopping", name = "Shopping Knife" },
	},
	["Island"] = {
		first = { kind = "title", id = "islander", name = "Islander" },
	},
	["Military Farm"] = {
		first = { kind = "knife", id = "military", name = "Military Knife" },
	},
	["Night Shift"] = {
		first = { kind = "pose", id = "playingdead", name = "Playing Dead" },
	},
	["Party Hall"] = {
		first = { kind = "pose", id = "backward", name = "Backward" },
	},
	["School"] = {
		first = { kind = "title", id = "student", name = "Student" },
	},
	["Oversized PC"] = {
		first = { kind = "knife", id = "intercoolerpc", name = "Intercooler PC Knife" },
	},
	["Pyramids"] = {
		first = { kind = "knife", id = "pyramid", name = "Pyramid Knife" },
	},
}

function ColoringBookConfig.getMapReward(mapName)
	return ColoringBookConfig.MAP_REWARDS[mapName]
end

ColoringBookConfig.CURRENCY_ICONS = {
	coins = "rbxassetid://87945704599777",
	fireworks = "rbxassetid://97593273862463",
}

return ColoringBookConfig
