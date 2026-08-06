local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local UnboxResult = Remotes:WaitForChild("UnboxResult")
local KillEffectManager = require(ReplicatedStorage:WaitForChild("KillEffectManager"))
local KnifeIcon = require(ReplicatedStorage:WaitForChild("KnifeIcon"))
local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))

local Confetti
pcall(function()
	Confetti = require(ReplicatedStorage:WaitForChild("Confetti", 5))
end)

local CONFETTI_MIN_RANK = KnifeSkinManager.rarityRank("Legendary")

local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("CratesOpening")
local holder = gui:WaitForChild("HolderFrame")
local panel = holder:WaitForChild("CratesOpening")
local panelTemplate = panel:Clone()
local title = panel:WaitForChild("Title")
local whiteTitle = panel:FindFirstChild("WhiteStrokeTitle")
local reel = panel:WaitForChild("ScrollingFrame")
local listLayout = reel:WaitForChild("UIListLayout")

reel.ScrollingEnabled = false
reel.ScrollBarThickness = 0
reel.CanvasSize = UDim2.new(0, 0, 0, 0)
reel.AutomaticCanvasSize = Enum.AutomaticSize.None
reel.ClipsDescendants = true

local strip = reel:FindFirstChild("Strip")
if not strip then
	strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.BorderSizePixel = 0
	strip.AnchorPoint = Vector2.new(0, 0.5)
	strip.Position = UDim2.new(0, 0, 0.5, 0)
	strip.Size = UDim2.new(0, 100, 1, 0)
	strip.Parent = reel
end

if listLayout.Parent ~= strip then
	listLayout.Parent = strip
end

listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder

local RARITY_TEMPLATE_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Secret" }
local cellTemplates = {}
for _, rname in ipairs(RARITY_TEMPLATE_NAMES) do
	local orig = reel:FindFirstChild(rname)
	if orig then
		cellTemplates[rname] = orig:Clone()
		orig:Destroy()
	end
end

local function templateFor(rarity)
	return cellTemplates[rarity] or cellTemplates.Common
end

local SPIN_TIME = 5.7
local TICK_SLICE = 0.13

local function setTitleText(txt)
	title.Text = txt
	local top = title:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then
		top.Text = txt
	end

	if whiteTitle and whiteTitle:IsA("TextLabel") then
		whiteTitle.Text = txt
		local wtop = whiteTitle:FindFirstChild("Top")
		if wtop and wtop:IsA("TextLabel") then
			wtop.Text = txt
		end
	end
end

local function playSound(name)
	local t = SoundService:FindFirstChild(name)
	if not t then
		return
	end
	local s = t:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then
		s.SoundGroup = sfx
	end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 2) + 0.2, function()
		if s then
			s:Destroy()
		end
	end)
end

local PLACEHOLDER_ICON = "rbxassetid://99971107297730"

local SECRET_ICON = "rbxassetid://77573523807035"
local SECRET_RARITY = "Secret"

local KILL_EFFECT_VIEWPORT_NAME = "KillEffectViewport"

local function clearIconViewports(icon)
	KnifeIcon.render(icon, nil)
	local existing = icon:FindFirstChild(KILL_EFFECT_VIEWPORT_NAME)
	if existing then
		existing:Destroy()
	end
end

local function renderKillEffectIcon(icon, effectId)
	clearIconViewports(icon)
	icon.BackgroundTransparency = 1
	icon.Image = KillEffectManager.effectIcon(effectId) or ""
end

local function applyIcon(icon, entry, revealSecret)
	if entry.rarity == SECRET_RARITY and not revealSecret then
		clearIconViewports(icon)
		icon.BackgroundTransparency = 1
		icon.Image = SECRET_ICON
		return
	end
	if entry.itemKind == "killeffect" then
		renderKillEffectIcon(icon, entry.effectId or entry.id)
	else
		clearIconViewports(icon)
		icon.Image = ""
		icon.BackgroundTransparency = 1
		KnifeIcon.render(icon, entry.skinId)
	end
end

local function entryDisplayName(entry)
	if entry.itemKind == "killeffect" then
		return entry.name or KillEffectManager.effectName(entry.effectId or entry.id)
	end
	return KnifeSkinManager.displayName(entry.name)
end

local _notifCtrl
local function getNotifications()
	if _notifCtrl then
		return _notifCtrl
	end
	local ok, ctrl = pcall(function()
		return Knit.GetController("NotificationController")
	end)
	if ok and ctrl then
		_notifCtrl = ctrl
	end
	return _notifCtrl
end

local function notifyDuplicateRefund(won)
	if not won or won.itemKind ~= "killeffect" then
		return
	end
	local refund = tonumber(won.refundCoins)
	if not won.duplicate or not refund or refund <= 0 then
		return
	end
	local ctrl = getNotifications()
	if not ctrl then
		return
	end
	ctrl:Notify({
		Type = "SUCCESS",
		Text = ("You were refunded %d coins due to duplicate %s"):format(refund, entryDisplayName(won)),
	})
end

local function itemRarityRank(entryOrRarity)
	local rarity = type(entryOrRarity) == "table" and entryOrRarity.rarity or entryOrRarity
	return KnifeSkinManager.rarityRank(rarity)
end

local function setLayeredText(label, txt)
	if not (label and label:IsA("TextLabel")) then
		return
	end
	label.Text = txt
	local top = label:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then
		top.Text = txt
	end
end

local function setCellName(cell, name)
	setLayeredText(cell:FindFirstChild("KnifeName"), name)
end

local function setCellRarity(cell, rarityText)
	setLayeredText(cell:FindFirstChild("Rarity"), rarityText)
end

local cellW, slotW
local function clearReel()
	for _, c in ipairs(strip:GetChildren()) do
		if c.Name == "Cell" then
			c:Destroy()
		end
	end
end

local function buildCells(entries)
	clearReel()

	local reelW = reel.AbsoluteSize.X
	cellW = math.floor(reelW * 0.207161)
	local gap = math.floor(reelW * 0.0127877)
	listLayout.Padding = UDim.new(0, gap)
	slotW = cellW + gap
	for i, entry in ipairs(entries) do
		local cell = templateFor(entry.rarity):Clone()
		cell.Name = "Cell"
		cell.Visible = true
		cell.LayoutOrder = i

		cell.AnchorPoint = Vector2.new(0, 0.5)
		cell.Position = UDim2.new(0, 0, 0.5, 0)
		cell.Size = UDim2.new(0, cellW, 1, 0)

		local isSecret = (entry.rarity == SECRET_RARITY)
		setCellName(cell, isSecret and "SECRET" or entryDisplayName(entry))
		setCellRarity(cell, entry.rarity)
		local icon = cell:FindFirstChild("Icon")
		if icon then
			applyIcon(icon, entry)
		end
		cell.Parent = strip
	end

	strip.Size = UDim2.new(0, #entries * slotW, 1, 0)
end

local function cellByIndex(index)
	for _, c in ipairs(strip:GetChildren()) do
		if c.Name == "Cell" and c.LayoutOrder == index then
			return c
		end
	end
	return nil
end

local function stripXForIndex(index)
	local cell = cellByIndex(index)
	if cell then
		local cellLeftInStrip = cell.AbsolutePosition.X - strip.AbsolutePosition.X
		local cellCenterInStrip = cellLeftInStrip + cell.AbsoluteSize.X / 2

		return (reel.AbsoluteSize.X / 2) - cellCenterInStrip + strip.Position.X.Offset
	end

	local cellCenter = (index - 1) * slotW + cellW / 2
	return (reel.AbsoluteSize.X / 2) - cellCenter
end

local function getOrCreateScale(parent, name)
	local scale = parent:FindFirstChild(name)
	if not scale then
		scale = Instance.new("UIScale")
		scale.Name = name
		scale.Scale = 1
		scale.Parent = parent
	end
	return scale
end

local function playWinnerPop(cell)
	if not cell then
		return
	end

	local cellScale = getOrCreateScale(cell, "WinnerPopScale")
	local icon = cell:FindFirstChild("Icon")
	local iconScale = icon and getOrCreateScale(icon, "WinnerIconPopScale") or nil

	cellScale.Scale = 1
	if iconScale then
		iconScale.Scale = 1
	end

	local grow = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local settle = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	TweenService:Create(cellScale, grow, { Scale = 1.12 }):Play()
	if iconScale then
		TweenService:Create(iconScale, grow, { Scale = 1.2 }):Play()
	end

	task.delay(0.18, function()
		if cellScale.Parent then
			TweenService:Create(cellScale, settle, { Scale = 1.06 }):Play()
		end
		if iconScale and iconScale.Parent then
			TweenService:Create(iconScale, settle, { Scale = 1.08 }):Play()
		end
	end)
end

local spinning = false
local pendingUnboxes = {}
local processingQueue = false
local reopenShopOnClose = false
local lastWon = nil

local KnifeUnboxedLocal = Remotes:FindFirstChild("KnifeUnboxedLocal")
if not KnifeUnboxedLocal then
	KnifeUnboxedLocal = Instance.new("BindableEvent")
	KnifeUnboxedLocal.Name = "KnifeUnboxedLocal"
	KnifeUnboxedLocal.Parent = Remotes
end

local BLOCKING_MENUS = { "Inventory", "Settings", "Shop", "ConfirmSellGui", "SeekerQueueGui" }
local function isMenuOpen(g)
	if not (g and g:IsA("ScreenGui")) then
		return false
	end
	if not g.Enabled then
		return false
	end
	local dim = g:FindFirstChild("Dim")
	if dim and dim:IsA("GuiObject") then
		return dim.Visible
	end
	return true
end
local function anotherMenuOpen()
	for _, name in ipairs(BLOCKING_MENUS) do
		if isMenuOpen(pg:FindFirstChild(name)) then
			return true
		end
	end
	return false
end

local function close(hasQueuedUnboxes)
	gui.Enabled = false
	clearReel()
	if not hasQueuedUnboxes then
		player:SetAttribute("Unboxing", false)
	end
	spinning = false

	if reopenShopOnClose then
		reopenShopOnClose = false
		if not hasQueuedUnboxes and not anotherMenuOpen() then
			local crateGui = pg:FindFirstChild("CratesShop")
			local openEvent = crateGui and crateGui:FindFirstChild("OpenCrateShop")
			if openEvent then
				openEvent:Fire()
			end
		end
	end

	if lastWon then
		if lastWon.itemKind ~= "killeffect" then
			KnifeUnboxedLocal:Fire({ name = lastWon.name, skinId = lastWon.skinId, rarity = lastWon.rarity })
		end
		lastWon = nil
	end
end

local function playUnbox(data)
	if type(data) ~= "table" then
		return
	end
	spinning = true
	player:SetAttribute("Unboxing", true)

	setTitleText(data.titleOverride or "Opening Box...")

	reopenShopOnClose = (data.titleOverride == nil)
	gui.Enabled = true

	task.wait(0.05)
	buildCells(data.reel)

	strip.Position = UDim2.new(0, 0, 0.5, 0)
	task.wait(0.05)

	local startX = stripXForIndex(1)
	local targetX = stripXForIndex(data.winnerIndex)
	strip.Position = UDim2.new(0, startX, 0.5, 0)

	local ticking = true
	local stopTickOffset = math.abs(targetX - startX) - slotW
	task.spawn(function()
		local tmplSound = SoundService:FindFirstChild("Spin")
		if not tmplSound then
			return
		end
		local sfx = SoundService:FindFirstChild("SFX")
		local function playClick()
			local s = tmplSound:Clone()
			if sfx then
				s.SoundGroup = sfx
			end
			s.Parent = SoundService
			s.TimePosition = 0
			s:Play()
			task.delay(TICK_SLICE, function()
				if s then
					s:Stop()
				end
			end)
			task.delay(TICK_SLICE + 0.1, function()
				if s then
					s:Destroy()
				end
			end)
		end
		local startOffset = strip.Position.X.Offset
		local nextThreshold = slotW
		while ticking do
			local traveled = math.abs(strip.Position.X.Offset - startOffset)
			while slotW > 0 and traveled >= nextThreshold do
				if nextThreshold <= stopTickOffset then
					playClick()
				end
				nextThreshold += slotW
			end
			RunService.Heartbeat:Wait()
		end
	end)

	local tween = TweenService:Create(strip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, targetX, 0.5, 0),
	})
	tween:Play()
	tween.Completed:Wait()
	ticking = false

	strip.Position = UDim2.new(0, targetX, 0.5, 0)
	local won = data.won
	local rarity = won and won.rarity or "Common"
	lastWon = won

	if won and rarity == SECRET_RARITY then
		for _, cell in ipairs(strip:GetChildren()) do
			if cell.Name == "Cell" and cell.LayoutOrder == data.winnerIndex then
				setCellName(cell, entryDisplayName(won))
				local icon = cell:FindFirstChild("Icon")
				if icon then
					applyIcon(icon, won, true)
				end
				break
			end
		end
	end
	playWinnerPop(cellByIndex(data.winnerIndex))

	setTitleText("You unboxed: " .. (won and entryDisplayName(won) or "?"))
	playSound("RevealRow")

	if itemRarityRank(rarity) >= CONFETTI_MIN_RANK and Confetti then
		pcall(function()
			Confetti.Emit(2)
		end)
	end

	if won then
		local knl = Remotes:FindFirstChild("KnifeNotifyLocal")
		if knl then
			knl:Fire({ name = won.name, rarity = won.rarity })
		end
	end

	notifyDuplicateRefund(won)

	task.wait(2.0)
	close(#pendingUnboxes > 0)
end

local function createBatchPanelController(panelInstance)
	local batchTitle = panelInstance:WaitForChild("Title")
	local batchWhiteTitle = panelInstance:FindFirstChild("WhiteStrokeTitle")
	local batchReel = panelInstance:WaitForChild("ScrollingFrame")
	local batchListLayout = batchReel:FindFirstChild("UIListLayout", true)

	batchReel.ScrollingEnabled = false
	batchReel.ScrollBarThickness = 0
	batchReel.CanvasSize = UDim2.new(0, 0, 0, 0)
	batchReel.AutomaticCanvasSize = Enum.AutomaticSize.None
	batchReel.ClipsDescendants = true

	for _, rname in ipairs(RARITY_TEMPLATE_NAMES) do
		local orig = batchReel:FindFirstChild(rname)
		if orig then
			orig:Destroy()
		end
	end

	local batchStrip = batchReel:FindFirstChild("Strip")
	if not batchStrip then
		batchStrip = Instance.new("Frame")
		batchStrip.Name = "Strip"
		batchStrip.BackgroundTransparency = 1
		batchStrip.BorderSizePixel = 0
		batchStrip.AnchorPoint = Vector2.new(0, 0.5)
		batchStrip.Position = UDim2.new(0, 0, 0.5, 0)
		batchStrip.Size = UDim2.new(0, 100, 1, 0)
		batchStrip.Parent = batchReel
	end
	if batchListLayout and batchListLayout.Parent ~= batchStrip then
		batchListLayout.Parent = batchStrip
	end
	batchListLayout.FillDirection = Enum.FillDirection.Horizontal
	batchListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	batchListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	batchListLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local batchCellW, batchSlotW

	local function setBatchTitleText(txt)
		batchTitle.Text = txt
		local top = batchTitle:FindFirstChild("Top")
		if top and top:IsA("TextLabel") then
			top.Text = txt
		end
		if batchWhiteTitle and batchWhiteTitle:IsA("TextLabel") then
			batchWhiteTitle.Text = txt
			local wtop = batchWhiteTitle:FindFirstChild("Top")
			if wtop and wtop:IsA("TextLabel") then
				wtop.Text = txt
			end
		end
	end

	local function clearBatchReel()
		for _, c in ipairs(batchStrip:GetChildren()) do
			if c.Name == "Cell" then
				c:Destroy()
			end
		end
	end

	local function buildBatchCells(entries)
		clearBatchReel()
		local reelW = batchReel.AbsoluteSize.X
		batchCellW = math.floor(reelW * 0.207161)
		local gap = math.floor(reelW * 0.0127877)
		batchListLayout.Padding = UDim.new(0, gap)
		batchSlotW = batchCellW + gap
		for i, entry in ipairs(entries) do
			local cell = templateFor(entry.rarity):Clone()
			cell.Name = "Cell"
			cell.Visible = true
			cell.LayoutOrder = i
			cell.AnchorPoint = Vector2.new(0, 0.5)
			cell.Position = UDim2.new(0, 0, 0.5, 0)
			cell.Size = UDim2.new(0, batchCellW, 1, 0)
			local isSecret = (entry.rarity == SECRET_RARITY)
			setCellName(cell, isSecret and "SECRET" or entryDisplayName(entry))
			setCellRarity(cell, entry.rarity)
			local icon = cell:FindFirstChild("Icon")
			if icon then
				applyIcon(icon, entry)
			end
			cell.Parent = batchStrip
		end
		batchStrip.Size = UDim2.new(0, #entries * batchSlotW, 1, 0)
	end

	local function batchCellByIndex(index)
		for _, c in ipairs(batchStrip:GetChildren()) do
			if c.Name == "Cell" and c.LayoutOrder == index then
				return c
			end
		end
		return nil
	end

	local function batchStripXForIndex(index)
		local cell = batchCellByIndex(index)
		if cell then
			local cellLeftInStrip = cell.AbsolutePosition.X - batchStrip.AbsolutePosition.X
			local cellCenterInStrip = cellLeftInStrip + cell.AbsoluteSize.X / 2
			return (batchReel.AbsoluteSize.X / 2) - cellCenterInStrip + batchStrip.Position.X.Offset
		end
		local cellCenter = (index - 1) * batchSlotW + batchCellW / 2
		return (batchReel.AbsoluteSize.X / 2) - cellCenter
	end

	local function play(data)
		setBatchTitleText(data.titleOverride or "Opening Box...")
		panelInstance.Visible = true
		task.wait(0.05)
		buildBatchCells(data.reel)
		batchStrip.Position = UDim2.new(0, 0, 0.5, 0)
		task.wait(0.05)

		local startX = batchStripXForIndex(1)
		local targetX = batchStripXForIndex(data.winnerIndex)
		batchStrip.Position = UDim2.new(0, startX, 0.5, 0)

		local ticking = true
		local stopTickOffset = math.abs(targetX - startX) - batchSlotW
		task.spawn(function()
			local tmplSound = SoundService:FindFirstChild("Spin")
			if not tmplSound then
				return
			end
			local sfx = SoundService:FindFirstChild("SFX")
			local function playClick()
				local s = tmplSound:Clone()
				if sfx then
					s.SoundGroup = sfx
				end
				s.Parent = SoundService
				s.TimePosition = 0
				s:Play()
				task.delay(TICK_SLICE, function()
					if s then
						s:Stop()
					end
				end)
				task.delay(TICK_SLICE + 0.1, function()
					if s then
						s:Destroy()
					end
				end)
			end
			local startOffset = batchStrip.Position.X.Offset
			local nextThreshold = batchSlotW
			while ticking do
				local traveled = math.abs(batchStrip.Position.X.Offset - startOffset)
				while batchSlotW > 0 and traveled >= nextThreshold do
					if nextThreshold <= stopTickOffset then
						playClick()
					end
					nextThreshold += batchSlotW
				end
				RunService.Heartbeat:Wait()
			end
		end)

		local tween = TweenService:Create(batchStrip, TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			Position = UDim2.new(0, targetX, 0.5, 0),
		})
		tween:Play()
		tween.Completed:Wait()
		ticking = false

		batchStrip.Position = UDim2.new(0, targetX, 0.5, 0)
		local won = data.won
		local rarity = won and won.rarity or "Common"

		if won and rarity == SECRET_RARITY then
			for _, cell in ipairs(batchStrip:GetChildren()) do
				if cell.Name == "Cell" and cell.LayoutOrder == data.winnerIndex then
					setCellName(cell, entryDisplayName(won))
					local icon = cell:FindFirstChild("Icon")
					if icon then
						applyIcon(icon, won, true)
					end
					break
				end
			end
		end
		playWinnerPop(batchCellByIndex(data.winnerIndex))

		setBatchTitleText("You unboxed: " .. (won and entryDisplayName(won) or "?"))
		playSound("RevealRow")
		if itemRarityRank(rarity) >= CONFETTI_MIN_RANK and Confetti then
			pcall(function()
				Confetti.Emit(2)
			end)
		end
		if won then
			local knl = Remotes:FindFirstChild("KnifeNotifyLocal")
			if knl then
				knl:Fire({ name = won.name, rarity = won.rarity })
			end
			task.delay(2.0, function()
				KnifeUnboxedLocal:Fire({ name = won.name, skinId = won.skinId, rarity = won.rarity })
			end)
		end

		notifyDuplicateRefund(won)

		task.wait(2.0)
		clearBatchReel()
	end

	return {
		play = play,
		destroy = function()
			clearBatchReel()
			panelInstance:Destroy()
		end,
	}
end

local function positionBatchPanel(batchPanel, index, count)
	local yPositions = if count == 2 then { 0.34, 0.66 } else { 0.2, 0.5, 0.8 }
	batchPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	batchPanel.Position = UDim2.new(0.5, 0, yPositions[index], 0)
	batchPanel.Size = UDim2.new(0.438541681, 0, count == 3 and 0.235 or 0.279629618, 0)
	batchPanel.Visible = true
end

local function playUnboxBatch(batch)
	spinning = true
	player:SetAttribute("Unboxing", true)
	reopenShopOnClose = false
	gui.Enabled = true
	panel.Visible = false

	local controllers = {}
	local complete = 0
	for i, data in ipairs(batch) do
		local batchPanel = panelTemplate:Clone()
		batchPanel.Name = "CratesOpeningBatch" .. i
		positionBatchPanel(batchPanel, i, #batch)
		batchPanel.Parent = holder
		local controller = createBatchPanelController(batchPanel)
		controllers[i] = controller
		task.spawn(function()
			controller.play(data)
			complete += 1
		end)
	end

	while complete < #batch do
		RunService.Heartbeat:Wait()
	end

	for _, controller in ipairs(controllers) do
		controller.destroy()
	end
	panel.Visible = true
	gui.Enabled = false
	player:SetAttribute("Unboxing", false)
	spinning = false

	local shouldReopenShop = false
	for _, data in ipairs(batch) do
		if data.titleOverride == nil then
			shouldReopenShop = true
			break
		end
	end
	if shouldReopenShop and not anotherMenuOpen() then
		local crateGui = pg:FindFirstChild("CratesShop")
		local openEvent = crateGui and crateGui:FindFirstChild("OpenCrateShop")
		if openEvent then
			openEvent:Fire()
		end
	end
end

local function processUnboxQueue()
	if processingQueue then
		return
	end
	processingQueue = true
	while #pendingUnboxes > 0 do
		task.wait(0.05)
		local batch = {}
		while #pendingUnboxes > 0 and #batch < 3 do
			batch[#batch + 1] = table.remove(pendingUnboxes, 1)
		end
		if #batch == 1 then
			playUnbox(batch[1])
		else
			playUnboxBatch(batch)
		end
	end
	processingQueue = false
end

UnboxResult.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	table.insert(pendingUnboxes, data)
	task.defer(processUnboxQueue)
end)
