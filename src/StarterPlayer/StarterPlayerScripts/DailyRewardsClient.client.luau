-- DailyRewardsClient: drives the StarterGui.DailyRewards screen. It builds one card per day in the
-- reward track (from the shared DailyRewardsConfig), renders each card's state (Claimed / Claim now /
-- Locked), runs the HH:MM:SS countdown to the next claim, shows the current streak, opens the screen
-- on join when a reward is available, and sends a claim request when the player taps Claim.
--
-- The server (DailyRewardsManager) is authoritative: it pushes state via DailyRewardsState and we send
-- claim requests via DailyRewardsClaim. We never decide claimability ourselves — we render what the
-- server says and re-render when it pushes an update.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("DailyRewardsConfig"))

local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local DailyState = remotes:WaitForChild("DailyRewardsState")
local DailyClaim = remotes:WaitForChild("DailyRewardsClaim")

local UISounds
pcall(function() UISounds = require(ReplicatedStorage:WaitForChild("UISounds", 5)) end)
local function sound(name) if UISounds and UISounds[name] then pcall(UISounds[name]) end end

-- Confetti for the claim celebration (screen + character), same module the code-claim uses.
local Confetti
pcall(function() Confetti = require(ReplicatedStorage:WaitForChild("Confetti", 5)) end)

local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("DailyRewards")
local root = gui:WaitForChild("HolderFrame"):WaitForChild("DailyRewards")
local scroll = root:WaitForChild("ScrollingFrame")
local template = scroll:WaitForChild("CardTemplate")
local closeButton = root:WaitForChild("CloseButton")
local dayCounter = root:WaitForChild("DayCounter")
local timerLabel = root:WaitForChild("Timer")

template.Visible = false
gui.Enabled = false

-- ===== helpers =====
-- set a layered label's text (the label + its nested "Top"/"TextLabel" overlay copy, if present)
local function setLayered(label, text)
	if not label then return end
	if label:IsA("TextLabel") or label:IsA("TextButton") then label.Text = text end
	for _, c in ipairs(label:GetDescendants()) do
		if c:IsA("TextLabel") then c.Text = text end
	end
end

local function formatTimer(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

local function commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ===== reward-text styling (colors + animated gradients) =====
-- The reward label inside a card is layered: IconHolder.TextLabel (dark back) with a nested white
-- "Top" copy (IconHolder.TextLabel.TextLabel). We style the FRONT (white) copy so the colour/gradient
-- reads cleanly over the dark back layer. Returns that front label, or nil.
local function frontRewardLabel(card)
	local ih = card:FindFirstChild("IconHolder")
	local back = ih and ih:FindFirstChild("TextLabel")
	local front = back and back:FindFirstChild("TextLabel")
	return front
end

-- Coin gold colour for coin-reward text.
local COIN_GOLD = Color3.fromRGB(255, 205, 40)

-- A yellow gradient (bright -> deep gold -> bright) for the LEGENDARY text.
local YELLOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0.0, Color3.fromRGB(255, 240, 150)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 190, 30)),
	ColorSequenceKeypoint.new(1.0, Color3.fromRGB(255, 240, 150)),
})

-- A rainbow gradient for the Graffiti/Brainrot crate text.
local RAINBOW_SEQUENCE = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 180, 60)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(255, 245, 70)),
	ColorSequenceKeypoint.new(0.51, Color3.fromRGB(90, 230, 110)),
	ColorSequenceKeypoint.new(0.68, Color3.fromRGB(80, 180, 255)),
	ColorSequenceKeypoint.new(0.85, Color3.fromRGB(160, 110, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 80, 80)),
})

-- Attach an animated UIGradient to a label and slide its Offset side-to-side (a shimmer), matching
-- the crate-shop badge animation (Sine InOut, infinite, auto-reverse). Guarded so it only animates once.
local SHIMMER_RANGE = 0.5
local SHIMMER_TIME = 1.6
local function animatedGradient(label, sequence)
	if not label then return end
	label.TextColor3 = Color3.fromRGB(255, 255, 255)  -- white base so the gradient shows true colours
	local grad = label:FindFirstChildOfClass("UIGradient")
	if not grad then grad = Instance.new("UIGradient"); grad.Parent = label end
	grad.Color = sequence
	if grad:GetAttribute("ShimmerAnim") then return end
	grad:SetAttribute("ShimmerAnim", true)
	grad.Offset = Vector2.new(-SHIMMER_RANGE, 0)
	TweenService:Create(
		grad,
		TweenInfo.new(SHIMMER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Offset = Vector2.new(SHIMMER_RANGE, 0) }
	):Play()
end

-- Style a card's reward text based on the reward: gold for coins, a rainbow shimmer for the Graffiti
-- and Brainrot crates, and a yellow shimmer for the LEGENDARY (random_legendary) reward.
local RAINBOW_CRATES = { ["Silver Crate"] = true, ["Brainrot Crate"] = true }  -- Graffiti = Silver Crate
local function styleRewardText(card, reward)
	local front = frontRewardLabel(card)
	if not front or not reward then return end
	if reward.kind == "coins" then
		front.TextColor3 = COIN_GOLD
	elseif reward.kind == "random_legendary" then
		animatedGradient(front, YELLOW_SEQUENCE)
	elseif reward.kind == "crate" and RAINBOW_CRATES[reward.crate] then
		animatedGradient(front, RAINBOW_SEQUENCE)
	end
end

-- ===== claim feedback (mirrors CodeRedeemClient) =====
-- coin award chime: clone SoundService.CoinReward into the SFX SoundGroup so the volume slider applies
local function playCoinReward()
	local tmpl = SoundService:FindFirstChild("CoinReward")
	if not tmpl or not tmpl:IsA("Sound") then return end
	local s = tmpl:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function() if s then s:Destroy() end end)
end

-- big centered floating text that holds then drifts up + fades, e.g. "DAILY REWARD! [+500 COINS]".
-- Lives in its own ScreenGui so it shows even after the daily screen closes.
local function showClaimText(message)
	local fxGui = Instance.new("ScreenGui")
	fxGui.Name = "DailyClaimFX"
	fxGui.ResetOnSpawn = false
	fxGui.IgnoreGuiInset = true
	fxGui.DisplayOrder = 50
	fxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	fxGui.Parent = pg

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.4)
	label.Size = UDim2.fromScale(0.6, 0.1)
	label.BackgroundTransparency = 1
	label.Text = message
	label.TextColor3 = Color3.fromRGB(255, 215, 0)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	local okFont = pcall(function()
		label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	end)
	if not okFont then label.Font = Enum.Font.FredokaOne end
	label.Parent = fxGui

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 48
	constraint.Parent = label

	local RISE, HOLD, RISE_TIME = 0.12, 1.6, 1.8
	task.delay(HOLD, function()
		if not label.Parent then return end
		TweenService:Create(label, TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromScale(0.5, 0.4 - RISE) }):Play()
		TweenService:Create(label, TweenInfo.new(RISE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(HOLD + RISE_TIME + 0.15, function() if fxGui then fxGui:Destroy() end end)
end

-- play the full success celebration for a claim. For rewards that trigger the UNBOX animation (a
-- crate, or the Day-7 random Legendary) we skip the coin sound + floating text (the unbox gives its
-- own feedback) but still pop confetti. Coin rewards get the coin chime + floating text.
local function triggersUnbox(rewardKind)
	return rewardKind == "crate" or rewardKind == "random_legendary"
end
local function celebrate(rewardKind, rewardAmount, rewardLabel)
	if Confetti then pcall(function() Confetti.Emit(2) end) end
	if triggersUnbox(rewardKind) then return end  -- unbox animation handles the rest
	sound("select")
	playCoinReward()
	if rewardKind == "coins" then
		showClaimText("DAILY REWARD! [+" .. commas(rewardAmount or 0) .. " COINS]")
	else
		showClaimText("DAILY REWARD! [" .. tostring(rewardLabel or "Claimed") .. "]")
	end
end

-- ===== current server state =====
local serverState = nil   -- last payload from the server

-- ===== card building =====
-- One card per configured day. Cards are built once; their STATE (claimed/claim/locked) is updated
-- on each render. claimedDay = how many days already claimed in this streak; the next claimable day
-- is claimedDay + 1 (when available).
local cards = {}  -- [dayNumber] = card Frame

local function buildCards()
	if next(cards) then return end  -- already built
	local n = Config.dayCount()
	for day = 1, n do
		local reward = Config.rewardForDay(day)
		local card = template:Clone()
		card.Name = "Day" .. day
		card.LayoutOrder = day
		card.Visible = true

		-- Day title
		setLayered(card:FindFirstChild("Title"), "Day " .. day)

		-- icon + reward label
		local ih = card:FindFirstChild("IconHolder")
		if ih then
			local icon = ih:FindFirstChild("Icon")
			if icon and icon:IsA("ImageLabel") and reward and reward.icon then icon.Image = reward.icon end
			setLayered(ih:FindFirstChild("TextLabel"), reward and reward.label or "")
		end
		-- colour / animated gradient on the reward text (gold coins, rainbow Graffiti+Brainrot, yellow LEGENDARY)
		styleRewardText(card, reward)

		-- wire the claim button for this card: press tween + claim request
		local claimBtn = card:FindFirstChild("ClaimButton")
		if claimBtn then
			claimBtn.AutoButtonColor = false
			local function getScale()
				local sc = claimBtn:FindFirstChildOfClass("UIScale")
				if not sc then sc = Instance.new("UIScale"); sc.Scale = 1; sc.Parent = claimBtn end
				return sc
			end
			local TW = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			claimBtn.MouseEnter:Connect(function() sound("hover"); TweenService:Create(getScale(), TW, { Scale = 1.06 }):Play() end)
			claimBtn.MouseLeave:Connect(function() TweenService:Create(getScale(), TW, { Scale = 1 }):Play() end)
			claimBtn.MouseButton1Down:Connect(function() TweenService:Create(getScale(), TW, { Scale = 0.93 }):Play() end)
			claimBtn.MouseButton1Up:Connect(function() TweenService:Create(getScale(), TW, { Scale = 1.06 }):Play() end)
			claimBtn.MouseButton1Click:Connect(function()
				-- only meaningful if this card is the active claimable one
				if serverState and serverState.available and (serverState.claimedDay + 1) == day then
					sound("click")
					DailyClaim:FireServer()
				end
			end)
		end

		card.Parent = scroll
		cards[day] = card
	end
end

-- Give a Locked button a gentle continuous "breathing" pulse (subtle scale in/out) so it reads as
-- alive rather than static. Guarded so it only starts one tween per button instance.
local function pulseLocked(lockedBtn)
	if not lockedBtn then return end
	if lockedBtn:GetAttribute("PulseAnim") then return end
	lockedBtn:SetAttribute("PulseAnim", true)
	local sc = lockedBtn:FindFirstChildOfClass("UIScale")
	if not sc then sc = Instance.new("UIScale"); sc.Scale = 1; sc.Parent = lockedBtn end
	sc.Scale = 0.97
	TweenService:Create(
		sc,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.03 }
	):Play()
end

-- show exactly one of the three state elements on a card
local function setCardState(card, state)
	-- state: "claimed" | "claim" | "locked"
	local claimBtn = card:FindFirstChild("ClaimButton")
	local lockedBtn = card:FindFirstChild("LockedButton")
	local claimedFrame = card:FindFirstChild("Claimed")
	local title = card:FindFirstChild("Title")

	if claimBtn then claimBtn.Visible = (state == "claim") end
	if lockedBtn then lockedBtn.Visible = (state == "locked") end
	if claimedFrame then claimedFrame.Visible = (state == "claimed") end

	-- start the locked-button pulse when this card is locked (guarded so it won't stack)
	if state == "locked" then pulseLocked(lockedBtn) end

	-- Title reads "Claimed" on a claimed card, else "Day X"
	if title then
		local dayNum = tonumber(card.Name:match("%d+")) or 1
		setLayered(title, state == "claimed" and "Claimed" or ("Day " .. dayNum))
	end
end

-- ===== render from server state =====
local function render()
	if not serverState then return end
	buildCards()

	local claimedDay = serverState.claimedDay or 0
	local available = serverState.available
	local activeDay = claimedDay + 1  -- the day that is claimable (if available)

	for day, card in pairs(cards) do
		if day <= claimedDay then
			setCardState(card, "claimed")
		elseif available and day == activeDay then
			setCardState(card, "claim")
		else
			setCardState(card, "locked")
		end
	end

	-- streak label: "Current Streak: X Days". The streak shown is the number of consecutive claims.
	setLayered(dayCounter, string.format("Current Streak: %d Day%s", claimedDay, claimedDay == 1 and "" or "s"))
end

-- ===== countdown timer =====
local function updateTimer()
	if not serverState then return end
	if serverState.available then
		setLayered(timerLabel, "Claim Now!")
	else
		local now = os.time()
		local remaining = (serverState.nextClaimAt or 0) - now
		if remaining <= 0 then
			-- The 24h window has elapsed: the next day is now claimable. Flip to available locally and
			-- re-render so the next card changes Locked -> Claim WITHOUT needing a rejoin (the server
			-- still re-validates the actual claim, so trusting the client here only affects display).
			serverState.available = true
			serverState.nextClaimAt = 0
			-- Miss-window check: if SO much time has passed that a day was missed, the streak will reset
			-- to Day 1 on claim. Reflect that in the display now (claimedDay -> 0) so the card that
			-- lights up is Day 1, matching what the server will actually grant.
			local lastClaimAt = serverState.lastClaimAt or 0
			if Config.MISS_AFTER and lastClaimAt > 0 and (now - lastClaimAt) >= Config.MISS_AFTER then
				serverState.claimedDay = 0
			end
			render()
			setLayered(timerLabel, "Claim Now!")
		else
			setLayered(timerLabel, formatTimer(remaining))
		end
	end
end

-- ===== open / close =====
local function openGui()
	sound("select")
	gui.Enabled = true
end
local function closeGui()
	sound("close")
	gui.Enabled = false
end
closeButton.MouseButton1Click:Connect(closeGui)
closeButton.MouseEnter:Connect(function() sound("hover") end)

-- BindableEvents so the HUD (or a button) can open the screen on demand later
local openEvent = gui:FindFirstChild("OpenDailyRewards")
if not openEvent then openEvent = Instance.new("BindableEvent"); openEvent.Name = "OpenDailyRewards"; openEvent.Parent = gui end
openEvent.Event:Connect(openGui)

-- ===== receive state =====
local openedOnce = false
DailyState.OnClientEvent:Connect(function(payload)
	serverState = payload
	render()
	updateTimer()
	-- claim success feedback: coin sound + floating text + confetti (unbox rewards skip sound/text)
	if payload and payload.justClaimed then
		celebrate(payload.rewardKind, payload.rewardAmount, payload.rewardLabel)
		-- if the reward triggers the unbox animation (crate / random legendary), close the daily screen
		-- so the unbox UI isn't hidden behind it.
		if triggersUnbox(payload.rewardKind) then
			gui.Enabled = false
		end
	end
	-- open automatically on join the FIRST time we hear a state with a claim available
	if not openedOnce and payload and payload.available then
		openedOnce = true
		openGui()
	end
end)

-- tick the countdown every second
task.spawn(function()
	while true do
		updateTimer()
		task.wait(1)
	end
end)
