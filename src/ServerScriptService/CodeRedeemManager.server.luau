-- CodeRedeemManager (server): redeem promo codes for rewards. The client (Settings > Code row) sends a
-- typed code via the RedeemCode remote; the server is authoritative -- it validates the code, checks the
-- player hasn't already redeemed it (persisted per-player via DataStore so it's once-per-player-ever and
-- survives rejoin/server hops), grants the reward, and replies with the outcome for the client to show.
--
-- Codes are matched case-insensitively (we upper-case both the input and the table keys). To add a code
-- later, just add an entry to CODES with its reward.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local _DataService, _CoinService
local function data()
	if not _DataService then
		local ok, s = pcall(function() return Knit.GetService("DataService") end)
		if ok then _DataService = s end
	end
	return _DataService
end
local function coins()
	if not _CoinService then
		local ok, s = pcall(function() return Knit.GetService("CoinService") end)
		if ok then _CoinService = s end
	end
	return _CoinService
end

-- ===== code table =====
-- key = the code the player types (stored UPPER-CASE; input is upper-cased before lookup so matching is
-- case-insensitive). Each entry describes its reward. Extend this table to add more codes.
-- Milestone codes use varied, branded wording (not a predictable "NMVISITS" sequence) so players can't
-- just guess the next one. The comment after each entry says which milestone it's for.
local CODES = {


	["4MILVISITS"]   = { coins = 1000 },  -- 4,000,000 visits
	["5MILVISITS"]   = { coins = 1100 },  -- 5,000,000 visits
	--["VISITS6M"]   = { coins = 1200 },  -- 6,000,000 visits
	--["LUCKY7VISITS"] = { coins = 1250 },  -- 7,000,000 visits
	--["VISITS8MIL"]   = { coins = 1300 },  -- 8,000,000 visits
	--["9MILVISITS"]   = { coins = 1400 },  -- 9,000,000 visits
	--["MEGA10MIL"]    = { coins = 1500 },  -- 10,000,000 visits

	-- ===== thumbs-up (likes) milestones =====
	["THANKYOU5K"]  = { coins = 700 },   -- 5,000 likes
	["6KTHANKYOU"]  = { coins = 800 },   -- 6,000 likes
	["LIKES7K"]     = { coins = 900 },   -- 7,000 likes
	["THANKYOU8K"]  = { coins = 1000 },  -- 8,000 likes
	["9KLIKED"]     = { coins = 1100 },  -- 9,000 likes
	["MEGA10KLIKES"]= { coins = 1200 },  -- 10,000 likes
	["FIREWORK"] = { coins = 100 },
	["NEWUPDATE"] = { coins = 750 },
	["COLORINGBOOKS"] = { coins = 1000 },
	["REVERSE"] = { coins = 500 },
}

-- ===== remotes =====
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
-- client -> server: a typed code string to redeem
local RedeemCode = Remotes:FindFirstChild("RedeemCode")
if not RedeemCode then
	RedeemCode = Instance.new("RemoteEvent")
	RedeemCode.Name = "RedeemCode"
	RedeemCode.Parent = Remotes
end
-- server -> client: redemption outcome { ok = bool, reason = string, codeName = string?, amount = number? }
-- reason is one of: "ok" (granted), "invalid" (unknown code), "already" (already redeemed), "empty".
local RedeemResult = Remotes:FindFirstChild("RedeemResult")
if not RedeemResult then
	RedeemResult = Instance.new("RemoteEvent")
	RedeemResult.Name = "RedeemResult"
	RedeemResult.Parent = Remotes
end

-- grant a code's reward to a player. Currently only coins; extend here for other reward kinds.
local function grantReward(player, reward)
	if reward.coins and reward.coins > 0 then
		coins():Credit(player, reward.coins, "code redeem")
	end
	if reward.fireworks and reward.fireworks > 0 then
		coins():CreditFireworks(player, reward.fireworks, "code redeem")
	end
end

-- per-player debounce so a mashed Claim button can't race two grants of the same code through.
local busy = {}

RedeemCode.OnServerEvent:Connect(function(player, rawCode)
	if not player or not player.Parent then return end
	if busy[player.UserId] then return end
	busy[player.UserId] = true
	local function finish() task.delay(0.5, function() busy[player.UserId] = nil end) end

	-- sanitize the input: must be a short-ish string; trim whitespace; upper-case for matching.
	if type(rawCode) ~= "string" then
		RedeemResult:FireClient(player, { ok = false, reason = "empty" })
		finish(); return
	end
	local code = rawCode:gsub("%s+", ""):upper()
	if code == "" or #code > 64 then
		RedeemResult:FireClient(player, { ok = false, reason = "empty" })
		finish(); return
	end

	local reward = CODES[code]
	if not reward then
		RedeemResult:FireClient(player, { ok = false, reason = "invalid" })
		finish(); return
	end

	local alreadyRedeemed = data():HasRedeemedCode(player, code)
	if alreadyRedeemed then
		RedeemResult:FireClient(player, { ok = false, reason = "already", codeName = code })
		finish(); return
	end

	data():MarkCodeRedeemed(player, code)
	grantReward(player, reward)
	data():Save(player)
	RedeemResult:FireClient(player, { ok = true, reason = "ok", codeName = code, amount = reward.coins or reward.fireworks, currency = reward.fireworks and "fireworks" or "coins" })
	finish()
end)

Players.PlayerRemoving:Connect(function(plr)
	busy[plr.UserId] = nil
end)
