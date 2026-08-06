-- QuestConfig (shared, ReplicatedStorage): the catalog of quest TYPES and the reward scaling rule.
--
-- A quest TYPE is a template (e.g. "win N rounds"). When a quest is generated for a player, the server
-- picks a type and rolls a target value N from that type's `targets` list. The reward is a FIXED coin
-- amount that scales with how hard the rolled target is -- harder (bigger N / rarer condition) pays
-- more -- ALWAYS rounded to the nearest 50 and clamped to [50, 250]. So an easy quest (e.g. play 1
-- round) pays ~50-100 and a hard one (e.g. win 3 as Seeker) pays ~200-250.
--
-- Both the server (QuestManager) and the client (QuestClient) require this module: the server to
-- generate/track/award, the client to render the description text + icon.

local QuestConfig = {}

-- Reward bounds (coins). Every reward is rounded to the nearest STEP and clamped to [MIN, MAX].
QuestConfig.REWARD_MIN = 50
QuestConfig.REWARD_MAX = 250
QuestConfig.REWARD_STEP = 50

-- Global scale applied to each quest type's raw reward(N) before rounding/clamping. The per-type
-- reward(N) functions below were tuned for a 100-500 spread; this halves them into the 50-250 range
-- while preserving each quest's relative difficulty ordering (harder target still pays more).
QuestConfig.REWARD_SCALE = 0.5

-- How long a set of quests lasts before it refreshes (seconds).
QuestConfig.CYCLE_SECONDS = 30 * 60  -- 30 minutes

-- How many quests a player has at once (matches the 3 UI slots: Quest1/Quest2/Quest3).
QuestConfig.QUEST_COUNT = 3

-- Round a raw coin value to the nearest REWARD_STEP, clamped into [REWARD_MIN, REWARD_MAX].
function QuestConfig.roundReward(raw)
	local step = QuestConfig.REWARD_STEP
	local rounded = math.floor((raw / step) + 0.5) * step
	if rounded < QuestConfig.REWARD_MIN then rounded = QuestConfig.REWARD_MIN end
	if rounded > QuestConfig.REWARD_MAX then rounded = QuestConfig.REWARD_MAX end
	return rounded
end

-- ===== Quest TYPES =====
-- Each type:
--   id          unique string key (persisted; don't rename casually)
--   event       which gameplay signal advances it (see QuestManager): one of
--                 "roundPlayed"   (+1 each round the player participates in)
--                 "roundPlayedAs" (+1 each round played in a specific role; uses `role`)
--                 "win"           (+1 each round won, any role)
--                 "winAs"         (+1 each round won in a specific role; uses `role`)
--                 "kill"          (+1 each hider the player finds/eliminates as seeker)
--                 "surviveRound"  (+1 each round the player survives to the end as a hider)
--                 "playMinutes"   (+elapsed minutes of round time; target is in MINUTES)
--                 "coinsEarned"   (+coins earned from rounds; target is a COIN amount)
--   role        (only for *As types) "Hider" or "Seeker"
--   targets     list of possible target values to roll for N
--   weight      relative pick weight when generating (higher = more common). default 1.
--   icon        rbxassetid for the slot Icon (optional; falls back to a default)
--   reward(N)   returns the RAW reward for target N (pre-round/clamp). The harder the target, the more.
--   text(N)     returns the human-readable quest description shown in the slot.
--
-- The reward(N) functions are tuned (for a 100-500 spread) so the easiest target lands near 100-150 and
-- the hardest near 450-500; REWARD_SCALE (0.5) then maps them into the 50-250 range. Simple linear-ish
-- maps; tweak freely.

local DEFAULT_ICON = "rbxassetid://77554898933730"  -- reuse the InnerBar art as a neutral placeholder icon

QuestConfig.TYPES = {
	-- ---- play / participation (easy) ----
	{
		id = "play_rounds",
		event = "roundPlayed",
		targets = { 2, 3, 5, 8 },
		weight = 3,
		icon = DEFAULT_ICON,
		reward = function(n) return 60 + n * 40 end,       -- 2->140, 3->180, 5->260, 8->380
		text = function(n) return "Play " .. n .. " rounds" end,
	},
	{
		id = "play_minutes",
		event = "playMinutes",
		targets = { 5, 10, 15, 20 },                       -- minutes of round time
		weight = 3,
		icon = DEFAULT_ICON,
		reward = function(n) return 80 + n * 18 end,       -- 5->170, 10->260, 15->350, 20->440
		text = function(n) return "Play for " .. n .. " minutes" end,
	},

	-- ---- role participation (easy/medium) ----
	{
		id = "play_hider",
		event = "roundPlayedAs",
		role = "Hider",
		targets = { 2, 4, 6 },
		weight = 2,
		icon = DEFAULT_ICON,
		reward = function(n) return 80 + n * 45 end,       -- 2->170, 4->260, 6->350
		text = function(n) return "Play " .. n .. " rounds as a Hider" end,
	},
	{
		id = "play_seeker",
		event = "roundPlayedAs",
		role = "Seeker",
		targets = { 1, 2, 3 },                             -- seeker is rarer, so smaller targets
		weight = 2,
		icon = DEFAULT_ICON,
		reward = function(n) return 120 + n * 80 end,      -- 1->200, 2->280, 3->360
		text = function(n) return "Play " .. n .. " rounds as a Seeker" end,
	},

	-- ---- finding hiders (medium) ----
	{
		id = "find_hiders",
		event = "kill",
		targets = { 3, 5, 8, 12 },
		weight = 2,
		icon = DEFAULT_ICON,
		reward = function(n) return 90 + n * 28 end,       -- 3->174, 5->230, 8->314, 12->426
		text = function(n) return "Find " .. n .. " hiders" end,
	},

	-- ---- surviving (medium/hard) ----
	{
		id = "survive_rounds",
		event = "surviveRound",
		targets = { 1, 2, 3, 5 },
		weight = 2,
		icon = DEFAULT_ICON,
		reward = function(n) return 110 + n * 75 end,      -- 1->185, 2->260, 3->335, 5->485
		text = function(n) return "Survive " .. n .. (n == 1 and " round as a Hider" or " rounds as a Hider") end,
	},

	-- ---- winning (hard) ----
	{
		id = "win_rounds",
		event = "win",
		targets = { 1, 2, 3, 5 },
		weight = 2,
		icon = DEFAULT_ICON,
		reward = function(n) return 120 + n * 75 end,      -- 1->195, 2->270, 3->345, 5->495
		text = function(n) return "Win " .. n .. (n == 1 and " round" or " rounds") end,
	},
	{
		id = "win_hider",
		event = "winAs",
		role = "Hider",
		targets = { 1, 2, 3 },
		weight = 1,
		icon = DEFAULT_ICON,
		reward = function(n) return 150 + n * 90 end,      -- 1->240, 2->330, 3->420
		text = function(n) return "Win " .. n .. (n == 1 and " round as a Hider" or " rounds as a Hider") end,
	},
	{
		id = "win_seeker",
		event = "winAs",
		role = "Seeker",
		targets = { 1, 2, 3 },
		weight = 1,
		icon = DEFAULT_ICON,
		reward = function(n) return 170 + n * 100 end,     -- 1->270, 2->370, 3->470
		text = function(n) return "Win " .. n .. (n == 1 and " round as a Seeker" or " rounds as a Seeker") end,
	},

	-- ---- coins earned (medium) ----
	{
		id = "earn_coins",
		event = "coinsEarned",
		targets = { 100, 200, 350, 500 },                  -- coins earned from rounds
		weight = 1,
		icon = DEFAULT_ICON,
		reward = function(n) return 100 + n * 0.6 end,     -- 100->160, 200->220, 350->310, 500->400
		text = function(n) return "Earn " .. n .. " coins from rounds" end,
	},
}

-- index types by id for quick lookup (used by both server + client)
QuestConfig.TYPES_BY_ID = {}
for _, t in ipairs(QuestConfig.TYPES) do
	QuestConfig.TYPES_BY_ID[t.id] = t
end

-- Resolve a quest's display text from its stored {typeId, target}. Safe if the type was removed.
function QuestConfig.describe(typeId, target)
	local t = QuestConfig.TYPES_BY_ID[typeId]
	if not t then return "Unknown quest" end
	return t.text(target)
end

-- Resolve a quest's icon (falls back to the default).
function QuestConfig.iconFor(typeId)
	local t = QuestConfig.TYPES_BY_ID[typeId]
	return (t and t.icon) or DEFAULT_ICON
end

-- Compute the FINAL (rounded, clamped) reward for a {typeId, target}. The raw per-type value is scaled
-- by REWARD_SCALE first so the whole catalog lands in the configured [REWARD_MIN, REWARD_MAX] range.
function QuestConfig.rewardFor(typeId, target)
	local t = QuestConfig.TYPES_BY_ID[typeId]
	if not t then return QuestConfig.REWARD_MIN end
	return QuestConfig.roundReward(t.reward(target) * QuestConfig.REWARD_SCALE)
end

return QuestConfig
