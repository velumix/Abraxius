-- SettingsClient: drives the new consolidated Settings UI (StarterGui.Settings), opened by the
-- Settings button in the Hud. Sound rows live in HolderFrame.Settings.ScrollingFrame:
--   SoundEffects -> SFX volume slider   (Bar: OuterBar / InnerBar fill / Slider knob, + Value label)
--   Music        -> Music volume slider  (same structure)
-- AFK is handled by the Knit AfkController as a Topbar button.
-- Routed to OUR systems: SFX/Music -> SoundService SoundGroups.
-- The whole UI is shown/hidden via the ScreenGui's .Enabled (there is no "Dim" frame like the old one).
--
-- Slider model: the new Slider is a plain ImageButton (no UIDragDetector), so we drive it with mouse
-- input -- press/drag anywhere on the Bar maps the mouse X across the bar's width to a 0..1 value,
-- moving the Slider knob, sizing the InnerBar fill, updating the layered Value label, and applying
-- the volume.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))

local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("Settings")
local frame = gui:WaitForChild("HolderFrame"):WaitForChild("Settings")
local scroll = frame:WaitForChild("ScrollingFrame")

-- start hidden; open()/close() toggle the ScreenGui's Enabled (the GUI persists, ResetOnSpawn=false)
gui.Enabled = false

-- ===== Open / close =====
local function open() UISounds.select(); gui.Enabled = true end
local function close() UISounds.close(); gui.Enabled = false end
local function closeSilent() gui.Enabled = false end  -- close without the close sound (e.g. opening another menu)

local exit = frame:FindFirstChild("CloseButton")
if exit then exit.MouseButton1Click:Connect(close); UISounds.bindTween(exit) end
-- NOTE: clicking outside the panel intentionally does NOT close it.

local openEvent = gui:FindFirstChild("OpenSettings")
if not openEvent then
	openEvent = Instance.new("BindableEvent"); openEvent.Name = "OpenSettings"; openEvent.Parent = gui
end
openEvent.Event:Connect(open)

-- let other UIs (e.g. the HUD's Shop button) close settings
local closeEvent = gui:FindFirstChild("CloseSettings")
if not closeEvent then
	closeEvent = Instance.new("BindableEvent"); closeEvent.Name = "CloseSettings"; closeEvent.Parent = gui
end
closeEvent.Event:Connect(closeSilent)

-- ===== Sound groups our sliders control =====
local sfxGroup = SoundService:FindFirstChild("SFX")
if not sfxGroup then sfxGroup = Instance.new("SoundGroup"); sfxGroup.Name = "SFX"; sfxGroup.Parent = SoundService end
local musicGroup = SoundService:FindFirstChild("Music")
if not musicGroup then musicGroup = Instance.new("SoundGroup"); musicGroup.Name = "Music"; musicGroup.Parent = SoundService end

-- ===== Slider wiring (SoundEffects -> SFX, Music -> Music) =====
-- rowName: the ScrollingFrame child name; soundGroup: the SoundGroup whose Volume it sets.
local function wireSlider(rowName, soundGroup)
	local row = scroll:FindFirstChild(rowName)
	if not row then warn("[SettingsClient] slider row not found: " .. rowName); return end
	local bar = row:FindFirstChild("Bar")
	local outer = bar and bar:FindFirstChild("OuterBar")
	local inner = bar and bar:FindFirstChild("InnerBar")
	local knob = bar and bar:FindFirstChild("Slider")
	local value = row:FindFirstChild("Value")
	if not (bar and outer and knob) then
		warn("[SettingsClient] slider parts missing in " .. rowName); return
	end

	-- The InnerBar (blue fill) is LEFT-anchored at the Bar's left edge, and the knob travels along the
	-- same Bar-relative 0..1 axis. So the fill width in Bar-scale equals the knob's scale position --
	-- that makes the fill's right edge land exactly under the knob at every value (no center-shrink, no
	-- drift). We keep the InnerBar's authored Y height.
	local innerYScale = inner and inner.Size.Y.Scale or 1

	-- write a 0..1 value across the knob position, fill width, layered label, and volume
	local function applyScale(scale)
		scale = math.clamp(scale, 0, 1)
		knob.Position = UDim2.new(scale, 0, knob.Position.Y.Scale, 0)
		if inner then inner.Size = UDim2.new(scale, 0, innerYScale, 0) end  -- fill right edge tracks the knob
		if value then
			local txt = string.format("%.1f", scale)
			value.Text = txt
			local top = value:FindFirstChild("Top")
			if top and top:IsA("TextLabel") then top.Text = txt end
		end
		soundGroup.Volume = scale
	end

	-- map an absolute mouse X to a 0..1 position across the OuterBar's rendered span
	local function scaleFromMouseX(mouseX)
		local x0 = outer.AbsolutePosition.X
		local w = outer.AbsoluteSize.X
		if w <= 0 then return 0 end
		return math.clamp((mouseX - x0) / w, 0, 1)
	end

	-- initialise from the knob's current authored position (and push that volume immediately)
	applyScale(math.clamp(knob.Position.X.Scale, 0, 1))

	-- drag handling: press on the knob (or anywhere on the bar) begins a drag; we follow the mouse
	-- until release. We listen on the knob AND the outer bar so a click on the track jumps the knob.
	local dragging = false
	local function beginDrag(input)
		dragging = true
		applyScale(scaleFromMouseX(input.Position.X))
	end
	knob.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)
	outer.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			beginDrag(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			applyScale(scaleFromMouseX(input.Position.X))
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

wireSlider("SoundEffects", sfxGroup)
wireSlider("Music", musicGroup)

-- AFK toggle lives in the Topbar via AfkController so server-authoritative state stays in sync.
