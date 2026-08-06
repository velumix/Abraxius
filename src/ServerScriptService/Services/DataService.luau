local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local ProfileTemplate = require(ServerScriptService.Modules.ProfileTemplate)
local LegacyImport = require(ServerScriptService.Modules.LegacyImport)
local PoseConfig = require(ReplicatedStorage.PoseConfig)
local KnifeSkinManager = require(ReplicatedStorage.KnifeSkinManager)
local KillEffectManager = require(ReplicatedStorage.KillEffectManager)
local TitleManager = require(ReplicatedStorage.TitleManager)

local STORE_NAME = "PlayerData_PS"

local LEVEL_BASE_XP = 100
local LEVEL_PER_LEVEL_XP = 50
local LEVEL_MAX = 200

local UNSELLABLE_SKINS = { vip = true, galaxyseer = true, frozen = true, darkrose = true }

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {},
})

local PlayerStore
local profiles = {}
local ready = {}
local readyEvent = Instance.new("BindableEvent")

local function dataOf(player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

local function newUid()
	return HttpService:GenerateGUID(false)
end

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in pairs(t) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function gameRemote(name)
	local folder = ReplicatedStorage:FindFirstChild("GameRemotes")
	return folder and folder:FindFirstChild(name)
end

local CoinService
local function coinService()
	if not CoinService then
		CoinService = Knit.GetService("CoinService")
	end
	return CoinService
end

local NotificationService
local function notifications()
	if not NotificationService then
		NotificationService = Knit.GetService("NotificationService")
	end
	return NotificationService
end

local BackKnife
local function backKnife()
	if not BackKnife then
		BackKnife = require(ServerScriptService.BackKnife)
	end
	return BackKnife
end

local function fireItemAdded(player)
	local r = gameRemote("InventoryItemAdded")
	if r then
		r:FireClient(player)
	end
end

local function fireKnifeNotify(player, info)
	local r = gameRemote("KnifeNotify")
	if r then
		r:FireClient(player, info)
	end
end

local function poseName(poseId)
	for _, def in PoseConfig.POSES do
		if def.id == poseId then
			return def.name
		end
	end
	return poseId
end

local function ensureStat(ls, name, priority)
	local stat = ls:FindFirstChild(name)
	if not stat then
		stat = Instance.new("IntValue")
		stat.Name = name
		local p = Instance.new("NumberValue")
		p.Name = "Priority"
		p.Value = priority
		p.Parent = stat
		stat.Parent = ls
	end
	return stat
end

local function ensureLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	ensureStat(ls, "Rank", 3)
	ensureStat(ls, "Wins", 2)
	ensureStat(ls, "Coins", 1)
	return ls
end

local function setStat(player, name, value)
	local ls = ensureLeaderstats(player)
	local stat = ls:FindFirstChild(name)
	if stat then
		stat.Value = value
	end
end

local function xpForLevel(level)
	return LEVEL_BASE_XP + LEVEL_PER_LEVEL_XP * (level - 1)
end

local function pushCoins(player)
	local d = dataOf(player)
	if not d then
		return
	end
	local r = gameRemote("CoinUpdate")
	if r then
		r:FireClient(player, d.Coins.Coins)
	end
	setStat(player, "Coins", d.Coins.Coins)
end

local function normalizeFireworks(d)
	if type(d.Fireworks) ~= "number" then
		warn("[DataService] Fireworks data was corrupted (" .. type(d.Fireworks) .. "); resetting to 0")
		d.Fireworks = 0
	end
end

local function convertFireworksToCoins(player, d)
	normalizeFireworks(d)
	local amount = math.floor(d.Fireworks)
	if amount <= 0 then
		d.Fireworks = 0
		return 0
	end

	d.Fireworks = 0
	d.Coins.Coins += amount

	task.delay(2, function()
		if player.Parent ~= Players then
			return
		end
		local ok, service = pcall(notifications)
		if ok and service then
			service:Preset(player, "SUCCESS", string.format("%d fireworks converted into %d coins!", amount, amount), {
				duration = 6,
			})
		end
	end)
	return amount
end

local function pushFireworks(player)
	local d = dataOf(player)
	if not d then
		return
	end
	normalizeFireworks(d)
	local r = gameRemote("FireworkUpdate") -- no-ops until the event UI adds this remote
	if r then
		r:FireClient(player, d.Fireworks)
	end
end

local function pushLevel(player)
	local d = dataOf(player)
	if not d then
		return
	end
	setStat(player, "Rank", d.Levels.Level)
	local r = gameRemote("LevelUpdate")
	if r then
		r:FireClient(player, {
			level = d.Levels.Level,
			xp = d.Levels.XP,
			xpNeeded = xpForLevel(d.Levels.Level),
			maxLevel = LEVEL_MAX,
		})
	end
end

local function pushWins(player)
	local d = dataOf(player)
	if not d then
		return
	end
	setStat(player, "Wins", d.Stats.Wins)
end

local function pushInventory(player)
	local d = dataOf(player)
	if not d then
		return
	end

	local equippedWeapon = d.Equipped.Weapon
	if equippedWeapon == "" then
		equippedWeapon = nil
	end

	d.Inventory.FavoriteWeapons = d.Inventory.FavoriteWeapons or {}
	local favoriteWeapons = d.Inventory.FavoriteWeapons
	local payload = { equipped = equippedWeapon, items = {} }
	for _, item in d.Inventory.Weapons do
		local def = KnifeSkinManager.getSkin(item.skinId)
		payload.items[#payload.items + 1] = {
			uid = item.uid,
			skinId = item.skinId,
			name = def and def.name or item.skinId,
			rarity = def and def.rarity or "Common",
			effect = item.effect or "none",
			effectName = KnifeSkinManager.effectName(item.effect or "none"),
			favorite = favoriteWeapons[item.uid] == true,
		}
	end

	local keItems = {}
	for _, def in KillEffectManager.EFFECTS do
		keItems[#keItems + 1] = {
			id = def.id,
			name = def.name,
			rarity = def.rarity,
			owned = d.Inventory.KillEffects[def.id] == true,
		}
	end
	local equippedKE = d.Equipped.KillEffect
	if equippedKE == "" then
		equippedKE = nil
	end
	payload.killEffects = { equipped = equippedKE, items = keItems }

	local equippedPoses = d.Equipped.Poses
	if equippedPoses == nil or #equippedPoses == 0 then
		equippedPoses = PoseConfig.DEFAULT_EQUIPPED
	end
	local equippedSet = {}
	for _, id in equippedPoses do
		equippedSet[id] = true
	end
	local poseItems = {}
	for _, def in PoseConfig.POSES do
		local owned = def.free or (d.Inventory.Poses[def.id] == true)
		poseItems[#poseItems + 1] = {
			id = def.id,
			name = def.name,
			free = def.free and true or false,
			price = def.price,
			rarity = def.rarity,
			owned = owned and true or false,
			equipped = equippedSet[def.id] and true or false,
		}
	end
	payload.poses = { equipped = equippedPoses, items = poseItems, maxEquipped = PoseConfig.MAX_EQUIPPED }

	d.Inventory.Titles = d.Inventory.Titles or {}
	local equippedTitle = d.Equipped.Title
	if equippedTitle == "" then
		equippedTitle = nil
	end
	local titleItems = {}
	for _, t in ipairs(TitleManager.TITLES) do
		titleItems[#titleItems + 1] = {
			id = t.id,
			name = t.name,
			rarity = t.rarity,
			owned = d.Inventory.Titles[t.id] == true,
			equipped = (equippedTitle == t.id),
		}
	end
	payload.titles = { equipped = equippedTitle, items = titleItems }

	local r = gameRemote("InventoryUpdate")
	if r then
		r:FireClient(player, payload)
	end
end

local function hadReadError(sources)
	for _, result in sources do
		if type(result) == "string" and string.sub(result, 1, 6) == "error:" then
			return true
		end
	end
	return false
end

local messageListeners = {}

local function loadPlayer(player)
	local profile = PlayerStore:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your data could not be loaded. Please rejoin.")
		end
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	if profile.OnSessionEnd then
		profile.OnSessionEnd:Connect(function()
			profiles[player] = nil
			ready[player] = nil
			if player.Parent == Players then
				player:Kick("Your data session ended. Please rejoin.")
			end
		end)
	end

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	if profile.Data.Migration.FromLegacy ~= true then
		local ok, sources = pcall(LegacyImport.Apply, player.UserId, profile.Data)
		if not ok or hadReadError(sources) then
			profile:EndSession()
			profiles[player] = nil
			ready[player] = nil
			if player.Parent == Players then
				player:Kick("Your data could not be migrated. Please rejoin in a moment.")
			end
			return
		end
		profile.Data.SchemaVersion = ProfileTemplate.SchemaVersion
		profile.Data.Migration.FromLegacy = true
		profile.Data.Migration.At = os.time()
		profile.Data.Migration.Sources = sources
	end

	profiles[player] = profile
	ready[player] = true
	readyEvent:Fire(player)

	-- Starter pack timer begins from the moment a player first joins and persists in their data.
	local pack = profile.Data.StarterPack
	if not pack.Purchased and pack.ExpiresAt == 0 then
		DataService:StartStarterPackTimer(player)
	end

	if profile.MessageHandler then
		profile:MessageHandler(function(message, processed)
			local handled = false
			for _, fn in messageListeners do
				local ok, res = pcall(fn, player, message)
				if ok and res == true then
					handled = true
				end
			end
			if handled then
				processed()
			end
		end)
	end

	ensureLeaderstats(player)
	local convertedFireworks = convertFireworksToCoins(player, profile.Data)
	if convertedFireworks and convertedFireworks > 0 then
		pcall(function()
			profile:Save()
		end)
	end
	pushCoins(player)
	pushFireworks(player)
	pushLevel(player)
	pushWins(player)
	pushInventory(player)
	player:SetAttribute("EquippedTitle", profile.Data.Equipped.Title or "")
	player:LoadCharacter()
	player:SetAttribute("DataLoaded", true)
end

local function releasePlayer(player)
	local profile = profiles[player]
	if profile then
		profile:EndSession()
	end
	profiles[player] = nil
	ready[player] = nil
end

function DataService:KnitInit()
	PlayerStore = ProfileStore.New(STORE_NAME, ProfileTemplate)
end

function DataService:KnitStart()
	Players.CharacterAutoLoads = false

	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPlayer, player)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end

	Players.PlayerRemoving:Connect(releasePlayer)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			local profile = profiles[player]
			if profile then
				profile:EndSession()
			end
		end
	end)

	local action = gameRemote("InventoryAction")
	if action then
		action.OnServerEvent:Connect(function(player, act, uid)
			if act == "equip" and type(uid) == "string" then
				self:EquipWeapon(player, uid)
			elseif act == "unequip" then
				self:UnequipWeapon(player)
			elseif act == "sell" and type(uid) == "string" then
				self:Sell(player, uid)
			elseif act == "toggleFavorite" and type(uid) == "string" then
				self:ToggleFavoriteWeapon(player, uid)
			elseif act == "equipKillEffect" and type(uid) == "string" then
				self:EquipKillEffect(player, uid)
			elseif act == "unequipKillEffect" then
				self:UnequipKillEffect(player)
			elseif act == "buyPose" and type(uid) == "string" then
				self:BuyPose(player, uid)
			elseif act == "equipPose" and type(uid) == "string" then
				self:EquipPose(player, uid)
			elseif act == "unequipPose" and type(uid) == "string" then
				self:UnequipPose(player, uid)
			elseif act == "equipTitle" and type(uid) == "string" then
				self:EquipTitle(player, uid)
			elseif act == "unequipTitle" then
				self:UnequipTitle(player)
			elseif act == "request" then
				task.spawn(function()
					self:WaitForData(player)
					self:PushInventory(player)
				end)
			end
		end)
	end
end

function DataService:WaitForData(player)
	if ready[player] then
		return profiles[player].Data
	end
	while not ready[player] and player.Parent == Players do
		readyEvent.Event:Wait()
	end
	local profile = profiles[player]
	return profile and profile.Data or nil
end

function DataService:IsReady(player)
	return ready[player] == true
end

function DataService:IsLoaded(player)
	return self:IsReady(player)
end

function DataService:IsActive()
	return true
end

function DataService:Get(player)
	return dataOf(player)
end

function DataService:Save(player)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local ok = pcall(function()
		profile:Save()
	end)
	return ok
end

function DataService:Wipe(player)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local fresh = deepCopy(ProfileTemplate)
	for k, v in pairs(fresh) do
		profile.Data[k] = v
	end
	for k in pairs(profile.Data) do
		if fresh[k] == nil then
			profile.Data[k] = nil
		end
	end
	self:Save(player)
	self:PushInventory(player)
	return true
end

function DataService:PushInventory(player)
	pushInventory(player)
end

function DataService:OnServerMessage(fn)
	table.insert(messageListeners, fn)
end

function DataService:SendMessage(userId, message)
	return PlayerStore:MessageAsync(tostring(userId), message)
end

function DataService:GetCoins(player)
	local d = dataOf(player)
	return d and d.Coins.Coins or 0
end

function DataService:AddCoins(player, amount, _reason)
	local d = dataOf(player)
	if not d then
		return
	end
	if amount == nil or amount <= 0 then
		return
	end
	d.Coins.Coins += math.floor(amount)
	pushCoins(player)
end

function DataService:SpendCoins(player, amount)
	local d = dataOf(player)
	if not d then
		return false
	end
	if amount == nil or amount < 0 then
		return false
	end
	if d.Coins.Coins < amount then
		return false
	end
	d.Coins.Coins -= math.floor(amount)
	pushCoins(player)
	return true
end

function DataService:GrantVIPCoinsOnce(player, amount)
	local d = dataOf(player)
	if not d then
		return false
	end
	if d.Coins.VIPCoinsGranted then
		return false
	end
	d.Coins.VIPCoinsGranted = true
	d.Coins.Coins += math.floor(amount or 0)
	pushCoins(player)
	return true
end

function DataService:GetFireworks(player)
	local d = dataOf(player)
	if not d then
		return 0
	end
	normalizeFireworks(d)
	return d.Fireworks
end

function DataService:AddFireworks(player, amount, _reason)
	local d = dataOf(player)
	if not d then
		return
	end
	if type(amount) ~= "number" then
		warn(`[DataService] AddFireworks received non-number amount ({type(amount)}); ignoring`)
		return
	end
	if amount <= 0 then
		return
	end
	normalizeFireworks(d)
	d.Fireworks = d.Fireworks + math.floor(amount)
	pushFireworks(player)
end

function DataService:SpendFireworks(player, amount)
	local d = dataOf(player)
	if not d then
		return false
	end
	if amount == nil or amount < 0 then
		return false
	end
	normalizeFireworks(d)
	if d.Fireworks < amount then
		return false
	end
	d.Fireworks -= math.floor(amount)
	pushFireworks(player)
	return true
end

function DataService:GetLevel(player)
	local d = dataOf(player)
	return d and d.Levels.Level or 1
end

function DataService:GetXP(player)
	local d = dataOf(player)
	return d and d.Levels.XP or 0
end

function DataService:SetXP(player, xp)
	local d = dataOf(player)
	if not d then
		return
	end
	d.Levels.XP = xp
	pushLevel(player)
end

function DataService:SetLevel(player, level)
	local d = dataOf(player)
	if not d then
		return
	end
	d.Levels.Level = level
	pushLevel(player)
end

function DataService:Snapshot(player)
	local d = dataOf(player)
	local level = d and d.Levels.Level or 1
	local xp = d and d.Levels.XP or 0
	return {
		level = level,
		xp = xp,
		xpNeeded = xpForLevel(level),
		maxLevel = LEVEL_MAX,
	}
end

function DataService:GetWins(player)
	local d = dataOf(player)
	return d and d.Stats.Wins or 0
end

function DataService:AddWin(player)
	local d = dataOf(player)
	if not d then
		return
	end
	d.Stats.Wins += 1
	pushWins(player)
end

function DataService:AddWins(player, amount)
	local d = dataOf(player)
	amount = math.floor(tonumber(amount) or 0)
	if not d or amount <= 0 then
		return false
	end
	d.Stats.Wins += amount
	pushWins(player)
	return true
end

function DataService:GetTimePlayed(player)
	local d = dataOf(player)
	return d and d.Stats.TimePlayed or 0
end

function DataService:AddTimePlayed(player, seconds)
	local d = dataOf(player)
	if not d then
		return
	end
	d.Stats.TimePlayed += math.floor(seconds or 0)
end

function DataService:GetWeapons(player)
	local d = dataOf(player)
	return d and d.Inventory.Weapons or {}
end

function DataService:HasWeapon(player, uid)
	local d = dataOf(player)
	if not d then
		return false
	end
	for _, item in d.Inventory.Weapons do
		if item.uid == uid then
			return true
		end
	end
	return false
end

function DataService:HasWeaponSkin(player, skinId)
	local d = dataOf(player)
	if not d then
		return false
	end
	for _, item in d.Inventory.Weapons do
		if item.skinId == skinId then
			return true
		end
	end
	return false
end

function DataService:AddWeapon(player, skinId, effect, notify)
	local d = dataOf(player)
	if not d then
		return nil
	end
	local item = { uid = newUid(), skinId = skinId, effect = effect or "none" }
	table.insert(d.Inventory.Weapons, item)
	pushInventory(player)
	fireItemAdded(player)
	if notify ~= false then
		local def = KnifeSkinManager.getSkin(skinId)
		fireKnifeNotify(player, {
			name = def and def.name or skinId,
			rarity = def and def.rarity or "Common",
		})
	end
	return item.uid
end

function DataService:GrantWeaponOnce(player, skinId, effect)
	local d = dataOf(player)
	if not d then
		return nil
	end
	for _, item in d.Inventory.Weapons do
		if item.skinId == skinId then
			return item.uid
		end
	end
	return self:AddWeapon(player, skinId, effect)
end

function DataService:RemoveWeapon(player, uid)
	local d = dataOf(player)
	if not d then
		return false
	end
	for i, item in d.Inventory.Weapons do
		if item.uid == uid then
			table.remove(d.Inventory.Weapons, i)
			d.Inventory.FavoriteWeapons = d.Inventory.FavoriteWeapons or {}
			d.Inventory.FavoriteWeapons[uid] = nil
			pushInventory(player)
			return true
		end
	end
	return false
end

function DataService:ToggleFavoriteWeapon(player, uid)
	local d = dataOf(player)
	if not d then
		return false
	end
	local ownsWeapon = false
	for _, item in d.Inventory.Weapons do
		if item.uid == uid then
			ownsWeapon = true
			break
		end
	end
	if not ownsWeapon then
		return false
	end

	d.Inventory.FavoriteWeapons = d.Inventory.FavoriteWeapons or {}
	local isFavorite = d.Inventory.FavoriteWeapons[uid] ~= true
	d.Inventory.FavoriteWeapons[uid] = if isFavorite then true else nil
	pushInventory(player)
	return true, isFavorite
end

function DataService:Sell(player, uid)
	local d = dataOf(player)
	if not d then
		return false, "noload"
	end
	for _, item in d.Inventory.Weapons do
		if item.uid == uid then
			d.Inventory.FavoriteWeapons = d.Inventory.FavoriteWeapons or {}
			if d.Inventory.FavoriteWeapons[uid] == true then
				return false, "favorite"
			end
			if d.Equipped.Weapon == uid then
				return false, "equipped"
			end
			if UNSELLABLE_SKINS[item.skinId] then
				return false, "unsellable"
			end
			local def = KnifeSkinManager.getSkin(item.skinId)
			local value = def and KnifeSkinManager.sellValue(def.rarity) or 0
			self:RemoveWeapon(player, uid)
			if value > 0 then
				coinService():Credit(player, value, "sold skin")
			end
			return true, value
		end
	end
	return false, "notfound"
end

function DataService:EquipWeapon(player, uid)
	local d = dataOf(player)
	if not d then
		return false
	end
	for _, item in d.Inventory.Weapons do
		if item.uid == uid then
			d.Equipped.Weapon = uid
			pushInventory(player)
			backKnife().refresh(player)
			return true
		end
	end
	return false
end

function DataService:UnequipWeapon(player)
	local d = dataOf(player)
	if not d then
		return false
	end
	d.Equipped.Weapon = ""
	pushInventory(player)
	backKnife().refresh(player)
	return true
end

function DataService:GetEquippedWeapon(player)
	local d = dataOf(player)
	if not d then
		return nil
	end
	local uid = d.Equipped.Weapon
	if uid == nil or uid == "" then
		return nil
	end
	for _, item in d.Inventory.Weapons do
		if item.uid == uid then
			return item.skinId, item.effect or "none"
		end
	end
	return nil
end

function DataService:GetEquippedSkin(player)
	return self:GetEquippedWeapon(player)
end

function DataService:HasKillEffect(player, effectId)
	local d = dataOf(player)
	return d ~= nil and d.Inventory.KillEffects[effectId] == true
end

function DataService:AddKillEffect(player, effectId, notify)
	local d = dataOf(player)
	if not d then
		return false
	end
	local already = d.Inventory.KillEffects[effectId] == true
	d.Inventory.KillEffects[effectId] = true
	pushInventory(player)
	fireItemAdded(player)
	if notify ~= false then
		local def = KillEffectManager.getEffect(effectId)
		fireKnifeNotify(player, {
			name = (def and def.name or effectId) .. " (Kill Effect)",
			rarity = def and def.rarity or "Common",
		})
	end
	return true, already
end

function DataService:EquipKillEffect(player, effectId)
	local d = dataOf(player)
	if not d then
		return false
	end
	if d.Inventory.KillEffects[effectId] ~= true then
		return false
	end
	d.Equipped.KillEffect = effectId
	pushInventory(player)
	return true
end

function DataService:UnequipKillEffect(player)
	local d = dataOf(player)
	if not d then
		return false
	end
	d.Equipped.KillEffect = ""
	pushInventory(player)
	return true
end

function DataService:GetEquippedKillEffect(player)
	local d = dataOf(player)
	if not d then
		return nil
	end
	local id = d.Equipped.KillEffect
	if id == nil or id == "" then
		return nil
	end
	return id
end

function DataService:HasPose(player, poseId)
	if PoseConfig.isFree(poseId) then
		return true
	end
	local d = dataOf(player)
	return d ~= nil and d.Inventory.Poses[poseId] == true
end

function DataService:GrantPose(player, poseId, notify)
	local d = dataOf(player)
	if not d then
		return false
	end
	local already = d.Inventory.Poses[poseId] == true
	d.Inventory.Poses[poseId] = true
	pushInventory(player)
	fireItemAdded(player)
	if notify ~= false then
		fireKnifeNotify(player, {
			name = poseName(poseId) .. " (Pose)",
			rarity = "Common",
		})
	end
	return true, already
end

function DataService:BuyPose(player, poseId)
	local d = dataOf(player)
	if not d then
		return false, "noload"
	end
	if not PoseConfig.isPurchasable(poseId) then
		return false, "invalid"
	end
	if d.Inventory.Poses[poseId] then
		return false, "owned"
	end
	local price = PoseConfig.price(poseId) or 0
	if not coinService():Spend(player, price) then
		return false, "insufficient"
	end
	self:GrantPose(player, poseId, false)
	return true, "ok"
end

function DataService:GetEquippedPoses(player)
	local d = dataOf(player)
	if not d then
		return PoseConfig.DEFAULT_EQUIPPED
	end
	local eq = d.Equipped.Poses
	if eq == nil or #eq == 0 then
		return PoseConfig.DEFAULT_EQUIPPED
	end
	return eq
end

function DataService:EquipPose(player, poseId)
	local d = dataOf(player)
	if not d then
		return false
	end
	if not self:HasPose(player, poseId) then
		return false, "unowned"
	end
	local loadout = d.Equipped.Poses
	if loadout == nil then
		loadout = { table.unpack(PoseConfig.DEFAULT_EQUIPPED) }
	end
	for _, id in loadout do
		if id == poseId then
			return false, "already"
		end
	end
	if #loadout >= PoseConfig.MAX_EQUIPPED then
		return false, "full"
	end
	table.insert(loadout, poseId)
	d.Equipped.Poses = loadout
	pushInventory(player)
	return true
end

function DataService:UnequipPose(player, poseId)
	local d = dataOf(player)
	if not d then
		return false
	end
	local loadout = d.Equipped.Poses
	if loadout == nil then
		loadout = { table.unpack(PoseConfig.DEFAULT_EQUIPPED) }
	end
	local found = false
	for i = #loadout, 1, -1 do
		if loadout[i] == poseId then
			table.remove(loadout, i)
			found = true
		end
	end
	d.Equipped.Poses = loadout
	if found then
		pushInventory(player)
	end
	return found
end

function DataService:GetTitles(player)
	local d = dataOf(player)
	if not d then
		return {}
	end
	d.Inventory.Titles = d.Inventory.Titles or {}
	return d.Inventory.Titles
end

function DataService:HasTitle(player, titleId)
	local d = dataOf(player)
	if not d then
		return false
	end
	d.Inventory.Titles = d.Inventory.Titles or {}
	return d.Inventory.Titles[titleId] == true
end

function DataService:GrantTitle(player, titleId, notify)
	local d = dataOf(player)
	if not d then
		return false
	end
	d.Inventory.Titles = d.Inventory.Titles or {}
	local already = d.Inventory.Titles[titleId] == true
	d.Inventory.Titles[titleId] = true
	pushInventory(player)
	fireItemAdded(player)
	if notify ~= false then
		local def = TitleManager.getTitle and TitleManager.getTitle(titleId)
		local name = (TitleManager.titleName and TitleManager.titleName(titleId)) or titleId
		fireKnifeNotify(player, {
			name = name .. " (Title)",
			rarity = (def and def.rarity) or "Legendary",
		})
	end
	return true, already
end

function DataService:GetEquippedTitle(player)
	local d = dataOf(player)
	if not d then
		return nil
	end
	local id = d.Equipped.Title
	if id == nil or id == "" then
		return nil
	end
	return id
end

function DataService:EquipTitle(player, titleId)
	local d = dataOf(player)
	if not d then
		return false
	end
	d.Inventory.Titles = d.Inventory.Titles or {}
	if d.Inventory.Titles[titleId] ~= true then
		return false
	end
	d.Equipped.Title = titleId
	player:SetAttribute("EquippedTitle", titleId)
	pushInventory(player)
	return true
end

function DataService:UnequipTitle(player)
	local d = dataOf(player)
	if not d then
		return false
	end
	d.Equipped.Title = ""
	player:SetAttribute("EquippedTitle", "")
	pushInventory(player)
	return true
end

function DataService:OwnsBundle(player, bundleId)
	local d = dataOf(player)
	return d ~= nil and d.Inventory.Bundles[tostring(bundleId)] ~= nil
end

function DataService:GetOwnedBundles(player)
	local d = dataOf(player)
	return d and d.Inventory.Bundles or {}
end

function DataService:MarkBundleOwned(player, bundleId, claimNumber)
	local d = dataOf(player)
	if not d then
		return false
	end
	local key = tostring(bundleId)
	if d.Inventory.Bundles[key] then
		return true
	end
	d.Inventory.Bundles[key] = {
		PurchasedAt = os.time(),
		ClaimNumber = tonumber(claimNumber) or 0,
	}
	return true
end

function DataService:HasGrantedReceipt(player, purchaseId)
	if not purchaseId then
		return false
	end
	local d = dataOf(player)
	return d ~= nil and d.GrantedReceipts[purchaseId] == true
end

function DataService:MarkGrantedReceipt(player, purchaseId)
	if not purchaseId then
		return
	end
	local d = dataOf(player)
	if not d then
		return
	end
	d.GrantedReceipts[purchaseId] = true
end

function DataService:GetReceiptRecord(player, purchaseId)
	if not purchaseId then
		return nil
	end
	local d = dataOf(player)
	return d and d.ReceiptLedger and d.ReceiptLedger[purchaseId] or nil
end

function DataService:RecordReceipt(player, purchaseId, receipt)
	if not purchaseId or type(receipt) ~= "table" then
		return nil
	end
	local d = dataOf(player)
	if not d then
		return nil
	end

	d.ReceiptLedger = d.ReceiptLedger or {}
	local existing = d.ReceiptLedger[purchaseId]
	if type(existing) ~= "table" then
		existing = {
			PurchaseId = purchaseId,
			CreatedAt = os.time(),
		}
		d.ReceiptLedger[purchaseId] = existing
	end

	existing.ProductId = tonumber(receipt.ProductId) or existing.ProductId or 0
	existing.PurchaserUserId = tonumber(receipt.PurchaserUserId) or existing.PurchaserUserId or 0
	existing.RecipientUserId = tonumber(receipt.RecipientUserId) or existing.RecipientUserId or player.UserId
	existing.Source = tostring(receipt.Source or existing.Source or "purchase")
	existing.GrantState = tostring(receipt.GrantState or existing.GrantState or "granted")
	existing.FallbackState = tostring(receipt.FallbackState or existing.FallbackState or "none")
	existing.UpdatedAt = os.time()

	if existing.GrantState == "granted" then
		d.GrantedReceipts[purchaseId] = true
	end

	return existing
end

local function receiptWasPersisted(snapshot, purchaseId)
	if type(snapshot) ~= "table" then
		return false
	end
	local granted = snapshot.GrantedReceipts
	local ledger = snapshot.ReceiptLedger
	local record = type(ledger) == "table" and ledger[purchaseId] or nil
	return type(granted) == "table"
		and granted[purchaseId] == true
		and type(record) == "table"
		and record.GrantState == "granted"
end

-- A receipt is acknowledged only after ProfileStore exposes the saved snapshot.
function DataService:CommitReceipt(player, purchaseId, timeoutSeconds)
	if not purchaseId then
		return false
	end
	local profile = profiles[player]
	if not profile or not profile:IsActive() then
		return false
	end
	if receiptWasPersisted(profile.LastSavedData, purchaseId) then
		return true
	end

	local completed = false
	local resultEvent = Instance.new("BindableEvent")
	local saveConnection
	local endConnection

	local function finish(result)
		if completed then
			return
		end
		completed = true
		resultEvent:Fire(result)
	end

	saveConnection = profile.OnAfterSave:Connect(function(lastSavedData)
		if receiptWasPersisted(lastSavedData, purchaseId) then
			finish(true)
		end
	end)
	endConnection = profile.OnSessionEnd:Connect(function()
		finish(false)
	end)

	task.delay(math.max(1, tonumber(timeoutSeconds) or 30), function()
		finish(false)
	end)
	task.defer(function()
		if profile:IsActive() then
			profile:Save()
		else
			finish(false)
		end
	end)

	local persisted = resultEvent.Event:Wait()
	if saveConnection then
		saveConnection:Disconnect()
	end
	if endConnection then
		endConnection:Disconnect()
	end
	resultEvent:Destroy()
	return persisted == true
end

function DataService:GetQuests(player)
	local d = dataOf(player)
	if not d then
		return 0, {}
	end
	return d.Quests.Deadline, d.Quests.Quests
end

function DataService:SetQuests(player, deadline, list)
	local d = dataOf(player)
	if not d then
		return
	end
	d.Quests.Deadline = deadline
	d.Quests.Quests = list
end

function DataService:GetDaily(player)
	local d = dataOf(player)
	if not d then
		return 0, 0
	end
	return d.DailyRewards.Streak, d.DailyRewards.LastClaim
end

function DataService:SetDaily(player, streak, lastClaim)
	local d = dataOf(player)
	if not d then
		return
	end
	d.DailyRewards.Streak = streak
	d.DailyRewards.LastClaim = lastClaim
end

function DataService:HasRedeemedCode(player, code)
	local d = dataOf(player)
	return d ~= nil and d.RedeemedCodes[code] == true
end

function DataService:MarkCodeRedeemed(player, code)
	local d = dataOf(player)
	if not d then
		return
	end
	d.RedeemedCodes[code] = true
end

function DataService:GetFlag(player, name)
	local d = dataOf(player)
	return d and d.Flags[name]
end

function DataService:SetFlag(player, name, value)
	local d = dataOf(player)
	if not d then
		return
	end
	d.Flags[name] = value
end

local STARTER_PACK_DURATION = 600

function DataService:GetStarterPackStatus(player)
	local d = dataOf(player)
	if not d then
		return nil
	end
	local pack = d.StarterPack
	if pack.Purchased then
		return { state = "purchased", expiresAt = pack.ExpiresAt, secondsRemaining = 0 }
	end
	if pack.ExpiresAt == 0 then
		return { state = "not_started", expiresAt = 0, secondsRemaining = STARTER_PACK_DURATION }
	end
	local remaining = math.max(0, pack.ExpiresAt - os.time())
	if remaining <= 0 then
		return { state = "expired", expiresAt = pack.ExpiresAt, secondsRemaining = 0 }
	end
	return { state = "active", expiresAt = pack.ExpiresAt, secondsRemaining = remaining }
end

function DataService:StartStarterPackTimer(player)
	local d = dataOf(player)
	if not d then
		return 0, "no_data"
	end
	local pack = d.StarterPack
	if pack.Purchased then
		return pack.ExpiresAt, "purchased"
	end
	if pack.ExpiresAt > 0 then
		return pack.ExpiresAt, "already_started"
	end
	pack.ExpiresAt = os.time() + STARTER_PACK_DURATION
	pcall(function()
		self:Save(player)
	end)
	return pack.ExpiresAt
end

function DataService:MarkStarterPackPurchased(player)
	local d = dataOf(player)
	if not d then
		return false
	end
	d.StarterPack.Purchased = true
	return true
end

function DataService:GetCustomTauntSoundId(player)
	local d = dataOf(player)
	return d and d.CustomTaunt and d.CustomTaunt.SoundId or ""
end

function DataService:SetCustomTauntSoundId(player, soundId: string)
	local d = dataOf(player)
	if not d then
		return false
	end
	d.CustomTaunt.SoundId = soundId
	pcall(function()
		self:Save(player)
	end)
	return true
end

return DataService
