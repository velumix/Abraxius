-- SeekerQueueShopClient: drives the SeekerQueueGui frame (new flat CleanFrame layout).
-- Shows the guaranteed-seeker queue (count + next person's image/name), and the purchase
-- button prompts the same "Be Seeker" dev product (each purchase = one more queue spot).
--
-- New GUI structure (SeekerQueueGui, ScreenGui, .Enabled = open/close — no "Dim" frame). The content
-- was transplanted from the original SeekerQueue GUI and re-nested under the Information frame:
--   HolderFrame.CleanFrame
--     Background (ImageLabel), Icon, Title / WhiteStrokeTitle (layered header), CloseButton
--     Information
--       QueueAmount (TextLabel)                            -- "N in Queue" / "Queue is Empty"
--       Rewardicon.PlayerImage (ImageLabel)                -- next-in-queue player's headshot
--       Rewardicon.PlayerName (Frame of layered TextLabels) -- their name
--       Buttons.RobuxPurchaseButton (ImageButton) -> RobuxPrice (TextLabel)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local AdService = game:GetService("AdService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SeekerQueueUpdate = Remotes:WaitForChild("SeekerQueueUpdate")
local PurchaseFX = require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX"))

local SEEKER_PRODUCT_ID = 3601754778  -- same "Be Seeker" / 100% Seeker (1 Round) product

local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("SeekerQueueGui")
local holder = gui:WaitForChild("HolderFrame")
local frame = holder:WaitForChild("CleanFrame")

-- display elements (real content from the original GUI; now nested under the Information frame)
local information = frame:WaitForChild("Information")
local queueLabel = information:WaitForChild("QueueAmount")
local rewardicon = information:WaitForChild("Rewardicon")
local playerImage = rewardicon:WaitForChild("PlayerImage")
local nameFrame = rewardicon:WaitForChild("PlayerName")  -- a Frame holding layered name TextLabels
local buyBtn = information:WaitForChild("Buttons"):WaitForChild("RobuxPurchaseButton")

-- ===== Open / close =====
-- The new GUI toggles via the ScreenGui's .Enabled (like the new Shop/Settings); no "Dim" frame.
local function open() UISounds.select(); gui.Enabled = true end
local function close() UISounds.close(); gui.Enabled = false end

local exit = frame:FindFirstChild("CloseButton")
if exit then
	exit.MouseButton1Click:Connect(close)
	UISounds.bindTween(exit)
	exit.MouseEnter:Connect(function() UISounds.play("hover") end)
	exit:SetAttribute("UISoundsBound", true)
end

local openEvent = gui:FindFirstChild("OpenSeekerQueue")
if not openEvent then openEvent = Instance.new("BindableEvent"); openEvent.Name = "OpenSeekerQueue"; openEvent.Parent = gui end
openEvent.Event:Connect(open)
local closeEvent = gui:FindFirstChild("CloseSeekerQueue")
if not closeEvent then closeEvent = Instance.new("BindableEvent"); closeEvent.Name = "CloseSeekerQueue"; closeEvent.Parent = gui end
closeEvent.Event:Connect(function() gui.Enabled = false end)

-- ===== helpers =====
-- PlayerName is a Frame holding layered name TextLabels (a fill + a stroke copy); set every
-- TextLabel child so both layers stay in sync, matching the original GUI's behavior.
local function setName(text)
	for _, lbl in ipairs(nameFrame:GetChildren()) do
		if lbl:IsA("TextLabel") then lbl.Text = text end
	end
end

local function setThumbnail(userId)
	if not userId then return end
	-- use the direct rbxthumb:// URL: instant, never yields, and always resolves
	-- (GetUserThumbnailAsync can intermittently fail or return a not-ready image).
	playerImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=420&h=420"
end

-- default placeholder image (whatever was set in the GUI), so we can restore on empty
local PLACEHOLDER_IMAGE = playerImage.Image

-- start in the empty state (no image, "Nobody") until the first queue update arrives
playerImage.Image = ""
playerImage.ImageTransparency = 1
setName("Nobody")

-- ===== queue display =====
SeekerQueueUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	local count = data.count or 0

	if count <= 0 then
		queueLabel.Text = "Queue is Empty"
		setName("Nobody")
		-- no one queued -> show no image
		playerImage.Image = ""
		playerImage.ImageTransparency = 1
	else
		queueLabel.Text = (count == 1) and "1 in Queue" or (count .. " in Queue")
		setName(data.nextName or "...")
		playerImage.ImageTransparency = 0
		if data.nextUserId then setThumbnail(data.nextUserId) end
	end
end)

-- ===== purchase button (same Be Seeker product) =====
if buyBtn then
	buyBtn.Active = true
	buyBtn.Interactable = true
	UISounds.bindTween(buyBtn)
	buyBtn.MouseEnter:Connect(function() UISounds.play("hover") end)
	buyBtn:SetAttribute("UISoundsBound", true)
	buyBtn.MouseButton1Click:Connect(function()
		UISounds.click()
		PurchaseFX.prompt()
		MarketplaceService:PromptProductPurchase(player, SEEKER_PRODUCT_ID)
	end)

	-- show the real product price on the button
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(SEEKER_PRODUCT_ID, Enum.InfoType.Product)
		end)
		if ok and info then
			-- use Roblox's built-in Robux glyph (U+E002) instead of "R$"
			local priceText = info.PriceInRobux and (utf8.char(0xE002) .. " " .. info.PriceInRobux) or "Buy"
			local pt = buyBtn:FindFirstChild("RobuxPrice")
			if pt then pt.Text = priceText end
		end
	end)
end

print("[SeekerQueueShopClient] ready (queue + purchase)")

-- ===== Watch Ad -> seeker queue (rewarded video, 10-minute persistent cooldown) =====
-- Same rewarded-ad method as the lobby Watch-Ad signs: check availability with
-- AdService:GetAdAvailabilityNowAsync, then fire a remote so the SERVER shows the ad
-- (AdService:ShowRewardedVideoAdAsync) and grants a seeker-queue spot on completion. The server owns the
-- persistent cooldown (DataStore) and tells us the remaining time via SeekerQueueAdStatus so we can show
-- a live countdown on the button and disable it while it's cooling down.
do
	local adBtn = information:FindFirstChild("Buttons")
	adBtn = adBtn and adBtn:FindFirstChild("WatchAdButton")
	if adBtn then
		local ClaimSeekerQueueAd = Remotes:WaitForChild("ClaimSeekerQueueAd")
		local SeekerQueueAdStatus = Remotes:WaitForChild("SeekerQueueAdStatus")
		local SeekerQueueAdQuery = Remotes:WaitForChild("SeekerQueueAdQuery")

		-- the button's label ("Watch AD"); we swap its text for the cooldown countdown / status
		local adLabel = adBtn:FindFirstChild("WatchAD")
		local DEFAULT_TEXT = adLabel and adLabel.Text or "Watch AD"

		-- the visible fill of this button is its GreenGradient child ImageLabel. To "gray out" the button
		-- we swap that image for the shared gray button texture (the same asset the Settings AFK GrayButton
		-- uses), and restore the original green gradient when the button is usable again.
		local gradient = adBtn:FindFirstChild("GreenGradient")
		local DEFAULT_GRADIENT_IMAGE = gradient and gradient.Image or ""
		local GRAY_IMAGE = "rbxassetid://138186545670173"

		-- the "FREE!" tag sits next to the button (sibling under Buttons). It only makes sense while the
		-- button is actually claimable, so we hide it whenever the button is grayed (cooldown or
		-- unavailable) and show it again when the button returns to its normal ready state.
		local freeLabel = adBtn.Parent and adBtn.Parent:FindFirstChild("Free")

		-- animate the "FREE!" gradient with the same side-to-side shimmer used on the shop badges:
		-- slide the UIGradient Offset -0.5 -> +0.5 over 1.6s, Sine InOut, infinite, autoreverse. Guarded
		-- by a ShimmerAnim attribute so it only ever starts one tween.
		do
			local grad = freeLabel and freeLabel:FindFirstChildOfClass("UIGradient")
			if grad and not grad:GetAttribute("ShimmerAnim") then
				grad:SetAttribute("ShimmerAnim", true)
				grad.Offset = Vector2.new(-0.5, grad.Offset.Y)
				TweenService:Create(
					grad,
					TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Offset = Vector2.new(0.5, grad.Offset.Y) }
				):Play()
			end
		end

		local function setGray(on)
			if gradient then
				gradient.Image = on and GRAY_IMAGE or DEFAULT_GRADIENT_IMAGE
			end
			if freeLabel then
				freeLabel.Visible = not on  -- hide "FREE!" while grayed; show it when ready
			end
		end

		adBtn.Active = true
		adBtn.Interactable = true
		UISounds.bindTween(adBtn)
		adBtn.MouseEnter:Connect(function() UISounds.play("hover") end)
		adBtn:SetAttribute("UISoundsBound", true)

		-- local cooldown mirror so the countdown ticks smoothly without spamming the server
		local cooldownUntil = 0   -- os.clock()-based deadline; 0 = ready
		local requesting = false  -- waiting on a server response after a click
		local unavailableShown = false  -- true while the temporary "Unavailable" gray state is showing

		local function fmt(sec)
			sec = math.max(0, math.floor(sec + 0.5))
			local m = math.floor(sec / 60)
			local s = sec % 60
			return string.format("%d:%02d", m, s)
		end

		local function setLabel(text)
			if adLabel then adLabel.Text = text end
		end

		-- one ticker updates the label while on cooldown; restores the default text when ready
		local function refresh()
			local remaining = cooldownUntil - os.clock()
			if remaining > 0 then
				adBtn.Interactable = false
				adBtn.AutoButtonColor = false
				setGray(true)  -- grayed out while cooling down
				setLabel(fmt(remaining))
			else
				cooldownUntil = 0
				if not requesting and not unavailableShown then
					adBtn.Interactable = true
					adBtn.AutoButtonColor = true
					setGray(false)  -- restore the normal colored button
					setLabel(DEFAULT_TEXT)
				end
			end
		end

		task.spawn(function()
			while true do
				refresh()
				task.wait(0.5)
			end
		end)

		local function startCooldown(remaining)
			if remaining and remaining > 0 then
				cooldownUntil = os.clock() + remaining
			else
				cooldownUntil = 0
			end
			unavailableShown = false  -- a real cooldown/ready state supersedes any "Unavailable" flash
			refresh()
		end

		-- temporary "no ad right now" state: gray the button + show "Unavailable" for 1.5s, then restore
		-- (unless a real cooldown started in the meantime). A token guards against overlapping flashes.
		local unavailableToken = 0
		local function showUnavailable()
			if cooldownUntil > os.clock() then return end  -- on cooldown: keep the countdown, don't override
			unavailableToken += 1
			local myToken = unavailableToken
			unavailableShown = true
			adBtn.Interactable = false
			adBtn.AutoButtonColor = false
			setGray(true)
			setLabel("Unavailable")
			task.delay(1.5, function()
				if myToken ~= unavailableToken then return end  -- superseded by a newer flash / state
				unavailableShown = false
				if cooldownUntil <= os.clock() then
					adBtn.Interactable = true
					adBtn.AutoButtonColor = true
					setGray(false)
					setLabel(DEFAULT_TEXT)
				else
					refresh()  -- a cooldown began during the flash: show the countdown
				end
			end)
		end

		SeekerQueueAdStatus.OnClientEvent:Connect(function(data)
			if type(data) ~= "table" then return end
			requesting = false
			if data.kind == "cooldown" then
				startCooldown(data.remaining)
			elseif data.kind == "reward" then
				UISounds.play("select")
				startCooldown(data.remaining)  -- full cooldown begins now
			elseif data.kind == "ready" then
				startCooldown(0)
			elseif data.kind == "unavailable" then
				-- no ad to show right now (not on cooldown): gray out + "Unavailable", then restore
				UISounds.play("error")
				if cooldownUntil <= os.clock() then showUnavailable() end
			end
		end)

		-- client-side availability pre-check (mirrors the Watch-Ad signs) before asking the server
		local INELIGIBLE = {
			Enum.AdAvailabilityResult.PlayerIneligible,
			Enum.AdAvailabilityResult.DeviceIneligible,
			Enum.AdAvailabilityResult.PublisherIneligible,
			Enum.AdAvailabilityResult.ExperienceIneligible,
		}
		local function adLikelyAvailable()
			local ok, result = pcall(function()
				return AdService:GetAdAvailabilityNowAsync(Enum.AdFormat.RewardedVideo)
			end)
			if not ok or result == nil then return false end
			return table.find(INELIGIBLE, result.AdAvailabilityResult) == nil
		end

		adBtn.MouseButton1Click:Connect(function()
			if requesting or unavailableShown then return end
			if cooldownUntil > os.clock() then return end  -- still cooling down
			UISounds.click()
			if not adLikelyAvailable() then
				UISounds.play("error")
				showUnavailable()
				return
			end
			requesting = true
			ClaimSeekerQueueAd:FireServer()
		end)

		-- seed the cooldown state when the GUI opens (and once on load), so the button shows the right
		-- countdown immediately on a rejoin instead of looking ready.
		local function queryCooldown() SeekerQueueAdQuery:FireServer() end
		openEvent.Event:Connect(queryCooldown)
		task.spawn(function()
			task.wait(1)
			queryCooldown()
		end)
	end
end

-- ===== Proximity: open the shop when the player is near the SeekerQueuePad, close when they leave =====
local RunService = game:GetService("RunService")
local TRIGGER_PADDING = 1  -- small leeway (studs) beyond the pad's edges; set to 0 for strict

-- SeekerQueuePad now lives in the central Workspace.LobbyInteractives folder; recursive find is robust
-- to nesting and means scripts never need re-pointing when the lobby changes.
local interactives = workspace:WaitForChild("LobbyInteractives", 30)
local pad = interactives and interactives:FindFirstChild("SeekerQueuePad", true)
if not pad then
	local waited = 0
	while interactives and not pad and waited < 30 do task.wait(0.2); waited += 0.2; pad = interactives:FindFirstChild("SeekerQueuePad", true) end
end
if pad then
	local inRange = false          -- are we currently within the pad radius?
	local dismissedInRange = false -- did the player manually close it while still standing on the pad?

	-- if the player closes via the X (or another menu) while on the pad, don't keep reopening
	-- until they step off and come back.
	local function onClosed()
		if inRange then dismissedInRange = true end
	end
	if exit then exit.MouseButton1Click:Connect(onClosed) end
	closeEvent.Event:Connect(onClosed)

	RunService.Heartbeat:Connect(function()
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then return end

		-- check the player against the pad's actual footprint (its X/Z bounds), not a radius,
		-- so the shop only opens while standing on the mesh itself.
		local localPos = pad.CFrame:PointToObjectSpace(hrp.Position)
		local halfX = pad.Size.X / 2 + TRIGGER_PADDING
		local halfZ = pad.Size.Z / 2 + TRIGGER_PADDING
		local nowInRange = math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ

		if nowInRange and not inRange then
			-- just entered range -> open (unless they already dismissed it this visit)
			inRange = true
			if not dismissedInRange then open() end
		elseif not nowInRange and inRange then
			-- just left range -> close and reset the dismiss flag for next time
			inRange = false
			dismissedInRange = false
			gui.Enabled = false
		end
	end)
else
	warn("[SeekerQueueShopClient] SeekerQueuePad not found in Workspace")
end
