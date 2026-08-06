-- RevealUIClient: wires the Hud.RevealButtons buttons (RevealAllButton / RevealOneButton) shown only
-- to the active seeker. Each button prompts a dev product; on a successful purchase the SERVER
-- (MatchManager) validates the buyer is an active seeker and fires RevealHiders back:
--   * to the buyer with mode="highlight" + a list of hider userIds -> we draw a red see-through
--     Highlight on each for the duration (same look as the seeker highlight hiders normally see).
--   * to each revealed hider with mode="revealed" -> we show a red warning banner that counts down,
--     play a sound, and highlight their own body so they know they've been exposed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RevealHiders = Remotes:WaitForChild("RevealHiders")
local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
local InRound = Remotes:WaitForChild("InRound")
local StateChanged = Remotes:WaitForChild("StateChanged")
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))
-- Before a Core purchase prompt opens on a gamepad, hand UI selection to the prompt so its OK/Cancel
-- are reachable (clears any game-owned gamepad selection). No-op on KBM/touch. See GamepadConfig.
local function prepGamepadPrompt() GamepadConfig.prepForCorePrompt() end

-- dev product IDs (match MatchManager)
local REVEAL_ALL_PRODUCT = 3604590604
local REVEAL_ONE_PRODUCT = 3604589435

-- Suppress the generic confetti "thank you" celebration for these products — the reveal has its own
-- on-screen banner, so the confetti would be redundant. PurchaseFX checks this set in its global
-- PromptProductPurchaseFinished handler.
local okFX, PurchaseFX = pcall(function()
	return require(player:WaitForChild("PlayerScripts"):WaitForChild("PurchaseFX", 5))
end)
if okFX and PurchaseFX and PurchaseFX.suppressProducts then
	PurchaseFX.suppressProducts[REVEAL_ALL_PRODUCT] = true
	PurchaseFX.suppressProducts[REVEAL_ONE_PRODUCT] = true
end

-- shared UI sound helper (click/hover sounds route through the SFX SoundGroup, like the other buttons)
local UISounds
pcall(function()
	UISounds = require(ReplicatedStorage:WaitForChild("UISounds", 5))
end)

local HIGHLIGHT_NAME = "RevealHighlight_Local"
local SOUND_LOOP_SECONDS = 9  -- loop the warning sound for this long while the banner is active

-- ===== button prompts + hover/press tween =====
-- tween a UIScale on each button (created at runtime if missing) so feedback never fights the
-- UIListLayout that positions the two buttons.
local HOVER_SCALE = 1.06   -- grow a touch on hover
local PRESS_SCALE = 0.93   -- dip on press
local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function getScale(btn)
	local s = btn:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Scale = 1
		s.Parent = btn
	end
	return s
end
local function tweenTo(btn, scale)
	TweenService:Create(getScale(btn), TWEEN_INFO, { Scale = scale }):Play()
end

local function bindButton(btn, productId)
	if not btn or not btn:IsA("GuiButton") then return end
	if btn:GetAttribute("RevealBound") then return end  -- already wired this instance
	btn:SetAttribute("RevealBound", true)
	btn.Active = true
	btn.AutoButtonColor = false  -- we handle feedback via the tween
	getScale(btn)                -- ensure a UIScale exists up front

	btn.MouseEnter:Connect(function()
		if UISounds then UISounds.play("hover") end
		tweenTo(btn, HOVER_SCALE)
	end)
	btn.MouseLeave:Connect(function() tweenTo(btn, 1) end)
	btn.MouseButton1Down:Connect(function() tweenTo(btn, PRESS_SCALE) end)
	btn.MouseButton1Up:Connect(function() tweenTo(btn, HOVER_SCALE) end)

	btn.MouseButton1Click:Connect(function()
		if UISounds then UISounds.click() end
		-- quick bounce on tap so touch users get feedback too
		tweenTo(btn, PRESS_SCALE)
		task.delay(0.1, function() tweenTo(btn, 1) end)
		MarketplaceService:PromptProductPurchase(player, productId)
	end)
end

-- ===== seeker-only button visibility + (re)binding =====
-- The buttons live in Hud.RevealButtons.{RevealAllButton,RevealOneButton} (the buttons ARE the
-- ImageButtons; their art is nested inside them). RevealButtons is a Frame inside the shared Hud
-- ScreenGui, so we toggle the FRAME's .Visible to show/hide just the reveal buttons (NOT the whole
-- Hud's .Enabled, which would hide the entire HUD). Shown only while the local player is an ACTIVE
-- seeker out in the round; hidden otherwise.
--
-- RESILIENCE: the Hud ScreenGui is ResetOnSpawn=false so it persists across the between-round
-- respawns. But if it's ever replaced, the old button references would be dead and clicks would stop
-- working. So instead of capturing the buttons ONCE at startup, we resolve + bind them through a
-- function that re-runs whenever a fresh Hud appears in PlayerGui. State (isSeeker / inRound / round)
-- lives at module scope so it survives a re-bind and the new copy shows correctly right away.
local isSeeker = false
local inRound = false
local roundActive = false  -- true only while the match state is ROUND (the seek phase). The reveal
                           -- buttons are only usable then; they hide the instant the round ends
                           -- (state -> RESOLVE / "round ended"), before InRound(false) even arrives.
local revealFrame  -- the Hud.RevealButtons frame currently wired

local function refreshVisible()
	if revealFrame and revealFrame.Parent then
		revealFrame.Visible = (isSeeker and inRound and roundActive)
	end
end

local function bindRevealUI(hud)
	if not hud then return end
	local frame = hud:FindFirstChild("RevealButtons")
	if not frame then return end
	revealFrame = frame
	bindButton(frame:FindFirstChild("RevealAllButton"), REVEAL_ALL_PRODUCT)
	bindButton(frame:FindFirstChild("RevealOneButton"), REVEAL_ONE_PRODUCT)
	refreshVisible()  -- apply current seeker/round state to this (possibly fresh) copy
end

-- bind the current Hud copy, and re-bind any future copy that gets added to PlayerGui
local existing = pg:FindFirstChild("Hud")
if existing then bindRevealUI(existing) end
pg.ChildAdded:Connect(function(child)
	if child.Name == "Hud" and child:IsA("ScreenGui") then
		task.defer(bindRevealUI, child)  -- defer so its descendants exist before we resolve them
	end
end)

RoleAnnounce.OnClientEvent:Connect(function(role)
	isSeeker = (role == "Seeker")
	refreshVisible()
end)
InRound.OnClientEvent:Connect(function(state)
	inRound = (state == true)
	if not inRound then isSeeker = false end  -- round over for us: hide until next seeker assignment
	refreshVisible()
end)
-- Hide the buttons the moment the seek phase ends. The server only sends InRound(false) at the START
-- of the NEXT round's intermission, so without this the buttons would linger through the RESOLVE /
-- "round ended" period. Tracking the match state lets us hide them immediately when state leaves ROUND.
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or data.state == nil then return end
	roundActive = (data.state == "ROUND")
	refreshVisible()
end)

-- ===== highlight helper (red, see-through walls) — matches SeekerHighlightClient's look =====
local function makeHighlight(char)
	if not char then return end
	local existing = char:FindFirstChild(HIGHLIGHT_NAME)
	if existing then existing:Destroy() end
	local hl = Instance.new("Highlight")
	hl.Name = HIGHLIGHT_NAME
	hl.FillColor = Color3.fromRGB(255, 0, 0)
	hl.FillTransparency = 0.5
	hl.OutlineColor = Color3.fromRGB(255, 0, 0)
	hl.OutlineTransparency = 0
	hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop  -- renders THROUGH walls
	hl.Adornee = char
	hl.Parent = char
	return hl
end
local function removeHighlight(char)
	if not char then return end
	local hl = char:FindFirstChild(HIGHLIGHT_NAME)
	if hl then hl:Destroy() end
end

-- ===== red "pointing down" arrow billboard (drawn above a highlighted hider, seeker's screen only) =====
local ARROW_NAME = "RevealArrow_Local"
-- Attach a red downward-pointing arrow that floats above the hider's head and bobs. Built from a
-- BillboardGui + TextLabel using the ▼ glyph so there's no image dependency; it renders through walls
-- (BillboardGui always draws on top) so the seeker can track the hider anywhere.
local function makeArrow(char)
	if not char then return end
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not head then return end
	local existing = head:FindFirstChild(ARROW_NAME)
	if existing then existing:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Name = ARROW_NAME
	bb.Size = UDim2.fromOffset(60, 60)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)  -- float above the head
	bb.AlwaysOnTop = true
	bb.MaxDistance = math.huge
	bb.LightInfluence = 0
	bb.Adornee = head
	bb.Parent = head

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.BackgroundTransparency = 1
	arrow.Text = "\u{25BC}"  -- ▼ solid down-pointing triangle
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.fromRGB(255, 0, 0)
	arrow.Font = Enum.Font.FredokaOne
	arrow.Parent = bb

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2
	stroke.Parent = arrow

	-- gentle bob so it draws the eye
	TweenService:Create(bb, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ StudsOffsetWorldSpace = Vector3.new(0, 5, 0) }):Play()
	return bb
end
local function removeArrow(char)
	if not char then return end
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if head then
		local a = head:FindFirstChild(ARROW_NAME)
		if a then a:Destroy() end
	end
end

-- Highlight a set of players (by userId) for `duration` seconds on THIS client (the buying seeker).
-- Each gets the red see-through Highlight AND a red downward arrow above their head. Re-applies if a
-- highlighted player respawns mid-reveal, and cleans up when the timer ends.
--
-- DEATH/CORPSE HANDLING: when a revealed hider is killed, the corpse system clones their body into a
-- ragdoll. A naive "find the arrow on target.Character at cleanup time" misses two cases: (a) the
-- clone copies the Head *and its child arrow*, leaving an orphaned arrow pointing at the corpse that
-- our cleanup never sees, and (b) target.Character may have changed/gone by cleanup. So instead of
-- re-finding the visuals, we TRACK every Highlight/arrow instance we create and destroy those exact
-- objects. We also tear them down the instant the hider dies (Humanoid.Died / character removal), so
-- the corpse clone is taken AFTER the arrow is gone and can never capture a copy of it.
local highlightToken = 0
local function highlightUsers(userIds, duration)
	highlightToken += 1
	local myToken = highlightToken
	local conns = {}
	local created = {}  -- every Highlight/BillboardGui instance we spawned, tracked for direct cleanup
	local dead = {}     -- [Player] = true once they've died this reveal; suppresses re-apply on respawn

	local function track(inst) if inst then created[#created + 1] = inst end end
	local function decorate(target, char)
		if not char then return end
		local hl = makeHighlight(char)
		local arrow = makeArrow(char)
		track(hl)
		track(arrow)
		-- The moment this character dies, destroy ITS tracked visuals directly. The corpse system moves
		-- the real Head (with our arrow) onto the ragdoll, so removing by instance — not by re-finding on
		-- the now-empty character — is what actually clears the arrow off the corpse right away. We also
		-- mark the target dead so the respawn re-apply below won't put the arrow back (a killed hider is
		-- out of the round, sent to the lobby, and is no longer a valid reveal target).
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			conns[#conns + 1] = hum.Died:Connect(function()
				if target then dead[target] = true end
				if hl then hl:Destroy() end
				if arrow then arrow:Destroy() end
				-- drop them from the tracked list so the end-of-window cleanup doesn't double-destroy
				for i = #created, 1, -1 do
					if created[i] == hl or created[i] == arrow then table.remove(created, i) end
				end
			end)
		end
	end

	local function cleanupAll()
		for _, c in ipairs(conns) do c:Disconnect() end
		table.clear(conns)
		-- destroy the exact instances we made, wherever they ended up (live char, corpse, nil parent)
		for _, inst in ipairs(created) do
			if inst then inst:Destroy() end
		end
		table.clear(created)
	end

	for _, uid in ipairs(userIds or {}) do
		local n = tonumber(uid)
		local target = n and Players:GetPlayerByUserId(n)
		if target then
			if target.Character then decorate(target, target.Character) end
			-- re-apply on a LEGITIMATE respawn during the reveal window (e.g. fell off the map), but NOT
			-- after a death — a killed hider is out of the round and should not be re-flagged.
			conns[#conns + 1] = target.CharacterAdded:Connect(function(char)
				if myToken == highlightToken and not dead[target] then
					task.wait(0.2)  -- let the Head assemble before adorning the arrow
					if myToken == highlightToken and not dead[target] then decorate(target, char) end
				end
			end)
		end
	end

	task.delay(duration or 10, function()
		if myToken ~= highlightToken then return end  -- a newer reveal superseded this one
		cleanupAll()
	end)
end

-- ===== red banner (shared) =====
-- Shown full-screen in red pixel font with a live (Ns) countdown. Used for BOTH:
--   * the revealed hider ("A SEEKER HAS REVEALED YOUR LOCATION!") — selfHighlight=true so they also
--     see the red wash on their own body, matching what the seeker sees.
--   * the buying seeker ("YOU REVEALED A HIDER" / "YOU REVEALED ALL HIDERS!") — selfHighlight=false
--     (the seeker highlights the HIDERS, not themself).
local PIXEL = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local warnGui = Instance.new("ScreenGui")
warnGui.Name = "RevealWarningGui"
warnGui.ResetOnSpawn = false
warnGui.IgnoreGuiInset = true
warnGui.DisplayOrder = 320  -- above the knife-notify toast (300) so the warning is never hidden
warnGui.Enabled = false
warnGui.Parent = pg

local warnLabel = Instance.new("TextLabel")
warnLabel.Name = "WarnLabel"
warnLabel.AnchorPoint = Vector2.new(0.5, 0)
warnLabel.Position = UDim2.new(0.5, 0, 0.30, 0)
warnLabel.Size = UDim2.new(0.7, 0, 0.06, 0)
warnLabel.BackgroundTransparency = 1
warnLabel.FontFace = PIXEL
warnLabel.TextScaled = true
warnLabel.TextColor3 = Color3.fromRGB(255, 40, 40)
warnLabel.Text = ""
warnLabel.Parent = warnGui

local warnStroke = Instance.new("UIStroke")
warnStroke.Color = Color3.fromRGB(0, 0, 0)
warnStroke.Thickness = 3
warnStroke.Parent = warnLabel

local warnSizeConstraint = Instance.new("UITextSizeConstraint")
warnSizeConstraint.MaxTextSize = 28
warnSizeConstraint.Parent = warnLabel

local warnToken = 0
local activeSound  -- the currently-looping warning sound clone (module scope so a new reveal can stop it)
local function stopActiveSound()
	if activeSound then
		pcall(function() activeSound:Stop() end)
		activeSound:Destroy()
		activeSound = nil
	end
end

-- Show the red countdown banner. messageFmt must contain a single %d for the remaining seconds.
-- selfHighlight: also red-highlight the local player's own body for the duration (for the hider).
local function showBanner(messageFmt, duration, selfHighlight)
	duration = duration or 10
	warnToken += 1
	local myToken = warnToken

	warnGui.Enabled = true

	-- Loop the warning sound for SOUND_LOOP_SECONDS while the banner is up. We clone the project's
	-- SoundService.WarningSound (so the asset/volume stays editable in one place), force Looped on the
	-- clone, and stop+destroy it when the loop window ends, the countdown finishes, or a NEWER reveal
	-- supersedes this one. stopActiveSound() first kills any sound still looping from a prior reveal so
	-- two never overlap. A non-looping clone would only play once; Looped keeps it going for the window.
	stopActiveSound()
	local template = SoundService:FindFirstChild("WarningSound")
	if template then
		local sound = template:Clone()
		sound.Looped = true
		sound.Parent = warnGui
		activeSound = sound
		pcall(function() sound:Play() end)
		task.delay(SOUND_LOOP_SECONDS, function()
			-- only stop if THIS reveal is still the active one (a newer reveal already replaced the sound)
			if myToken == warnToken and activeSound == sound then stopActiveSound() end
		end)
	end

	-- (revealed hider only) highlight their OWN body so they see what the seeker now sees
	local selfConn
	if selfHighlight then
		local function applySelf(char) if char and myToken == warnToken then makeHighlight(char) end end
		applySelf(player.Character)
		selfConn = player.CharacterAdded:Connect(applySelf)
	end

	-- live countdown ticking down each second
	task.spawn(function()
		for remaining = duration, 1, -1 do
			if myToken ~= warnToken then return end
			warnLabel.Text = string.format(messageFmt, remaining)
			-- gentle pulse each tick
			warnLabel.TextTransparency = 0
			TweenService:Create(warnLabel, TweenInfo.new(0.8), { TextTransparency = 0.15 }):Play()
			task.wait(1)
		end
		if myToken ~= warnToken then return end
		-- done: clean up
		warnGui.Enabled = false
		if selfConn then selfConn:Disconnect() end
		if selfHighlight then removeHighlight(player.Character) end
		stopActiveSound()
	end)
end

-- ===== server messages =====
RevealHiders.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.mode == "highlight" then
		highlightUsers(data.userIds, data.duration)
		-- seeker's own confirmation banner (no self-highlight — the hiders are highlighted, not the seeker)
		local msg = (data.revealMode == "all")
			and "YOU REVEALED ALL HIDERS! (%ds)"
			or "YOU REVEALED A HIDER (%ds)"
		showBanner(msg, data.duration, false)
	elseif data.mode == "revealed" then
		showBanner("A SEEKER HAS REVEALED YOUR LOCATION! (%ds)", data.duration, true)
	elseif data.mode == "paintbucket" then
		highlightUsers(data.userIds, data.duration)
		local msg = (data.revealMode == "all")
			and "PAINT BUCKET REVEALED NEARBY HIDERS! (%ds)"
			or "PAINT BUCKET REVEALED A HIDER! (%ds)"
		showBanner(msg, data.duration, false)
	end
end)

-- ===== gamepad bridges (Reveal One / Reveal All) =====
-- The on-screen buttons prompt the dev product directly in their click handlers. To let a controller
-- trigger the SAME action, we expose two BindableEvents the gamepad layer (GamepadGameplayClient) fires
-- on L1 / L2. Each self-gates to an active seeker in the seek phase — identical to the button gating
-- (the buttons are only VISIBLE then, and the server validates the buyer is an active seeker anyway) —
-- so a press does nothing out of context, exactly like the buttons.
local function promptReveal(productId)
	if not (isSeeker and inRound and roundActive) then return end
	if UISounds then pcall(function() UISounds.click() end) end
	prepGamepadPrompt()  -- clear game gamepad-selection so the prompt's own buttons are reachable
	MarketplaceService:PromptProductPurchase(player, productId)
end

local function ensureBridge(name)
	local evt = ReplicatedStorage:FindFirstChild(name)
	if not evt then
		evt = Instance.new("BindableEvent")
		evt.Name = name
		evt.Parent = ReplicatedStorage
	end
	return evt
end
ensureBridge("RevealOne").Event:Connect(function() promptReveal(REVEAL_ONE_PRODUCT) end)
ensureBridge("RevealAll").Event:Connect(function() promptReveal(REVEAL_ALL_PRODUCT) end)
