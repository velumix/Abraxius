local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CONFIG = require(ReplicatedStorage.Config.Constants).XP

local LevelService = Knit.CreateService({
	Name = "LevelService",
	Client = {},
})
LevelService.CONFIG = CONFIG

local DataService
local hasFriendPresent = {}

local function data()
	if not DataService then DataService = Knit.GetService("DataService") end
	return DataService
end

local function gameRemote(name)
	local folder = ReplicatedStorage:FindFirstChild("GameRemotes")
	return folder and folder:FindFirstChild(name)
end

local function xpForLevel(level)
	return CONFIG.BASE_XP + CONFIG.PER_LEVEL_XP * (level - 1)
end

local function processLevelUps(record)
	local gained = 0
	while record.level < CONFIG.MAX_LEVEL do
		local need = xpForLevel(record.level)
		if record.xp >= need then
			record.xp -= need
			record.level += 1
			gained += 1
		else
			break
		end
	end
	if record.level >= CONFIG.MAX_LEVEL then
		record.xp = 0
	end
	return gained
end

local function isFriendPresent(player)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, friends = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and friends then return true end
		end
	end
	return false
end

local function refreshFriendPresence()
	for _, plr in Players:GetPlayers() do
		task.spawn(function()
			hasFriendPresent[plr.UserId] = isFriendPresent(plr)
		end)
	end
end

function LevelService:KnitStart()
	Players.PlayerAdded:Connect(refreshFriendPresence)
	Players.PlayerRemoving:Connect(function(plr)
		hasFriendPresent[plr.UserId] = nil
		refreshFriendPresence()
	end)
	refreshFriendPresence()
end

function LevelService:Award(player, amount, reason)
	if not player or amount == nil or amount <= 0 then return end
	if game.PrivateServerId ~= "" then return end
	if hasFriendPresent[player.UserId] then
		amount = amount * CONFIG.FRIEND_BONUS_MULT
	end
	amount = math.floor(amount + 0.5)
	if amount <= 0 then return end
	local ds = data()
	local d = ds:Get(player)
	if not d then return end
	local record = { level = d.Levels.Level, xp = d.Levels.XP + amount }
	local gained = processLevelUps(record)
	d.Levels.Level = record.level
	ds:SetXP(player, record.xp)
	if gained > 0 then
		local r = gameRemote("LevelUp")
		if r then r:FireClient(player, record.level) end
	end
end

function LevelService:Snapshot(player)
	return data():Snapshot(player)
end

function LevelService:GetLevel(player)
	return data():GetLevel(player)
end

function LevelService:GetXP(player)
	return data():GetXP(player)
end

function LevelService:XpForLevel(level)
	return xpForLevel(level)
end

return LevelService