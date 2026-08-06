local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MapCatalog = require(ReplicatedStorage:WaitForChild("MapCatalog"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local ColoringBookConfig = require(ReplicatedStorage:WaitForChild("ColoringBookConfig"))
local KnifeIcon = require(ReplicatedStorage:WaitForChild("KnifeIcon"))
local KnifeImages = require(ReplicatedStorage:WaitForChild("KnifeImages"))
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))
local PoseConfig = require(ReplicatedStorage:WaitForChild("PoseConfig"))
local TitleManager = require(ReplicatedStorage:WaitForChild("TitleManager"))

local GameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local ColoringBookUpdate = GameRemotes:WaitForChild("ColoringBookUpdate")
local ColoringBookRequest = GameRemotes:WaitForChild("ColoringBookRequest")
local ColoringBookClaim = GameRemotes:WaitForChild("ColoringBookClaim")
local ColoringBookMarkSeen = GameRemotes:WaitForChild("ColoringBookMarkSeen")
local ColoringBookTutorialDone = GameRemotes:WaitForChild("ColoringBookTutorialDone")

local TAB_SELECTED = Color3.fromRGB(70, 255, 107)
local TAB_UNSELECTED = Color3.fromRGB(255, 255, 255)

local gui = playerGui:WaitForChild("ColoringBook")
local holderFrame = gui:WaitForChild("HolderFrame")
local root = holderFrame:WaitForChild("ColoringBook"):WaitForChild("ColoringBook")
local mapScroll = root:WaitForChild("MapScrollingFrame")
local template = mapScroll:WaitForChild("MapTemplate")
local closeBtn = root:WaitForChild("CloseButton")
local tutorialBtn = root:WaitForChild("Tutorial")

local fade = holderFrame:WaitForChild("Fade")
local fadeNoteBook = fade:WaitForChild("NoteBook")
local fadeConfirm = fadeNoteBook:WaitForChild("Confirm")
local fadeButtonHolder = fadeNoteBook:WaitForChild("ButtonHolder")
local fadeNext = fadeButtonHolder:WaitForChild("NextPage")
local fadePrev = fadeButtonHolder:WaitForChild("PreviousPage")
local fadePageNumber = fadeButtonHolder:WaitForChild("PageNumber")
local FADE_PAGES = 3
local tutorialPage = 1
local tutorialDone = false
local receivedData = false

local bookButtonNotif = playerGui:WaitForChild("Hud"):WaitForChild("LeftButtons"):WaitForChild("MainButtons"):WaitForChild("ColoringBookButton"):WaitForChild("NotificationIcon")

local noteBook = root:WaitForChild("NoteBook")
local noteIcon = noteBook:WaitForChild("Icon")
local claimBtn = noteBook:WaitForChild("Claim")
local progressHolder = noteBook:WaitForChild("ProgressHolder")
local progressBar = progressHolder:WaitForChild("Bar")
local progressLabel = progressHolder:WaitForChild("Progress")
local mapNameLabel = noteIcon:WaitForChild("MapName")
local pageNumber = noteIcon:WaitForChild("PageNumber")
local nextBtn = noteIcon:WaitForChild("NextPage")
local prevBtn = noteIcon:WaitForChild("PreviousPage")

local rewardIcon = noteBook:WaitForChild("RewardIcon")
local rewardTitle = rewardIcon:WaitForChild("Title")
local REWARD_TITLE_POS = rewardTitle.Position
local rewardAmount = rewardIcon:WaitForChild("Amount")
local REWARD_PLACEHOLDER = rewardIcon.Image

local tiles = {}
local selectedName = nil
local currentPage = 1
local booksData = {}
local rewardsData = {}
local canClaim = false  -- true only when the current page is complete AND not yet claimed

local iconComplete = noteIcon:WaitForChild("Icon_Complete")

local BLACK = Color3.fromRGB(0, 0, 0)
local WHITE = Color3.fromRGB(255, 255, 255)
local CLAIM_DISABLED = Color3.fromRGB(170, 170, 170)  -- light grey (like the unselected map tabs) shown when the page isn't claimable yet
local CLAIM_CLAIMED = Color3.fromRGB(90, 90, 90)

local function partIcons()
	local list = {}
	for _, child in ipairs(noteIcon:GetChildren()) do
		if child:IsA("ImageLabel") then
			local n = string.match(child.Name, "^Icon_(%d+)$")
			if n then
				list[tonumber(n)] = child
			end
		end
	end
	return list
end

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local BRUSH_SHEET = "rbxassetid://82849086340434"
local BRUSH_COLS = 5
local BRUSH_FRAMES = 23
local BRUSH_SHEET_PX = 1024
local BRUSH_FRAME_PX = BRUSH_SHEET_PX / BRUSH_COLS
local BRUSH_FRAME_SIZE = Vector2.new(BRUSH_FRAME_PX, BRUSH_FRAME_PX)
local BRUSH_FPS = 72
local BRUSH_LOOPS = 8
local BRUSH_SCALE = 1.5

local REVEAL_SOUND = Instance.new("Sound")
REVEAL_SOUND.Name = "ColoringBookReveal"
REVEAL_SOUND.SoundId = "rbxassetid://122208765404090"
REVEAL_SOUND.Volume = 1.5
local sfxGroup = SoundService:FindFirstChild("SFX")
if sfxGroup and sfxGroup:IsA("SoundGroup") then
	REVEAL_SOUND.SoundGroup = sfxGroup
end
REVEAL_SOUND.Parent = SoundService

local function playRevealSound()
	local s = REVEAL_SOUND:Clone()
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 2) + 0.1, function()
		if s then s:Destroy() end
	end)
end

local revealed = {}
local animating = {}
local revealQueues = {}

local COMPLETE_FADE = 0.7
local completeDone = {}
local completeAnimating = {}
local revealJustFinished = false

local function markRevealed(map, pageId, index)
	local m = revealed[map]
	if not m then m = {} revealed[map] = m end
	local p = m[pageId]
	if not p then p = {} m[pageId] = p end
	p[index] = true
end

local function isRevealed(map, pageId, index)
	local m = revealed[map]
	local p = m and m[pageId]
	return (p and p[index]) == true
end

local function setAnimating(map, pageId, index, value)
	local m = animating[map]
	if not m then m = {} animating[map] = m end
	local p = m[pageId]
	if not p then p = {} m[pageId] = p end
	p[index] = value or nil
end

local function isAnimating(map, pageId, index)
	local m = animating[map]
	local p = m and m[pageId]
	return (p and p[index]) == true
end

local function isCollected(map, pageId, index)
	local md = booksData[map]
	local entry = md and md[pageId]
	return entry ~= nil and type(entry.parts) == "table" and entry.parts["Book" .. index] == true
end

local function mapNeedsReveal(map)
	local md = booksData[map]
	if type(md) ~= "table" then
		return false
	end
	for pageId, entry in pairs(md) do
		if type(entry) == "table" and type(entry.parts) == "table" then
			for k, v in pairs(entry.parts) do
				if v == true then
					local idx = tonumber(string.match(k, "^Book(%d+)$"))
					if idx and not isRevealed(map, pageId, idx) and not isAnimating(map, pageId, idx) then
						return true
					end
				end
			end
		end
	end
	return false
end

local function updateNotifications()
	local anyPending = false
	for name, data in pairs(tiles) do
		local needs = mapNeedsReveal(name)
		if needs then
			anyPending = true
		end
		local notif = data.button:FindFirstChild("NotificationIcon")
		if notif then
			local viewing = gui.Enabled and name == selectedName
			notif.Visible = (not viewing) and needs
		end
	end
	if bookButtonNotif then
		bookButtonNotif.Visible = anyPending or not tutorialDone
	end
end

local function refreshTutorialPage()
	for i = 1, FADE_PAGES do
		local pg = fadeNoteBook:FindFirstChild("Page" .. i)
		if pg then
			pg.Visible = (i == tutorialPage)
		end
	end
	fadePrev.Visible = tutorialPage > 1
	fadeNext.Visible = tutorialPage < FADE_PAGES
	fadePageNumber.Text = string.format("%d of %d", tutorialPage, FADE_PAGES)
end

local function showTutorial()
	if fade.Visible then
		return
	end
	tutorialPage = 1
	refreshTutorialPage()
	fade.Visible = true
end

local function finishTutorial()
	fade.Visible = false
	if not tutorialDone then
		tutorialDone = true
		ColoringBookTutorialDone:FireServer()
		updateNotifications()
	end
end

fadeNext.Activated:Connect(function()
	UISounds.click()
	if tutorialPage < FADE_PAGES then
		tutorialPage += 1
		refreshTutorialPage()
	end
end)

fadePrev.Activated:Connect(function()
	UISounds.click()
	if tutorialPage > 1 then
		tutorialPage -= 1
		refreshTutorialPage()
	end
end)

fadeConfirm.Activated:Connect(function()
	UISounds.click()
	finishTutorial()
end)

tutorialBtn.Active = true
tutorialBtn.Activated:Connect(function()
	UISounds.click()
	showTutorial()
end)

UISounds.bindAll(fade)

local function playPartReveal(label, onDone)
	local brush = Instance.new("ImageLabel")
	brush.Name = "BrushReveal"
	brush.BackgroundTransparency = 1
	brush.AnchorPoint = Vector2.new(0.5, 0.5)
	brush.Position = UDim2.new(0.5, 0, -BRUSH_SCALE / 2, 0)
	brush.Size = UDim2.fromScale(BRUSH_SCALE, BRUSH_SCALE)
	brush.Image = BRUSH_SHEET
	brush.ImageRectSize = BRUSH_FRAME_SIZE
	brush.ImageRectOffset = Vector2.zero
	brush.ZIndex = 40
	brush.Parent = label.Parent

	label.ImageColor3 = BLACK
	local duration = (BRUSH_FRAMES * BRUSH_LOOPS) / BRUSH_FPS
	local colorTween = TweenService:Create(label, TweenInfo.new(duration, Enum.EasingStyle.Linear), { ImageColor3 = WHITE })
	local brushTween = TweenService:Create(brush, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Position = UDim2.new(0.5, 0, 0.5, 0) })

	task.spawn(function()
		playRevealSound()
		colorTween:Play()
		brushTween:Play()
		for _ = 1, BRUSH_LOOPS do
			for i = 0, BRUSH_FRAMES - 1 do
				local col = i % BRUSH_COLS
				local row = math.floor(i / BRUSH_COLS)
				brush.ImageRectOffset = Vector2.new(col * BRUSH_FRAME_PX, row * BRUSH_FRAME_PX)
				task.wait(1 / BRUSH_FPS)
			end
		end
		if brush.Parent then
			brush:Destroy()
		end
		label.ImageColor3 = WHITE
		if onDone then
			onDone()
		end
	end)
end

local function rewardName(reward)
	if reward.kind == "coins" then
		return "Coins"
	elseif reward.kind == "fireworks" then
		return "Fireworks"
	elseif reward.kind == "knife" then
		local d = KnifeSkinManager.getSkin(reward.id)
		return (d and d.name) or reward.name or reward.id
	elseif reward.kind == "killEffect" then
		local d = KillEffectManager.getEffect(reward.id)
		return (d and d.name) or reward.name or reward.id
	elseif reward.kind == "pose" then
		local d = PoseConfig.getPose(reward.id)
		return (d and d.name) or reward.name or reward.id
	elseif reward.kind == "title" then
		return (TitleManager.titleName and TitleManager.titleName(reward.id)) or reward.name or reward.id
	end
	return reward.name or ""
end

local function setAmount(text)
	rewardAmount.Text = text
	local top = rewardAmount:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then
		top.Text = text
	end
end

local function rewardImage(reward)
	if reward.kind == "coins" then
		return ColoringBookConfig.CURRENCY_ICONS and ColoringBookConfig.CURRENCY_ICONS.coins
	elseif reward.kind == "fireworks" then
		return ColoringBookConfig.CURRENCY_ICONS and ColoringBookConfig.CURRENCY_ICONS.fireworks
	elseif reward.kind == "knife" then
		return KnifeImages.get(reward.id)
	elseif reward.kind == "killEffect" then
		local d = KillEffectManager.getEffect(reward.id)
		return d and d.icon
	elseif reward.kind == "pose" then
		local d = PoseConfig.getPose(reward.id)
		return d and d.icon
	end
	return nil
end

local function refreshReward()
	if not selectedName then
		return
	end
	local def = ColoringBookConfig.getMapReward(selectedName)
	if not def then
		return
	end
	local reward = def.first
	if not reward then
		return
	end

	rewardTitle.Text = rewardName(reward)
	if reward.kind == "title" then
		rewardTitle.Position = UDim2.fromScale(0.5, 0.5)
	elseif reward.kind == "knife" then
		rewardTitle.Position = REWARD_TITLE_POS + UDim2.fromScale(0, 0.08)
	else
		rewardTitle.Position = REWARD_TITLE_POS
	end

	local rewardScale = rewardIcon:FindFirstChildOfClass("UIScale")
	if not rewardScale then
		rewardScale = Instance.new("UIScale")
		rewardScale.Parent = rewardIcon
	end
	rewardScale.Scale = reward.kind == "knife" and 1.3 or 1

	if reward.kind == "knife" then
		local img = rewardImage(reward)
		if img and img ~= "" then
			KnifeIcon.render(rewardIcon, nil)
			rewardIcon.Image = img
		else
			rewardIcon.Image = REWARD_PLACEHOLDER
			KnifeIcon.render(rewardIcon, reward.id)
		end
		setAmount("")
		rewardAmount.Visible = false
	elseif reward.kind == "title" then
		KnifeIcon.render(rewardIcon, nil)
		rewardIcon.Image = ""
		setAmount("")
		rewardAmount.Visible = false
	else
		KnifeIcon.render(rewardIcon, nil)
		local img = rewardImage(reward)
		if img == nil or img == "" then
			img = REWARD_PLACEHOLDER
		end
		rewardIcon.Image = img
		if reward.kind == "coins" or reward.kind == "fireworks" then
			setAmount(tostring(reward.amount))
			rewardAmount.Visible = true
		else
			setAmount("")
			rewardAmount.Visible = false
		end
	end
end

local function refreshIcons()
	if not selectedName then
		return
	end
	local pageId = "Page" .. currentPage
	local mapData = booksData[selectedName]
	local entry = mapData and mapData[pageId]
	local parts = (entry and entry.parts) or {}

	local art = ColoringBookConfig.getIcons(selectedName)
	local artParts = (art and art.parts) or {}

	local icons = partIcons()
	local total, got, shownCount = 0, 0, 0
	for index, label in pairs(icons) do
		total += 1
		if artParts[index] then
			label.Image = artParts[index]
		end
		if parts["Book" .. index] == true then
			got += 1
		end
		local shown = isRevealed(selectedName, pageId, index)
		if shown then
			shownCount += 1
		end
		if not isAnimating(selectedName, pageId, index) then
			label.ImageColor3 = shown and WHITE or BLACK
		end
	end

	if art and art.complete then
		iconComplete.Image = art.complete
	end

	local complete = total > 0 and got == total
	local completeShown = total > 0 and shownCount == total
	local claimed = entry and entry.claimed == true

	progressLabel.Text = string.format("%d/%d", got, total)
	progressBar.Size = UDim2.new(total > 0 and (got / total) or 0, 0, 1, 0)

	canClaim = complete and not claimed
	claimBtn.Visible = true
	claimBtn.Active = canClaim
	claimBtn.AutoButtonColor = canClaim
	local claimText = claimBtn:FindFirstChildOfClass("TextLabel")
	local claimTop = claimText and claimText:FindFirstChild("Top")
	local function setClaimLabel(text, transparency)
		if claimText then
			claimText.Text = text
			claimText.TextTransparency = transparency
			if claimTop and claimTop:IsA("TextLabel") then
				claimTop.Text = text
				claimTop.TextTransparency = transparency
			end
		end
	end
	if claimed then
		claimBtn.ImageColor3 = CLAIM_CLAIMED
		setClaimLabel("Claimed", 0)
	elseif canClaim then
		claimBtn.ImageColor3 = WHITE
		setClaimLabel("Claim", 0)
	else
		claimBtn.ImageColor3 = CLAIM_DISABLED
		setClaimLabel("Claim", 0.4)
	end

	local pageKey = selectedName .. "|" .. pageId
	local doAnimate = revealJustFinished
	revealJustFinished = false

	if completeShown then
		if not completeDone[pageKey] and doAnimate then
			completeDone[pageKey] = true
			completeAnimating[pageKey] = true
			for _, label in pairs(icons) do
				label.Visible = true
			end
			iconComplete.ImageTransparency = 1
			local info = TweenInfo.new(COMPLETE_FADE, Enum.EasingStyle.Linear)
			TweenService:Create(iconComplete, info, { ImageTransparency = 0 }):Play()
			for _, label in pairs(icons) do
				TweenService:Create(label, info, { ImageTransparency = 1 }):Play()
			end
			local animKey = pageKey
			task.delay(COMPLETE_FADE, function()
				completeAnimating[animKey] = nil
				if not selectedName then
					return
				end
				if (selectedName .. "|Page" .. currentPage) ~= animKey then
					return
				end
				for _, lb in pairs(partIcons()) do
					lb.Visible = false
					lb.ImageTransparency = 0
				end
			end)
		elseif not completeAnimating[pageKey] then
			completeDone[pageKey] = true
			for _, label in pairs(icons) do
				label.Visible = false
				label.ImageTransparency = 0
			end
			iconComplete.ImageTransparency = 0
		end
	else
		completeDone[pageKey] = nil
		completeAnimating[pageKey] = nil
		for _, label in pairs(icons) do
			label.Visible = true
			label.ImageTransparency = 0
		end
		iconComplete.ImageTransparency = 1
	end

	refreshReward()
end

local function runRevealQueue(map, pageId)
	local key = map .. "|" .. pageId
	if revealQueues[key] then
		return
	end
	revealQueues[key] = true
	task.spawn(function()
		while selectedName == map and ("Page" .. currentPage) == pageId do
			local icons = partIcons()
			local nextIdx = nil
			for index = 1, 25 do
				local label = icons[index]
				if label and isCollected(map, pageId, index)
					and not isRevealed(map, pageId, index)
					and not isAnimating(map, pageId, index) then
					nextIdx = index
					break
				end
			end
			if not nextIdx then
				break
			end
			local label = icons[nextIdx]
			setAnimating(map, pageId, nextIdx, true)
			updateNotifications()
			local finished = false
			playPartReveal(label, function()
				markRevealed(map, pageId, nextIdx)
				setAnimating(map, pageId, nextIdx, false)
				ColoringBookMarkSeen:FireServer(map, pageId, "Book" .. nextIdx)
				finished = true
			end)
			while not finished do
				task.wait()
			end
			revealJustFinished = true
			refreshIcons()
			updateNotifications()
		end
		revealQueues[key] = false
		refreshIcons()
		updateNotifications()
	end)
end

local function getMapPages(entry)
	return { entry.thumbnail }
end

local function renderPage()
	local data = selectedName and tiles[selectedName]
	if not data then
		return
	end
	local pages = getMapPages(data.entry)
	local total = #pages
	currentPage = math.clamp(currentPage, 1, math.max(1, total))
	
	local multiPage = total > 1
	pageNumber.Visible = multiPage
	if multiPage then
		pageNumber.Text = string.format("%d of %d", currentPage, total)
	end
	
	prevBtn.Visible = multiPage and currentPage > 1
	nextBtn.Visible = multiPage and currentPage < total
	refreshIcons()
	updateNotifications()
	if gui.Enabled and selectedName then
		runRevealQueue(selectedName, "Page" .. currentPage)
	end
end

local function selectMap(name)
	local data = tiles[name]
	if not data then
		return
	end
	selectedName = name
	currentPage = 1
	for n, t in pairs(tiles) do
		t.button.ImageColor3 = (n == name) and TAB_SELECTED or TAB_UNSELECTED
	end
	mapNameLabel.Text = data.entry.name
	renderPage()
end

local built = false
local function buildTiles()
	if built then
		return
	end
	built = true
	template.Parent = nil
	for _, entry in ipairs(MapCatalog.list()) do
		local tile = template:Clone()
		tile.Name = "MapTile_" .. entry.name
		tile.LayoutOrder = entry.order or 0
		tile.Visible = true
		local limitedTime = tile:FindFirstChild("LimitedTime")
		if limitedTime and limitedTime:IsA("GuiObject") then
			limitedTime.Visible = false
		end
		local mapIcon = tile:FindFirstChild("MapIcon")
		if mapIcon and entry.thumbnail and entry.thumbnail ~= "" then
			mapIcon.Image = entry.thumbnail
		end
		local top = tile:FindFirstChild("Top")
		if top and top:IsA("TextLabel") then
			top.Text = entry.name
		end
		tiles[entry.name] = { button = tile, entry = entry }
		tile.Activated:Connect(function()
			UISounds.click()
			selectMap(entry.name)
		end)
		tile.Parent = mapScroll
	end
	local first = MapCatalog.list()[1]
	if first then
		selectMap(first.name)
	end
end

nextBtn.Activated:Connect(function()
	UISounds.click()
	currentPage += 1
	renderPage()
end)

prevBtn.Activated:Connect(function()
	UISounds.click()
	currentPage -= 1
	renderPage()
end)

closeBtn.Activated:Connect(function()
	UISounds.close()
	gui.Enabled = false
end)

claimBtn.Activated:Connect(function()
	if not selectedName then
		return
	end
	
	if not canClaim then
		return
	end
	
	UISounds.click()
	ColoringBookClaim:FireServer(selectedName, "Page" .. currentPage)
end)

buildTiles()

claimBtn:SetAttribute("UISoundsBound", true)
claimBtn.MouseEnter:Connect(function()
	if canClaim then UISounds.hover() end
end)
UISounds.bindTween(claimBtn, function() return canClaim end)
UISounds.bindAll(root)

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	updateNotifications()
	if gui.Enabled then
		if receivedData and not tutorialDone then
			showTutorial()
		end
		if selectedName then
			runRevealQueue(selectedName, "Page" .. currentPage)
		end
	end
end)

ColoringBookUpdate.OnClientEvent:Connect(function(data)
	booksData = (data and data.books) or {}
	rewardsData = (data and data.rewards) or {}
	tutorialDone = (data and data.tutorialDone) == true
	receivedData = true

	for map, md in pairs(booksData) do
		if type(md) == "table" then
			for pageId, entry in pairs(md) do
				if type(entry) == "table" and type(entry.seen) == "table" then
					for k, v in pairs(entry.seen) do
						if v == true then
							local idx = tonumber(string.match(k, "^Book(%d+)$"))
							if idx then
								markRevealed(map, pageId, idx)
							end
						end
					end
				end
			end
		end
	end

	refreshIcons()
	updateNotifications()

	if gui.Enabled and not tutorialDone then
		showTutorial()
	end

	if gui.Enabled and selectedName then
		runRevealQueue(selectedName, "Page" .. currentPage)
	end
end)

ColoringBookRequest:FireServer()
