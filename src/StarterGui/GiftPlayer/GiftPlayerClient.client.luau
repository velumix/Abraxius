-- GiftPlayerClient: drives the GiftPlayer GUI -- the recipient picker for gifting a dev product to
-- another player in the server.
--
-- FLOW:
--   1. A "Gift" button somewhere (e.g. on a shop tile) calls openGift(productId) -- see the OPEN API
--      at the bottom. We remember the productId being gifted and show this GUI.
--   2. The GUI lists every OTHER player currently in the server, each as a tile with their headshot +
--      username/display name (cloned from the ItemFrame template).
--   3. The buyer clicks a player's tile. We ask MarketplaceController to register the server-side
--      gift intent. If validation passes, the controller prompts the dev product purchase; ProcessReceipt
--      delivers to the recipient, not the buyer.
--
-- The server is the source of truth for who gets the item; this script only collects the choice. As a
-- courtesy we also HIDE players restricted from paid random items from the list (the server enforces
-- this regardless -- see PolicyManager) so the buyer isn't offered a recipient that would be refused.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local PurchaseFX
pcall(function()
	PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX"))
end)

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local MarketplaceController = require(player:WaitForChild("PlayerScripts"):WaitForChild("Controllers"):WaitForChild("MarketplaceController"))

-- the gift picker is opened FROM the shop (its gift buttons close the shop first so the two don't
-- overlap). When the picker closes again we re-open the shop so the player lands back where they were.
-- We reach the shop through its OpenShop BindableEvent (the same one the shop's HUD button uses).
local shopGui = pg:WaitForChild("Shop")
local shopOpenEvent = shopGui:WaitForChild("OpenShop")
local function reopenShop()
	shopOpenEvent:Fire()  -- no section -> shop opens at the top, same as the HUD store button
end

-- a recipient restricted from paid random items can't receive gifts (server-enforced). The server
-- PolicyManager publishes each player's status as the "PaidRandomRestricted" attribute, readable from
-- any client, so we can hide restricted players from the picker. Treat unresolved (nil) as restricted
-- (fail-closed) -- they'll simply appear once their policy resolves on a rebuild.
local RESTRICT_ATTR = "PaidRandomRestricted"
local function canReceiveGifts(target)
	local v = target:GetAttribute(RESTRICT_ATTR)
	return v == false  -- only show players explicitly resolved as NOT restricted
end

-- ===== GUI refs =====
local gui = pg:WaitForChild("GiftPlayer")
local panel = gui:WaitForChild("HolderFrame"):WaitForChild("Gift"):WaitForChild("Gift")
local scroll = panel:WaitForChild("ScrollingFrame")
local template = scroll:WaitForChild("ItemFrame")
local closeButton = panel:WaitForChild("CloseButton")

template.Visible = false  -- the studio template is only cloned, never shown directly
gui.Enabled = false

-- the product the player is currently choosing a recipient for (set by openGift)
local activeProductId = nil
local allowedRecipients = nil
-- whether we should re-open the shop after the picker closes (false when opened from the StarterPack prompt)
local shouldReopenShop = true
-- guard so rapidly clicking tiles can't fire multiple gift requests for one open session
local awaitingServer = false

-- ===== helpers =====
-- the Username / DisplayName labels are layered (an outer TextLabel with a nested same-named inner
-- label for the drop-shadow look). Set the text on the outer label AND any nested TextLabel child.
local function setLayeredText(label, text)
	if not label then return end
	if label:IsA("TextLabel") then label.Text = text end
	for _, child in ipairs(label:GetChildren()) do
		if child:IsA("TextLabel") then child.Text = text end
	end
end

-- clear previously-built tiles (keep the hidden template)
local function clearTiles()
	for _, c in ipairs(scroll:GetChildren()) do
		if c:IsA("GuiObject") and c.Name == "PlayerTile" then c:Destroy() end
	end
end

-- build one tile for a given player
local function buildTile(target, order)
	local tile = template:Clone()
	tile.Name = "PlayerTile"
	tile.LayoutOrder = order
	tile.Visible = true

	setLayeredText(tile:FindFirstChild("Username"), "@" .. target.Name)
	setLayeredText(tile:FindFirstChild("DisplayName"), target.DisplayName ~= "" and target.DisplayName or target.Name)

	-- headshot thumbnail (async; don't block the tile build)
	local icon = tile:FindFirstChild("Icon")
	if icon and icon:IsA("ImageLabel") then
		task.spawn(function()
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(target.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
			end)
			if ok and content and icon.Parent then icon.Image = content end
		end)
	end

	-- click target: the "Player" ImageButton overlay (falls back to the tile if missing)
	local btn = tile:FindFirstChild("Player")
	if btn and btn:IsA("GuiButton") then
		UISounds.bindButton(btn)
		btn.MouseButton1Click:Connect(function()
			if awaitingServer then return end
			if not activeProductId then return end
			awaitingServer = true
			UISounds.click()
			if PurchaseFX then pcall(function() PurchaseFX.prompt() end) end
			local ok, err = MarketplaceController:PromptGift(activeProductId, target.UserId)
			awaitingServer = false
			if not ok then
				UISounds.error()
				warn("[GiftPlayerClient] gift refused: " .. tostring(err or "Couldn't gift that."))
				return
			end
			gui.Enabled = false
			activeProductId = nil
			if shouldReopenShop then
				reopenShop()
			end
			shouldReopenShop = true
		end)
	end

	tile.Parent = scroll
end

-- (re)build the whole player list (everyone EXCEPT the local player, and EXCEPT players restricted
-- from paid random items -- they can't receive gifts).
local function rebuildList()
	clearTiles()
	local order = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and canReceiveGifts(p) and (allowedRecipients == nil or allowedRecipients[p.UserId]) then
			order += 1
			buildTile(p, order)
		end
	end
end

-- ===== open / close =====
local function ensureUiScale(instance: GuiObject): UIScale
	local scale = instance:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = instance
	end
	return scale
end

local function addButtonEffects(button: GuiButton, isClose: boolean)
	local scale = ensureUiScale(button)
	local baseRot = button.Rotation

	local hoverScale = 1.1
	local pressScale = 0.92
	local hoverRot = isClose and 12 or 0
	local clickRot = isClose and 22 or 0

	local activeTween = nil
	local function playTween(tween)
		if activeTween then
			activeTween:Cancel()
		end
		activeTween = tween
		tween:Play()
	end

	button.MouseEnter:Connect(function()
		playTween(TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = hoverScale }))
		if isClose then
			playTween(TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = hoverRot }))
		end
	end)

	button.MouseLeave:Connect(function()
		playTween(TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }))
		if isClose then
			playTween(TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = baseRot }))
		end
	end)

	button.MouseButton1Down:Connect(function()
		playTween(TweenService:Create(scale, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = pressScale }))
		if isClose then
			playTween(TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rotation = clickRot }))
		end
	end)

	button.MouseButton1Up:Connect(function()
		playTween(TweenService:Create(scale, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = hoverScale }))
		if isClose then
			playTween(TweenService:Create(button, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = hoverRot }))
		end
	end)
end

local function closeGift()
	UISounds.close()
	gui.Enabled = false
	activeProductId = nil
	awaitingServer = false
end

-- close the picker via the X button. Re-opens the shop only if we were opened from the shop.
local function closeGiftAndReopenShop()
	if shouldReopenShop then
		reopenShop()
	end
	closeGift()
	shouldReopenShop = true
end

local function refreshAndRebuild()
	if not gui.Enabled or not activeProductId then
		return
	end
	local productId = activeProductId
	local list = MarketplaceController:GetGiftableRecipients(productId)
	if not gui.Enabled or activeProductId ~= productId then
		return
	end
	if list then
		local set = {}
		for _, uid in ipairs(list) do
			set[uid] = true
		end
		allowedRecipients = set
	else
		allowedRecipients = nil
	end
	rebuildList()
end

local function openGift(productId, reopenShopAfter)
	if type(productId) ~= "number" then
		warn("[GiftPlayerClient] openGift requires a numeric productId")
		return
	end
	activeProductId = productId
	allowedRecipients = nil
	shouldReopenShop = reopenShopAfter ~= false
	awaitingServer = false
	gui.Enabled = true
	UISounds.select()
	rebuildList()
	refreshAndRebuild()
end

closeButton.MouseButton1Click:Connect(closeGiftAndReopenShop)
addButtonEffects(closeButton, true)
closeButton.MouseEnter:Connect(function() UISounds.play("hover") end)

-- keep the list fresh while open if players join/leave, or if a player's restriction status resolves
-- after the list was first built (so they appear/disappear correctly).
Players.PlayerAdded:Connect(function() if gui.Enabled then task.spawn(refreshAndRebuild) end end)
Players.PlayerRemoving:Connect(function() if gui.Enabled then task.defer(refreshAndRebuild) end end)
Players.PlayerAdded:Connect(function(p)
	p:GetAttributeChangedSignal(RESTRICT_ATTR):Connect(function()
		if gui.Enabled then task.spawn(refreshAndRebuild) end
	end)
end)
for _, p in ipairs(Players:GetPlayers()) do
	p:GetAttributeChangedSignal(RESTRICT_ATTR):Connect(function()
		if gui.Enabled then task.spawn(refreshAndRebuild) end
	end)
end

-- ===== server replies =====
MarketplaceController.GiftFailed:Connect(function(_productId, _recipientUserId, reason)
	awaitingServer = false
	UISounds.error()
	warn("[GiftPlayerClient] gift refused: " .. tostring(reason or "Couldn't gift that."))
end)

-- ===== OPEN API for the Gift buttons =====
-- Other client scripts (the per-product "Gift" buttons) open this picker by firing the BindableEvent
-- ReplicatedStorage.GameRemotes.OpenGiftPicker with the dev-product id, e.g.:
--     local OpenGiftPicker = ReplicatedStorage.GameRemotes:WaitForChild("OpenGiftPicker")
--     giftButton.MouseButton1Click:Connect(function() OpenGiftPicker:Fire(PRODUCT_ID) end)
local OpenGiftPicker = Remotes:FindFirstChild("OpenGiftPicker")
if not OpenGiftPicker then
	OpenGiftPicker = Instance.new("BindableEvent")
	OpenGiftPicker.Name = "OpenGiftPicker"
	OpenGiftPicker.Parent = Remotes
end
OpenGiftPicker.Event:Connect(function(productId, reopenShopAfter) openGift(productId, reopenShopAfter) end)
