local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ColoringBookConfig = require(ReplicatedStorage.ColoringBookConfig)
local Knit = require(ReplicatedStorage.Packages.Knit)
local MapManager = require(ServerScriptService.MapManager)

local ColoringBookService = Knit.CreateService({
	Name = "ColoringBookService",
	Client = {},
})

local DataService
local function data()
	if not DataService then
		DataService = Knit.GetService("DataService")
	end
	
	return DataService
end

local CoinService
local function coins()
	if not CoinService then
		CoinService = Knit.GetService("CoinService")
	end
	
	return CoinService
end

local NotificationService
local function notif()
	if not NotificationService then
		NotificationService = Knit.GetService("NotificationService")
	end
	
	return NotificationService
end

local function grantReward(player, reward)
	if not reward then
		return
	end
	local kind = reward.kind
	if kind == "coins" then
		coins():Award(player, reward.amount, "coloring book reward")
	elseif kind == "fireworks" then
		data():AddFireworks(player, reward.amount, "coloring book reward")
	elseif kind == "knife" then
		data():GrantWeaponOnce(player, reward.id, reward.effect or "none")
	elseif kind == "killEffect" then
		data():AddKillEffect(player, reward.id)
	elseif kind == "pose" then
		data():GrantPose(player, reward.id)
	elseif kind == "title" then
		data():GrantTitle(player, reward.id)
	end
end

local function gameRemotesFolder()
	local folder = ReplicatedStorage:FindFirstChild("GameRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "GameRemotes"
		folder.Parent = ReplicatedStorage
	end
	
	return folder
end

local function ensureRemote(name)
	local folder = gameRemotesFolder()
	local r = folder:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = folder
	end
	
	return r
end

local friendPairCache = {}
local function friendPairKey(u1, u2)
	if u1 > u2 then u1, u2 = u2, u1 end
	return u1 .. "_" .. u2
end
local function areFriends(p1, p2)
	local key = friendPairKey(p1.UserId, p2.UserId)
	local cached = friendPairCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return p1:IsFriendsWith(p2.UserId)
	end)
	local val = ok and result == true
	friendPairCache[key] = val
	return val
end

local function booksOf(d)
	if type(d.ColoringBooks) ~= "table" then
		d.ColoringBooks = {}
	end
	
	return d.ColoringBooks
end

local function rewardsOf(d)
	if type(d.ColoringBookRewards) ~= "table" then
		d.ColoringBookRewards = {}
	end
	
	return d.ColoringBookRewards
end

local function normalizeSeen(d)
	local books = booksOf(d)
	for _, map in pairs(books) do
		if type(map) == "table" then
			for _, entry in pairs(map) do
				if type(entry) == "table" and type(entry.parts) == "table" and type(entry.seen) ~= "table" then
					local seen = {}
					for partId, v in pairs(entry.parts) do
						if v == true then
							seen[partId] = true
						end
					end
					entry.seen = seen
				end
			end
		end
	end
end

local function pageEntry(d, mapName, pageId, create)
	local books = booksOf(d)
	local map = books[mapName]
	if not map then
		if not create then
			return nil
		end
		map = {}
		books[mapName] = map
	end
	
	local entry = map[pageId]
	if not entry then
		if not create then
			return nil
		end
		entry = { parts = {}, claimed = false, seen = {} }
		map[pageId] = entry
	end
	
	if type(entry.parts) ~= "table" then
		entry.parts = {}
	end
	
	return entry
end

local function findMapModel(mapName)
	local activeName = MapManager.getActiveMapName and MapManager.getActiveMapName()
	if activeName and activeName == mapName and MapManager.getActiveMap then
		local m = MapManager.getActiveMap()
		if m then
			return m
		end
	end
	
	if MapManager.getMapByName then
		return MapManager.getMapByName(mapName)
	end
	
	return nil
end

local function bookFolderOf(mapName)
	local map = findMapModel(mapName)
	return map and map:FindFirstChild(ColoringBookConfig.FOLDER_NAME) or nil
end

local function pageFolderOf(mapName, pageId)
	local book = bookFolderOf(mapName)
	return book and book:FindFirstChild(pageId) or nil
end

local function pushBooks(player)
	local r = ensureRemote("ColoringBookUpdate")
	if not r then
		return
	end
	local d = data():Get(player)
	r:FireClient(player, {
		books = d and booksOf(d) or {},
		rewards = d and rewardsOf(d) or {},
		tutorialDone = d and d.ColoringBookTutorialDone == true,
	})
end

function ColoringBookService:shareWithFriends(collector, mapName, pageId, partId)
	local collectorName = collector.DisplayName
	local friendRemote = ensureRemote("ColoringBookFriendFound")
	for _, friend in ipairs(Players:GetPlayers()) do
		if friend ~= collector and areFriends(collector, friend) then
			local fd = data():Get(friend)
			if fd then
				local fentry = pageEntry(fd, mapName, pageId, true)
				if not fentry.parts[partId] then
					fentry.parts[partId] = true
					pushBooks(friend)
					pcall(function()
						notif():Preset(friend, "SUCCESS", "Coloring book found by your friend " .. collectorName)
					end)
					if friendRemote then
						friendRemote:FireClient(friend)
					end
				end
			end
		end
	end
end

function ColoringBookService:Get(player)
	local d = data():Get(player)
	if not d then
		return {}
	end
	
	return booksOf(d)
end

function ColoringBookService:GetPageParts(mapName, pageId)
	local ids = {}
	local folder = pageFolderOf(mapName, pageId)
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			ids[#ids + 1] = child.Name
		end
	end
	
	return ids
end

function ColoringBookService:GetPages(mapName)
	local ids = {}
	local book = bookFolderOf(mapName)
	if book then
		for _, page in ipairs(book:GetChildren()) do
			ids[#ids + 1] = page.Name
		end
	end
	
	return ids
end

function ColoringBookService:GetPageState(player, mapName, pageId)
	local parts = self:GetPageParts(mapName, pageId)
	local d = data():Get(player)
	local entry = d and pageEntry(d, mapName, pageId, false)
	local collected = {}
	local count = 0
	if entry then
		for _, id in ipairs(parts) do
			if entry.parts[id] then
				collected[id] = true
				count += 1
			end
		end
	end
	
	return {
		total = #parts,
		collectedCount = count,
		collected = collected,
		complete = (#parts > 0 and count >= #parts),
		claimed = entry and entry.claimed or false,
	}
end

function ColoringBookService:IsPageComplete(player, mapName, pageId)
	local d = data():Get(player)
	if not d then
		return false
	end
	
	local parts = self:GetPageParts(mapName, pageId)
	if #parts == 0 then
		return false
	end
	
	local entry = pageEntry(d, mapName, pageId, false)
	if not entry then
		return false
	end
	
	for _, id in ipairs(parts) do
		if not entry.parts[id] then
			return false
		end
	end
	
	return true
end

function ColoringBookService:IsBookComplete(player, mapName)
	local book = bookFolderOf(mapName)
	if not book then
		return false
	end
	
	local anyPage = false
	for _, page in ipairs(book:GetChildren()) do
		anyPage = true
		if not self:IsPageComplete(player, mapName, page.Name) then
			return false
		end
	end
	
	return anyPage
end

function ColoringBookService:CollectPart(player, mapName, pageId, partId)
	if not ColoringBookConfig.ENABLED then
		return false, "disabled"
	end
	
	if type(mapName) ~= "string" or type(pageId) ~= "string" or type(partId) ~= "string" then
		return false, "badargs"
	end
	
	local d = data():Get(player)
	if not d then
		return false, "nodata"
	end
	
	local valid = false
	for _, id in ipairs(self:GetPageParts(mapName, pageId)) do
		if id == partId then
			valid = true
			break
		end
	end
	
	if not valid then
		return false, "invalidpart"
	end
	
	local entry = pageEntry(d, mapName, pageId, true)
	if entry.parts[partId] then
		return true, "already"
	end
	
	entry.parts[partId] = true
	pushBooks(player)

	coins():Award(player, 25, "coloring book piece")
	do
		local pModel = pageFolderOf(mapName, pageId)
		pModel = pModel and pModel:FindFirstChild(partId)
		local worldPos = pModel and pModel:GetPivot().Position
		if worldPos then
			local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
			local cc = remotes and remotes:FindFirstChild("CoinCollected")
			if cc then
				cc:FireClient(player, worldPos, 25, "Coin")
			end
		end
	end

	task.spawn(function()
		self:shareWithFriends(player, mapName, pageId, partId)
	end)
	
	local parts = self:GetPageParts(mapName, pageId)
	local total = #parts
	local got = 0
	for _, id in ipairs(parts) do
		if entry.parts[id] then
			got += 1
		end
	end
	
	if total > 0 and got >= total then
		pcall(function()
			notif():Preset(player, "SUCCESS", ("Coloring book complete! (%d/%d)"):format(got, total))
		end)
		return true, "completed"
	end
	
	pcall(function()
		notif():Preset(player, "INFO", ("Found a coloring book piece! (%d/%d)"):format(got, total))
	end)
	return true, "collected"
end

function ColoringBookService:CollectPartInstance(player, partInstance)
	if typeof(partInstance) ~= "Instance" then
		return false, "badinstance"
	end
	
	local pageFolder = partInstance.Parent
	local book = pageFolder and pageFolder.Parent
	local mapModel = book and book.Parent
	if not (pageFolder and book and mapModel) then
		return false, "badhierarchy"
	end
	
	if book.Name ~= ColoringBookConfig.FOLDER_NAME then
		return false, "notbook"
	end
	
	local mapName
	if MapManager.getActiveMap and mapModel == MapManager.getActiveMap() then
		mapName = (MapManager.getActiveMapName and MapManager.getActiveMapName()) or mapModel.Name
	else
		mapName = mapModel.Name
	end
	
	return self:CollectPart(player, mapName, pageFolder.Name, partInstance.Name)
end

function ColoringBookService:MarkSeen(player, mapName, pageId, partId)
	if type(mapName) ~= "string" or type(pageId) ~= "string" or type(partId) ~= "string" then
		return
	end
	local d = data():Get(player)
	if not d then
		return
	end
	local entry = pageEntry(d, mapName, pageId, false)
	if not entry then
		return
	end
	if not entry.parts[partId] then
		return
	end
	if type(entry.seen) ~= "table" then
		entry.seen = {}
	end
	entry.seen[partId] = true
end

function ColoringBookService:ResetBook(player, mapName)
	local d = data():Get(player)
	if not d then
		return false
	end
	
	local books = booksOf(d)
	if mapName then
		books[mapName] = nil
	else
		table.clear(books)
	end
	
	pushBooks(player)
	return true
end

function ColoringBookService:ClaimPageReward(player, mapName, pageId)
	if not ColoringBookConfig.ENABLED then
		return false, "disabled"
	end
	
	if type(mapName) ~= "string" or type(pageId) ~= "string" then
		return false, "badargs"
	end
	
	local d = data():Get(player)
	if not d then
		return false, "nodata"
	end
	
	if not self:IsPageComplete(player, mapName, pageId) then
		return false, "incomplete"
	end
	
	local entry = pageEntry(d, mapName, pageId, true)
	if entry.claimed then
		return false, "already"
	end
	
	local def = ColoringBookConfig.getMapReward(mapName)
	local rewards = rewardsOf(d)
	local granted
	if def and def.first and not rewards[mapName] then
		grantReward(player, def.first)
		rewards[mapName] = true
		granted = def.first
	end
	
	entry.claimed = true
	pushBooks(player)
	return true, "claimed", granted
end

function ColoringBookService:MarkTutorialDone(player)
	local d = data():Get(player)
	if not d then
		return
	end
	if d.ColoringBookTutorialDone == true then
		return
	end
	d.ColoringBookTutorialDone = true
	pushBooks(player)
end

local touchConns = {}
local touchDebounce = {}

local function disconnectTouchConns()
	for _, c in ipairs(touchConns) do
		if c then
			c:Disconnect()
		end
	end
	table.clear(touchConns)
	table.clear(touchDebounce)
end

function ColoringBookService:SetActive(active)
	local map = MapManager.getActiveMap and MapManager.getActiveMap()
	local book = map and map:FindFirstChild(ColoringBookConfig.FOLDER_NAME)
	if not book then
		disconnectTouchConns()
		return
	end
	
	disconnectTouchConns()
	
	local dist = active and ColoringBookConfig.CLICK_DISTANCE or 0
	for _, page in ipairs(book:GetChildren()) do
		for _, model in ipairs(page:GetChildren()) do
			if model:IsA("Model") then
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("BasePart") then
						if d.Name == "Collision" then
							local cd = d:FindFirstChildOfClass("ClickDetector")
							if cd then
								cd.MaxActivationDistance = dist
							end
							if active then
								d.CanTouch = true
								local collectModel = model
								table.insert(touchConns, d.Touched:Connect(function(hit)
									local char = hit and hit:FindFirstAncestorOfClass("Model")
									local toucher = char and Players:GetPlayerFromCharacter(char)
									if not toucher then
										return
									end
									local perPlayer = touchDebounce[toucher]
									local now = os.clock()
									if perPlayer and perPlayer[collectModel] and now - perPlayer[collectModel] < 1 then
										return
									end
									if not perPlayer then
										perPlayer = {}
										touchDebounce[toucher] = perPlayer
									end
									perPlayer[collectModel] = now
									self:CollectPartInstance(toucher, collectModel)
								end))
							end
						else
							d.Transparency = active and 0 or 1
						end
					end
				end
			end
		end
	end
end

function ColoringBookService:KnitStart()
	ensureRemote("ColoringBookUpdate")
	ensureRemote("ColoringBookPageComplete")
	ensureRemote("ColoringBookFriendFound")
	
	local collect = ensureRemote("ColoringBookCollectRequest")
	collect.OnServerEvent:Connect(function(player, inst)
		if typeof(inst) ~= "Instance" then
			return
		end
		local model = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
		if not model then
			return
		end
		local active = MapManager.getActiveMap and MapManager.getActiveMap()
		if not active or not model:IsDescendantOf(active) then
			return
		end
		self:CollectPartInstance(player, model)
	end)
	
	local claim = ensureRemote("ColoringBookClaim")
	claim.OnServerEvent:Connect(function(player, mapName, pageId)
		if type(mapName) ~= "string" or type(pageId) ~= "string" then
			return
		end
		self:ClaimPageReward(player, mapName, pageId)
	end)
	
	local request = ensureRemote("ColoringBookRequest")
	request.OnServerEvent:Connect(function(player)
		task.spawn(function()
			data():WaitForData(player)
			local d = data():Get(player)
			if d then
				normalizeSeen(d)
			end
			pushBooks(player)
		end)
	end)
	
	local markSeen = ensureRemote("ColoringBookMarkSeen")
	markSeen.OnServerEvent:Connect(function(player, mapName, pageId, partId)
		self:MarkSeen(player, mapName, pageId, partId)
	end)

	local tutorialDoneRemote = ensureRemote("ColoringBookTutorialDone")
	tutorialDoneRemote.OnServerEvent:Connect(function(player)
		self:MarkTutorialDone(player)
	end)
	
	local function primePlayer(player)
		task.spawn(function()
			data():WaitForData(player)
			local d = data():Get(player)
			if d then
				normalizeSeen(d)
			end
			pushBooks(player)
		end)
	end
	
	Players.PlayerRemoving:Connect(function(player)
		local uid = tostring(player.UserId)
		for key in pairs(friendPairCache) do
			local a, b = key:match("^(%d+)_(%d+)$")
			if a == uid or b == uid then
				friendPairCache[key] = nil
			end
		end
	end)

	Players.PlayerAdded:Connect(primePlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		primePlayer(player)
	end
end

return ColoringBookService
