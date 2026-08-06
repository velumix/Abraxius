local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local FireworkCrateConfig = require(ReplicatedStorage.FireworkCrateConfig)

local FireworkCrateService = Knit.CreateService({
	Name = "FireworkCrateService",
	Client = {},
})

local EVENT_ACTIVE = false

local DataService
local function data()
	if not DataService then DataService = Knit.GetService("DataService") end
	return DataService
end

local CoinService
local function coins()
	if not CoinService then CoinService = Knit.GetService("CoinService") end
	return CoinService
end

local function ensureRemote(name, className)
	local folder = ReplicatedStorage:FindFirstChild("GameRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GameRemotes"
		folder.Parent = ReplicatedStorage
	end
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new(className or "RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r
end

local function getPlayerData(player)
	local d = data():Get(player)
	if d then
		d.FireworkCrateSpins = d.FireworkCrateSpins or 0
	end
	return d
end

local function pushSpins(player)
	local d = getPlayerData(player)
	if not d then return end
	ensureRemote("FireworkCrateSpinUpdate"):FireClient(player, d.FireworkCrateSpins)
end

function FireworkCrateService:GetSpins(player)
	if not EVENT_ACTIVE then
		return 0
	end
	local d = getPlayerData(player)
	return d and d.FireworkCrateSpins or 0
end

function FireworkCrateService:GrantSpins(player, amount, reason)
	if not EVENT_ACTIVE then return false end
	if not player or not amount or amount <= 0 then return false end
	local d = getPlayerData(player)
	if not d then return false end
	d.FireworkCrateSpins += math.floor(amount)
	pushSpins(player)
	return true
end

local function consumeSpin(player)
	local d = getPlayerData(player)
	if not d then return false end
	if d.FireworkCrateSpins <= 0 then return false end
	d.FireworkCrateSpins -= 1
	pushSpins(player)
	return true
end

local function refundDuplicate(player)
	local refund = math.floor(FireworkCrateConfig.COST * (FireworkCrateConfig.DUPLICATE_REFUND_PCT or 0))
	if refund > 0 then
		coins():CreditFireworks(player, refund, "firework crate duplicate")
	end
	return refund
end

function FireworkCrateService:Open(player, preferSpin)
	if not EVENT_ACTIVE then return false, "event_closed" end
	local d = getPlayerData(player)
	if not d then return false, "noload" end

	local spentSpin = false
	if preferSpin ~= false and d.FireworkCrateSpins > 0 then
		if not consumeSpin(player) then return false, "nospin" end
		spentSpin = true
	elseif not coins():SpendFireworks(player, FireworkCrateConfig.COST) then
		return false, "insufficient"
	end

	local item = FireworkCrateConfig.roll()
	local result = {
		itemType = item.itemType,
		id = item.id,
		name = item.name,
		rarity = item.rarity,
		amount = item.amount,
		spentSpin = spentSpin,
	}

	if item.itemType == "coins" then
		coins():Credit(player, item.amount, "firework crate")
	elseif item.itemType == "knife" then
		data():AddWeapon(player, item.id, "none", true)
	elseif item.itemType == "killeffect" then
		local _, already = data():AddKillEffect(player, item.id, true)
		result.duplicate = already
		if already then result.refund = refundDuplicate(player) end
	elseif item.itemType == "title" then
		local _, already = data():GrantTitle(player, item.id, true)
		result.duplicate = already
		if already then result.refund = refundDuplicate(player) end
	end

	ensureRemote("FireworkCrateResult"):FireClient(player, result)
	return true, result
end

function FireworkCrateService:KnitStart()
	ensureRemote("FireworkCrateResult")
	ensureRemote("FireworkCrateSpinUpdate")
	ensureRemote("FireworkUpdate")
	local getState = ensureRemote("FireworkCrateGetState", "RemoteFunction")
	getState.OnServerInvoke = function(player)
		return {
			spins = self:GetSpins(player),
			fireworks = 0,
			cost = FireworkCrateConfig.COST,
			items = {},
			active = EVENT_ACTIVE,
		}
	end

	local remote = ensureRemote("FireworkCratePurchase")
	remote.OnServerEvent:Connect(function(player, preferSpin)
		local ok, resultOrReason = self:Open(player, preferSpin ~= false)
		if not ok then
			remote:FireClient(player, false, resultOrReason)
		end
	end)
end

return FireworkCrateService
