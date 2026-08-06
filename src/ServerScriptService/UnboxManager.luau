local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local BoostConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BoostConfig"))
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local Luck = require(ServerScriptService:WaitForChild("SparkMod"):WaitForChild("Services"):WaitForChild("Luck"))

local UnboxManager = {}

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local function svc(n)
	local ok, s = pcall(function()
		return Knit.GetService(n)
	end)
	return ok and s or nil
end
local _inv, _level
local function invSvc()
	if not _inv then
		_inv = svc("DataService")
	end
	return _inv
end
local function levelSvc()
	if not _level then
		_level = svc("LevelService")
	end
	return _level
end

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local UnboxResult = Remotes:FindFirstChild("UnboxResult")
if not UnboxResult then
	UnboxResult = Instance.new("RemoteEvent")
	UnboxResult.Name = "UnboxResult"
	UnboxResult.Parent = Remotes
end

local GlobalUnbox = Remotes:FindFirstChild("GlobalUnbox")
if not GlobalUnbox then
	GlobalUnbox = Instance.new("RemoteEvent")
	GlobalUnbox.Name = "GlobalUnbox"
	GlobalUnbox.Parent = Remotes
end

local function announceGlobalUnbox(payload)
	if type(payload) ~= "table" then
		return
	end
	GlobalUnbox:FireAllClients(payload)
end

local ANNOUNCE_MIN_RANK = KnifeSkinManager.rarityRank("Secret")

local REEL_LENGTH = 50
local WINNER_INDEX = 46

local function getLuckMultiplier(player)
	local ok, multiplier = pcall(function()
		if Luck._Init then
			Luck._Init()
		end
		return Luck:GetEffective(player, BoostConfig.Channel)
	end)
	if ok and type(multiplier) == "number" and multiplier > 1 then
		return multiplier
	end
	return 1
end

local function buildReel(crateName, winnerId, luckMultiplier)
	local odds = KnifeSkinManager.getCrateOdds(crateName, nil, luckMultiplier)
	local weighted = {}
	local totalW = 0
	for _, o in ipairs(odds) do
		if o.id and o.id ~= "__secret__" and KnifeSkinManager.isCrateEligible(o.id) and (o.chance or 0) > 0 then
			totalW += o.chance
			weighted[#weighted + 1] = { id = o.id, cum = totalW }
		end
	end
	
	local flat = {}
	if totalW <= 0 then
		local pool = KnifeSkinManager.getCratePool(crateName)
		if pool then
			for _, id in ipairs(pool) do
				if KnifeSkinManager.isCrateEligible(id) then
					flat[#flat + 1] = id
				end
			end
		end
		if #flat == 0 then
			flat = { winnerId }
		end
	end
	
	local function pickWeighted()
		if totalW <= 0 then
			return flat[math.random(1, #flat)]
		end
		local r = math.random() * totalW
		for _, w in ipairs(weighted) do
			if r <= w.cum then
				return w.id
			end
		end
		return weighted[#weighted].id
	end
	
	local reel = {}
	for i = 1, REEL_LENGTH do
		reel[i] = pickWeighted()
	end
	reel[WINNER_INDEX] = winnerId
	
	local cells = {}
	for i, id in ipairs(reel) do
		local def = KnifeSkinManager.getSkin(id)
		cells[i] = {
			skinId = id,
			name = def and def.name or id,
			rarity = def and def.rarity or "Common",
		}
	end
	return cells
end

local function doOpenCrate(player, crateName, titleOverride, nerfTopTiers, forcedWinnerId, useLuck)
	local pool = KnifeSkinManager.getCratePool(crateName)
	if not pool then
		warn("[UnboxManager] no pool for crate: " .. tostring(crateName))
		return false
	end
	local luckMultiplier = if useLuck then getLuckMultiplier(player) else 1
	
	local winnerId
	if forcedWinnerId then
		winnerId = forcedWinnerId
	elseif nerfTopTiers then
		winnerId = KnifeSkinManager.rollSkinWithOdds(crateName, KnifeSkinManager.LEVELUP_RARITY_ODDS)
	else
		winnerId = KnifeSkinManager.rollSkin(crateName, luckMultiplier)
	end
	local effectId = KnifeSkinManager.rollEffect()
	
	local uid = nil
	uid = invSvc():AddWeapon(player, winnerId, effectId, false)
	
	local def = KnifeSkinManager.getSkin(winnerId)
	
	local rarityName = def and def.rarity or "Common"
	if KnifeSkinManager.rarityRank(rarityName) >= ANNOUNCE_MIN_RANK then
		announceGlobalUnbox({
			playerName = player.DisplayName,
			playerUserName = player.Name,
			skinName = def and def.name or winnerId,
			rarity = rarityName,
			effect = effectId,
			effectName = KnifeSkinManager.effectName(effectId),
		})
	end
	
	UnboxResult:FireClient(player, {
		crateName = crateName,
		titleOverride = titleOverride,
		reel = buildReel(crateName, winnerId, luckMultiplier),
		winnerIndex = WINNER_INDEX,
		won = {
			uid = uid,
			skinId = winnerId,
			name = def and def.name or winnerId,
			rarity = def and def.rarity or "Common",
			effect = effectId,
			effectName = KnifeSkinManager.effectName(effectId),
		},
	})
	return true
end

function UnboxManager.openCrate(player, crateName)
	return doOpenCrate(player, crateName, nil, false, nil, true)
end

function UnboxManager.openCrateAsReward(player, crateName, title)
	return doOpenCrate(player, crateName, title or "Daily Reward", false)
end

function UnboxManager.openLegendaryReward(player, crateChoices, title)
	crateChoices = crateChoices or { "Brainrot Crate", "Silver Crate", "Wooden Crate" }
	
	local candidates = {}
	for _, crateName in ipairs(crateChoices) do
		local pool = KnifeSkinManager.getCratePool(crateName)
		if pool then
			local legendaries = {}
			for _, id in ipairs(pool) do
				local def = KnifeSkinManager.getSkin(id)
				if def and def.rarity == "Legendary" and KnifeSkinManager.isCrateEligible(id) then
					legendaries[#legendaries + 1] = id
				end
			end
			if #legendaries > 0 then
				candidates[#candidates + 1] = { crate = crateName, legendaries = legendaries }
			end
		end
	end
	if #candidates == 0 then
		warn("[UnboxManager] openLegendaryReward: no crate with an eligible Legendary")
		return false
	end
	local pick = candidates[math.random(1, #candidates)]
	local winnerId = pick.legendaries[math.random(1, #pick.legendaries)]
	return doOpenCrate(player, pick.crate, title or "Daily Reward", false, winnerId)
end

local LEVELUP_CRATE_BANDS = {
	{
		minLevel = 20,
		choices = { { crate = "Wooden Crate", weight = 30 }, { crate = "Silver Crate", weight = 50 }, { crate = "Golden Crate", weight = 30 } },
	},
	{ minLevel = 10, choices = { { crate = "Wooden Crate", weight = 50 }, { crate = "Silver Crate", weight = 50 } } },
	{ minLevel = 1, choices = { { crate = "Wooden Crate", weight = 80 }, { crate = "Wooden Crate", weight = 20 } } },
}

local function rollLevelUpCrate(player)
	local level = 1
	local snap
	snap = levelSvc():Snapshot(player)
	if snap and snap.level then
		level = snap.level
	end
	
	local band
	for _, b in ipairs(LEVELUP_CRATE_BANDS) do
		if level >= b.minLevel then
			band = b
			break
		end
	end
	if not band then
		band = LEVELUP_CRATE_BANDS[#LEVELUP_CRATE_BANDS]
	end
	
	local total = 0
	for _, c in ipairs(band.choices) do
		total += c.weight
	end
	local r = math.random() * total
	local acc = 0
	for _, c in ipairs(band.choices) do
		acc += c.weight
		if r <= acc then
			return c.crate
		end
	end
	return band.choices[1].crate
end

local pendingLevelUpRewards = {}

local LevelUpReward = Remotes:FindFirstChild("LevelUpReward")
if not LevelUpReward then
	LevelUpReward = Instance.new("RemoteEvent")
	LevelUpReward.Name = "LevelUpReward"
	LevelUpReward.Parent = Remotes
end

function UnboxManager.grantLevelUpReward(player)
	if not player then
		return
	end
	pendingLevelUpRewards[player.UserId] = (pendingLevelUpRewards[player.UserId] or 0) + 1
end

LevelUpReward.OnServerEvent:Connect(function(player)
	local owed = pendingLevelUpRewards[player.UserId] or 0
	if owed <= 0 then
		return
	end
	
	if player:GetAttribute("Unboxing") then
		return
	end
	local crateName = rollLevelUpCrate(player)
	local ok = doOpenCrate(player, crateName, "Level Up Reward", true)
	if ok then
		pendingLevelUpRewards[player.UserId] = owed - 1
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	pendingLevelUpRewards[plr.UserId] = nil
end)

return UnboxManager
