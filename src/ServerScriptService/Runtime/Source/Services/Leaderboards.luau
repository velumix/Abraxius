local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local Component = Mince.Component

local Leaderboards = {
	Name = "Leaderboards",
	ActiveBoards = {},
}

local PlayerDataManager
local LeaderboardStores = {
	Playtime = DataStoreService:GetOrderedDataStore("Leaderboard_Playtime"),
	FishScanned = DataStoreService:GetOrderedDataStore("Leaderboard_FishScanned"),
	TotalCoins = DataStoreService:GetOrderedDataStore("Leaderboard_TotalCoins"),
}

local Leaderboard = Component({
	Tag = "Leaderboard",
})

function Leaderboard:Construct()
	self.Model = self.Instance
	self.Type = self.Instance:GetAttribute("Type") or "Playtime"

	self.UIHolder = self.Instance:FindFirstChild("UIHolder")

	if not self.UIHolder then
		return print("Missing UI Holder")
	end

	self.LeaderboardGui = self.UIHolder:WaitForChild("LeaderboardGui")
	self.EntryHolder = self.LeaderboardGui:WaitForChild("EntryHolder")
	self.EntryTemplate = self.EntryHolder:WaitForChild("EntryTemplate")
	self.Title = self.LeaderboardGui:WaitForChild("Title")

	self.Title.Text = self.Type

	Leaderboards.new(self)
end

function Leaderboard:UpdateLeaderboard()
	if not PlayerDataManager then
		return
	end

	for _, child in self.EntryHolder:GetChildren() do
		if child.Name:match("^Entry%d+$") then
			child:Destroy()
		end
	end

	local topPlayers = Leaderboards:GetTopPlayers(self.Type, 20)

	for i, playerData in ipairs(topPlayers) do
		local entry = self.EntryTemplate:Clone()
		entry.Name = "Entry" .. i
		entry.Visible = true
		entry.LayoutOrder = i + 1

		entry.Rank.Text = "#" .. playerData.Rank

		local success, playerName = pcall(function()
			return Players:GetNameFromUserIdAsync(tonumber(playerData.UserId))
		end)
		entry.Player.Text = success and playerName or "Player " .. playerData.UserId

		local avatarSuccess, avatarData = pcall(function()
			return Players:GetUserThumbnailAsync(
				tonumber(playerData.UserId),
				Enum.ThumbnailType.HeadShot,
				Enum.ThumbnailSize.Size100x100
			)
		end)

		if avatarSuccess and avatarData then
			entry.Icon.Image = avatarData
		end

		entry.Data.Text = self:FormatValue(playerData.Value)

		if playerData.Rank == 1 then
			entry.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
			entry.BackgroundTransparency = 0.7
		elseif playerData.Rank == 2 then
			entry.BackgroundColor3 = Color3.fromRGB(192, 192, 192)
			entry.BackgroundTransparency = 0.7
		elseif playerData.Rank == 3 then
			entry.BackgroundColor3 = Color3.fromRGB(205, 127, 50)
			entry.BackgroundTransparency = 0.7
		end

		entry.Parent = self.EntryHolder
	end
end

function Leaderboard:GetLeaderboardTitle()
	local titles = {
		Playtime = "🕒 Top Players by Playtime",
		FishScanned = "🐟 Top Fish Scanners",
		TotalCoins = "💰 Top Coin Collectors",
	}
	return titles[self.Type] or "🏆 Leaderboard"
end

function Leaderboard:FormatValue(value)
	if self.Type == "Playtime" then
		local actualSeconds = value

		if value >= 1000000 then
			local days = math.floor(value / 1000000)
			local remainingSeconds = value % 1000000
			actualSeconds = days * 86400 + remainingSeconds
		end

		local totalMinutes = math.floor(actualSeconds / 60)
		local hours = math.floor(totalMinutes / 60)
		local minutes = totalMinutes % 60
		local days = math.floor(hours / 24)
		hours = hours % 24

		if days > 0 then
			return days .. "d " .. hours .. "h " .. minutes .. "m"
		elseif hours > 0 then
			return hours .. "h " .. minutes .. "m"
		else
			return minutes .. "m"
		end
	elseif self.Type == "FishScanned" then
		return tostring(math.floor(value)) .. " fish"
	elseif self.Type == "TotalCoins" then
		if value >= 1000000 then
			return string.format("%.1fM", value / 1000000)
		elseif value >= 1000 then
			return string.format("%.1fK", value / 1000)
		else
			return tostring(math.floor(value))
		end
	end
	return tostring(value)
end

function Leaderboards.new(leaderboardComponent)
	if not PlayerDataManager then
		PlayerDataManager = Mince:Get("PlayerDataManager")
	end

	task.spawn(function()
		while leaderboardComponent.Model.Parent do
			leaderboardComponent:UpdateLeaderboard()
			task.wait(30)
		end
	end)
end

function Leaderboards:Setup()
	self.Connections = {}
	self.PlayerDataManager = Mince:Get("PlayerDataManager")
end

function Leaderboards:GameStart()
	self.Connections.ProfileLoaded = self.PlayerDataManager.ProfileLoaded:Connect(function(player, profile)
		self:UpdateLeaderboard(player, "Playtime", profile.Data.TotalPlayTime or 0)
		self:UpdateLeaderboard(player, "FishScanned", profile.Data.Statistics.Scanned or 0)
		self:UpdateLeaderboard(player, "TotalCoins", profile.Data.Currency.TotalEarned or 0)
	end)

	self.Connections.PlayerRemoving = Players.PlayerRemoving:Connect(function(player)
		local profile = self.PlayerDataManager:GetProfile(player)
		if profile then
			self:UpdateLeaderboard(player, "Playtime", profile.Data.TotalPlayTime or 0)
			self:UpdateLeaderboard(player, "FishScanned", profile.Data.Statistics.Scanned or 0)
			self:UpdateLeaderboard(player, "TotalCoins", profile.Data.Currency.TotalEarned or 0)
		end
	end)
end

function Leaderboards:GetTopPlayers(statName, count)
	statName = statName or "Playtime"
	count = math.min(count or 10, 100)

	if not LeaderboardStores[statName] then
		warn("No leaderboard exists for stat:", statName)
		return {}
	end

	local success, result = pcall(function()
		return LeaderboardStores[statName]:GetSortedAsync(false, count)
	end)

	if success then
		local topPlayers = {}
		local currentPage = result:GetCurrentPage()

		for rank, data in ipairs(currentPage) do
			table.insert(topPlayers, {
				UserId = tonumber(data.key),
				Value = data.value,
				Rank = rank,
				StatName = statName,
			})
		end

		return topPlayers
	else
		warn("Failed to get top players for", statName, ":", result)
		return {}
	end
end

function Leaderboards:UpdateLeaderboard(player, statName, value)
	if not LeaderboardStores[statName] then
		warn("No leaderboard exists for stat:", statName)
		return false
	end

	if type(value) ~= "number" or value < 0 then
		warn("Invalid value for leaderboard:", value)
		return false
	end

	local SECONDS_PER_DAY = 86400
	local MAX_SAFE_SECONDS = 31536000000

	local validatedValue = math.max(0, value)

	if validatedValue > MAX_SAFE_SECONDS then
		local days = math.floor(validatedValue / SECONDS_PER_DAY)
		local remainingSeconds = validatedValue % SECONDS_PER_DAY
		validatedValue = days * 1000000 + remainingSeconds
	end

	validatedValue = math.round(validatedValue)

	local success, error = pcall(function()
		return LeaderboardStores[statName]:SetAsync(tostring(player.UserId), validatedValue)
	end)

	if not success then
		warn("Failed to update leaderboard for", player.Name, "in", statName, ":", error)
	end

	return success
end

return Leaderboards
