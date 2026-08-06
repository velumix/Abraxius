local Constants = {}

local mainGameId = 9977954973
local devGameId = 10383935394

local devGameDevProduct = 3609195562
local mainGameDevProduct = 3609195183

local queueDevProduct = (game.GameId == mainGameId and mainGameDevProduct) or devGameDevProduct

Constants.QUEUE_CUSTOM_MAP_PRODUCT = queueDevProduct
Constants.CUSTOM_MAPS_ENABLED = false

Constants.RIG_TYPE = "R6"

Constants.Gamepasses = {
	SEEKER = 1862301038,        -- Seeker boost ("Be a Seeker" odds)
	DOUBLE_COINS = 1866812295,  -- 2x Coins
	VIP = 1867034514,           -- VIP (perks handled by VIPManager + double-XP via XP.VIP_GAMEPASS_ID)
	DOUBLE_VOTE = 1884347526,   -- 2x Map Vote
	CUSTOM_TAUNT = 1891127540,  -- Custom Taunt
}

Constants.Products = {
	-- coin packs (instant-grant)
	Coins500 = 3602353491,
	Coins1K = 3602353547,
	Coins5K = 3602353971,
	Coins10K = 3602354073,
	-- special-knife bundles
	FrozenKnife = 3606729742,     -- Frozen Knife (ShopClient SpecialKnife2)
	-- knife crates (x1)
	WoodenCrate = 3601833814,
	SilverCrate = 3601833916,
	GoldenCrate = 3601833996,
	BrainrotCrate = 3604206120,
	KawaiiKitchenCrate = 3605364388,
	BackroomsCrate = 3606120675,
	-- Elemental Crate (Robux-only; x1 / x3 / x10)
	ElementalCrateX1 = 3608973522,
	ElementalCrateX3 = 3608973496,
	ElementalCrateX10 = 3608973475,
	-- kill-effect crates
	NoviceCrate = 3606841768,
	EmotionalCrate = 3606841647,
}

Constants.LimitedTimePack = {
	Product = 3608964622,
	Knife = "dragonblade",
	Coins = 2000,
	Deadline = 1784379600,
}

Constants.XP = {
	SEEKER_XP_PER_KILL = 12,
	HIDER_XP_PER_SECOND = 1,
	WIN_XP = 30,
	LOSS_BONUS = 12,
	VICTORY_MULT = 1.5,
	VIP_VICTORY_MULT = 2.0,
	VIP_GAMEPASS_ID = Constants.Gamepasses.VIP,
	FRIEND_BONUS_MULT = 1.05,
	BASE_XP = 100,
	PER_LEVEL_XP = 50,
	MAX_LEVEL = 200,
}

Constants.Coins = {
	KILL_COINS = 20,
	HIDER_COINS_PER_10S = 1,
	WIN_BONUS = 15,
	LOSS_BONUS = 5,
}

return Constants
