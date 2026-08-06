-- PaintController — paint UI + interaction (Knit controller).
-- Full HSV color picker (hue slider + saturation/value square), eyedropper, quick presets.
-- Click/drag own body parts to paint them, or tap "Paint All Body" to recolor everything at once.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)

local player = Players.LocalPlayer
local EYEDROPPER_CURSOR = "rbxassetid://132343816278781"  -- same icon as the eyedropper button
local CURSOR_SIZE = 40  -- on-screen size of the custom eyedropper cursor (px)

local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))

local PaintController = Knit.CreateController({
	Name = "PaintController",
})

-- is a gamepad the active input device right now? (PreferredInput is the canonical check)
local function gamepadActive()
	local ok, pref = pcall(function() return UserInputService.PreferredInput end)
	if ok and pref ~= nil then return pref == Enum.PreferredInput.Gamepad end
	local lit = UserInputService:GetLastInputType()
	return lit == Enum.UserInputType.Gamepad1 or lit == Enum.UserInputType.Gamepad2
		or lit == Enum.UserInputType.Gamepad3 or lit == Enum.UserInputType.Gamepad4
end

function PaintController:KnitStart()
	local PaintService = Knit.GetService("PaintService")
	local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
	local RoleAnnounce = Remotes:WaitForChild("RoleAnnounce")
	local InRound = Remotes:WaitForChild("InRound")

	-- ===== State =====
	local paintMode = false
	local locked = false
	local eyedropper = false
	local hue, sat, val = 0, 0, 1            -- current HSV (start white)
	local currentColor = Color3.fromHSV(hue, sat, val)

	local lockAnimSuppressConn = nil
	local lockDisabledStates = nil
	local lockRoot: BasePart? = nil
	local lockRootWasAnchored: boolean? = nil
	local LOCK_DISABLED_STATES = {
		Enum.HumanoidStateType.Running,
		Enum.HumanoidStateType.RunningNoPhysics,
		Enum.HumanoidStateType.Climbing,
	}

	local function playPaintSplash(part, color, count)
		if not part or not part.Parent then return end
		count = count or 20

		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = part.Position
		attachment.Parent = part

		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(color)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.2, 1.2),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(0.4, 0.8)
		emitter.Speed = NumberRange.new(8, 20)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -35, 0)
		emitter.Rate = 0
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-180, 180)
		emitter.LightEmission = 0.2
		emitter.LightInfluence = 0
		emitter.Parent = attachment

		emitter:Emit(count)

		task.delay(2, function()
			if attachment then attachment:Destroy() end
		end)
	end

	PaintService.PaintSplashed:Connect(playPaintSplash)

	local function suppressLockAnimations(on)
		local char = player.Character
		local animate = char and char:FindFirstChild("Animate")
		local hum = char and char:FindFirstChildOfClass("Humanoid")

		if on then
			if animate then animate.Disabled = true end
			if hum then
				lockDisabledStates = {}
				for _, st in ipairs(LOCK_DISABLED_STATES) do
					lockDisabledStates[st] = hum:GetStateEnabled(st)
					hum:SetStateEnabled(st, false)
				end
			end
			-- Anchor the root locally so the lock is handled by the owning client and avoids server desync.
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				lockRoot = root
				lockRootWasAnchored = root.Anchored
				root.Anchored = true
			end
			if lockAnimSuppressConn then lockAnimSuppressConn:Disconnect() end
			lockAnimSuppressConn = RunService.RenderStepped:Connect(function()
				local c = player.Character
				local a = c and c:FindFirstChild("Animate")
				if a then a.Disabled = true end
				local h = c and c:FindFirstChildOfClass("Humanoid")
				local animator = h and h:FindFirstChildOfClass("Animator")
				if animator then
					for _, tr in ipairs(animator:GetPlayingAnimationTracks()) do
						tr:Stop(0)
					end
				end
			end)
		else
			if lockAnimSuppressConn then
				lockAnimSuppressConn:Disconnect()
				lockAnimSuppressConn = nil
			end
			if animate and not player:GetAttribute("Posed") then
				animate.Disabled = false
			end
			if hum and lockDisabledStates then
				for st, wasEnabled in pairs(lockDisabledStates) do
					hum:SetStateEnabled(st, wasEnabled)
				end
			end
			lockDisabledStates = nil
			if lockRoot and lockRoot.Parent then
				lockRoot.Anchored = lockRootWasAnchored or false
			end
			lockRoot = nil
			lockRootWasAnchored = nil
		end
	end

	-- ===== GUI root =====
	local gui = Instance.new("ScreenGui")
	gui.Name = "PaintGui"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- ===== Custom eyedropper cursor =====
	local cursorGui = Instance.new("ScreenGui")
	cursorGui.Name = "EyedropperCursor"
	cursorGui.ResetOnSpawn = false
	cursorGui.DisplayOrder = 200  -- above the paint UI
	cursorGui.IgnoreGuiInset = true
	cursorGui.Enabled = false
	cursorGui.Parent = player:WaitForChild("PlayerGui")

	local cursorIcon = Instance.new("ImageLabel")
	cursorIcon.Name = "Icon"
	cursorIcon.BackgroundTransparency = 1
	cursorIcon.Image = EYEDROPPER_CURSOR
	cursorIcon.Size = UDim2.fromOffset(CURSOR_SIZE, CURSOR_SIZE)
	cursorIcon.AnchorPoint = Vector2.new(0, 1)
	cursorIcon.Parent = cursorGui

	local cursorConn = nil
	local function setEyedropperCursor(active)
		if active then
			UserInputService.MouseIconEnabled = false
			cursorGui.Enabled = true
			if not cursorConn then
				cursorConn = RunService.RenderStepped:Connect(function()
					local m = UserInputService:GetMouseLocation()
					cursorIcon.Position = UDim2.fromOffset(m.X, m.Y)
				end)
			end
		else
			if cursorConn then cursorConn:Disconnect(); cursorConn = nil end
			cursorGui.Enabled = false
			UserInputService.MouseIconEnabled = true
		end
	end

	-- the Paint button now lives in the consolidated Hud bottom row
	local pg = player:WaitForChild("PlayerGui")
	local slots = pg:WaitForChild("Hud"):WaitForChild("BottomButtons")
	local paintBtn = slots:FindFirstChild("PaintButton", true)
	if not paintBtn then
		repeat task.wait() ; paintBtn = slots:FindFirstChild("PaintButton", true) until paintBtn
	end

	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local emulatingTouch = RunService:IsStudio() and UserInputService.TouchEnabled
	local isMobile = touchOnly or emulatingTouch
	local function setLayered(label, text)
		if not label then return end
		label.Text = text
		local top = label:FindFirstChild("Top")
		if top and top:IsA("TextLabel") then top.Text = text end
	end
	local paintKeybind = paintBtn:FindFirstChild("Keybind")
	if paintKeybind then
		if isMobile then
			paintKeybind.Visible = false
		else
			paintKeybind.Visible = true
			setLayered(paintKeybind, "(E)")
		end
	end

	-- Only hiders (in an active round) should see the paint UI.
	local myRole = nil
	local inRound = false
	local resetPaintMode
	local resetLock
	local updateLockVisibility
	local bindPaintApply, unbindPaintApply
	local function updatePaintVisibility()
		local canPaint = (inRound and myRole == "Hider")
		gui.Enabled = canPaint
		paintBtn.Visible = canPaint
		if updateLockVisibility then updateLockVisibility(canPaint) end
		if not canPaint then
			if resetPaintMode then resetPaintMode() end
			-- Reverse Race hides the controls during a role handoff, but the
			-- disguised character must stay locked until it is cloned/replaced.
			if resetLock and player:GetAttribute("ReverseRacePreserveDisguise") ~= true then
				resetLock()
			end
		end
	end
	RoleAnnounce.OnClientEvent:Connect(function(role)
		myRole = role
		updatePaintVisibility()
	end)
	InRound.OnClientEvent:Connect(function(active)
		inRound = active and true or false
		if not inRound then myRole = nil end
		updatePaintVisibility()
	end)
	player:GetAttributeChangedSignal("ReverseRacePreserveDisguise"):Connect(function()
		if player:GetAttribute("ReverseRacePreserveDisguise") ~= true then
			updatePaintVisibility()
		end
	end)
	updatePaintVisibility()

	-- Picker panel
	local panel = Instance.new("Frame")
	panel.Name = "Picker"
	panel.Active = true
	panel.Size = UDim2.new(0, 240, 0, 300)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3 = Color3.fromRGB(226, 204, 168)
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingTop = UDim.new(0,10); panelPad.PaddingBottom = UDim.new(0,10)
	panelPad.PaddingLeft = UDim.new(0,10); panelPad.PaddingRight = UDim.new(0,10)
	panelPad.Parent = panel

	-- Responsive scaling (mobile)
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local PANEL_W, PANEL_H = 240, 300
	local function poseMenuBounds()
		local cam = Workspace.CurrentCamera
		local poseGui = pg:FindFirstChild("PoseButtonGui")
		local poseFrame = poseGui and poseGui:FindFirstChild("Pose")
		if not (poseFrame and cam) then return nil end
		if poseFrame.Visible and poseFrame.AbsoluteSize.X > 0 then
			return poseFrame.AbsolutePosition, poseFrame.AbsoluteSize
		end
		local vp = cam.ViewportSize
		local pos, size, anchor = poseFrame.Position, poseFrame.Size, poseFrame.AnchorPoint
		local w = size.X.Scale * vp.X + size.X.Offset
		local h = size.Y.Scale * vp.Y + size.Y.Offset
		local centerX = pos.X.Scale * vp.X + pos.X.Offset
		local centerY = pos.Y.Scale * vp.Y + pos.Y.Offset
		local topLeftX = centerX - anchor.X * w
		local topLeftY = centerY - anchor.Y * h
		return Vector2.new(topLeftX, topLeftY), Vector2.new(w, h)
	end
	local function updatePanelScale()
		local cam = Workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		local scale = math.min(1, (vp.X * 0.38) / PANEL_W, (vp.Y * 0.55) / PANEL_H)
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			scale = math.min(scale, 0.85)
		end
		scale = math.max(0.5, scale)
		panelScale.Scale = scale

		local GAP = 16
		local posePos, poseSize = poseMenuBounds()
		local rightX, centerY
		if posePos and poseSize then
			rightX = posePos.X - GAP
			centerY = posePos.Y + poseSize.Y / 2
		else
			rightX = vp.X * 0.78
			centerY = vp.Y * 0.5
		end
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			centerY = centerY - vp.Y * 0.30
		end
		local w, h = PANEL_W * scale, PANEL_H * scale
		local minRight, maxRight = w + 8, vp.X - 8
		if maxRight < minRight then maxRight = minRight end
		local minCY, maxCY = h / 2 + 8, vp.Y - h / 2 - 8
		if maxCY < minCY then maxCY = minCY end
		rightX = math.clamp(rightX, minRight, maxRight)
		centerY = math.clamp(centerY, minCY, maxCY)
		panel.Position = UDim2.fromOffset(rightX, centerY)
	end
	pcall(updatePanelScale)
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			pcall(updatePanelScale)
		end)
	end

	-- Saturation/Value square
	local svSquare = Instance.new("Frame")
	svSquare.Name = "SV"
	svSquare.Active = true
	svSquare.Size = UDim2.new(0, 180, 0, 150)
	svSquare.Position = UDim2.new(0, 0, 0, 0)
	svSquare.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
	svSquare.BorderSizePixel = 0
	svSquare.Parent = panel
	Instance.new("UICorner", svSquare).CornerRadius = UDim.new(0, 6)

	local whiteOverlay = Instance.new("Frame")
	whiteOverlay.Size = UDim2.new(1,0,1,0)
	whiteOverlay.BackgroundColor3 = Color3.fromRGB(255,255,255)
	whiteOverlay.BorderSizePixel = 0
	whiteOverlay.Parent = svSquare
	Instance.new("UICorner", whiteOverlay).CornerRadius = UDim.new(0, 6)
	local whiteGrad = Instance.new("UIGradient")
	whiteGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	whiteGrad.Parent = whiteOverlay

	local blackOverlay = Instance.new("Frame")
	blackOverlay.Size = UDim2.new(1,0,1,0)
	blackOverlay.BackgroundColor3 = Color3.fromRGB(0,0,0)
	blackOverlay.BorderSizePixel = 0
	blackOverlay.Parent = svSquare
	Instance.new("UICorner", blackOverlay).CornerRadius = UDim.new(0, 6)
	local blackGrad = Instance.new("UIGradient")
	blackGrad.Rotation = 90
	blackGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	blackGrad.Parent = blackOverlay

	local svCursor = Instance.new("Frame")
	svCursor.Size = UDim2.new(0, 10, 0, 10)
	svCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	svCursor.BackgroundColor3 = Color3.fromRGB(255,255,255)
	svCursor.BorderSizePixel = 0
	svCursor.ZIndex = 5
	svCursor.Parent = svSquare
	Instance.new("UICorner", svCursor).CornerRadius = UDim.new(1, 0)
	local svCursorStroke = Instance.new("UIStroke")
	svCursorStroke.Color = Color3.fromRGB(0,0,0); svCursorStroke.Thickness = 1.5; svCursorStroke.Parent = svCursor

	-- Hue slider
	local hueSlider = Instance.new("Frame")
	hueSlider.Name = "Hue"
	hueSlider.Active = true
	hueSlider.Size = UDim2.new(0, 26, 0, 150)
	hueSlider.Position = UDim2.new(0, 192, 0, 0)
	hueSlider.BorderSizePixel = 0
	hueSlider.Parent = panel
	Instance.new("UICorner", hueSlider).CornerRadius = UDim.new(0, 6)
	local hueGrad = Instance.new("UIGradient")
	hueGrad.Rotation = 90
	hueGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0, 1, 1)),
		ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
		ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
		ColorSequenceKeypoint.new(0.50, Color3.fromHSV(0.50, 1, 1)),
		ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
		ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
		ColorSequenceKeypoint.new(1.00, Color3.fromHSV(1, 1, 1)),
	})
	hueGrad.Parent = hueSlider
	local hueCursor = Instance.new("Frame")
	hueCursor.Size = UDim2.new(1, 4, 0, 6)
	hueCursor.AnchorPoint = Vector2.new(0.5, 0.5)
	hueCursor.Position = UDim2.new(0.5, 0, 0, 0)
	hueCursor.BackgroundColor3 = Color3.fromRGB(255,255,255)
	hueCursor.BorderSizePixel = 0
	hueCursor.ZIndex = 5
	hueCursor.Parent = hueSlider
	local hueCursorStroke = Instance.new("UIStroke")
	hueCursorStroke.Color = Color3.fromRGB(0,0,0); hueCursorStroke.Thickness = 1.5; hueCursorStroke.Parent = hueCursor

	-- Preview + eyedropper row
	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.Size = UDim2.new(0, 60, 0, 40)
	preview.Position = UDim2.new(0, 0, 0, 160)
	preview.BackgroundColor3 = currentColor
	preview.BorderSizePixel = 0
	preview.Parent = panel
	Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 6)
	local previewStroke = Instance.new("UIStroke")
	previewStroke.Color = Color3.fromRGB(0,0,0); previewStroke.Thickness = 1; previewStroke.Transparency = 0.5
	previewStroke.Parent = preview

	local eyeBtn = Instance.new("ImageButton")
	eyeBtn.Name = "Eyedropper"
	eyeBtn.Size = UDim2.new(0, 44, 0, 40)
	eyeBtn.Position = UDim2.new(0, 66, 0, 160)
	eyeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
	eyeBtn.Image = "rbxassetid://132343816278781"
	eyeBtn.ImageColor3 = Color3.fromRGB(255, 255, 255)
	eyeBtn.ScaleType = Enum.ScaleType.Fit
	eyeBtn.Parent = panel
	Instance.new("UICorner", eyeBtn).CornerRadius = UDim.new(0, 6)
	local eyePad = Instance.new("UIPadding")
	eyePad.PaddingTop = UDim.new(0,6); eyePad.PaddingBottom = UDim.new(0,6)
	eyePad.PaddingLeft = UDim.new(0,6); eyePad.PaddingRight = UDim.new(0,6); eyePad.Parent = eyeBtn

	local eyeHint = Instance.new("TextLabel")
	eyeHint.Name = "EyedropperHint"
	eyeHint.BackgroundTransparency = 1
	eyeHint.Position = UDim2.new(0, 114, 0, 160)
	eyeHint.Size = UDim2.new(0, 106, 0, 40)
	eyeHint.Font = Enum.Font.FredokaOne
	eyeHint.Text = "\u{2190} COPY ANY COLOR"
	eyeHint.TextColor3 = Color3.fromRGB(60, 45, 25)
	eyeHint.TextScaled = true
	eyeHint.TextXAlignment = Enum.TextXAlignment.Left
	eyeHint.TextYAlignment = Enum.TextYAlignment.Center
	eyeHint.TextWrapped = true
	eyeHint.Parent = panel
	local eyeHintConstraint = Instance.new("UITextSizeConstraint")
	eyeHintConstraint.MaxTextSize = 13
	eyeHintConstraint.Parent = eyeHint

	-- Quick preset swatches
	local PRESETS = {
		Color3.fromRGB(38, 115, 44),
		Color3.fromRGB(31, 33, 29),
		Color3.fromRGB(167, 0, 0),
		Color3.fromRGB(255, 140, 0),
		Color3.fromRGB(97, 144, 114),
		Color3.fromRGB(186, 183, 132),
		Color3.fromRGB(121, 124, 140),
		Color3.fromRGB(82, 124, 174),
	}
	local presetRow = Instance.new("Frame")
	presetRow.Name = "Presets"
	presetRow.Size = UDim2.new(1, 0, 0, 30)
	presetRow.Position = UDim2.new(0, 0, 0, 210)
	presetRow.BackgroundTransparency = 1
	presetRow.Parent = panel
	local presetLayout = Instance.new("UIListLayout")
	presetLayout.FillDirection = Enum.FillDirection.Horizontal
	presetLayout.Padding = UDim.new(0, 4)
	presetLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	presetLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	presetLayout.Parent = presetRow

	local applyColor
	local function makePreset(col)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.108, 0, 1, 0)
		b.BackgroundColor3 = col
		b.Text = ""
		b.Parent = presetRow
		Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
		local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(0,0,0); st.Transparency = 0.6; st.Parent = b
		b.MouseButton1Click:Connect(function()
			hue, sat, val = Color3.toHSV(col)
			eyedropper = false
			applyColor(true)
		end)
		return b
	end
	for _, c in ipairs(PRESETS) do makePreset(c) end

	-- Paint entire body
	local paintAllBtn = Instance.new("TextButton")
	paintAllBtn.Name = "PaintAll"
	paintAllBtn.Size = UDim2.new(1, 0, 0, 30)
	paintAllBtn.AnchorPoint = Vector2.new(0.5, 0.5)
	paintAllBtn.Position = UDim2.new(0.5, 0, 0, 260)
	paintAllBtn.BackgroundColor3 = Color3.fromRGB(80, 140, 210)
	paintAllBtn.Text = "Paint All Body"
	paintAllBtn.Font = Enum.Font.FredokaOne
	paintAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	paintAllBtn.TextScaled = true
	paintAllBtn.Parent = panel
	Instance.new("UICorner", paintAllBtn).CornerRadius = UDim.new(0, 6)
	local paintAllStroke = Instance.new("UIStroke")
	paintAllStroke.Color = Color3.fromRGB(0, 0, 0)
	paintAllStroke.Transparency = 0.6
	paintAllStroke.Parent = paintAllBtn
	local paintAllTextConstraint = Instance.new("UITextSizeConstraint")
	paintAllTextConstraint.MaxTextSize = 14
	paintAllTextConstraint.Parent = paintAllBtn

	paintAllBtn.MouseButton1Click:Connect(function()
		if not paintMode then return end
		UISounds.click()
		PaintService:PaintBody(currentColor)
	end)

	-- Color application / UI refresh
	local function refreshEyeBtn()
		if eyedropper then
			eyeBtn.BackgroundColor3 = Color3.fromRGB(120, 160, 90)
			setEyedropperCursor(true)
		else
			eyeBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
			setEyedropperCursor(false)
		end
	end

	resetPaintMode = function()
		if paintMode then
			paintMode = false
			panel.Visible = false
			eyedropper = false
			mouseHeld = false
			lastPaintedPart = nil
			refreshEyeBtn()
			if unbindPaintApply then unbindPaintApply() end
			PaintService:SetPainting(false)
		end
	end

	applyColor = function(updateCursors)
		currentColor = Color3.fromHSV(hue, sat, val)
		svSquare.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
		preview.BackgroundColor3 = currentColor
		paintAllBtn.BackgroundColor3 = currentColor
		if updateCursors then
			svCursor.Position = UDim2.new(sat, 0, 1 - val, 0)
			hueCursor.Position = UDim2.new(0.5, 0, hue, 0)
		end
		refreshEyeBtn()
	end

	-- Dragging logic for SV square and hue slider
	local function clamp01(x) return math.clamp(x, 0, 1) end
	local draggingSV, draggingHue = false, false

	local function updateSVFromInput(inputPos)
		local abs = svSquare.AbsolutePosition
		local size = svSquare.AbsoluteSize
		local rx = clamp01((inputPos.X - abs.X) / size.X)
		local ry = clamp01((inputPos.Y - abs.Y) / size.Y)
		sat = rx
		val = 1 - ry
		svCursor.Position = UDim2.new(rx, 0, ry, 0)
		applyColor(false)
	end
	local function updateHueFromInput(inputPos)
		local abs = hueSlider.AbsolutePosition
		local size = hueSlider.AbsoluteSize
		local ry = clamp01((inputPos.Y - abs.Y) / size.Y)
		hue = ry
		hueCursor.Position = UDim2.new(0.5, 0, ry, 0)
		applyColor(false)
	end

	svSquare.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSV = true
			updateSVFromInput(input.Position)
		end
	end)
	hueSlider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingHue = true
			updateHueFromInput(input.Position)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if draggingSV then updateSVFromInput(input.Position) end
			if draggingHue then updateHueFromInput(input.Position) end
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			draggingSV = false
			draggingHue = false
		end
	end)

	eyeBtn.MouseButton1Click:Connect(function()
		UISounds.click()
		eyedropper = not eyedropper
		refreshEyeBtn()
	end)

	-- Toggle paint mode
	local function togglePaint()
		if not (inRound and myRole == "Hider") then return end
		UISounds.click()
		paintMode = not paintMode
		panel.Visible = paintMode
		if paintMode then
			updatePanelScale()
			if bindPaintApply then bindPaintApply() end
		else
			eyedropper = false
			refreshEyeBtn()
			if unbindPaintApply then unbindPaintApply() end
		end
		PaintService:SetPainting(paintMode)
	end
	paintBtn.MouseButton1Click:Connect(togglePaint)

	-- Gamepad bridge
	local gamepadPaintControl = Instance.new("BindableEvent")
	gamepadPaintControl.Name = "GamepadPaintControl"
	gamepadPaintControl.Parent = gui
	gamepadPaintControl.Event:Connect(function(cmd)
		if cmd == "toggle" then
			togglePaint()
		elseif cmd == "open" then
			if not paintMode then togglePaint() end
		elseif cmd == "close" then
			if paintMode then togglePaint() end
		end
	end)

	-- Position-lock toggle
	local lockBtn = slots:FindFirstChild("LockButton", true)
	if not lockBtn then
		repeat task.wait() ; lockBtn = slots:FindFirstChild("LockButton", true) until lockBtn
	end
	local lockTitle = lockBtn:FindFirstChild("Title")
	local lockedIcon = lockBtn:FindFirstChild("LockedIcon")
	local unlockedIcon = lockBtn:FindFirstChild("UnlockedIcon")
	local lockKeybind = lockBtn:FindFirstChild("Keybind")
	if lockKeybind then
		if isMobile then
			lockKeybind.Visible = false
		else
			lockKeybind.Visible = true
			setLayered(lockKeybind, "(F)")
		end
	end

	local function refreshLockVisual()
		if lockedIcon then lockedIcon.Visible = locked end
		if unlockedIcon then unlockedIcon.Visible = not locked end
		setLayered(lockTitle, locked and "Unlock" or "Lock")
	end

	local function setLock(state)
		locked = state
		player:SetAttribute("PositionLocked", locked)
		refreshLockVisual()
		suppressLockAnimations(locked)
		PaintService:SetLocked(locked)
	end

	resetLock = function()
		if locked then
			locked = false
			player:SetAttribute("PositionLocked", false)
			refreshLockVisual()
			suppressLockAnimations(false)
			PaintService:SetLocked(false)
		end
	end
	updateLockVisibility = function(canPaint)
		lockBtn.Visible = canPaint and true or false
	end

	local function toggleLock()
		if not (inRound and myRole == "Hider") then return end
		UISounds.click()
		setLock(not locked)
	end
	lockBtn.MouseButton1Click:Connect(toggleLock)

	local gamepadLockControl = Instance.new("BindableEvent")
	gamepadLockControl.Name = "GamepadLockControl"
	gamepadLockControl.Parent = gui
	gamepadLockControl.Event:Connect(function() toggleLock() end)

	player:SetAttribute("PositionLocked", locked)
	player.CharacterAdded:Connect(function()
		if locked then
			locked = false
			refreshLockVisual()
			PaintService:SetLocked(false)
			player:SetAttribute("PositionLocked", false)
		end
		suppressLockAnimations(false)
	end)
	refreshLockVisual()
	updateLockVisibility(inRound and myRole == "Hider")

	-- Keybinds (E = Paint, F = Lock)
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if input.KeyCode == Enum.KeyCode.E then
			togglePaint()
		elseif input.KeyCode == Enum.KeyCode.F then
			toggleLock()
		end
	end)

	-- hover/press tween on the paint UI buttons
	for _, b in ipairs({ paintBtn, lockBtn, eyeBtn, paintAllBtn }) do
		UISounds.bindTween(b)
		b.MouseEnter:Connect(function() UISounds.hover() end)
	end

	-- Painting via raycast (own body parts)
	local camera = Workspace.CurrentCamera

	local function raycastFromCursor()
		local pos = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(pos.X, pos.Y)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {}
		params.IgnoreWater = true

		local origin = ray.Origin
		local direction = ray.Direction * 1000
		local ignored = {}
		for _ = 1, 12 do
			local result = Workspace:Raycast(origin, direction, params)
			if not result or not result.Instance then return result end
			local part = result.Instance
			if part:IsA("BasePart") and part.Transparency >= 1 then
				table.insert(ignored, part)
				params.FilterDescendantsInstances = ignored
			else
				return result
			end
		end
		return nil
	end

	local function overPanel()
		local m = UserInputService:GetMouseLocation()
		local p, s = panel.AbsolutePosition, panel.AbsoluteSize
		return panel.Visible and m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
	end

	local mouseHeld = false
	local lastPaintedPart = nil

	local function applyPaintAtCursor()
		if not paintMode then return end
		if overPanel() then return end
		local result = raycastFromCursor()
		if not result or not result.Instance then
			lastPaintedPart = nil
			return
		end
		local target = result.Instance
		if eyedropper then
			lastPaintedPart = nil
			if target:IsA("BasePart") then
				hue, sat, val = Color3.toHSV(target.Color)
				eyedropper = false
				applyColor(true)
			end
			return
		end
		local char = player.Character
		if char and target:IsDescendantOf(char) and target:IsA("BasePart") then
			if target ~= lastPaintedPart then
				lastPaintedPart = target
				PaintService:PaintPart(target, currentColor)
			end
		else
			lastPaintedPart = nil
		end
	end

	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then return end
		if not paintMode then return end
		if gamepadActive() then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		mouseHeld = true
		applyPaintAtCursor()
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not mouseHeld then return end
		if not paintMode then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then return end
		applyPaintAtCursor()
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		mouseHeld = false
		lastPaintedPart = nil
	end)

	local paintApplyConn = nil
	bindPaintApply = function()
		if paintApplyConn then return end
		paintApplyConn = UserInputService.InputBegan:Connect(function(input)
			if not paintMode then return end
			if input.KeyCode ~= GamepadConfig.Keys.PaintConfirm then return end
			if overPanel() then return end
			applyPaintAtCursor()
		end)
	end
	unbindPaintApply = function()
		if paintApplyConn then paintApplyConn:Disconnect(); paintApplyConn = nil end
	end

	applyColor(true)
	print("[PaintController] ready (HSV picker)")
end

return PaintController
