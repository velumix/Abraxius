local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local function ensureRemote(name)
	local r = Remotes:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = Remotes
	end
	return r
end
local UnboxResult = ensureRemote("UnboxResult")

local _coin, _data
local function coinSvc()
	if not _coin then
		local ok, s = pcall(function() return Knit.GetService("CoinService") end)
		_coin = ok and s or nil
	end
	return _coin
end
local function dataSvc()
	if not _data then
		local ok, s = pcall(function() return Knit.GetService("DataService") end)
		_data = ok and s or nil
	end
	return _data
end

local REEL_LENGTH = 50
local WINNER_INDEX = 46
local DUPLICATE_REFUND_RATE = 0.15

local KillEffectCrateManager = {}

local function buildReel(crateName, winnerId)
	local odds = KillEffectManager.getCrateOdds(crateName)
	local weighted, totalW = {}, 0
	for _, o in ipairs(odds) do
		if (o.chance or 0) > 0 then
			totalW += o.chance
			weighted[#weighted + 1] = { id = o.id, cum = totalW }
		end
	end
	local function pick()
		if totalW <= 0 then return winnerId end
		local r = math.random() * totalW
		for _, w in ipairs(weighted) do if r <= w.cum then return w.id end end
		return weighted[#weighted].id
	end
	local cells = {}
	for i = 1, REEL_LENGTH do
		local id = pick()
		local def = KillEffectManager.getEffect(id)
		cells[i] = { itemKind = "killeffect", id = id, effectId = id, name = def and def.name or id, rarity = def and def.rarity or "Common" }
	end
	local wdef = KillEffectManager.getEffect(winnerId)
	cells[WINNER_INDEX] = { itemKind = "killeffect", id = winnerId, effectId = winnerId, name = wdef and wdef.name or winnerId, rarity = wdef and wdef.rarity or "Common" }
	return cells
end

local function refundDuplicate(player, crateName)
	local price = KillEffectManager.cratePrice(crateName)
	local refund = price and math.floor(price * DUPLICATE_REFUND_RATE) or 0
	if refund > 0 then
		coinSvc():Credit(player, refund, "duplicate kill effect refund")
	end
	return refund
end

function KillEffectCrateManager.openCrate(player, crateName)
	local winnerId = KillEffectManager.rollEffect(crateName)
	if not winnerId then return false end
	local def = KillEffectManager.getEffect(winnerId)
	local _, alreadyOwned = dataSvc():AddKillEffect(player, winnerId, false)
	local refund = alreadyOwned and refundDuplicate(player, crateName) or 0
	UnboxResult:FireClient(player, {
		crateName = crateName,
		itemKind = "killeffect",
		reel = buildReel(crateName, winnerId),
		winnerIndex = WINNER_INDEX,
		won = { itemKind = "killeffect", id = winnerId, effectId = winnerId, name = def and def.name or winnerId, rarity = def and def.rarity or "Common", duplicate = alreadyOwned == true, refundCoins = refund },
	})
	return true
end

return KillEffectCrateManager