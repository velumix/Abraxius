local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local FireworkMerchantConfig = require(ReplicatedStorage.FireworkMerchantConfig)

local FireworkMerchantService = Knit.CreateService({
	Name = "FireworkMerchantService",
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

local function ensureRemote(name)
	local folder = ReplicatedStorage:FindFirstChild("GameRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GameRemotes"
		folder.Parent = ReplicatedStorage
	end
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	return r
end

local function owns(d, itemType, id, player)
	if itemType == "knife" then
		return d:HasWeaponSkin(player, id)
	elseif itemType == "killeffect" then
		return d:HasKillEffect(player, id)
	elseif itemType == "pose" then
		return d:HasPose(player, id)
	elseif itemType == "title" then
		return d:HasTitle(player, id)
	end
	return false
end

local function grant(d, item, player)
	if item.itemType == "knife" then
		if item.repeatable then
			d:AddWeapon(player, item.id, "none")
		else
			d:GrantWeaponOnce(player, item.id, "none")
		end
	elseif item.itemType == "killeffect" then
		d:AddKillEffect(player, item.id, true)
	elseif item.itemType == "pose" then
		d:GrantPose(player, item.id, true)
	elseif item.itemType == "title" then
		d:GrantTitle(player, item.id, true)
	end
end

function FireworkMerchantService:Purchase(player, itemId)
	if not EVENT_ACTIVE then return false, "event_closed" end
	local item = FireworkMerchantConfig.get(itemId)
	if not item then return false, "invalid" end
	local d = data()
	if not d:Get(player) then return false, "noload" end
	if not item.repeatable and owns(d, item.itemType, item.id, player) then return false, "owned" end
	if not coins():SpendFireworks(player, item.cost) then return false, "insufficient" end
	grant(d, item, player)
	return true, "ok"
end

function FireworkMerchantService:KnitStart()
	local remote = ensureRemote("FireworkPurchase")
	remote.OnServerEvent:Connect(function(player, itemId)
		if type(itemId) ~= "string" then return end
		local ok, reason = self:Purchase(player, itemId)
		remote:FireClient(player, itemId, ok, reason)
	end)
end

return FireworkMerchantService
