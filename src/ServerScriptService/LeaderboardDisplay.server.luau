-- LeaderboardDisplay: fills the three physical global leaderboards (Wins / Rank / TimePlayed)
-- from their OrderedDataStores. Refreshes periodically.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local TOP_N = 100          -- how many ranks to show
local REFRESH = 60         -- seconds between refreshes

-- ===== formatters =====
local function abbreviate(n)
	n = tonumber(n) or 0
	if n >= 1e9 then return string.format("%.1fB", n/1e9):gsub("%.0B","B")
	elseif n >= 1e6 then return string.format("%.1fM", n/1e6):gsub("%.0M","M")
	elseif n >= 1e3 then return string.format("%.1fK", n/1e3):gsub("%.0K","K")
	else return tostring(math.floor(n)) end
end

local function formatTime(seconds)
	seconds = math.floor(tonumber(seconds) or 0)
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then return h .. "h " .. m .. "m"
	elseif m > 0 then return m .. "m"
	else return seconds .. "s" end
end

-- ===== board definitions =====
local function odsFor(name)
	return DataStoreService:GetOrderedDataStore(name)
end

local boards = {
	{
		model = workspace:WaitForChild("LobbyInteractives"):FindFirstChild("WinsLeaderboard", true),
		ods = odsFor("LB_Wins_v2"),
		title = 'Top <font color="#FF5959">Wins</font>',
		format = abbreviate,
	},
	{
		model = workspace:WaitForChild("LobbyInteractives"):FindFirstChild("RankLeaderboard", true),
		ods = odsFor("LB_Rank_v2"),
		title = 'Top <font color="#5491D3">Rank</font>',
		format = function(v) return tostring(math.floor(tonumber(v) or 0)) end,
	},
	{
		model = workspace:WaitForChild("LobbyInteractives"):FindFirstChild("TimePlayedLeaderboard", true),
		ods = odsFor("LB_TimePlayed_v2"),
		title = 'Top <font color="#4B974B">Time Played</font>',
		format = formatTime,
	},
}

-- find the SurfaceGui / Container / Template inside a board model
local function partsOf(model)
	local sg
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("SurfaceGui") then sg = d break end
	end
	if not sg then return nil end
	local container = sg:FindFirstChild("Container", true)
	local template = container and container:FindFirstChild("Template")
	local titleLabel
	local titleFrame = sg:FindFirstChild("Title", true)
	if titleFrame then titleLabel = titleFrame:FindFirstChildWhichIsA("TextLabel") end
	return sg, container, template, titleLabel
end

-- name cache so we don't re-fetch the same userId every refresh
local nameCache = {}
local function userName(userId)
	if nameCache[userId] then return nameCache[userId] end
	local ok, name = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
	local result = ok and name or ("Player" .. userId)
	nameCache[userId] = result
	return result
end

local function refreshBoard(board)
	local sg, container, template, titleLabel = partsOf(board.model)
	if not (container and template) then
		warn("[LeaderboardDisplay] missing Container/Template in " .. board.model.Name)
		return
	end
	if titleLabel then titleLabel.Text = board.title end
	template.Visible = false  -- the template itself is never shown

	-- fetch the top N
	local ok, pages = pcall(function()
		return board.ods:GetSortedAsync(false, TOP_N)  -- false = descending (highest first)
	end)
	if not ok then
		warn("[LeaderboardDisplay] GetSortedAsync failed for " .. board.model.Name .. ": " .. tostring(pages))
		return
	end
	local top = pages:GetCurrentPage()

	-- clear old rows (keep the Template)
	for _, c in ipairs(container:GetChildren()) do
		if c.Name == "Row" then c:Destroy() end
	end

	for i, entry in ipairs(top) do
		local userId = tonumber(entry.key)
		local value = entry.value
		if userId then
			local row = template:Clone()
			row.Name = "Row"
			row.Visible = true
			row.LayoutOrder = i
			local rankLabel = row:FindFirstChild("RankLabel")
			local nameLabel = row:FindFirstChild("NameLabel")
			local valueLabel = row:FindFirstChild("ValueLabel")
			local img = row:FindFirstChild("PlayerImage")
			if rankLabel then rankLabel.Text = "#" .. i end
			if nameLabel then nameLabel.Text = "@" .. userName(userId) end
			if valueLabel then valueLabel.Text = board.format(value) end
			if img then img.Image = "rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=420&h=420" end
			row.Parent = container
		end
	end
end

local function refreshAll()
	for _, board in ipairs(boards) do
		local okRun = pcall(refreshBoard, board)
		if not okRun then warn("[LeaderboardDisplay] refresh error for " .. board.model.Name) end
		task.wait(1)  -- stagger the datastore calls a little
	end
end

task.spawn(function()
	while true do
		refreshAll()
		task.wait(REFRESH)
	end
end)
