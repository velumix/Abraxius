local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local MapCatalog = require(ReplicatedStorage:WaitForChild("MapCatalog"))
local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local ChooseMapConfirm = Remotes:WaitForChild("ChooseMapConfirm")
local MapQueueUpdate = Remotes:WaitForChild("MapQueueUpdate")

local priceCache = {}

local playerCustomMaps
local top10Maps
local mapScroll, mapTemplate
local queueFrame, queueTemplate, queueEmpty
local yourMapScroll, yourMapTemplate
local communityMapsScroll, communityMapTemplate

local MAP_ID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"
local COOLDOWN_SECONDS = 60

local isOnCooldown = false

local function getGui()
	return playerGui:FindFirstChild("ChooseMap")
end

local function getRoot()
	local gui = getGui()
	local holder = gui and gui:FindFirstChild("HolderFrame")
	return holder and holder:FindFirstChild("ChooseMap")
end

local function setOpen(open)
	local gui = getGui()
	if gui then gui.Enabled = open end
end

local function ensureRefs()
	local root = getRoot()
	if not root then return false end
	if not mapTemplate then
		mapScroll = root:FindFirstChild("MapScrollingFrame")
		local t = mapScroll and mapScroll:FindFirstChild("Template")
		if t then
			mapTemplate = t
			t.Parent = nil
		end
	end
	if not communityMapTemplate then
		communityMapsScroll = root:FindFirstChild("CommunityMapScrollingFrame")
		local t = communityMapsScroll and communityMapsScroll:FindFirstChild("Template")
		if t then
			communityMapTemplate = t
			t.Parent = nil
		end
	end
	if not yourMapTemplate then
		yourMapScroll = root:FindFirstChild("YourMapsScrollingFrame")
		local t = yourMapScroll and yourMapScroll:FindFirstChild("Template")
		if t then
			yourMapTemplate = t
			t.Parent = nil
		end
	end
	if not queueTemplate then
		queueFrame = root:FindFirstChild("ActiveQueue")
		local t = queueFrame and queueFrame:FindFirstChild("Template")
		if t then
			queueTemplate = t
			t.Parent = nil
		end
		queueEmpty = queueFrame and queueFrame:FindFirstChild("Empty")
	end
	return (mapTemplate ~= nil) and (queueTemplate ~= nil)
end

local function addButtonFeel(button, hoverScale, pressScale)
	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Scale = 1
		scale.Parent = button
	end
	local function tween(to)
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = to }):Play()
	end
	button.MouseEnter:Connect(function() UISounds.hover(); tween(hoverScale) end)
	button.MouseLeave:Connect(function() tween(1) end)
	button.MouseButton1Down:Connect(function() tween(pressScale) end)
	button.MouseButton1Up:Connect(function() tween(hoverScale) end)
end

local function setText(label, text)
	if label then label.Text = text end
end

local function applyCreator(label, creator)
	if not label then return end
	if creator and creator ~= "" then
		label.Text = "By " .. creator
		label.Visible = true
	else
		label.Visible = false
	end
end

local function applyPrice(buy, productId)
	local price = buy and buy:FindFirstChild("Price")
	if not price then return end
	local top = price:FindFirstChild("Top")
	local function show(robux)
		setText(price, tostring(robux))
		setText(top, tostring(robux))
	end
	if priceCache[productId] then
		show(priceCache[productId])
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			priceCache[productId] = info.PriceInRobux
			show(info.PriceInRobux)
		end
	end)
end

local tilesBuilt = false
local function buildTiles()
	if tilesBuilt then return end
	if not ensureRefs() then return end
	tilesBuilt = true
	for _, entry in ipairs(MapCatalog.list()) do
		local tile = mapTemplate:Clone()
		tile.Name = "Tile_" .. entry.name
		tile.LayoutOrder = entry.order or 0
		tile.Visible = true
		local limitedTime = tile:FindFirstChild("LimitedTime")
		if limitedTime and limitedTime:IsA("GuiObject") then
			limitedTime.Visible = false
		end
		setText(tile:FindFirstChild("MapName"), entry.name)
		local icon = tile:FindFirstChild("MapIcon")
		if icon and entry.thumbnail and entry.thumbnail ~= "" then
			icon.Image = entry.thumbnail
		end
		applyCreator(tile:FindFirstChild("MapCreator"), entry.creator)
		local buy = tile:FindFirstChild("Buy")
		applyPrice(buy, entry.productId)
		if buy then
			addButtonFeel(buy, 1.05, 0.95)
			buy.Activated:Connect(function()
				UISounds.click()
				pcall(function()
					MarketplaceService:PromptProductPurchase(player, entry.productId)
				end)
			end)
		end
		tile.Parent = mapScroll
	end
end

local function renderQueue(snapshot)
	if not ensureRefs() then return end
	for _, child in ipairs(queueFrame:GetChildren()) do
		if child.Name == "QueueEntry" then child:Destroy() end
	end
	snapshot = snapshot or {}
	if queueEmpty then queueEmpty.Visible = (#snapshot == 0) end
	for i, item in ipairs(snapshot) do
		local cat = MapCatalog.get(item.name)
		local entry = queueTemplate:Clone()
		entry.Name = "QueueEntry"
		entry.LayoutOrder = i
		entry.Visible = true
		local limitedTime = entry:FindFirstChild("LimitedTime")
		if limitedTime and limitedTime:IsA("GuiObject") then
			limitedTime.Visible = false
		end
		setText(entry:FindFirstChild("MapName"), item.name)
		applyCreator(entry:FindFirstChild("MapCreator"), cat and cat.creator)
		setText(entry:FindFirstChild("QueueLabel"), "#" .. i)
		setText(entry:FindFirstChild("PlayerBought"), item.buyerName or "")
		local icon = entry:FindFirstChild("MapIcon")
		if icon and cat and cat.thumbnail and cat.thumbnail ~= "" then
			icon.Image = cat.thumbnail
		end
		local pIcon = entry:FindFirstChild("PlayerIcon")
		if pIcon and item.buyerUserId then
			task.spawn(function()
				local ok, url = pcall(function()
					return Players:GetUserThumbnailAsync(item.buyerUserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				if ok and url then pIcon.Image = url end
			end)
		end
		entry.Parent = queueFrame
	end
end

local function requestQueue()
	pcall(function() MapQueueUpdate:FireServer() end)
end

MapQueueUpdate.OnClientEvent:Connect(renderQueue)

local function wireClose()
	local root = getRoot()
	local closeBtn = root and root:FindFirstChild("CloseButton")
	if closeBtn and closeBtn:IsA("GuiButton") and not closeBtn:GetAttribute("CMWired") then
		closeBtn:SetAttribute("CMWired", true)
		closeBtn.AutoButtonColor = false
		addButtonFeel(closeBtn, 1.12, 0.9)
		closeBtn.Activated:Connect(function()
			UISounds.close()
			setOpen(false)
		end)
	end
end

local function showConfirm(mapName)
	local fx = playerGui:FindFirstChild("ChooseMapFX")
	if not fx then
		fx = Instance.new("ScreenGui")
		fx.Name = "ChooseMapFX"
		fx.ResetOnSpawn = false
		fx.IgnoreGuiInset = true
		fx.DisplayOrder = 50
		fx.Parent = playerGui
	end
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(0.5, 0.08)
	lbl.Position = UDim2.fromScale(0.25, 0.4)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.FredokaOne
	lbl.TextScaled = true
	lbl.TextColor3 = Color3.fromRGB(120, 255, 140)
	lbl.Text = (mapName or "Map") .. " queued for next round!"
	lbl.TextStrokeTransparency = 0.4
	lbl.Parent = fx
	task.delay(1.4, function()
		local up = TweenService:Create(lbl, TweenInfo.new(1.2, Enum.EasingStyle.Quad), {
			Position = lbl.Position - UDim2.fromScale(0, 0.06),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		})
		up:Play()
		up.Completed:Wait()
		lbl:Destroy()
	end)
end

ChooseMapConfirm.OnClientEvent:Connect(function(mapName)
	showConfirm(mapName)
	setOpen(false)
end)

local function openMenu()
	UISounds.select()
	buildTiles()
	wireClose()
	requestQueue()
	setOpen(true)
end

local function hookPrompt()
	local cm = Workspace:FindFirstChild("LobbyInteractives")
	cm = cm and cm:FindFirstChild("ChooseMap")
	local screen = cm and cm:FindFirstChild("Screen")
	local prompt = screen and screen:FindFirstChild("ChooseMapPrompt")
	if not prompt then return false end
	if prompt:GetAttribute("CMHooked") then return true end
	prompt:SetAttribute("CMHooked", true)
	prompt.Triggered:Connect(function(plr)
		if plr ~= player then return end
		openMenu()
	end)
	return true
end

local function loadCustomMaps()
	for _, frame in yourMapScroll:GetChildren() do
		if frame:IsA("Frame") and frame.Name == "Template" then
			frame:Destroy()
		end
	end
	
	for _, mapInfo in playerCustomMaps do
		local frame = yourMapTemplate:Clone()
		frame.MapCreator.Text = player.DisplayName or player.Name
		frame.MapName.Text = "Slot ".. mapInfo.slot
		frame.Frame.TextBox.Text = mapInfo.mapId
		frame.Parent = yourMapScroll
		frame.Visible = true
	end
end

local function loadTop10Maps()
	for _, frame in communityMapsScroll:GetChildren() do
		if frame:IsA("Frame") and frame.Name == "Template" then
			frame:Destroy()
		end
	end

	for _, mapInfo in top10Maps do
		--local success, username = pcall(function()
			--return Players:GetNameFromUserIdAsync(tonumber(mapInfo.CreatorId))
		--end)
		
		--if success then
		local frame = communityMapTemplate:Clone()
		--frame.MapCreator.Text = username
		frame.MapName.Text = mapInfo.Name
		frame.Frame.TextBox.Text = mapInfo.MapId
		frame.LoadTimes.Text = `Loaded {mapInfo.Loads} times`
		frame.Parent = communityMapsScroll
		frame.Visible = true
		--end
	end
end

local function loadCustomMapsLoop()
	while true do
		if not ensureRefs() then
			task.wait(1)
			continue
		end
				
		playerCustomMaps = Remotes:WaitForChild("GetPlayerMaps"):InvokeServer() -- loads from cache
		top10Maps = Remotes:WaitForChild("GetTopMaps"):InvokeServer() -- loads from cache
		
		loadCustomMaps()
		loadTop10Maps()
		
		task.wait(60)
	end
end

task.spawn(function()
	for _ = 1, 30 do
		if hookPrompt() then break end
		task.wait(1)
	end
end)

task.spawn(function()
	for _ = 1, 30 do
		if ensureRefs() then
			buildTiles()
			wireClose()
			break
		end
		task.wait(1)
	end
	requestQueue()
end)

local function isValidMapIdFormat(mapId)
	return type(mapId) == "string" and mapId:match(MAP_ID_PATTERN) ~= nil
end

local function tryPurchase(mapId)
	if isOnCooldown then return false, "cooldown" end
	if not isValidMapIdFormat(mapId) then return false, "invalid_format" end

	isOnCooldown = true
	task.delay(COOLDOWN_SECONDS, function()
		isOnCooldown = false
	end)

	local success, reason = Remotes.RequestMapPurchase:InvokeServer(mapId)
	if not success then return false, "request_failed" end
	
	return true
end

if Constants.CUSTOM_MAPS_ENABLED then
	local root = getRoot()
	repeat task.wait(1) root = getRoot() until getRoot()

	local buttons = root:WaitForChild("Buttons")
	local frames = {["Public"] = mapScroll, ["YourMaps"] = yourMapScroll, ["Community"] = communityMapsScroll}
	local queueMapButton = root:WaitForChild("QueueMap")
	local codeSlot = root:WaitForChild("CodeSlot")

	for buttonName, sFrame in frames do
		local button = buttons:WaitForChild(buttonName)
		button.MouseButton1Click:Connect(function()
			for bName, frame in frames do
				frame.Visible = button.Name == bName
			end
		end)
	end

	queueMapButton.MouseButton1Click:Connect(function()
		local mapId = codeSlot.Text
		local success, reason = tryPurchase(mapId)
		if not success then
			print("Purchase failed:", reason)
			codeSlot.Text = reason
			codeSlot.TextColor3 = Color3.fromRGB(255, 0, 0)
			task.delay(1, function()
				codeSlot.Text = ""
				codeSlot.TextColor3 = Color3.fromRGB(255, 255, 255)
			end)
		else
			print("Success")
		end
	end)


	loadCustomMapsLoop()
end
