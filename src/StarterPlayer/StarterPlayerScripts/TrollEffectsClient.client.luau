-- TrollEffectsClient: runs the CLIENT-driven troll effects fired by the server via TrollNotify.
--   * Jumpscare  -> fullscreen image + sound for JUMPSCARE_SECONDS
--   * Flashbang  -> fullscreen WHITE + (different) sound for FLASHBANG_SECONDS
--   * Confusion  -> fully invert movement (W<->S and A<->D, joystick reversed) for CONFUSION_SECONDS
-- The red "you have been trolled" banner is handled separately (TrollBannerClient); this script only
-- does the visuals/movement. All effects target the LOCAL player (the server only FireClients the
-- seeker who should receive them), so there's nothing to validate here.
--
-- IMAGES come from the asset id below; SOUNDS are cloned from SoundService.TrollSounds at play time
-- (so the audio asset/volume stays editable in one place, like RevealUIClient does with WarningSound).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local TrollNotify = Remotes:WaitForChild("TrollNotify")
local TrollConfig = require(ReplicatedStorage:WaitForChild("TrollConfig"))

-- ===== assets =====
local JUMPSCARE_IMAGE = "rbxassetid://35633881"  -- the IMAGE asset (35633882 was a Decal id, which an ImageLabel can't render -> black screen)
-- NOTE: the troll effect SOUNDS (Jumpscare/Flashbang/Trip) are now played SERVER-SIDE as 3D positional
-- sounds at the target (see TrollService.playTrollSoundAt), so nearby players hear them within ~30 studs.
-- This client only handles the fullscreen VISUALS + movement; it no longer plays a local 2D sound
-- (doing so would double up with the server's 3D sound for the target).

-- fade timing for the overlays (snap-in feels cheap; a quick tween reads better)
local JUMP_FADE = 0.08   -- jumpscare slams in fast (it's meant to startle)
local FLASH_FADE = 0.06  -- flashbang pops to white almost instantly
local FADE_OUT = 0.35    -- both ease back out

-- ===== fullscreen overlay GUI (built in code so it needs no pre-made UI) =====
local gui = Instance.new("ScreenGui")
gui.Name = "TrollEffectsGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 350  -- above the reveal banner (320) so a jumpscare covers everything
gui.Enabled = true
gui.Parent = pg

-- jumpscare image (hidden until used)
local jumpImage = Instance.new("ImageLabel")
jumpImage.Name = "Jumpscare"
jumpImage.Size = UDim2.fromScale(1, 1)
jumpImage.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
jumpImage.BackgroundTransparency = 1
jumpImage.Image = JUMPSCARE_IMAGE
jumpImage.ScaleType = Enum.ScaleType.Crop  -- fill the screen on any aspect ratio
jumpImage.ImageTransparency = 1
jumpImage.Visible = false
jumpImage.ZIndex = 10
jumpImage.Parent = gui

-- flashbang white wash (hidden until used)
local flash = Instance.new("Frame")
flash.Name = "Flashbang"
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
flash.BackgroundTransparency = 1
flash.Visible = false
flash.ZIndex = 9
flash.Parent = gui


-- ===== effects =====

local jumpToken = 0
local function doJumpscare(duration)
	jumpToken += 1
	local myToken = jumpToken
	jumpImage.Visible = true
	jumpImage.ImageTransparency = 1
	jumpImage.BackgroundTransparency = 1
	-- fast fade-in so it slams onto the screen
	TweenService:Create(jumpImage, TweenInfo.new(JUMP_FADE), { ImageTransparency = 0, BackgroundTransparency = 0 }):Play()
	task.delay(duration or TrollConfig.JUMPSCARE_SECONDS, function()
		if myToken ~= jumpToken then return end
		local tw = TweenService:Create(jumpImage, TweenInfo.new(FADE_OUT), { ImageTransparency = 1, BackgroundTransparency = 1 })
		tw.Completed:Once(function()
			if myToken == jumpToken then jumpImage.Visible = false end
		end)
		tw:Play()
	end)
end

local flashTokenN = 0
local function doFlashbang(duration)
	flashTokenN += 1
	local myToken = flashTokenN
	flash.Visible = true
	flash.BackgroundTransparency = 1
	-- near-instant pop to white
	TweenService:Create(flash, TweenInfo.new(FLASH_FADE), { BackgroundTransparency = 0 }):Play()
	task.delay(duration or TrollConfig.FLASHBANG_SECONDS, function()
		if myToken ~= flashTokenN then return end
		-- slow fade out (the classic flashbang "vision returning" feel)
		local tw = TweenService:Create(flash, TweenInfo.new(FADE_OUT), { BackgroundTransparency = 1 })
		tw.Completed:Once(function()
			if myToken == flashTokenN then flash.Visible = false end
		end)
		tw:Play()
	end)
end

-- ===== confusion (full movement inversion) =====
-- Roblox's default controls drive Humanoid:Move() each frame from the player's input (keyboard AND
-- the mobile thumbstick) and overwrite MoveDirection. We can't "edit the keys" portably across input
-- types, so we let the default controls compute the intended direction, then each frame re-issue the
-- OPPOSITE direction with Humanoid:Move(). Because our BindToRenderStep runs at a priority AFTER the
-- default control update, our inverted Move wins for that frame — covering keyboard, gamepad, and the
-- on-screen thumbstick uniformly (a true full invert: W<->S and A<->D). Self-heals across respawns.
local CONFUSE_BIND = "TrollConfusionInvert"
local confuseToken = 0
local confusing = false

local function stopConfusion()
	confusing = false
	pcall(function() RunService:UnbindFromRenderStep(CONFUSE_BIND) end)
end

local function startConfusion(duration)
	confuseToken += 1
	local myToken = confuseToken
	confusing = true

	-- run just AFTER the default character control step so our inverted Move is the final word
	pcall(function() RunService:UnbindFromRenderStep(CONFUSE_BIND) end)
	RunService:BindToRenderStep(CONFUSE_BIND, Enum.RenderPriority.Character.Value + 1, function()
		if myToken ~= confuseToken then return end
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 or hum.PlatformStand then return end
		local dir = hum.MoveDirection  -- the direction the default controls just set from real input
		if dir.Magnitude > 0.05 then
			-- invert horizontally (X and Z); Move expects a world-space direction, which MoveDirection is
			hum:Move(Vector3.new(-dir.X, 0, -dir.Z), false)
		end
	end)

	task.delay(duration or TrollConfig.CONFUSION_SECONDS, function()
		if myToken ~= confuseToken then return end
		stopConfusion()
	end)
end

-- a respawn mid-confusion would drop the bind's effect on the old body; re-arm for the remaining time
-- is overkill — instead we simply stop cleanly on death so the new body moves normally.
player.CharacterAdded:Connect(function()
	if confusing then stopConfusion() end
end)

-- ===== receive server cues =====
TrollNotify.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.effect == "Jumpscare" then
		doJumpscare(data.duration)
	elseif data.effect == "Flashbang" then
		doFlashbang(data.duration)
	elseif data.effect == "Confusion" then
		startConfusion(data.duration)
	end
	-- banner messages (data.banner) are handled by TrollBannerClient; ignored here.
end)
