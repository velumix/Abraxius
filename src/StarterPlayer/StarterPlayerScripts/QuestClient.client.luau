-- QuestClient: renders the hourly quest panel (Hud.Quests) and handles the slide in/out toggle.
--
-- The SERVER (QuestManager) owns all quest state. This script only:
--   * listens for QuestState (the player's current quests + hourly deadline) and renders the 3 slots,
--   * runs the live "refreshes in HH:MM:SS" countdown to the deadline (and re-requests state at 0),
--   * fills each quest's progress bar (via the InnerBar's UIGradient mask) and marks completed ones,
--   * plays a little celebration when QuestCompleted fires,
--   * toggles the panel open/closed with the HideButton: ">" (open) slides the panel off to the right
--     leaving only "<" visible; clicking "<" slides it back in.
--
-- It NEVER advances progress or grants rewards -- that is 100% server-authoritative.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local QuestState = Remotes:WaitForChild("QuestState")
local QuestCompleted = Remotes:WaitForChild("QuestCompleted")
local QuestRequest = Remotes:WaitForChild("QuestRequest")

-- ===== GUI refs =====
local hud = pg:WaitForChild("Hud")
local questsRoot = hud:WaitForChild("Quests")            -- the OUTER frame (right-anchored): [HideButton][panel]
local hideButton = questsRoot:WaitForChild("HideButton")
local panel = questsRoot:WaitForChild("Quests")          -- the INNER panel holding Header + Quest1..3
local header = panel:WaitForChild("Header")
local timerLabel = header:WaitForChild("Timer")

local slots = {
	panel:WaitForChild("Quest1"),
	panel:WaitForChild("Quest2"),
	panel:WaitForChild("Quest3"),
}

-- ===== layered-text helper =====
-- Labels in this UI are layered: an outer TextLabel with a "Top" child TextLabel (drop-shadow look).
-- Set BOTH so the layers stay in sync.
local function setLayered(label, text)
	if not label then return end
	if label:IsA("TextLabel") then label.Text = text end
	local top = label:FindFirstChild("Top")
	if top and top:IsA("TextLabel") then top.Text = text end
end

-- ===== progress bar (UIGradient transparency mask, like the settings sliders) =====
-- Each slot has Bar.InnerBar with a UIGradient. We reveal the left `pct` fraction of the InnerBar by
-- making the gradient opaque (Transparency 1) past `pct` and visible (0) before it -- a hard step.
local function setBarFill(slot, pct)
	pct = math.clamp(pct, 0, 1)
	local bar = slot:FindFirstChild("Bar")
	local inner = bar and bar:FindFirstChild("InnerBar")
	local grad = inner and inner:FindFirstChildWhichIsA("UIGradient")
	if not grad then return end
	grad.Offset = Vector2.new(0, 0)
	local seq
	if pct <= 0.001 then
		seq = NumberSequence.new(1)             -- fully empty: hide the whole fill
	elseif pct >= 0.999 then
		seq = NumberSequence.new(0)             -- full: show the whole fill
	else
		seq = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(pct, 0),
			NumberSequenceKeypoint.new(math.min(pct + 0.001, 1), 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	grad.Transparency = seq
end

-- ===== render one slot from a quest payload =====
-- quest = { id, typeId, target, progress, reward, done }
local function renderSlot(slot, quest)
	if not quest then
		slot.Visible = false
		return
	end
	slot.Visible = true

	setLayered(slot:FindFirstChild("Quest"), QuestConfig.describe(quest.typeId, quest.target))
	setLayered(slot:FindFirstChild("Amount"), tostring(quest.reward))

	-- NOTE: the slot's Icon is the authored coins icon and is intentionally left untouched (every quest
	-- pays coins, so the icon is always correct as authored).

	local pct = (quest.target > 0) and (quest.progress / quest.target) or 0
	if quest.done then pct = 1 end
	setBarFill(slot, pct)

	-- show a "x / y" count on the Amount? No -- Amount is the reward. The Bar conveys progress; we also
	-- append the count to the quest text for clarity, and grey the slot a touch when done.
	local qLabel = slot:FindFirstChild("Quest")
	if qLabel then
		local base = QuestConfig.describe(quest.typeId, quest.target)
		if quest.done then
			setLayered(qLabel, base .. "  (Done!)")
		else
			setLayered(qLabel, base .. "  (" .. math.floor(quest.progress) .. "/" .. quest.target .. ")")
		end
	end
end

-- ===== state =====
local currentDeadline = 0
local lastQuestsById = {}  -- id -> quest, to detect when a slot's quest changed (for a refresh flash)

local function render(payload)
	if type(payload) ~= "table" then return end
	currentDeadline = payload.deadline or 0
	local quests = payload.quests or {}
	for i, slot in ipairs(slots) do
		renderSlot(slot, quests[i])
	end
	lastQuestsById = {}
	for _, q in ipairs(quests) do lastQuestsById[q.id] = q end
end

QuestState.OnClientEvent:Connect(render)

-- ===== completion celebration =====
-- Play a one-shot SoundService sound, routed through the SFX SoundGroup (so the Settings SFX volume
-- slider applies, matching every other one-shot in the game), then clean it up. Safe no-op if missing.
local function playOneShot(soundName, volumeScale)
	local tmpl = SoundService:FindFirstChild(soundName)
	if not tmpl or not tmpl:IsA("Sound") then return end
	local s = tmpl:Clone()
	if volumeScale then s.Volume = tmpl.Volume * volumeScale end
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx and sfx:IsA("SoundGroup") then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function() if s then s:Destroy() end end)
end

local function playCompleteSound()
	-- the celebratory "Reward" chime, with the "CoinReward" coin sound layered a touch under it so a
	-- completed quest both feels rewarding AND clearly reads as "you got coins".
	playOneShot("Reward")
	playOneShot("CoinReward", 0.9)
end

-- ===== coin-received notification toast =====
-- A self-contained on-screen toast (mirrors GlobalGiftClient's style: FredokaOne, rich-text colored,
-- fades in then out). Tells the player they were paid for completing a quest, so they notice the coins
-- even if they aren't watching their balance. Positioned to sit clear of the gift/knife toasts.
local NOTIF_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)
local GOLD_HEX = "#FFD75A"   -- coin amount
local WHITE_HEX = "#FFFFFF"

local notifGui = Instance.new("ScreenGui")
notifGui.Name = "QuestNotifyGui"
notifGui.ResetOnSpawn = false
notifGui.IgnoreGuiInset = true
notifGui.DisplayOrder = 305
notifGui.Parent = pg

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "QuestNotifyLabel"
notifLabel.AnchorPoint = Vector2.new(0.5, 0)
notifLabel.Position = UDim2.new(0.5, 0, 0.34, 0)  -- below the gift toast (~0.27) so they never overlap
notifLabel.Size = UDim2.new(0.6, 0, 0.05, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.FontFace = NOTIF_FONT
notifLabel.TextScaled = true
notifLabel.RichText = true
notifLabel.Text = ""
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.TextTransparency = 1
notifLabel.Visible = false
notifLabel.ZIndex = 5
notifLabel.Parent = notifGui

local notifStroke = Instance.new("UIStroke")
notifStroke.Color = Color3.fromRGB(0, 0, 0)
notifStroke.Thickness = 2
notifStroke.Transparency = 1
notifStroke.Parent = notifLabel

local notifSizeConstraint = Instance.new("UITextSizeConstraint")
notifSizeConstraint.MaxTextSize = 24
notifSizeConstraint.Parent = notifLabel

local function escapeRich(s)
	s = tostring(s)
	s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
	return s
end

local notifToken = 0
local function showCoinToast(reward)
	notifLabel.Text = string.format(
		'<font color="%s">Quest complete!</font>  <font color="%s">+%s Coins</font>',
		WHITE_HEX, GOLD_HEX, escapeRich(reward)
	)
	notifToken += 1
	local myToken = notifToken
	notifLabel.Visible = true
	-- pop in: fade + a small upward slide for a bit of life
	notifLabel.Position = UDim2.new(0.5, 0, 0.355, 0)
	TweenService:Create(notifLabel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.34, 0) }):Play()
	TweenService:Create(notifStroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	task.delay(3.5, function()
		if myToken ~= notifToken then return end
		TweenService:Create(notifLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		local out = TweenService:Create(notifStroke, TweenInfo.new(0.4), { Transparency = 1 })
		out:Play()
		out.Completed:Connect(function()
			if myToken == notifToken then notifLabel.Visible = false end
		end)
	end)
end

QuestCompleted.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	playCompleteSound()
	local reward = tonumber(data.reward) or 0
	if reward > 0 then
		showCoinToast(reward)
	end
	-- a tiny pop on the panel for feedback
	local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = panel
	scale.Scale = 1
	TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.05 }):Play()
	task.delay(0.14, function()
		TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end)

-- ===== hourly countdown =====
local function fmtRemaining(seconds)
	if seconds < 0 then seconds = 0 end
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = math.floor(seconds % 60)
	return string.format("%02dh%02dm%02ds", h, m, s)
end

local lastRequestAt = 0
task.spawn(function()
	while true do
		if currentDeadline > 0 then
			local remaining = currentDeadline - os.time()
			setLayered(timerLabel, fmtRemaining(remaining))
			-- when the hour is up, ask the server for the fresh set (it rolls a new one on request/tick).
			-- throttle so we don't spam if the server is briefly slow to refresh.
			if remaining <= 0 and (os.clock() - lastRequestAt) > 3 then
				lastRequestAt = os.clock()
				QuestRequest:FireServer()
			end
		else
			setLayered(timerLabel, "--h--m--s")
		end
		task.wait(1)
	end
end)

-- ===== slide in / out toggle =====
-- The OUTER questsRoot frame is right-anchored ({1,0.5}) with [HideButton][panel] laid out L->R.
-- OPEN  = panel on screen, button text ">".
-- CLOSED = slide the whole frame RIGHT so the panel exits the screen and only the button (left edge of
--          the frame) stays visible at the right screen edge; button text "<".
-- We compute the slide distance from the panel's actual on-screen width fraction, so it's resolution-
-- independent and always tucks the panel fully off-screen while keeping the button peeking.
local buttonTextLabel = hideButton:WaitForChild("TextLabel")

-- the HideButton arrow is layered: an outer TextLabel (dark) with a NESTED same-named TextLabel inside
-- it (the lighter shadow). Both must change together. (This differs from the other labels' "Top"
-- layer, so it gets its own setter.) Recurse so every nested TextLabel under the button shows the arrow.
local function setButtonArrow(arrow)
	local function applyTo(inst)
		for _, child in ipairs(inst:GetChildren()) do
			if child:IsA("TextLabel") then
				child.Text = arrow
				applyTo(child)
			end
		end
	end
	if buttonTextLabel:IsA("TextLabel") then buttonTextLabel.Text = arrow end
	applyTo(buttonTextLabel)
end

local OPEN_POS = questsRoot.Position           -- authored open position (right-anchored at the edge)
local isOpen = true
local sliding = false

local function panelScreenWidthScale()
	-- fraction of the viewport the inner panel occupies (used as the slide distance)
	local cam = workspace.CurrentCamera
	local viewW = (cam and cam.ViewportSize.X) or 1
	if viewW <= 0 then viewW = 1 end
	return panel.AbsoluteSize.X / viewW
end

local function setButtonText(t)
	setButtonArrow(t)
end

-- give the arrow a little life on toggle: a quick scale "pop" (squash then settle) via a UIScale on
-- the button's text. Purely cosmetic; runs alongside the panel slide.
local arrowScale = buttonTextLabel:FindFirstChildOfClass("UIScale")
if not arrowScale then
	arrowScale = Instance.new("UIScale")
	arrowScale.Scale = 1
	arrowScale.Parent = buttonTextLabel
end
local function popArrow()
	arrowScale.Scale = 1
	-- pop up, then settle back with a slight overshoot for a bouncy feel
	TweenService:Create(arrowScale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.45 }):Play()
	task.delay(0.12, function()
		TweenService:Create(arrowScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
end

-- one-shot toggle SFX for the HideButton: play the click sound (asset id below) routed through the SFX
-- SoundGroup so the Settings SFX volume slider applies, then clean it up. This sound isn't a named
-- Sound in SoundService, so we build it from its raw asset id (playOneShot clones by name only).
local TOGGLE_SOUND_ID = "rbxassetid://132163823091536"
local function playToggleSound()
	local s = Instance.new("Sound")
	s.SoundId = TOGGLE_SOUND_ID
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx and sfx:IsA("SoundGroup") then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function() s:Destroy() end)
	task.delay(5, function() if s and s.Parent then s:Destroy() end end)  -- safety cleanup
end

local TWEEN = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function setOpen(open, instant)
	isOpen = open
	setButtonText(open and ">" or "<")
	-- toggled ON: reveal the inner Quests panel up front so it's visible while it slides in
	if open then panel.Visible = true end
	local targetPos
	if open then
		targetPos = OPEN_POS
	else
		-- shift right by the panel's screen-width fraction so the panel slides fully off the right edge
		local dx = panelScreenWidthScale()
		targetPos = UDim2.new(OPEN_POS.X.Scale + dx, OPEN_POS.X.Offset, OPEN_POS.Y.Scale, OPEN_POS.Y.Offset)
	end
	if instant then
		questsRoot.Position = targetPos
		panel.Visible = open  -- toggled OFF at startup => hide the inner panel immediately
		return
	end
	popArrow()  -- bouncy arrow feedback alongside the slide
	playToggleSound()  -- click SFX on every real toggle (open & close), but NOT the initial instant open
	sliding = true
	local tw = TweenService:Create(questsRoot, TWEEN, { Position = targetPos })
	tw.Completed:Connect(function()
		sliding = false
		-- toggled OFF: once the slide-out finishes, hide the inner Quests panel so it's fully invisible
		if not open then panel.Visible = false end
	end)
	tw:Play()
end

hideButton.MouseButton1Click:Connect(function()
	if sliding then return end
	setOpen(not isOpen)
end)

-- start open (the authored state; button already shows ">")
setOpen(true, true)

-- ===== request initial state =====
-- Ask the server for our quests now (and once more shortly after, in case GameRemotes/QuestManager
-- finished loading just after we did). The server also pushes on its own when it loads us.
QuestRequest:FireServer()
task.delay(2, function() QuestRequest:FireServer() end)
