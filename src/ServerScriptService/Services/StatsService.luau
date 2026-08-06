local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local odsWins = DataStoreService:GetOrderedDataStore("LB_Wins_v2")
local odsTime = DataStoreService:GetOrderedDataStore("LB_TimePlayed_v2")
local odsRank = DataStoreService:GetOrderedDataStore("LB_Rank_v2")

local FOLD_INTERVAL = 30
local MIRROR_INTERVAL = 120

local StatsService = Knit.CreateService({
	Name = "StatsService",
	Client = {},
})
StatsService.odsWins = odsWins
StatsService.odsTime = odsTime
StatsService.odsRank = odsRank

local DataService
local sessionStart = {}

local function data()
	if not DataService then DataService = Knit.GetService("DataService") end
	return DataService
end

local function foldSessionTime(player)
	local start = sessionStart[player.UserId]
	if not start then return end
	local now = os.clock()
	local elapsed = now - start
	if elapsed <= 0 then return end
	sessionStart[player.UserId] = now
	data():AddTimePlayed(player, elapsed)
end

local function mirrorToLeaderboards(player)
	local ds = data()
	if not ds:IsReady(player) then return end
	local d = ds:Get(player)
	if not d then return end
	local key = tostring(player.UserId)
	pcall(function() odsWins:SetAsync(key, d.Stats.Wins) end)
	pcall(function() odsTime:SetAsync(key, d.Stats.TimePlayed) end)
	pcall(function() odsRank:SetAsync(key, d.Levels.Level) end)
end

function StatsService:KnitStart()
	local function track(plr)
		task.spawn(function()
			if data():WaitForData(plr) then
				sessionStart[plr.UserId] = os.clock()
			end
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, plr in Players:GetPlayers() do
		track(plr)
	end

	Players.PlayerRemoving:Connect(function(plr)
		foldSessionTime(plr)
		mirrorToLeaderboards(plr)
		sessionStart[plr.UserId] = nil
	end)

	game:BindToClose(function()
		for _, plr in Players:GetPlayers() do
			foldSessionTime(plr)
			mirrorToLeaderboards(plr)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(FOLD_INTERVAL)
			for _, plr in Players:GetPlayers() do
				foldSessionTime(plr)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MIRROR_INTERVAL)
			for _, plr in Players:GetPlayers() do
				mirrorToLeaderboards(plr)
			end
		end
	end)
end

function StatsService:AddWin(player)
	if not player then return end
	if game.PrivateServerId ~= "" then return end
	data():AddWin(player)
end

function StatsService:GiveWins(player, amount)
	if not player then return false end
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 then return false end
	local ok = data():AddWins(player, amount)
	if ok then
		mirrorToLeaderboards(player)
	end
	return ok
end

function StatsService:GetWins(player)
	return data():GetWins(player)
end

function StatsService:GetTimePlayed(player)
	foldSessionTime(player)
	return data():GetTimePlayed(player)
end

return StatsService