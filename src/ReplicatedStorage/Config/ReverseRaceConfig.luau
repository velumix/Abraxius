local ReverseRaceConfig = {}

ReverseRaceConfig.HIDE_SECONDS = 45
ReverseRaceConfig.PREVIEW_SECONDS = 12
ReverseRaceConfig.HUNT_SECONDS = 50
ReverseRaceConfig.REVEAL_SECONDS = 8  -- red-highlight reveal of a surviving target, per turn
ReverseRaceConfig.TRANSITION_SECONDS = 3
ReverseRaceConfig.ROLL_SECONDS = 3.5

ReverseRaceConfig.HUNTER_LIVES = 3
ReverseRaceConfig.PROP_TAG_COOLDOWN = 1.5
ReverseRaceConfig.WRONG_HIDER_TAG_COOLDOWN = 3
-- If true, a swing that hits nothing at all (pure air miss) also costs a hunter a life (1.5s cd).
ReverseRaceConfig.COUNT_AIR_MISS = false

-- Sound effects (played client-side by ReverseRaceHUDController). A blank id simply plays nothing, so
-- the wiring stays in place even if one is cleared.
ReverseRaceConfig.SOUNDS = {
	LoseLife = "rbxassetid://87519554692663",        -- hunter lost a single life (wrong swing, lives remain)
	LoseAllLives = "rbxassetid://1836260410",        -- hunter lost their LAST life (out -> spectator)
	HideCountdownTick = "rbxassetid://134410911353980",  -- clock tick at 3 / 2 / 1 seconds left to hide (matches the regular mode)
}

-- Overhead hunter-lives billboard. Adjust these to move/resize it, or (for full visual control) create
-- a BillboardGui at ReplicatedStorage.Assets.UI.ReverseRaceLives with ImageLabels named Heart1/Heart2/
-- Heart3 -- if that template exists it's cloned instead of building from these values.
ReverseRaceConfig.LIVES_BILLBOARD = {
	StudsOffset = Vector3.new(0, 5, 0), -- above the title's (0,3,0) slot so they stack
	Size = UDim2.fromScale(2.6, 0.75),
	MaxDistance = 60,
	HeartScale = 0.3, -- each heart's width, as a scale of the billboard height (kept square)
	Padding = 0.03,
	HeartIcon = "rbxassetid://124916248857231",
	BrokenIcon = "rbxassetid://109111589672848",
}

ReverseRaceConfig.MIN_PLAYERS = 2
ReverseRaceConfig.MAX_TARGETS = 14

ReverseRaceConfig.TEAM_FIND_POINTS = 10
ReverseRaceConfig.TEAM_FIND_COINS = 100

-- Flat coin boost awarded to the surviving hider when every hunter is eliminated (all out of lives,
-- or all left) during their turn. Not awarded in private servers.
ReverseRaceConfig.HUNTERS_ELIMINATED_COINS = 300

-- ===== XP (per Reverse Race round) =====
-- All XP is capped per round (CAP_NORMAL / CAP_VIP). Coins are separate and unaffected.
ReverseRaceConfig.XP = {
	ROUND_PLAYED = 12,          -- participation: +12 to everyone who played the round
	HIDER_SECONDS_PER_XP = 3,   -- hider turn: +1 XP per 3 seconds survived as the target
	HIDER_XP_PER_TICK = 1,
	HUNTER_FIND = 12,           -- +12 to the hunter who finds the target
	TEAM_FIND_PER_HUNTER = 6,   -- +6 to every active hunter on a successful find
	VICTORY = 30,               -- +30 to each member of the winning side of a turn
	-- Speed bonus for the finder, by how early in the hunt the target was found:
	SPEED_EARLY = 18,           -- found in the first 30% of the turn
	SPEED_MID = 10,             -- found in the middle 40% of the turn
	SPEED_LATE = 4,             -- found in the final 30% of the turn
	SPEED_EARLY_FRAC = 0.30,
	SPEED_MID_FRAC = 0.70,      -- <= this fraction is the "middle 40%"; above it is the "final 30%"
	CAP_NORMAL = 175,           -- max XP a normal player can earn per round
	CAP_VIP = 250,              -- max XP a VIP player can earn per round
}

local function bandLookup(bands, seconds)
	for _, band in ipairs(bands) do
		if seconds <= band.maxSeconds then
			return band.points, band.coins
		end
	end
	local last = bands[#bands]
	return last.points, last.coins
end

-- Hider survival reward: by seconds survived as the target. Coins = 10 x points.
ReverseRaceConfig.HIDER_REWARD_BANDS = {
	{ maxSeconds = 5, points = 5, coins = 50 },
	{ maxSeconds = 10, points = 9, coins = 90 },
	{ maxSeconds = 15, points = 13, coins = 130 },
	{ maxSeconds = 18, points = 18, coins = 180 },
	{ maxSeconds = 21, points = 23, coins = 230 },
	{ maxSeconds = 24, points = 28, coins = 280 },
	{ maxSeconds = math.huge, points = 30, coins = 300 },  -- survives the full hunt
}

-- Hunter find reward: by how fast they found the target. Coins = 10 x points. A find after 24s (or no
-- find at all -- "hunters fail") pays 0, since hunterReward returns 0,0 past the last band.
ReverseRaceConfig.HUNTER_REWARD_BANDS = {
	{ maxSeconds = 5, points = 30, coins = 300 },
	{ maxSeconds = 10, points = 28, coins = 280 },
	{ maxSeconds = 15, points = 25, coins = 250 },
	{ maxSeconds = 18, points = 23, coins = 230 },
	{ maxSeconds = 21, points = 16, coins = 160 },
	{ maxSeconds = 24, points = 10, coins = 100 },
}

function ReverseRaceConfig.hiderReward(survivedSeconds)
	return bandLookup(ReverseRaceConfig.HIDER_REWARD_BANDS, survivedSeconds)
end

function ReverseRaceConfig.hunterReward(findSeconds)
	if findSeconds == nil then
		return 0, 0
	end
	if findSeconds > 24 then
		return 0, 0
	end
	return bandLookup(ReverseRaceConfig.HUNTER_REWARD_BANDS, findSeconds)
end

ReverseRaceConfig.TEXT = {
	HIDE_TITLE = "Blend in and hide!",
	HIDER_ONBOARD_TITLE = "Blend in and hide!",
	HIDER_ONBOARD_SUB = "Paint yourself to match the map, choose a good hiding spot, rotate your pose, then lock in before the timer ends. When it is your turn, survive as long as possible to earn more points.",
	HUNTER_ONBOARD_TITLE = "Find the target hider!",
	HUNTER_ONBOARD_SUB = "Examine the hider shown on the pedestal, then search the map for that exact disguise. Finding them faster gives more points. Wrong guesses remove hunter lives.",
	PREVIEW_TITLE = "EXAMINE THE HIDER!",
	PREVIEW_SUB = "Memorize their color, pose, and disguise.",
	HUNT_TITLE = "FIND WHERE THEY ARE HIDING!",
	HUNTED_TITLE = "YOU ARE BEING HUNTED!",
	HUNTED_SUB = "Survive longer to earn more points.",
	PREVIEW_TARGET_TITLE = "Hunters are viewing your disguise!",
	PREVIEW_TARGET_SUB = "Get ready -- they're about to hunt you.",
	REVEAL_TITLE = "The hider survived!",
	REVEAL_TARGET_TITLE = "You survived!",
}

return ReverseRaceConfig
