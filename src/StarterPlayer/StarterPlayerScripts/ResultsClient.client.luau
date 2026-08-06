-- ResultsClient: per-player end-of-round results with an animated XP bar, sequential
-- row reveals, sound effects, and a 10-second auto-close countdown.
--
-- Drives the new Results GUI (CleanFrame style, toggled via ScreenGui.Enabled):
--   Results.HolderFrame.Results
--     Title / WhiteStrokeTitle (layered) -- "Victory!" / "Defeat"
--     WinnerRole (+ Top)                 -- the player's role, colored
--     PlayerIcon.Icon (ImageLabel)       -- the player's avatar headshot
--     Bar: CurrentLevel / NextLevel labels + Bar.Bar.Bar (fill ImageLabel) + Bar.Bar.BehindBar
--     Stats.StatsRow1/2/3 (each: Name, Points, Icon) -- the XP breakdown, one row per item
--     CoinsEarned (+ Top)                -- coins earned this round
--     CloseButton (ImageButton)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoundSummary = Remotes:WaitForChild("RoundSummary")
local LevelUpReward = Remotes:WaitForChild("LevelUpReward")
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))

local SEEKER_COLOR = Color3.fromRGB(220, 70, 70)
local HIDER_COLOR = Color3.fromRGB(70, 180, 95)
local AUTO_CLOSE = 10  -- seconds before the screen closes itself

-- mirror of the server level curve (so the client can roll the bar across level-ups)
local BASE_XP, PER_LEVEL_XP = 100, 50
local function xpForLevel(level) return BASE_XP + PER_LEVEL_XP * (level - 1) end

local function ui()
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:WaitForChild("Results")
	local panel = gui:WaitForChild("HolderFrame"):WaitForChild("Results")
	return gui, panel
end

-- Find a label's overlay (front) layer, if any. This GUI uses a few overlay conventions:
--   * a child named "Top"  (Title, WinnerRole, level labels, CoinsEarned)
--   * a child with the SAME name as its parent  (e.g. the row label Name > Name)
--   * a child literally named "Name"  (the Stats rows' front white layer is ALWAYS "Name",
--     even on the Points label: Points > Name)
-- Returns the overlay TextLabel or nil. We never return the label itself, so the walk terminates.
local function overlayOf(label)
	local top = label:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then return top end
	local same = label:FindFirstChild(label.Name)
	if same and same ~= label and same:IsA("TextLabel") then return same end
	local named = label:FindFirstChild("Name")
	if named and named ~= label and named:IsA("TextLabel") then return named end
	return nil
end

-- set a layered label's text (the back label + its overlay) keeping every layer in sync. Walks the
-- overlay chain so a label nested two deep (back -> overlay -> overlay) all updates, not just one.
local function setLayered(label, text)
	if not label then return end
	local cur = label
	local guard = 0
	while cur and guard < 4 do
		cur.Text = text
		cur = overlayOf(cur)
		guard += 1
	end
end

local function avatarImage(userId)
	if not userId then return "" end
	return "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=420&h=420"
end

-- thousands separators for the big reward numbers (points / coins), e.g. 1960 -> "1,960"
local function commas(n)
	local s = tostring(math.floor(tonumber(n) or 0))
	local k
	repeat
		s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0
	return s
end

-- color a layered label (the back label + every overlay layer are tinted the same color)
local function tintLayered(label, color)
	if not label then return end
	local cur = label
	local guard = 0
	while cur and guard < 4 do
		cur.TextColor3 = color
		cur = overlayOf(cur)
		guard += 1
	end
end

-- play a SoundService sound by name (cloned through the SFX group). returns the playing clone.
local function playSound(name, looped)
	local template = SoundService:FindFirstChild(name)
	if not template then return nil end
	local s = template:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end
	s.Looped = looped and true or false
	s.Parent = SoundService
	s:Play()
	if not looped then
		task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function()
			if s then s:Destroy() end
		end)
	end
	return s
end

local function wireExit(panel)
	local exit = panel:FindFirstChild("CloseButton")
	if exit and not exit:GetAttribute("Wired") then
		exit:SetAttribute("Wired", true)
		UISounds.bindTween(exit)
		exit.MouseButton1Click:Connect(function()
			UISounds.close()
			closeScreen()
		end)
	end
end

-- single token controls EVERYTHING for the current screen (animation, reveals, countdown).
-- bumping it cancels all in-progress coroutines for the previous screen.
local token = 0
local countdownRunning = false
-- set true when THIS round's results were a level-up; on close we claim the free crate (once).
local pendingLevelUpReward = false

function closeScreen()
	token += 1
	countdownRunning = false
	local gui = ui()
	gui.Enabled = false
	-- if the player leveled up this round, claim their free Level Up Reward crate now that the
	-- results screen is closing. Clear the flag first so it only fires once.
	if pendingLevelUpReward then
		pendingLevelUpReward = false
		task.delay(0.35, function()  -- let the results screen finish closing before the crate opens
			LevelUpReward:FireServer()
		end)
	end
end

-- animate the XP bar; calls onDone() when the fill finishes. plays ProgressBar while filling.
-- New bar structure: barFrame (Bar) -> CurrentLevel / NextLevel labels + Bar.Bar (track) with
-- BehindBar (empty) and Bar (fill ImageLabel). We left-anchor the fill so it grows L->R by X-scale.
--
-- A centered "xp / needed XP" label is shown on the track. It is parented to the TRACK (not the
-- fill), so it stays centered over the whole bar and does NOT shrink/move as the fill animates.
local function ensureXpText(track)
	if not track then return nil end
	local lbl = track:FindFirstChild("XPText")
	if lbl then return lbl end
	lbl = Instance.new("TextLabel")
	lbl.Name = "XPText"
	lbl.BackgroundTransparency = 1
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.new(0.5, 0, 0.5, 0)
	lbl.Size = UDim2.new(1, 0, 1, 0)        -- fills the track; centered text sits over the whole bar
	lbl.ZIndex = 10                          -- above BehindBar + the fill
	lbl.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextScaled = true
	lbl.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = lbl
	-- keep the text a sensible size (TextScaled would otherwise fill the bar height with huge text)
	local tsc = Instance.new("UITextSizeConstraint")
	tsc.MaxTextSize = 16
	tsc.MinTextSize = 6
	tsc.Parent = lbl
	lbl.Parent = track
	return lbl
end

local function animateBar(barFrame, startLevel, startXp, gained, maxLevel, myToken, onDone, capNote)
	local leftLabel = barFrame:FindFirstChild("CurrentLevel")
	local rightLabel = barFrame:FindFirstChild("NextLevel")
	local track = barFrame:FindFirstChild("Bar")
	local barFill = track and track:FindFirstChild("Bar")
	local xpText = ensureXpText(track)

	-- the fill is authored center-anchored at ~0.99 wide; re-anchor it to the LEFT edge of the track
	-- so animating its X-scale fills the bar left-to-right (full width = the authored width).
	local FULL_W = barFill and barFill.Size.X.Scale or 1
	if barFill then
		barFill.AnchorPoint = Vector2.new(0, 0.5)
		barFill.Position = UDim2.new(0, 0, 0.5, 0)
	end

	local level = startLevel
	local xp = startXp
	local needed = xpForLevel(level)

	local function setLevelLabels()
		if leftLabel then setLayered(leftLabel, tostring(level)) end
		local atMax = maxLevel and level >= maxLevel
		if rightLabel then setLayered(rightLabel, atMax and "MAX" or tostring(level + 1)) end
	end

	-- update the centered "x / y XP" text for the current level/xp state. When the round hit the XP
	-- cap, capNote (e.g. "(175/175)") is appended so the player can see they maxed the round.
	local function setXpText()
		if not xpText then return end
		local atMax = maxLevel and level >= maxLevel
		local base
		if atMax then
			base = "MAX LEVEL"
		else
			base = tostring(math.floor(xp)) .. " / " .. tostring(needed) .. " XP"
		end
		if capNote and capNote ~= "" then
			base = base .. "   " .. capNote
		end
		xpText.Text = base
	end

	local function render(instant)
		setLevelLabels()
		setXpText()
		if not barFill then return end
		local atMax = maxLevel and level >= maxLevel
		local ratio = atMax and 1 or math.clamp(needed > 0 and (xp / needed) or 0, 0, 1)
		local target = UDim2.new(FULL_W * ratio, 0, barFill.Size.Y.Scale, barFill.Size.Y.Offset)
		if instant then
			barFill.Size = target
		else
			TweenService:Create(barFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = target }):Play()
		end
	end

	render(true)  -- show the starting state immediately

	-- the authoritative FINAL state, computed up front from the data. After the segmented animation
	-- we snap to exactly this so the bar can never be left visually mid-fill (the "stuck at ~20%" bug,
	-- which happened when a tween was superseded by a level-up reset or the loop exited mid-tween).
	local function computeFinal()
		local fLevel, fXp = startLevel, startXp + gained
		while not (maxLevel and fLevel >= maxLevel) do
			local fNeeded = xpForLevel(fLevel)
			if fXp < fNeeded then break end
			fXp -= fNeeded
			fLevel += 1
		end
		if maxLevel and fLevel >= maxLevel then return fLevel, 0, true end
		return fLevel, fXp, false
	end

	task.spawn(function()
		if gained > 0 then
			local progressSound = playSound("ProgressBar", true)  -- looped while the bar fills
			task.wait(0.35)
			local remaining = gained
			while remaining > 0 do
				if myToken ~= token then if progressSound then progressSound:Destroy() end return end
				if maxLevel and level >= maxLevel then xp = 0; render(false); break end
				local toFill = needed - xp
				if remaining >= toFill then
					remaining -= toFill
					xp = needed
					render(false)
					task.wait(0.45)
					if myToken ~= token then if progressSound then progressSound:Destroy() end return end
					level += 1
					xp = 0
					needed = xpForLevel(level)
					if barFill then barFill.Size = UDim2.new(0, 0, barFill.Size.Y.Scale, barFill.Size.Y.Offset) end
					setLevelLabels()
					setXpText()
					UISounds.play("select")  -- level-up ping
				else
					xp += remaining
					remaining = 0
					render(false)
				end
				task.wait(0.45)
			end
			if progressSound then progressSound:Stop(); progressSound:Destroy() end
		end
		-- GUARANTEED FINAL STATE: regardless of what raced during the segmented animation above, snap
		-- the bar + labels + text to the true end state so it always reflects the real result and never
		-- gets stuck partway. (Uses the data-derived final level/xp, not the loop's mutated locals.)
		if myToken == token then
			local fLevel, fXp, fMax = computeFinal()
			level, xp = fLevel, fXp
			needed = xpForLevel(level)
			setLevelLabels()
			setXpText()
			if barFill then
				local ratio = fMax and 1 or math.clamp(needed > 0 and (xp / needed) or 0, 0, 1)
				TweenService:Create(barFill, TweenInfo.new(0.25, Enum.EasingStyle.Quad),
					{ Size = UDim2.new(FULL_W * ratio, 0, barFill.Size.Y.Scale, barFill.Size.Y.Offset) }):Play()
			end
		end
		if myToken == token and onDone then onDone() end
	end)
end

local function show(data)
	token += 1
	local myToken = token
	-- remember whether this round leveled the player up, so closeScreen() can grant the free crate.
	pendingLevelUpReward = data.leveledUp and true or false

	local gui, panel = ui()

	local role = data.myRole
	local roleColor = (role == "Seeker") and SEEKER_COLOR or HIDER_COLOR
	if data.roleColor then
		roleColor = Color3.fromRGB(data.roleColor[1], data.roleColor[2], data.roleColor[3])
	end
	local roleLabelText = data.roleText or role

	-- ===== Title: Victory! / Defeat (layered Title + WhiteStrokeTitle) =====
	local titleText = data.won and "Victory!" or "Defeat"
	local titleColor = data.won and HIDER_COLOR or SEEKER_COLOR
	local title = panel:FindFirstChild("Title")
	local whiteTitle = panel:FindFirstChild("WhiteStrokeTitle")
	setLayered(title, titleText)
	tintLayered(title, titleColor)
	if whiteTitle then setLayered(whiteTitle, titleText) end

	-- ===== Role label (colored) + avatar =====
	local winnerRole = panel:FindFirstChild("WinnerRole")
	if winnerRole then
		if roleLabelText then
			winnerRole.Visible = true
			setLayered(winnerRole, string.upper(roleLabelText))
			tintLayered(winnerRole, roleColor)
		else
			winnerRole.Visible = false
		end
	end
	local playerIcon = panel:FindFirstChild("PlayerIcon")
	local avatarImg = playerIcon and playerIcon:FindFirstChild("Icon")
	if avatarImg then
		avatarImg.Image = avatarImage(data.myUserId)
		avatarImg.ImageTransparency = 0
	end

	-- ===== Stats rows: one per xpBreakdown item (3 fixed rows; unused hidden) =====
	local stats = panel:FindFirstChild("Stats")
	local breakdown = data.statsRows or data.xpBreakdown or {}
	local statRows = {}
	for i = 1, 3 do
		local rowFrame = stats and stats:FindFirstChild("StatsRow" .. i)
		if rowFrame then
			local item = breakdown[i]
			if item then
				local label = item.label or "Bonus"
				if item.mult then label = label .. "  " .. tostring(item.mult) .. "x" end
				setLayered(rowFrame:FindFirstChild("Name"), label)
				setLayered(rowFrame:FindFirstChild("Points"), item.valueText or ("+" .. tostring(item.amount or 0)))
				rowFrame.Visible = false  -- revealed one-by-one after the bar fills
				statRows[#statRows + 1] = rowFrame
			else
				rowFrame.Visible = false  -- no breakdown item for this slot: keep it hidden
			end
		end
	end

	-- ===== Coins earned (separate label, revealed last) =====
	local coinsLabel = panel:FindFirstChild("CoinsEarned")
	if coinsLabel then
		coinsLabel.Visible = false
		-- Show the total Points to the LEFT of the coin amount so players can see what their points
		-- translate to (coins = 10 x points). pointsEarned comes from the server; fall back to coins/10.
		local coinsEarned = data.coinsEarned or 0
		local pointsEarned = data.pointsEarned or math.floor(coinsEarned / 10)
		setLayered(coinsLabel, commas(pointsEarned) .. " Points   =" .. commas(coinsEarned) .. " Coins")
	end

	-- the auto-close countdown starts only AFTER the bar + reveals finish. It shows the remaining
	-- seconds in the CloseTimer label next to the X.
	local closeTimer = panel:FindFirstChild("CloseTimer")
	if closeTimer then closeTimer.Text = "(" .. AUTO_CLOSE .. "s)" end
	local function startCountdown()
		countdownRunning = true
		task.spawn(function()
			for t = AUTO_CLOSE, 1, -1 do
				if myToken ~= token then countdownRunning = false; return end
				if closeTimer then closeTimer.Text = "(" .. t .. "s)" end
				task.wait(1)
			end
			countdownRunning = false
			if myToken == token then closeScreen() end
		end)
	end

	-- reveal each populated stat row one at a time, then the coins line, then start the countdown
	local function revealRows()
		task.spawn(function()
			for _, rowFrame in ipairs(statRows) do
				if myToken ~= token then return end
				rowFrame.Visible = true
				playSound("RevealRow", false)
				task.wait(0.35)
			end
			if coinsLabel and (data.coinsEarned or 0) > 0 then
				if myToken ~= token then return end
				coinsLabel.Visible = true
				playSound("RevealRow", false)
				task.wait(0.35)
			end
			if myToken == token then startCountdown() end
		end)
	end

	-- animate the XP bar; when it finishes, reveal the rows. When the round's XP was capped, show the
	-- "(earned/cap)" note on the bar (e.g. "(175/175)" / "(250/250)") so the player sees they maxed it.
	local bar = panel:FindFirstChild("Bar")
	local capNote = nil
	if data.xpCapped and data.xpCap then
		capNote = "(" .. tostring(data.xpEarned or data.xpCap) .. "/" .. tostring(data.xpCap) .. ")"
	end
	animateBar(bar, data.level or 1, data.xp or 0, data.totalXp or 0, data.maxLevel, myToken, revealRows, capNote)

	wireExit(panel)

	gui.Enabled = true
end

RoundSummary.OnClientEvent:Connect(function(data)
	if data == nil then
		-- server's end-of-RESOLVE hide. The client owns the visible 20s countdown, so don't
		-- force-close while it's still running (that would cut the timer short). It'll close
		-- itself when the countdown reaches 0 (or the player hits X). Only honor this nil if
		-- the screen is up but no countdown is active (e.g. animation never started).
		if not countdownRunning then closeScreen() end
	else
		show(data)
	end
end)

print("[ResultsClient] ready (animated + sounds + auto-close)")
