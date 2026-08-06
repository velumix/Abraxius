local PoseConfig = {}

PoseConfig.MAX_EQUIPPED = 5

PoseConfig.POSES = {
	{
		id = "crouch",
		name = "Crouch",
		free = true,
		rarity = "Uncommon",
		order = 1,
		icon = "rbxassetid://133036923434939",
	},
	
	{
		id = "crawl",
		name = "Crawl",
		free = true,
		rarity = "Common",
		order = 2,
		icon = "rbxassetid://124122822571200",
	},
	
	{
		id = "raisehands",
		name = "Raise Hands",
		free = true,
		rarity = "Common",
		order = 3,
		icon = "rbxassetid://75626674555654",
	},
	
	{
		id = "tpose",
		name = "T-Pose",
		free = true,
		rarity = "Common",
		order = 4,
		icon = "rbxassetid://105179554062668",
	},
	
	{
		id = "star",
		name = "Star",
		free = false,
		price = 200,
		rarity = "Uncommon",
		order = 5,
		icon = "rbxassetid://134515924583170",
	},
	
	{
		id = "sit",
		name = "Sit",
		free = false,
		price = 330,
		rarity = "Rare",
		order = 6,
		icon = "rbxassetid://95469503967636",
	},
	
	{
		id = "laying",
		name = "Laying",
		free = false,
		price = 450,
		rarity = "Epic",
		order = 7,
		icon = "rbxassetid://81734738830120",
	},
	
	{
		id = "ononeknee",
		name = "On One Knee",
		free = false,
		rarity = "Rare",
		order = 8,
		icon = "rbxassetid://107935668198634",
	},

	{
		id = "crossedarms",
		name = "Crossed Arms",
		free = false,
		rarity = "Rare",
		order = 9,
		icon = "rbxassetid://128534538699793",
	},

	{
		id = "backward",
		name = "Backward",
		free = false,
		rarity = "Rare",
		order = 10,
		icon = "rbxassetid://97508809735003",
	},

	{
		id = "playingdead",
		name = "Playing Dead",
		free = false,
		rarity = "Rare",
		order = 11,
		icon = "rbxassetid://110815975759199",
	},
}

PoseConfig.POSE_BY_ID = {}
for _, p in ipairs(PoseConfig.POSES) do 
	PoseConfig.POSE_BY_ID[p.id] = p 
end

PoseConfig.DEFAULT_EQUIPPED = { "crouch", "crawl", "raisehands", "tpose" }

function PoseConfig.getPose(id) return PoseConfig.POSE_BY_ID[id] end

function PoseConfig.exists(id) return PoseConfig.POSE_BY_ID[id] ~= nil end

function PoseConfig.isFree(id)
	local p = PoseConfig.POSE_BY_ID[id]
	return p ~= nil and p.free == true
end

function PoseConfig.isPurchasable(id)
	local p = PoseConfig.POSE_BY_ID[id]
	return p ~= nil and not p.free and type(p.price) == "number" and p.price > 0
end

function PoseConfig.price(id)
	local p = PoseConfig.POSE_BY_ID[id]
	return p and p.price or nil
end

function PoseConfig.displayName(id)
	local p = PoseConfig.POSE_BY_ID[id]
	return p and p.name or tostring(id)
end

function PoseConfig.freeIds()
	local t = {}
	for _, p in ipairs(PoseConfig.POSES) do
		if p.free then t[#t + 1] = p.id end
	end
	return t
end

return PoseConfig
