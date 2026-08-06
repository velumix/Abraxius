local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local TimerController = Knit.CreateController({
	Name = "TimerController",
})

local TYPE_DELAY = 0.045
local REVEAL_HOLD = 6
local REVEAL_SOUND = "rbxassetid://131039887376992"
local HUD_FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local GREEN = "70,180,95"
local RED = "220,70,70"
local WHITE = "255,255,255"

type MatchStateName = string
type CountdownMode = "HIDE" | "ROUND" | "REVEALING_HIDERS"
type RoleName = "Seeker" | "Hider"
type StatePayload = {
	state: MatchStateName?,
	timeLeft: number?,
	roundTimeLeft: number?,
	waiting: boolean?,
	activePlayers: number?,
	neededPlayers: number?,
	note: string?,
	rr: boolean?,
	hide: boolean?,
	announce: string?,
	timerTitle: string?,
	spectateActive: boolean?,
	voting: boolean?,
	voteSkipped: boolean?,
	upcomingEvent: string?,
}

local function rich(rgb: string, text: string | number): string
	return string.format('<font color="rgb(%s)">%s</font>', rgb, text)
end

local function fmt(t: number?): string
	t = math.max(0, math.floor(t or 0))
	return string.format("%d:%02d", math.floor(t / 60), t % 60)
end

function TimerController:KnitInit()
	self.player = Players.LocalPlayer
	self.remotes = ReplicatedStorage:WaitForChild("GameRemotes")
	self.stateChanged = self.remotes:WaitForChild("StateChanged")
	self.roleAnnounce = self.remotes:WaitForChild("RoleAnnounce")
	self.inRoundRemote = self.remotes:WaitForChild("InRound")
	self.hidersLeftRemote = self.remotes:WaitForChild("HidersLeft")

	self.currentState = nil
	self.waitingShown = nil
	self.mapLoading = false
	self.myRole = nil
	self.inRound = false
	self.lastHiderCount = 0
	self.seekPhaseActive = false
	self.bossActive = false
	self.timerTextVisible = true
	self.countdownMode = nil
	self.countdownDeadline = nil
	self.rrDeadline = nil
	self.rrTitle = "Time"
	self.typeToken = 0
	self.typingActive = false
	self.blackScreenMusic = nil
	self.lastTickSecond = nil
	self.eventHandoffDeadline = nil
end

function TimerController:KnitStart()
	self:setupGui()
	self:setupSounds()
	self:bindEvents()
	self:startCountdownLoop()
	self:showWaitingFallback()
	self:requestStateSync()

	print("[TimerController] ready (top layout timer)")
end

function TimerController:setupGui(): ()
	local playerGui = self.player:WaitForChild("PlayerGui")
	self.hud = playerGui:WaitForChild("Hud")
	self.holder = self.hud:WaitForChild("Main"):WaitForChild("Top"):WaitForChild("Timer")
	self.announce = self.holder:WaitForChild("Announce")
	self.timer = self.holder:WaitForChild("Timer")
	self.holderManagesLabelLayout = self.holder:FindFirstChildOfClass("UIListLayout") ~= nil

	self.hidersLabel = self.holder:FindFirstChild("HidersLeftLabel")
	if not self.hidersLabel then
		self.hidersLabel = Instance.new("TextLabel")
		self.hidersLabel.Name = "HidersLeftLabel"
		self.hidersLabel.BackgroundTransparency = 1
		self.hidersLabel.AnchorPoint = Vector2.new(0.5, 0)
		self.hidersLabel.Position = UDim2.new(0.5, 0, 0, 114)
		self.hidersLabel.Size = UDim2.new(1, 0, 0, 30)
		self.hidersLabel.RichText = true
		self.hidersLabel.Text = ""
		self.hidersLabel.Visible = false
		self.hidersLabel.ZIndex = 3
		self.hidersLabel.Parent = self.holder
	end

	local roleGui = playerGui:WaitForChild("RoleNotifGui")
	self.black = roleGui:WaitForChild("RevealBlack")

	self.revealText = self.black:FindFirstChild("RevealText")
	if not self.revealText then
		local lbl = Instance.new("TextLabel")
		lbl.Name = "RevealText"
		lbl.AnchorPoint = Vector2.new(0.5, 0.5)
		lbl.Position = UDim2.new(0.5, 0, 0.5, 0)
		lbl.Size = UDim2.new(0.8, 0, 0.25, 0)
		lbl.BackgroundTransparency = 1
		lbl.RichText = true
		lbl.TextScaled = true
		lbl.TextWrapped = true
		lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		lbl.TextTransparency = 1
		lbl.Text = ""
		lbl.ZIndex = 20
		lbl.FontFace = HUD_FONT
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(0, 0, 0)
		stroke.Thickness = 3
		stroke.Parent = lbl
		local sizeConstraint = Instance.new("UITextSizeConstraint")
		sizeConstraint.MaxTextSize = 48
		sizeConstraint.Parent = lbl
		lbl.Parent = self.black
		self.revealText = lbl
	end

	self:refreshBossActive()
	self:syncTimerStyle()
	self:updateTextSize()
	self:refreshHolderVisibility()
end

function TimerController:setupSounds(): ()
	local typingTemplate = SoundService:FindFirstChild("Typing")
	if typingTemplate then
		self.typingSound = typingTemplate:Clone()
	else
		self.typingSound = Instance.new("Sound")
		self.typingSound.SoundId = "rbxassetid://121687622702082"
		local sfx = SoundService:FindFirstChild("SFX")
		if sfx then
			self.typingSound.SoundGroup = sfx
		end
	end
	self.typingSound.Looped = true
	self.typingSound.Parent = SoundService
	ContentProvider:PreloadAsync({ self.typingSound })

	local countdownTemplate = SoundService:FindFirstChild("CountdownTick")
	if countdownTemplate then
		self.countdownTick = countdownTemplate:Clone()
		local sfx = SoundService:FindFirstChild("SFX")
		if sfx then
			self.countdownTick.SoundGroup = sfx
		end
		self.countdownTick.Looped = false
		self.countdownTick.Parent = SoundService
	end

	-- Dedicated clock tick for the HIDE-phase 3/2/1 countdown (same sound Reverse Race plays for its
	-- hide countdown, so both modes match). The intermission countdown keeps its own CountdownTick above.
	self.hideCountdownTick = Instance.new("Sound")
	self.hideCountdownTick.SoundId = "rbxassetid://134410911353980"
	self.hideCountdownTick.Looped = false
	do
		local sfx = SoundService:FindFirstChild("SFX")
		if sfx then
			self.hideCountdownTick.SoundGroup = sfx
		end
	end
	self.hideCountdownTick.Parent = SoundService
end

function TimerController:bindEvents(): ()
	self.hidersLeftRemote.OnClientEvent:Connect(function(n: number)
		self.lastHiderCount = tonumber(n) or 0
		self:refreshHidersLabel()
	end)

	self.roleAnnounce.OnClientEvent:Connect(function(role: RoleName)
		self.myRole = role
		self:refreshHidersLabel()
	end)

	self.inRoundRemote.OnClientEvent:Connect(function(active: boolean?)
		self.inRound = active and true or false
		if not self.inRound then
			self.myRole = nil
		end
		self:refreshHidersLabel()
	end)

	self.hud.ChildAdded:Connect(function(child: Instance)
		if child.Name == "PaintingBossActive" then
			child.Changed:Connect(function()
				self:refreshBossActive()
			end)
			self:refreshBossActive()
		end
	end)

	local activeValue = self.hud:FindFirstChild("PaintingBossActive")
	if activeValue then
		activeValue.Changed:Connect(function()
			self:refreshBossActive()
		end)
	end

	self.announce:GetPropertyChangedSignal("FontFace"):Connect(function()
		self:syncTimerStyle()
	end)
	self.announce:GetPropertyChangedSignal("TextSize"):Connect(function()
		self:syncTimerStyle()
	end)
	self.announce:GetPropertyChangedSignal("TextScaled"):Connect(function()
		self:syncTimerStyle()
	end)

	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			self:updateTextSize()
		end)
	end

	self.stateChanged.OnClientEvent:Connect(function(data: unknown)
		self:onStateChanged(data)
	end)

	Players.PlayerAdded:Connect(function()
		task.defer(function()
			self:requestStateSync()
		end)
	end)

	Players.PlayerRemoving:Connect(function()
		task.defer(function()
			self:requestStateSync()
		end)
	end)
end

function TimerController:refreshBossActive(): ()
	local activeValue = self.hud and self.hud:FindFirstChild("PaintingBossActive")
	self.bossActive = activeValue and activeValue.Value or false
	if self.hidersLabel then
		self:refreshHidersLabel()
	end
end

function TimerController:refreshHolderVisibility(): ()
	self.holder.Visible = self.announce.Visible
		or self.timer.Visible
		or (self.hidersLabel and self.hidersLabel.Visible)
		or false
end

function TimerController:setAnnounceText(text: string?): ()
	self.announce.Text = text or ""
	self.announce.Visible = self.announce.Text ~= ""
	self:refreshHolderVisibility()
end

function TimerController:setTimerText(text: string?, showWhenText: boolean?): ()
	self.timer.Text = text or ""
	self.timer.Visible = self.timer.Text ~= "" and showWhenText ~= false
	self:refreshHolderVisibility()
end

function TimerController:syncTimerStyle(): ()
	self.announce.FontFace = HUD_FONT
	self.timer.FontFace = HUD_FONT
	self.timer.TextSize = self.announce.TextSize
	self.timer.TextScaled = self.announce.TextScaled
	self.timer.TextWrapped = self.announce.TextWrapped
	self.timer.TextStrokeTransparency = self.announce.TextStrokeTransparency
	self.timer.TextStrokeColor3 = self.announce.TextStrokeColor3
	self.timer.LineHeight = self.announce.LineHeight

	self.hidersLabel.FontFace = HUD_FONT
	self.hidersLabel.TextSize = self.announce.TextSize
	self.hidersLabel.TextScaled = self.announce.TextScaled
	self.hidersLabel.TextWrapped = self.announce.TextWrapped
	self.hidersLabel.TextStrokeTransparency = self.announce.TextStrokeTransparency
	self.hidersLabel.TextStrokeColor3 = self.announce.TextStrokeColor3
end

function TimerController:updateTextSize(): ()
	local camera = Workspace.CurrentCamera
	if not camera then return end

	self.baseTextSize = self.baseTextSize or self.announce.TextSize
	local factor = math.clamp(camera.ViewportSize.X / 1280, 0.55, 1)
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local emulatingTouch = RunService:IsStudio() and UserInputService.TouchEnabled
	local isMobile = touchOnly or emulatingTouch

	if isMobile then
		factor = math.min(factor, 0.62)
	end

	self.announce.TextSize = math.max(10, math.floor(self.baseTextSize * factor))
	self:syncTimerStyle()

	if self.holderManagesLabelLayout then
		return
	end

	if isMobile then
		self.timer.Position = UDim2.new(0.5, 0, 0, 40)
		self.hidersLabel.Position = UDim2.new(0.5, 0, 0, 70)
	else
		self.timer.Position = UDim2.new(0.5, 0, 0, 78)
		self.hidersLabel.Position = UDim2.new(0.5, 0, 0, 114)
	end
end

function TimerController:refreshHidersLabel(): ()
	if not self.bossActive and self.seekPhaseActive and self.lastHiderCount > 0 then
		self.hidersLabel.Text = rich(GREEN, "Hiders") .. rich(RED, " Left: ") .. rich(WHITE, tostring(self.lastHiderCount))
		self.hidersLabel.Visible = true
	else
		self.hidersLabel.Visible = false
	end
	self:refreshHolderVisibility()
end

function TimerController:playRevealSound(): ()
	local sound = Instance.new("Sound")
	sound.SoundId = REVEAL_SOUND
	sound.Volume = 1
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then
		sound.SoundGroup = sfx
	end
	sound.Parent = SoundService
	sound:Play()
	task.delay((sound.TimeLength > 0 and sound.TimeLength or 5) + 0.2, function()
		if sound then
			sound:Destroy()
		end
	end)
end

function TimerController:playCountdownTick(secondsLeft: number, sound: Sound?): ()
	sound = sound or self.countdownTick
	if not sound or self.lastTickSecond == secondsLeft then
		return
	end
	self.lastTickSecond = secondsLeft
	sound:Stop()
	sound.TimePosition = 0
	sound:Play()
end

function TimerController:stopBlackScreenMusic(fadeTime: number?): ()
	local sound = self.blackScreenMusic
	self.blackScreenMusic = nil
	if not sound then return end

	if fadeTime and fadeTime > 0 and sound.IsPlaying then
		TweenService:Create(sound, TweenInfo.new(fadeTime), { Volume = 0 }):Play()
		task.delay(fadeTime + 0.05, function()
			if sound then
				sound:Destroy()
			end
		end)
	else
		sound:Destroy()
	end
end

function TimerController:playBlackScreenMusic(): ()
	self:stopBlackScreenMusic(0)
	local folder = SoundService:FindFirstChild("DuringBlackScreen")
	local template = folder and folder:FindFirstChild("Track1")
	if not template then return end

	local sound = template:Clone()
	local music = SoundService:FindFirstChild("Music")
	if music then
		sound.SoundGroup = music
	end
	sound.Parent = SoundService
	self.blackScreenMusic = sound
	sound:Play()
end

function TimerController:setResetEnabled(_enabled: boolean): ()
end

function TimerController:hideAnnounce(role: RoleName): (string, string)
	if role == "Seeker" then
		return "You are a Seeker. Get ready to hunt!",
			"You are a " .. rich(RED, "Seeker") .. ". Get ready to hunt!"
	end
	return "You are a Hider. Quickly find a spot to hide!",
		"You are a " .. rich(GREEN, "Hider") .. ". Quickly find a spot to hide!"
end

function TimerController:timerLine(role: RoleName, timeLeft: number): string
	local label = (role == "Seeker") and "Time Until You're Released: " or "Time Until Seeker Arrives: "
	return rich(RED, label) .. rich(WHITE, fmt(timeLeft))
end

function TimerController:intermissionAnnounce(): (string, string)
	return "Next round starting soon... Get ready!",
		rich(WHITE, "Next round starting soon... ") .. rich(GREEN, "Get ready!")
end

function TimerController:waitingAnnounce(): (string, string)
	return "Waiting for more players to join...",
		rich(WHITE, "Waiting for more players to join...")
end

function TimerController:roundTimerLine(timeLeft: number): string
	return rich(RED, "Round Ends In: ") .. rich(WHITE, fmt(timeLeft))
end

function TimerController:isTyping(): boolean
	return self.typingActive
end

function TimerController:typeOut(
	plainText: string,
	finalRich: string,
	onDone: (() -> ())?,
	showTimerWhenDone: boolean?,
	delayOverride: number?
): ()
	if showTimerWhenDone == nil then
		showTimerWhenDone = true
	end

	self.typeToken += 1
	local token = self.typeToken
	self.typingActive = true
	self.announce.RichText = false
	self:setAnnounceText("")
	self.timer.Visible = false
	self:refreshHolderVisibility()

	self.typingSound.TimePosition = 0
	self.typingSound:Play()
	for i = 1, #plainText do
		if token ~= self.typeToken then return end
		self:setAnnounceText(string.sub(plainText, 1, i))
		task.wait(delayOverride or TYPE_DELAY)
	end

	self.typingSound:Stop()
	if token ~= self.typeToken then return end
	self.announce.RichText = true
	self:setAnnounceText(finalRich)
	self.typingActive = false

	if showTimerWhenDone and self.timer.Text ~= "" then
		self.timer.Visible = true
		self:refreshHolderVisibility()
	end
	if onDone then
		onDone()
	end
end

function TimerController:cancelTyping(): ()
	self.typeToken += 1
	self.typingActive = false
	self.typingSound:Stop()
end

function TimerController:stopLocalCountdown(): ()
	self.countdownMode = nil
	self.countdownDeadline = nil
end

function TimerController:startLocalCountdown(mode: CountdownMode, timeLeft: number?): ()
	if type(timeLeft) ~= "number" then
		return
	end
	self.countdownMode = mode
	self.countdownDeadline = os.clock() + math.max(0, timeLeft)
end

function TimerController:startCountdownLoop(): ()
	RunService.Heartbeat:Connect(function()
		self:refreshLocalCountdown()
	end)
end

function TimerController:refreshLocalCountdown(): ()
	if self.rrDeadline then
		local left = self.rrDeadline - os.clock()
		if left <= 0 then
			self.rrDeadline = nil
			self:setTimerText("")
		else
			self:setTimerText(rich(RED, self.rrTitle .. ": ") .. rich(WHITE, fmt(left)), self.timerTextVisible)
		end
	end

	if not self.countdownMode or not self.countdownDeadline then
		return
	end

	local left = math.max(0, math.ceil(self.countdownDeadline - os.clock()))
	if self.countdownMode == "HIDE" then
		if self.myRole and not self.bossActive then
			self:setTimerText(self:timerLine(self.myRole, left), self.timerTextVisible)
		end
	elseif self.countdownMode == "ROUND" then
		if not self.bossActive then
			self:setTimerText(self:roundTimerLine(left), true)
		end
	elseif self.countdownMode == "REVEALING_HIDERS" then
		self:setTimerText(rich(RED, "Reveal Ends In: ") .. rich(WHITE, fmt(left)), true)
	end

	if left <= 0 then
		self:stopLocalCountdown()
	end
end

function TimerController:showWaitingFallback(): ()
	if self.currentState ~= nil and self.waitingShown ~= true then
		return
	end
	self.holder.Visible = true
	self.announce.RichText = true
	local _, waitingRich = self:waitingAnnounce()
	self:setAnnounceText(waitingRich)
	self.timer.RichText = true
	self:setTimerText(rich(RED, "Waiting for players..."), true)
end

function TimerController:startHideReveal(): ()
	if not self.inRound or not self.myRole then
		self.holder.Visible = false
		self.black.Visible = false
		return
	end

	self.timerTextVisible = false
	self.holder.Visible = true
	self.black.Visible = true
	self.black.BackgroundTransparency = 1
	local plain, final = self:hideAnnounce(self.myRole)
	if self.revealText then
		self.revealText.Text = final
		self.revealText.TextTransparency = 1
	end
	TweenService:Create(self.black, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	if self.revealText then
		TweenService:Create(self.revealText, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end
	self:setResetEnabled(false)
	self:playRevealSound()
	self:playBlackScreenMusic()

	task.spawn(function()
		self:typeOut(plain, final, nil, false, TYPE_DELAY / 1.15)
	end)

	task.delay(REVEAL_HOLD, function()
		self:setResetEnabled(true)
		local fade = TweenService:Create(self.black, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		fade:Play()
		if self.revealText then
			TweenService:Create(self.revealText, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
		self:stopBlackScreenMusic(0.5)
		fade.Completed:Connect(function()
			self.black.Visible = false
			if self.revealText then
				self.revealText.Text = ""
			end
			self.timerTextVisible = true
			if self.timer.Text ~= "" then
				self.timer.Visible = true
				self:refreshHolderVisibility()
			end
		end)
	end)
end

function TimerController:startRRReveal(message: string): ()
	self.timerTextVisible = false
	self.holder.Visible = true
	self.black.Visible = true
	self.black.BackgroundTransparency = 1
	if self.revealText then
		self.revealText.Text = message
		self.revealText.TextTransparency = 1
	end
	TweenService:Create(self.black, TweenInfo.new(0.3), { BackgroundTransparency = 0 }):Play()
	if self.revealText then
		TweenService:Create(self.revealText, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
	end
	self:setResetEnabled(false)
	self:playRevealSound()
	self:playBlackScreenMusic()

	task.delay(REVEAL_HOLD, function()
		self:setResetEnabled(true)
		local fade = TweenService:Create(self.black, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		fade:Play()
		if self.revealText then
			TweenService:Create(self.revealText, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
		self:stopBlackScreenMusic(0.5)
		fade.Completed:Connect(function()
			self.black.Visible = false
			if self.revealText then
				self.revealText.Text = ""
			end
			self.timerTextVisible = true
			if self.timer.Text ~= "" then
				self.timer.Visible = true
				self:refreshHolderVisibility()
			end
		end)
	end)
end

function TimerController:startIntermission(): ()
	self.timerTextVisible = true
	self.holder.Visible = true
	local plain, final = self:intermissionAnnounce()
	task.spawn(function()
		self:typeOut(plain, final)
	end)
end

function TimerController:startRound(): ()
	self.timerTextVisible = true
	self.holder.Visible = true
	self:cancelTyping()
	self:setAnnounceText("")
end

function TimerController:requestStateSync(): ()
	self.stateChanged:FireServer("sync")
end

function TimerController:onStateChanged(data: unknown): ()
	if type(data) ~= "table" then return end
	local payload = data :: StatePayload
	local now = os.clock()

	-- MatchManager can continue broadcasting its normal waiting/intermission state while the mode
	-- orchestrator announces an event takeover. Keep that handoff visible for its countdown instead
	-- of allowing the next routine intermission packet to erase it.
	if payload.voteSkipped and payload.upcomingEvent then
		self.eventHandoffDeadline = now + math.max(0, payload.timeLeft or 0)
	elseif self.eventHandoffDeadline then
		if payload.state == "INTERMISSION" and now < self.eventHandoffDeadline then
			return
		end
		self.eventHandoffDeadline = nil
	end

	-- While a Reverse Race phase is live on screen, drop any NON-rr StateChanged: during Reverse Race
	-- the regular-mode MatchManager isn't the active driver, so a state it answers (e.g. a sync when
	-- another player joins/leaves) is STALE and would clobber the RR banner/timer with a leftover
	-- intermission ("Next round starting soon"). The real RR -> intermission handoff arrives first as an
	-- rr=true hide payload (handled below, which resets currentState), so this only discards stale syncs.
	if not payload.rr and type(self.currentState) == "string" and string.sub(self.currentState, 1, 3) == "RR_" then
		return
	end

	if self:handleReverseRace(payload) then
		return
	end

	-- A round is ongoing and this client isn't in it -> lobby "Round active" banner.
	if payload.spectateActive then
		self:handleRoundActive()
		return
	end

	local state = payload.state
	self.seekPhaseActive = state == "ROUND"
	self:refreshHidersLabel()

	if (state == "HIDE" or state == "ROUND") and not self.inRound then
		self:handleSpectatingRound(payload)
		return
	end

	if state == "HIDE" then
		self:handleHide(payload)
	elseif state == "INTERMISSION" then
		self:handleIntermission(payload)
	elseif state == "ROUND" then
		self:handleRound(payload)
	elseif state == "REVEALING_HIDERS" then
		self:handleRevealingHiders(payload)
	elseif state == "RESOLVE" then
		self:handleResolve()
	else
		self:handleUnknownState(state)
	end
end

function TimerController:handleReverseRace(data: StatePayload): boolean
	if not data.rr then
		self.rrDeadline = nil
		return false
	end

	self:stopLocalCountdown()

	if data.hide then
		self.currentState = nil
		self.rrDeadline = nil
		self:cancelTyping()
		self:setAnnounceText("")
		self:setTimerText("")
		self.black.Visible = false
		self.black.BackgroundTransparency = 1
		self.holder.Visible = false
		self:stopBlackScreenMusic(0)
		return true
	end

	local rrState = "RR_" .. tostring(data.state)
	if self.currentState ~= rrState then
		self.currentState = rrState
		self:cancelTyping()
		self:stopBlackScreenMusic(0)
		self:setAnnounceText("")  -- drop any stale intermission/matchmaking announce carried in from before the RR round

		if data.state == "HIDE" and data.announce and data.announce ~= "" then
			self.holder.Visible = true
			self:startRRReveal(data.announce)
		else
			self.black.Visible = false
			self.black.BackgroundTransparency = 1
			self.holder.Visible = true

			if data.announce and data.announce ~= "" then
				local final = data.announce
				local plain = final:gsub("<[^>]->", "")
				task.spawn(function()
					self:typeOut(plain, final)
				end)
			else
				self.announce.RichText = true
				self:setAnnounceText("")
			end
		end
	end

	self.holder.Visible = true
	self.rrTitle = data.timerTitle or "Time"
	if data.timeLeft and data.timeLeft > 0 then
		self.rrDeadline = os.clock() + data.timeLeft
		self:setTimerText(rich(RED, self.rrTitle .. ": ") .. rich(WHITE, fmt(data.timeLeft)), self.timerTextVisible)
	else
		self.rrDeadline = nil
		self:setTimerText("")
	end

	return true
end

function TimerController:handleRoundActive(): ()
	self:stopLocalCountdown()
	self.rrDeadline = nil
	if self.currentState ~= "ROUND_ACTIVE" then
		self.currentState = "ROUND_ACTIVE"
		self:cancelTyping()
		self.black.Visible = false
		self.black.BackgroundTransparency = 1
		self:stopBlackScreenMusic(0)
		self.announce.RichText = true
		self:setAnnounceText(rich(RED, "Round active"))
	end
	self:setTimerText("")
	self.holder.Visible = true
end

function TimerController:handleSpectatingRound(data: StatePayload): ()
	self.timerTextVisible = true
	self:stopLocalCountdown()
	self:setResetEnabled(true)

	if self.currentState ~= "WATCHING" then
		self.currentState = "WATCHING"
		self:cancelTyping()
		self.black.Visible = false
		self.black.BackgroundTransparency = 1
		self.holder.Visible = true
		self:stopBlackScreenMusic(0)
		self.announce.RichText = true
		local text = if self.bossActive then rich(WHITE, "Defeat the ") .. rich(RED, "Paint Boss!") else rich(RED, "Round active")
		self:setAnnounceText(text)
	end

	if not self.bossActive then
		local totalLeft = data.roundTimeLeft or data.timeLeft
		if totalLeft ~= nil then
			self:setTimerText(rich(RED, "Time Left: ") .. rich(WHITE, fmt(totalLeft)), true)
		end
	end
end

function TimerController:handleHide(data: StatePayload): ()
	if self.currentState ~= "HIDE" then
		self.currentState = "HIDE"
		self:startHideReveal()
	end

	if data.timeLeft ~= nil and self.myRole and not self.bossActive then
		self:startLocalCountdown("HIDE", data.timeLeft)
		self:setTimerText(self:timerLine(self.myRole, data.timeLeft), self.timerTextVisible)
		-- 3 / 2 / 1 hide countdown clock tick so the final seconds of hiding get an audible countdown
		-- (matches Reverse Race, which plays the same clock sound server-driven).
		if data.timeLeft >= 1 and data.timeLeft <= 3 then
			self:playCountdownTick(data.timeLeft, self.hideCountdownTick)
		end
	end
end

function TimerController:handleIntermission(data: StatePayload): ()
	self.timerTextVisible = true
	self:stopLocalCountdown()

	if self.currentState ~= "INTERMISSION" then
		self.currentState = "INTERMISSION"
		self.waitingShown = nil
		self.lastTickSecond = nil
		self.mapLoading = false
	end

	-- A full-round event can replace the mode vote. Give players a short, explicit handoff instead
	-- of making the voting card silently disappear.
	if data.voteSkipped and data.upcomingEvent then
		self.mapLoading = false
		self.waitingShown = nil
		self.holder.Visible = true
		self:cancelTyping()
		self.announce.RichText = true
		self:setAnnounceText(
			rich(WHITE, "Mode vote skipped — ") .. rich(RED, data.upcomingEvent) .. rich(WHITE, " is taking over!")
		)
		if data.timeLeft ~= nil then
			self:setTimerText(rich(RED, data.upcomingEvent .. " Starts In: ") .. rich(WHITE, fmt(data.timeLeft)), true)
		else
			self:setTimerText(rich(RED, data.upcomingEvent .. " incoming!"), true)
		end
		return
	end

	-- Game-mode vote window (orchestrator): a clear "Voting for game mode" banner + vote countdown.
	if data.voting then
		self.mapLoading = false
		self.waitingShown = nil
		self.holder.Visible = true
		self:cancelTyping()
		self.announce.RichText = true
		self:setAnnounceText(rich(WHITE, "Voting for game mode..."))
		if data.timeLeft ~= nil then
			self:setTimerText(rich(RED, "Vote ends in: ") .. rich(WHITE, fmt(data.timeLeft)), true)
		else
			self:setTimerText("")
		end
		return
	end

	if data.note == "loading map" then
		self.mapLoading = true
	end

	self:setResetEnabled(not self.mapLoading)
	if data.waiting and self.waitingShown ~= true then
		self.waitingShown = true
		self.holder.Visible = true
		local plain, final = self:waitingAnnounce()
		task.spawn(function()
			self:typeOut(plain, final)
		end)
	elseif not data.waiting and self.waitingShown ~= false then
		self.waitingShown = false
		self:startIntermission()
	end

	self.holder.Visible = true
	if self.announce.Text == "" and not self:isTyping() then
		self.announce.RichText = true
		self:setAnnounceText(rich(WHITE, "Intermission..."))
	end

	if data.waiting then
		local active = data.activePlayers or 0
		local needed = data.neededPlayers or 0
		self:setTimerText(rich(RED, "Waiting for players... ") .. rich(WHITE, active .. "/" .. needed), true)
	elseif self.mapLoading then
		self:setTimerText(rich(WHITE, "Selecting map..."), true)
	elseif data.timeLeft ~= nil then
		self:setTimerText(rich(RED, "Round Starts In: ") .. rich(WHITE, fmt(data.timeLeft)), true)
		if data.timeLeft >= 1 and data.timeLeft <= 3 then
			self:playCountdownTick(data.timeLeft)
		end
	else
		self:setTimerText("")
	end
end

function TimerController:handleRound(data: StatePayload): ()
	self.timerTextVisible = true
	self:setResetEnabled(true)

	if self.currentState ~= "ROUND" then
		self.currentState = "ROUND"
		self:startRound()
	end

	if data.timeLeft ~= nil and not self.bossActive then
		self:startLocalCountdown("ROUND", data.timeLeft)
		self:setTimerText(self:roundTimerLine(data.timeLeft), true)
	end
end

function TimerController:handleRevealingHiders(data: StatePayload): ()
	self.timerTextVisible = true
	self:setResetEnabled(true)

	if self.currentState ~= "REVEALING_HIDERS" then
		self.currentState = "REVEALING_HIDERS"
		self:cancelTyping()
		self.black.Visible = false
		self.black.BackgroundTransparency = 1
		self.holder.Visible = true
		self.announce.RichText = true
		self:setAnnounceText(rich(WHITE, "Hiders Revealed!"))
		self:stopBlackScreenMusic(0)
	end

	self.holder.Visible = true
	if data.timeLeft ~= nil then
		self:startLocalCountdown("REVEALING_HIDERS", data.timeLeft)
		self:setTimerText(rich(RED, "Reveal Ends In: ") .. rich(WHITE, fmt(data.timeLeft)), true)
	end
end

function TimerController:handleResolve(): ()
	self.timerTextVisible = true
	self:stopLocalCountdown()
	self:setResetEnabled(true)

	if self.currentState ~= "RESOLVE" then
		self.currentState = "RESOLVE"
		self:cancelTyping()
		self.black.Visible = false
		self.black.BackgroundTransparency = 1
		self.holder.Visible = true
		self.announce.RichText = true
		self:setAnnounceText(rich(WHITE, "Round Ended."))
		self:stopBlackScreenMusic(0)
	end

	self.holder.Visible = true
	self:setTimerText("")
	if self.announce.Text == "" and not self:isTyping() then
		self.announce.RichText = true
		self:setAnnounceText(rich(WHITE, "Round Ended."))
	end
end

function TimerController:handleUnknownState(state: MatchStateName?): ()
	self.timerTextVisible = true
	self:stopLocalCountdown()
	self:setResetEnabled(true)

	if self.currentState == "HIDE" or self.currentState == "INTERMISSION" then
		self:cancelTyping()
	end

	self.currentState = state
	self.holder.Visible = true
	self:setAnnounceText("")
	self:setTimerText("")
	self.black.Visible = false
	self.black.BackgroundTransparency = 1
	self:stopBlackScreenMusic(0)
end

return TimerController
