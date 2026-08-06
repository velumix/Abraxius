-- DailyRewardsConfig: the single source of truth for the daily-login reward track.
-- Read by BOTH the client (to render the day cards) and the server (to grant the reward), so the
-- displayed reward always matches what is actually granted.
--
-- Each entry = one day in the streak (Day 1 = REWARDS[1], Day 2 = REWARDS[2], ...). A player claims
-- one per day; the streak advances by 1 each claimed day and LOOPS back to Day 1 after the last day.
-- Missing a day (letting the 24h claim window lapse by a full extra day) resets the streak to Day 1.
--
-- Reward `kind` is one of:
--   "coins"             -> amount = number of coins to award
--   "crate"             -> crate = internal crate key (e.g. "Wooden Crate"); opens that crate
--   "knife"             -> skinId = a KnifeSkinManager skin id to grant
--   "random_legendary"  -> grants ONE random Legendary-rarity knife (server picks). Displayed with the
--                          generic SECRET-style mystery image so the exact knife is a surprise.
-- `label` is the text shown on the card under the icon (e.g. "500 Coins", "Basic Crate").
-- `icon`  is the rbxassetid for the card icon. Coins/crate icons reuse the in-game art.
--
-- NOTE: only this table needs editing to change the track (no code changes).

local DailyRewardsConfig = {}

-- seconds between claims, and the miss window. A claim becomes available 24h after the last claim;
-- if MORE than MISS_AFTER seconds pass since the last claim without claiming, the streak resets to 1.
DailyRewardsConfig.CLAIM_INTERVAL = 24 * 60 * 60   -- 24 hours between claims
DailyRewardsConfig.MISS_AFTER     = 48 * 60 * 60   -- miss a day (>48h since last claim) -> reset to Day 1

-- shared icon ids (reuse existing in-game art)
local COIN_ICON     = "rbxassetid://91783344342233"    -- coin stack icon
local BASIC_ICON    = "rbxassetid://107463946938232"   -- Basic / Wooden crate art
local GRAFFITI_ICON = "rbxassetid://112997424817621"   -- Graffiti / Silver crate art
local BRAINROT_ICON = "rbxassetid://127169457762280"   -- Brainrot crate art
local SECRET_ICON   = "rbxassetid://77573523807035"    -- generic mystery image (same as crate-unbox SECRET mask)

-- The reward track. Index = day number.
DailyRewardsConfig.REWARDS = {
	{ kind = "coins", amount = 200, label = "200 Coins", icon = COIN_ICON },                         -- Day 1
	{ kind = "crate", crate = "Wooden Crate",   label = "Basic Crate",    icon = BASIC_ICON },        -- Day 2
	{ kind = "coins", amount = 300, label = "300 Coins", icon = COIN_ICON },                         -- Day 3
	{ kind = "crate", crate = "Silver Crate",   label = "Graffiti Crate", icon = GRAFFITI_ICON },     -- Day 4
	{ kind = "coins", amount = 600, label = "600 Coins", icon = COIN_ICON },                         -- Day 5
	{ kind = "crate", crate = "Brainrot Crate", label = "Brainrot Crate", icon = BRAINROT_ICON },     -- Day 6
	{ kind = "random_legendary", label = "LEGENDARY", icon = SECRET_ICON },                       -- Day 7
}

function DailyRewardsConfig.dayCount()
	return #DailyRewardsConfig.REWARDS
end

-- reward for a given day number (1-based). Loops past the end so the track repeats.
function DailyRewardsConfig.rewardForDay(day)
	local n = #DailyRewardsConfig.REWARDS
	if n == 0 then return nil end
	local idx = ((day - 1) % n) + 1
	return DailyRewardsConfig.REWARDS[idx]
end

return DailyRewardsConfig
