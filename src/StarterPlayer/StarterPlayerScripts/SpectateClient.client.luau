-- SpectateClient: a functional spectate camera. A lobby player opens it from the HUD
-- Spectate button; it points their camera at in-round players and lets them cycle
-- through them with Prev / Next, or Exit back to their own view. Also used when the
-- server tells an eliminated player to spectate.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local SpectateEvent = Remotes:WaitForChild("Spectate")
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))
local RoleMap = Remotes:WaitForChild("RoleMap")
local RequestRoleMap = Remotes:WaitForChild("RequestRoleMap")

-- role colors for the label
local HIDER_COLOR = "70,180,95"
local SEEKER_COLOR = "220,70,70"
local roleByUserId = {}  -- [userId] = "Hider" | "Seeker"
RoleMap.OnClientEvent:Connect(function(map)
	-- Remotes convert numeric table keys to STRINGS in transit, so the server's roleMap[userId]
	-- (number key) arrives here with string keys. Normalize back to number keys so lookups by
	-- p.UserId (a number) work correctly.
	roleByUserId = {}
	if type(map) == "table" then
		for k, v in pairs(map) do
			roleByUserId[tonumber(k) or k] = v
		end
	end
end)

local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("SpectateGui")
local nameLabel = gui:WaitForChild("NowSpectating")
nameLabel.RichText = true
local controls = gui:WaitForChild("Controls")
local prevBtn = controls:WaitForChild("Prev")
local nextBtn = controls:WaitForChild("Next")
local exitBtn = controls:WaitForChild("Exit")

-- ===== Responsive scaling (mobile/tablet) =====
-- The Controls bar is a fixed 400px wide with three fixed-size buttons; on a phone that's most of
-- the screen width and can crowd the on-screen jump button. Shrink the whole bar uniformly with a
-- UIScale on small/touch screens (desktop stays full size). Same pattern as the paint/pose UI.
local CONTROLS_W = 400
local controlsScale = Instance.new("UIScale")
controlsScale.Parent = controls
local function updateSpectateScale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	-- keep the bar within ~70% of screen width; never upscale past 1
	local scale = math.min(1, (vp.X * 0.7) / CONTROLS_W)
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		scale = math.min(scale, 0.8)  -- a touch smaller on phones/tablets
	end
	controlsScale.Scale = math.max(0.5, scale)
end
updateSpectateScale()
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateSpectateScale)
end

local camera = workspace.CurrentCamera
local spectating = false
local isForced = false  -- true for a server-forced spectate (out-of-lives hunter): the player can't exit it
-- Spectating is BLOCKED during the HIDE phase. Exploit it closes: a hider who dies/resets during the
-- 30s head start becomes a lobby spectator, and the Join-As-Seeker offer is (by design) deferred to
-- the SEEK phase -- so without this they could spectate hiders' hiding spots during HIDE and then
-- join as seeker with that intel. While blocked, opening spectate is refused and any active spectate
-- is force-stopped. Updated from the server's StateChanged broadcasts (see the handler near the end).
local spectateBlocked = false
local targets = {}      -- list of players we can watch
local index = 1
local renderConn = nil

-- ===== free-orbit camera state =====
-- While spectating, the player can drag to orbit around the target and scroll/pinch to zoom.
local orbitYaw = 0           -- horizontal angle (radians) around the target
local orbitPitch = 0.25      -- vertical angle (radians); slightly above the target by default
local orbitDist = 14         -- distance from the target
local MIN_PITCH, MAX_PITCH = -1.3, 1.3   -- clamp so the camera can't flip over the poles
local MIN_DIST, MAX_DIST = 6, 40
local ROT_SPEED = 0.006      -- mouse drag sensitivity (radians per pixel)
local TOUCH_ROT_SPEED = 0.012
local GP_ROT_SPEED = 2.5     -- gamepad right-stick orbit speed (radians per second at full deflection)
local ZOOM_STEP = 3          -- studs per scroll notch
local dragging = false
local inputConns = {}        -- orbit input connections, cleared on stop

-- build the list of players we can spectate: ONLY SEEKERS currently in the round, never hiders and
-- never lobby players. roleByUserId comes from the server's RoleMap remote, which contains exactly
-- the in-round players and is cleared to {} when the round ends. So a player counts as a valid
-- target only if their role is "Seeker" (and a live character, and aren't us). Restricting to seekers
-- prevents a spectator from learning hiders' hiding spots.
local function buildTargets()
	targets = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player
			and roleByUserId[p.UserId] == "Seeker"   -- seekers only; hiders and lobby players are excluded
			and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(targets, p)
		end
	end
	if index > #targets then index = 1 end
	if index < 1 then index = #targets end
end

local function currentTarget()
	if #targets == 0 then return nil end
	return targets[index]
end

local function updateLabel()
	local t = currentTarget()
	if t then
		local role = roleByUserId[t.UserId]
		if role == "Seeker" then
			nameLabel.Text = string.format('Spectating <font color="rgb(%s)">Seeker</font>: %s', SEEKER_COLOR, t.DisplayName)
		elseif role == "Hider" then
			nameLabel.Text = string.format('Spectating <font color="rgb(%s)">Hider</font>: %s', HIDER_COLOR, t.DisplayName)
		else
			nameLabel.Text = "Spectating: " .. t.DisplayName
		end
	else
		nameLabel.Text = "No one to spectate"
	end
end

local noOneToken = 0
local stopSpectate  -- forward-declared (used inside startSpectate's loop)
local cycle         -- forward-declared (gamepad controls below reference it before its definition)
local bindGamepadControls, unbindGamepadControls  -- forward-declared; assigned after endOrbitInput

-- ===== orbit input (drag to rotate, scroll/pinch to zoom) =====
-- Connections are created when spectating starts and disconnected when it stops, so they never
-- interfere with normal play. We only rotate while a drag is active (right mouse on desktop, or a
-- touch drag on mobile) so casual mouse movement doesn't spin the camera.
local function beginOrbitInput()
	for _, c in ipairs(inputConns) do if c then c:Disconnect() end end
	inputConns = {}
	dragging = false

	inputConns[#inputConns+1] = UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end  -- ignore clicks that landed on the Prev/Next/Exit GUI buttons
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging = true
			-- lock the mouse in place so InputChanged reports a non-zero Delta for MouseMovement
			-- (without locking, mouse Delta is always 0 and dragging does nothing).
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		elseif input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	inputConns[#inputConns+1] = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.MouseButton2 then
			dragging = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		elseif input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	inputConns[#inputConns+1] = UserInputService.InputChanged:Connect(function(input, gpe)
		if not spectating then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement and dragging then
			orbitYaw = orbitYaw - input.Delta.X * ROT_SPEED
			orbitPitch = math.clamp(orbitPitch + input.Delta.Y * ROT_SPEED, MIN_PITCH, MAX_PITCH)
		elseif input.UserInputType == Enum.UserInputType.Touch and dragging then
			orbitYaw = orbitYaw - input.Delta.X * TOUCH_ROT_SPEED
			orbitPitch = math.clamp(orbitPitch + input.Delta.Y * TOUCH_ROT_SPEED, MIN_PITCH, MAX_PITCH)
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			orbitDist = math.clamp(orbitDist - input.Position.Z * ZOOM_STEP, MIN_DIST, MAX_DIST)
		end
	end)
end

local function endOrbitInput()
	for _, c in ipairs(inputConns) do if c then c:Disconnect() end end
	inputConns = {}
	dragging = false
	-- always restore normal mouse behavior when spectating stops
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

-- ===== gamepad spectate controls (bumpers cycle, B exits; right-stick orbit is read in the loop) =====
-- Bound only while actually spectating. Gamepad keycodes only respond to a controller, so KBM/touch
-- spectators are unaffected. Exit is bound above GamepadUIManager's Back so B wins while spectating.
bindGamepadControls = function()
	ContextActionService:BindAction("SpectateGpPrev", function(_, s)
		if s == Enum.UserInputState.Begin then GamepadConfig.playHaptic(Enum.HapticEffectType.UIClick); cycle(-1) end
		return Enum.ContextActionResult.Sink
	end, false, GamepadConfig.Keys.SpectatePrev)
	ContextActionService:BindAction("SpectateGpNext", function(_, s)
		if s == Enum.UserInputState.Begin then GamepadConfig.playHaptic(Enum.HapticEffectType.UIClick); cycle(1) end
		return Enum.ContextActionResult.Sink
	end, false, GamepadConfig.Keys.SpectateNext)
	ContextActionService:BindActionAtPriority("SpectateGpExit", function(_, s)
		if s == Enum.UserInputState.Begin then GamepadConfig.playHaptic(Enum.HapticEffectType.UIClick); stopSpectate() end
		return Enum.ContextActionResult.Sink
	end, false, GamepadConfig.Priority.Spectate, GamepadConfig.Keys.SpectateExit)
end
unbindGamepadControls = function()
	for _, n in ipairs({ "SpectateGpPrev", "SpectateGpNext", "SpectateGpExit" }) do
		pcall(function() ContextActionService:UnbindAction(n) end)
	end
end

local function startSpectate(forced)
	if spectating then return end
	-- Refuse to open spectate during the HIDE phase (anti-exploit). A short error flash tells the player
	-- why, mirroring the "No one to spectate" message style, without hijacking their camera.
	if spectateBlocked then
		noOneToken += 1
		local myToken = noOneToken
		gui.Enabled = true
		controls.Visible = false
		nameLabel.Text = "Spectating is locked during the hide phase"
		nameLabel.TextColor3 = Color3.fromRGB(220, 70, 70)
		local SoundService = game:GetService("SoundService")
		local errTemplate = SoundService:FindFirstChild("Error")
		if errTemplate then
			local s = errTemplate:Clone()
			local sfx = SoundService:FindFirstChild("SFX")
			if sfx then s.SoundGroup = sfx end
			s.Parent = SoundService
			s:Play()
			task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function()
				if s then s:Destroy() end
			end)
		end
		task.delay(3, function()
			if myToken == noOneToken and not spectating then
				gui.Enabled = false
				controls.Visible = true
				nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			end
		end)
		return
	end
	-- Pull the CURRENT role map from the server before building targets. This covers players who
	-- joined mid-round (or whose client missed the one-shot HIDE broadcast): the server replies on
	-- RoleMap, our handler fills roleByUserId, and the short wait below lets it arrive. Without this,
	-- such a player would always see "No one to spectate" even with a round in progress.
	RequestRoleMap:FireServer()
	-- wait briefly for the reply to populate roleByUserId (only if we don't already have a map)
	if next(roleByUserId) == nil then
		for _ = 1, 30 do                       -- up to ~0.5s (30 * ~1/60)
			if next(roleByUserId) ~= nil then break end
			RunService.Heartbeat:Wait()
		end
	end
	if spectating then return end          -- guard: a server push may have started us during the wait
	buildTargets()
	-- nobody to watch: just flash a message for 3s, don't hijack the camera
	if #targets == 0 then
		noOneToken += 1
		local myToken = noOneToken
		gui.Enabled = true
		controls.Visible = false       -- no Prev/Next/Exit needed for the message
		nameLabel.Text = "No one to spectate"
		nameLabel.TextColor3 = Color3.fromRGB(220, 70, 70)  -- red for the error message
		-- play the Error sound
		local SoundService = game:GetService("SoundService")
		local errTemplate = SoundService:FindFirstChild("Error")
		if errTemplate then
			local s = errTemplate:Clone()
			local sfx = SoundService:FindFirstChild("SFX")
			if sfx then s.SoundGroup = sfx end
			s.Parent = SoundService
			s:Play()
			task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function()
				if s then s:Destroy() end
			end)
		end
		task.delay(3, function()
			if myToken == noOneToken and not spectating then
				gui.Enabled = false
				controls.Visible = true    -- restore for next time
				nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)  -- restore white
			end
		end)
		return
	end

	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)  -- normal white for real spectating
	spectating = true
	isForced = forced == true
	exitBtn.Visible = not isForced  -- a forced (out-of-lives) spectate hides Exit so it can't be left
	gui.Enabled = true
	controls.Visible = true
	updateLabel()
	camera.CameraType = Enum.CameraType.Scriptable
	beginOrbitInput()   -- let the spectator drag to orbit / scroll to zoom (mouse/touch)
	bindGamepadControls()  -- gamepad: bumpers cycle, B exits, right-stick orbits (read in the loop)

	renderConn = RunService.RenderStepped:Connect(function(dt)
		-- gamepad right-stick orbit (mouse/touch drag is handled separately via beginOrbitInput)
		local gp = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
		for _, s in ipairs(gp) do
			if s.KeyCode == Enum.KeyCode.Thumbstick2 then
				local v = s.Position
				if math.abs(v.X) > 0.12 then orbitYaw = orbitYaw - v.X * GP_ROT_SPEED * dt end
				if math.abs(v.Y) > 0.12 then orbitPitch = math.clamp(orbitPitch + v.Y * GP_ROT_SPEED * dt, MIN_PITCH, MAX_PITCH) end
			end
		end
		-- keep the target valid; rebuild if they left/died
		local t = currentTarget()
		if not t or not t.Character or not t.Character:FindFirstChild("HumanoidRootPart") then
			buildTargets()
			updateLabel()
			t = currentTarget()
		end
		-- everyone we could watch is gone: stop spectating cleanly
		if #targets == 0 then
			stopSpectate()
			return
		end
		if t and t.Character then
			local hrp = t.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- orbit the camera around the target using the player-controlled yaw/pitch/distance.
				local focus = hrp.Position + Vector3.new(0, 2, 0)
				local cosP = math.cos(orbitPitch)
				local offset = Vector3.new(
					math.sin(orbitYaw) * cosP,
					math.sin(orbitPitch),
					math.cos(orbitYaw) * cosP
				) * orbitDist
				camera.CFrame = CFrame.lookAt(focus + offset, focus)
			end
		end
	end)
end

stopSpectate = function(force)
	-- a forced spectate can only be ended by the server (force=true), never by the player
	if isForced and not force then
		return
	end
	isForced = false
	exitBtn.Visible = true
	spectating = false
	gui.Enabled = false
	if renderConn then renderConn:Disconnect(); renderConn = nil end
	endOrbitInput()   -- stop listening for orbit input so it never affects normal play
	unbindGamepadControls()  -- release the gamepad spectate binds (cycle / exit)
	-- return the camera to the player
	camera.CameraType = Enum.CameraType.Custom
	if player.Character then
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then camera.CameraSubject = hum end
	end
end

cycle = function(dir)
	buildTargets()
	if #targets == 0 then updateLabel(); return end
	index = index + dir
	if index > #targets then index = 1 end
	if index < 1 then index = #targets end
	updateLabel()
end

prevBtn.MouseButton1Click:Connect(function() cycle(-1) end)
nextBtn.MouseButton1Click:Connect(function() cycle(1) end)
exitBtn.MouseButton1Click:Connect(function() stopSpectate() end)

-- expose a toggle the HUD button can call via a BindableEvent
local toggleEvent = gui:FindFirstChild("ToggleSpectate")
if not toggleEvent then
	toggleEvent = Instance.new("BindableEvent")
	toggleEvent.Name = "ToggleSpectate"
	toggleEvent.Parent = gui
end
toggleEvent.Event:Connect(function()
	if spectating then stopSpectate() else startSpectate() end
end)

-- a dedicated STOP (never starts) — used when a round begins so it can't accidentally
-- toggle spectate ON for in-round players.
local stopEvent = gui:FindFirstChild("StopSpectate")
if not stopEvent then
	stopEvent = Instance.new("BindableEvent")
	stopEvent.Name = "StopSpectate"
	stopEvent.Parent = gui
end
stopEvent.Event:Connect(function()
	if spectating then stopSpectate() end
end)

-- server-driven spectate (e.g. eliminated players)
SpectateEvent.OnClientEvent:Connect(function(show, forced)
	if show then startSpectate(forced) else stopSpectate(true) end
end)

-- FAILSAFE: whenever the match returns to intermission/lobby, force-stop spectating so
-- nobody can ever get stuck in the spectate camera (e.g. after a round ends).
local StateChanged = Remotes:WaitForChild("StateChanged")
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	-- Block spectating during HIDE (anti-exploit, see spectateBlocked above); allow it again otherwise.
	spectateBlocked = (data.state == "HIDE")
	-- Force-stop on the phases where a lingering spectate camera shouldn't persist: the HIDE block,
	-- and the existing INTERMISSION/RESOLVE failsafe so nobody is ever stuck in the spectate camera.
	if spectating and (data.state == "HIDE" or data.state == "INTERMISSION" or data.state == "RESOLVE" or data.state == "REVEALING_HIDERS") then
		stopSpectate()
	end
end)

print("[SpectateClient] ready (functional camera)")
