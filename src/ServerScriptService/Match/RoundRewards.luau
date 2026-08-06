local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))
local MatchState = require(script.Parent:WaitForChild("MatchState"))
local MatchRemotes = require(script.Parent:WaitForChild("MatchRemotes"))
local UnboxManager = require(ServerScriptService:WaitForChild("UnboxManager"))
local QuestManager = require(ServerScriptService:WaitForChild("QuestManager"))

local RoundSummary = MatchRemotes.RoundSummary

local seekers = MatchState.seekers
local hiders = MatchState.hiders
local kills = MatchState.kills
local found = MatchState.found
local foundTime = MatchState.foundTime

local function knitSvc(name)
	local ok, s = pcall(function()
		return Knit.GetService(name)
	end)
	return ok and s or nil
end
local function dsLevel() return knitSvc("LevelService") end
local function dsCoin() return knitSvc("CoinService") end
local function dsStats() return knitSvc("StatsService") end

local RoundRewards = {}

function RoundRewards.resolve(bossEventVictory, bossEventTimeout, seekersWin, resultText)
	local now = os.clock()
	local cfg = Constants.XP
	local roundStartTime = MatchState.roundStartTime

	local function isVIP(plr)
		if not cfg.VIP_GAMEPASS_ID or cfg.VIP_GAMEPASS_ID == 0 then
			return false
		end
		return plr:GetAttribute("IsVIP") == true
	end

	local function resolvePlayer(plr, role, survivedSecs, won, baseItems, baseCoins)
		local before
		before = dsLevel():Snapshot(plr)

		local breakdown = {}
		local baseTotal = 0
		for _, item in ipairs(baseItems) do
			table.insert(breakdown, item)
			baseTotal += item.amount
		end

		local grandTotal = baseTotal
		if won then
			if cfg.WIN_XP > 0 then
				table.insert(breakdown, { label = "Win", amount = cfg.WIN_XP })
				grandTotal += cfg.WIN_XP
			end

			local mult = isVIP(plr) and cfg.VIP_VICTORY_MULT or cfg.VICTORY_MULT
			local bonus = math.floor((baseTotal + cfg.WIN_XP) * mult)
			if bonus > 0 then
				table.insert(breakdown, { label = "Victory Bonus!", amount = bonus, mult = mult })
				grandTotal += bonus
			end
		else
			if cfg.LOSS_BONUS > 0 then
				table.insert(breakdown, { label = "Round Played", amount = cfg.LOSS_BONUS })
				grandTotal += cfg.LOSS_BONUS
			end
		end

		if grandTotal > 0 then
			dsLevel():Award(plr, grandTotal, role .. " round")
		end

		local after
		after = dsLevel():Snapshot(plr)
		local leveledUp = after.level > before.level
		if leveledUp then
			UnboxManager.grantLevelUpReward(plr)
		end

		local ccfg = Constants.Coins
		local coinsEarned = (baseCoins or 0) + (won and ccfg.WIN_BONUS or ccfg.LOSS_BONUS)
		if coinsEarned > 0 then
			dsCoin():Award(plr, coinsEarned, role .. " round")
		end

		if won then
			dsStats():AddWin(plr)
		end

		local survivedToEnd = (role == "Hider") and not found[plr] or false
		pcall(QuestManager.notifyRoundResolved, plr, role, won, survivedToEnd, coinsEarned)

		local summaryPayload = {
			winner = (bossEventVictory and "Everyone") or (bossEventTimeout and "Painting Boss") or (seekersWin and "Seeker" or "Hider"),
			headline = resultText,
			myRole = role,
			myUserId = plr.UserId,
			survivedSecs = survivedSecs,
			won = won,
			xpBreakdown = breakdown,
			totalXp = grandTotal,
			coinsEarned = coinsEarned,
			level = before.level,
			xp = before.xp,
			xpNeeded = before.xpNeeded,
			maxLevel = before.maxLevel,
			leveledUp = leveledUp,
		}
		RoundSummary:FireClient(plr, summaryPayload)
	end

	for _, sk in ipairs(seekers) do
		if sk and sk.Parent then
			local baseItems = {}
			local k = kills[sk] or 0
			if k > 0 then
				table.insert(baseItems, { label = k .. " Kill" .. (k == 1 and "" or "s"), amount = k * cfg.SEEKER_XP_PER_KILL })
			end

			local okR, errR = pcall(resolvePlayer, sk, "Seeker", nil, bossEventVictory or seekersWin, baseItems, 0)
			if not okR then
				warn("[MatchManager] seeker award failed for " .. sk.Name .. ": " .. tostring(errR))
			end
		end
	end

	for _, h in ipairs(hiders) do
		if h and h.Parent then
			local baseItems = {}
			local hiderWon = if bossEventVictory then true elseif bossEventTimeout then false else not seekersWin
			local endT = found[h] and (foundTime[h] or now) or now
			local survived = math.max(0, math.floor(endT - (roundStartTime > 0 and roundStartTime or now)))
			if survived > 0 then
				local label
				if found[h] then
					local m, s = math.floor(survived / 60), survived % 60
					label = string.format("Survived %dm %02ds", m, s)
				elseif hiderWon then
					label = "Survived the Round!"
				else
					label = "Outlasted the Round"
				end
				table.insert(baseItems, { label = label, amount = survived * cfg.HIDER_XP_PER_SECOND })
			end
			local okR, errR = pcall(
				resolvePlayer,
				h,
				"Hider",
				survived,
				hiderWon,
				baseItems,
				math.floor(survived / 10) * Constants.Coins.HIDER_COINS_PER_10S
			)
			if not okR then
				warn("[MatchManager] hider award failed for " .. h.Name .. ": " .. tostring(errR))
			end
		end
	end
end

return RoundRewards
