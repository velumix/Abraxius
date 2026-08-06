local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local DOUBLE_COINS_GAMEPASS_ID = Constants.Gamepasses.DOUBLE_COINS
local RESTRICT_ATTR = "PaidRandomRestricted"

local CoinService = Knit.CreateService({
	Name = "CoinService",
	Client = {},
})

local DataService
local doubleCoinsOwned = {}

local function data()
	if not DataService then DataService = Knit.GetService("DataService") end
	return DataService
end

local function ownsDoubleCoins(player)
	local cached = doubleCoinsOwned[player.UserId]
	if cached ~= nil then return cached end
	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, DOUBLE_COINS_GAMEPASS_ID)
	end)
	local owns = ok and result or false
	doubleCoinsOwned[player.UserId] = owns
	return owns
end

local function isPaidRandomRestricted(player)
	if not player then return true end
	local v = player:GetAttribute(RESTRICT_ATTR)
	if v == nil then return true end
	return v == true
end

function CoinService:KnitStart()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(plr, passId, wasPurchased)
		if passId == DOUBLE_COINS_GAMEPASS_ID and wasPurchased then
			doubleCoinsOwned[plr.UserId] = true
		end
	end)
	Players.PlayerRemoving:Connect(function(plr)
		doubleCoinsOwned[plr.UserId] = nil
	end)
end

function CoinService:GetBalance(player)
	return data():GetCoins(player)
end

function CoinService:Award(player, amount, reason)
	if not player or amount == nil or amount <= 0 then return end
	if game.PrivateServerId ~= "" then return end
	if ownsDoubleCoins(player) then
		amount = amount * 2
	end
	data():AddCoins(player, amount, reason)
end

function CoinService:Credit(player, amount, reason)
	if not player or amount == nil or amount <= 0 then return end
	data():AddCoins(player, amount, reason)
end

function CoinService:CreditFromPack(player, amount, reason)
	if not player or amount == nil or amount <= 0 then return false end
	if isPaidRandomRestricted(player) then
		warn("[CoinService] withheld " .. tostring(amount) .. " pack coins from restricted player " .. player.Name .. " (" .. tostring(reason) .. ")")
		return false
	end
	data():AddCoins(player, amount, reason)
	return true
end

function CoinService:GrantVIPCoinsOnce(player, amount)
	if not player then return false end
	if isPaidRandomRestricted(player) then
		warn("[CoinService] withheld VIP pack coins from restricted player " .. player.Name)
		return false
	end
	return data():GrantVIPCoinsOnce(player, amount)
end

function CoinService:Spend(player, amount)
	if not player or amount == nil or amount < 0 then return false end
	return data():SpendCoins(player, amount)
end

function CoinService:GetFireworkBalance(player)
	return 0
end

function CoinService:AwardFireworks(player, amount, reason)
	if not player or type(amount) ~= "number" or amount <= 0 then
		warn(`[CoinService] AwardFireworks rejected for {player and player.Name or "?"}: amount={tostring(amount)}`)
		return
	end
	if game.PrivateServerId ~= "" then return end -- no farming event currency in private servers (mirrors :Award)
	local ok, err = pcall(function()
		data():AddCoins(player, amount, reason or "fireworks converted")
	end)
	if not ok then
		warn(`[CoinService] AwardFireworks coin conversion failed for {player.Name}: {err}`)
	end
end

function CoinService:CreditFireworks(player, amount, reason)
	if not player or type(amount) ~= "number" or amount <= 0 then
		warn(`[CoinService] CreditFireworks rejected for {player and player.Name or "?"}: amount={tostring(amount)}`)
		return
	end
	local ok, err = pcall(function()
		data():AddCoins(player, amount, reason or "fireworks converted")
	end)
	if not ok then
		warn(`[CoinService] CreditFireworks coin conversion failed for {player.Name}: {err}`)
	end
end

function CoinService:SpendFireworks(player, amount)
	return amount == 0
end

return CoinService
