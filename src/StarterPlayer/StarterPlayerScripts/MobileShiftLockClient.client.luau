-- MobileShiftLockClient: a SELF-CONTAINED shift lock (mouse lock) for touch devices.
--
-- Roblox has no official mobile shift-lock API — its CameraModule deliberately disables the
-- MouseLockController on touch devices. Rather than fork or monkey-patch Roblox's PlayerModule
-- (both documented to break on Roblox camera updates), this is a standalone implementation that
-- depends on NOTHING internal, so it can't be broken by future PlayerModule changes.
--
-- While active it does what desktop shift lock does:
--   * locks the mouse to the screen centre (so camera drag rotates the view continuously),
--   * applies an over-the-shoulder camera offset (character sits left-of-centre),
--   * turns OFF Humanoid.AutoRotate and rotates the character each frame to face the camera's
--     horizontal look direction (so the character always faces where the camera looks).
-- Turning it off restores all of those.
--
-- Shown only on touch-only devices (phones/tablets), matching the game's mobile convention.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer

-- touch-only devices only (same convention used across the game's mobile UI)
local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
local emulatingTouch = RunService:IsStudio() and UserInputService.TouchEnabled
if not (touchOnly or emulatingTouch) then
	return
end

local camera = Workspace.CurrentCamera

-- ===== tuning =====
local SHOULDER_OFFSET = Vector3.new(1.75, 0, 0)  -- over-the-shoulder framing (matches Roblox's ~1.75)
local ROTATE_SPEED = 0.3                          -- how snappily the body turns toward the camera (0..1 lerp)

-- ===== state =====
local enabled = false
local humanoid = nil
local rootPart = nil
local renderConn = nil
local savedAutoRotate = true

-- resolve the current character's humanoid + root
local function bindCharacter(character)
	humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	-- if shift lock was on when we respawned, re-apply the humanoid-side settings
	if enabled and humanoid and not player:GetAttribute("PositionLocked") then
		savedAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false
		humanoid.CameraOffset = SHOULDER_OFFSET
	end
end

local function startLock()
	if enabled then return end
	-- Don't enable while the root is position-locked (painting anchors it); rotating it fights that state.
	if player:GetAttribute("PositionLocked") then return end
	enabled = true
	if humanoid then
		savedAutoRotate = humanoid.AutoRotate
		humanoid.AutoRotate = false               -- we control facing manually
		humanoid.CameraOffset = SHOULDER_OFFSET   -- over-the-shoulder framing
	end
	-- lock the mouse to the centre so dragging keeps rotating the camera (mouse-lock behaviour)
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

	-- each frame, face the character in the camera's horizontal look direction
	renderConn = RunService.RenderStepped:Connect(function()
		if not (rootPart and rootPart.Parent and humanoid and humanoid.Health > 0) then return end
		-- Skip rotation while the root is position-locked (painting anchors it) so it isn't forced to move.
		if player:GetAttribute("PositionLocked") then return end
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.001 then return end
		flat = flat.Unit
		local targetCF = CFrame.lookAt(rootPart.Position, rootPart.Position + flat)
		-- smooth the turn so it doesn't snap harshly
		rootPart.CFrame = rootPart.CFrame:Lerp(targetCF, ROTATE_SPEED)
	end)
end

local function stopLock()
	if not enabled then return end
	enabled = false
	if renderConn then renderConn:Disconnect(); renderConn = nil end
	if humanoid then
		humanoid.AutoRotate = savedAutoRotate
		humanoid.CameraOffset = Vector3.zero
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
end

local function toggle()
	if enabled then stopLock() else startLock() end
end

-- ===== toggle button (in the topbar row, just right of Roblox's native icons) =====
local gui = Instance.new("ScreenGui")
gui.Name = "MobileShiftLockGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true   -- (0,0) is the true top-left so we can line up with the topbar
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("ImageButton")
btn.Name = "ShiftLockButton"
btn.AnchorPoint = Vector2.new(0, 0.5)
btn.BackgroundColor3 = Color3.fromRGB(20, 20, 22)   -- dark, matching the native topbar buttons
btn.BackgroundTransparency = 0.15
btn.AutoButtonColor = true
btn.Image = "rbxassetid://115990119566411"
btn.ScaleType = Enum.ScaleType.Fit
btn.Parent = gui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = btn
local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 8); pad.PaddingBottom = UDim.new(0, 8)
pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8)
pad.Parent = btn

-- Position/size the button to sit centered IN the topbar. The topbar height varies (old bar = 36px,
-- new bar = 58px), so we read the actual inset from GuiService instead of hardcoding, and re-apply
-- it whenever the inset changes (e.g. device rotation). x clears Roblox's native icon cluster.
local X_OFFSET = 215   -- horizontal spot just right of the logo/menu/chat/voice icons
local Y_NUDGE = 5      -- small downward shift so it sits slightly lower / better aligned with the icons
local MARGIN = 22      -- vertical breathing room inside the topbar (larger = smaller button, closer to the native icon size)
local function layoutButton()
	local inset = GuiService:GetGuiInset()        -- inset.Y = topbar height
	local barH = inset.Y > 0 and inset.Y or 36
	local size = math.max(24, barH - MARGIN)      -- square, fits within the bar
	btn.Size = UDim2.new(0, size, 0, size)
	btn.Position = UDim2.new(0, X_OFFSET, 0, barH / 2 + Y_NUDGE)  -- vertically centered in the topbar, nudged down
end
layoutButton()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(layoutButton)

local function refreshVisual()
	if enabled then
		btn.BackgroundColor3 = Color3.fromRGB(120, 90, 0)   -- amber tint when active
	else
		btn.BackgroundColor3 = Color3.fromRGB(20, 20, 22)   -- dark idle, matching the topbar
	end
end

btn.Activated:Connect(function()
	toggle()
	refreshVisual()
end)

-- ===== character lifecycle =====
if player.Character then bindCharacter(player.Character) end
player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function()
	-- the render loop guards on a live root, so nothing to do here beyond letting bind re-resolve
	humanoid = nil
	rootPart = nil
end)

Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	camera = Workspace.CurrentCamera
end)
