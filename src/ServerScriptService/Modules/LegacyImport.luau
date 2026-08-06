local DataStoreService = game:GetService("DataStoreService")

local INCLUDE_FLAG_STORES = true

local function num(v, fallback)
	return tonumber(v) or fallback
end

local function asTable(v, fallback)
	return (type(v) == "table") and v or fallback
end

local function legacyKey(userId)
	return "u_" .. userId
end

local STORES = {
	{
		name = "PlayerCoins_v2",
		map = function(v, data)
			data.Coins.Coins = num(v.coins, data.Coins.Coins)
			data.Coins.VIPCoinsGranted = v.vipCoinsGranted == true
		end,
	},
	{
		name = "PlayerLevels_v2",
		map = function(v, data)
			data.Levels.XP = num(v.xp, data.Levels.XP)
			data.Levels.Level = num(v.level, data.Levels.Level)
		end,
	},
	{
		name = "PlayerStats_v2",
		map = function(v, data)
			data.Stats.Wins = num(v.wins, data.Stats.Wins)
			data.Stats.TimePlayed = num(v.timePlayed, data.Stats.TimePlayed)
		end,
	},
	{
		name = "PlayerInventory_v1",
		map = function(v, data)
			local inv = data.Inventory
			inv.Weapons = asTable(v.items, inv.Weapons)
			inv.KillEffects = asTable(v.killEffects, inv.KillEffects)
			inv.Poses = asTable(v.poses, inv.Poses)
			inv.Bundles = asTable(v.bundles, inv.Bundles)

			data.GrantedReceipts = asTable(v.grantedReceipts, data.GrantedReceipts)

			data.Equipped.Weapon = v.equipped or data.Equipped.Weapon
			data.Equipped.KillEffect = v.equippedKillEffect or data.Equipped.KillEffect
			data.Equipped.Poses = asTable(v.equippedPoses, data.Equipped.Poses)
		end,
	},
	{
		name = "PlayerQuests_v1",
		map = function(v, data)
			data.Quests.Deadline = num(v.deadline, data.Quests.Deadline)
			data.Quests.Quests = asTable(v.quests, data.Quests.Quests)
		end,
	},
	{
		name = "DailyRewards_v1",
		map = function(v, data)
			data.DailyRewards.Streak = num(v.streak, data.DailyRewards.Streak)
			data.DailyRewards.LastClaim = num(v.lastClaim, data.DailyRewards.LastClaim)
		end,
	},
	{
		name = "RedeemedCodes_v1",
		map = function(v, data)
			data.RedeemedCodes = asTable(v, data.RedeemedCodes)
		end,
	},
}

if INCLUDE_FLAG_STORES then
	local FLAG_STORES = {
		{ name = "HiderTutorialSeen_v1", field = "HiderTutorialSeen" },
		{ name = "KnifeTutorialSeen_v1", field = "KnifeTutorialSeen" },
		{ name = "GroupChestCooldown_v1", field = "GroupChestCooldown" },
		{ name = "ObbyWinnerPadCooldown_v1", field = "ObbyWinnerPadCooldown" },
		{ name = "SeekerQueueAdCooldown_v1", field = "SeekerQueueAdCooldown" },
	}
	for _, fs in FLAG_STORES do
		table.insert(STORES, {
			name = fs.name,
			map = function(v, data)
				data.Flags[fs.field] = v
			end,
		})
	end
end

local LegacyImport = {}

function LegacyImport.Apply(userId, data)
	local sources = {}
	for _, store in STORES do
		local ok, value = pcall(function()
			return DataStoreService:GetDataStore(store.name):GetAsync(legacyKey(userId))
		end)
		if not ok then
			sources[store.name] = "error: " .. tostring(value)
		elseif value == nil then
			sources[store.name] = "empty"
		else
			local mok, merr = pcall(store.map, value, data)
			sources[store.name] = mok and "ok" or ("map error: " .. tostring(merr))
		end
	end
	return sources
end

return LegacyImport