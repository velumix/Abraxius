--!nonstrict
-- GamepadShiftLockClient (LocalScript, StarterPlayer.StarterPlayerScripts)
-- ============================================================================
-- Controller-only SHIFT LOCK, toggled with R3 (right-stick click) — the console convention for a
-- custom shift-lock button (PC uses Shift, mobile uses an on-screen button; both are untouched here).
--
-- Canonical shift-lock behavior: the camera locks behind the character and the character continuously
-- FACES the camera's look direction, with a center crosshair. The right stick still rotates the camera.
-- This is exactly the mode in which camera-center aiming (the seeker knife throw) is pixel-accurate.
--
-- By default R3 toggles the engine camera's first-person zoom. We claim R3 through ContextActionService
-- and SINK it, so the press toggles shift lock instead. We do NOT touch PC or mobile: this whole script
-- early-returns unless the client is GamepadEnabled and not TouchEnabled.
-- ============================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local GamepadConfig = require(ReplicatedStorage:WaitForChild("GamepadConfig"))

-- gate: console, or a PC/handheld with a controller, but NOT touch (phones with a paired pad keep the
-- on-screen path). KBM players never press ButtonR3 anyway, but we still only bind for gamepad clients.
local function gamepadEligible(): boolean
	return UserInputService.GamepadEnabled and not UserInputService.TouchEnabled
end

-- ===== tunables =====
local SHOULDER_OFFSET = Vector3.new(1.75, 0, 0)  -- over-the-shoulder camera offset while locked (studs)
local SHIFTLOCK_ACTION = "GamepadShiftLock"

-- NOTE: no custom crosshair. The engine already draws its shift-lock center crosshair while a locked
-- camera state is active, so adding our own produced a SECOND on-screen cursor. We rely on the engine's.

-- ===== shift lock state =====
local shiftLockOn = false
local renderConn: RBXScriptConnection? = nil

local function currentHumanoid(): Humanoid?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	return hum
end

local function startShiftLock()
	if shiftLockOn then return end
	local hum = currentHumanoid()
	if not hum then return end
	-- Don't enable while the hider is position-locked or posed; rotating the root fights those states.
	if player:GetAttribute("PositionLocked") or player:GetAttribute("Posed") then return end
	shiftLockOn = true

	-- Each frame: turn the character to face the camera's horizontal look direction, and hold the
	-- over-shoulder camera offset. AutoRotate off so movement input doesn't fight the facing.
	renderConn = RunService.RenderStepped:Connect(function()
		local humNow = currentHumanoid()
		if not humNow then return end
		-- Skip rotation while position-locked or posed so the root isn't forced to move/rotate.
		if player:GetAttribute("PositionLocked") or player:GetAttribute("Posed") then return end
		local root = humNow.RootPart
		if not root then return end
		humNow.AutoRotate = false
		humNow.CameraOffset = SHOULDER_OFFSET
		local cam = workspace.CurrentCamera
		if not cam then return end
		-- camera look flattened to the horizontal plane -> face that direction
		local look = cam.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 0.001 then
			local pos = root.Position
			root.CFrame = CFrame.lookAt(pos, pos + flat.Unit)
		end
	end)
end

local function stopShiftLock()
	if not shiftLockOn then return end
	shiftLockOn = false
	if renderConn then renderConn:Disconnect(); renderConn = nil end
	local hum = currentHumanoid()
	if hum then
		hum.AutoRotate = true
		hum.CameraOffset = Vector3.zero
	end
end

local function toggleShiftLock()
	if shiftLockOn then stopShiftLock() else startShiftLock() end
end

-- ===== R3 binding (sink so it overrides the default first-person zoom) =====
local function onShiftLockAction(_actionName, inputState, _inputObject)
	if inputState == Enum.UserInputState.Begin then
		GamepadConfig.playHaptic(Enum.HapticEffectType.UIClick)
		toggleShiftLock()
	end
	return Enum.ContextActionResult.Sink
end

local bound = false
local function bind()
	if bound or not gamepadEligible() then return end
	bound = true
	-- High priority + sink: claim R3 above the CoreScript camera's default first-person toggle.
	ContextActionService:BindActionAtPriority(
		SHIFTLOCK_ACTION, onShiftLockAction, false, 3000, GamepadConfig.Keys.ShiftLock
	)
end
local function unbind()
	if not bound then return end
	bound = false
	pcall(function() ContextActionService:UnbindAction(SHIFTLOCK_ACTION) end)
	stopShiftLock()
end

-- a fresh character resets Humanoid props, so re-apply the lock state on respawn (and don't leak it)
player.CharacterAdded:Connect(function()
	if shiftLockOn then
		-- restart cleanly against the new humanoid
		shiftLockOn = false
		startShiftLock()
	end
end)

if gamepadEligible() then bind() end
UserInputService.GamepadConnected:Connect(function() if gamepadEligible() then bind() end end)
UserInputService.GamepadDisconnected:Connect(function()
	if not UserInputService.GamepadEnabled then unbind() end
end)

print("[GamepadShiftLockClient] ready (R3 toggles shift lock)")
