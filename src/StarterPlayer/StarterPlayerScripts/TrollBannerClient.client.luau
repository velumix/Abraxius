-- TrollBannerClient: the red countdown banner for the Trolls feature, fired by the server via
-- TrollNotify. Reuses the look of the Reveal Hiders warning banner (FredokaOne pixel font, red text,
-- black stroke, live (Ns) countdown) so it feels native to the game.
--   * trolled seeker sees: "You have been trolled by X! (Ns)"
--   * buying hider sees:   "You trolled X! (Ns)"
-- Banner duration is always TrollConfig.BANNER_SECONDS (5s) per design.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local TrollNotify = Remotes:WaitForChild("TrollNotify")
local TrollConfig = require(ReplicatedStorage:WaitForChild("TrollConfig"))

local PIXEL = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local gui = Instance.new("ScreenGui")
gui.Name = "TrollBannerGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 321  -- just above the reveal banner (320); below the jumpscare overlay (350)
gui.Enabled = false
gui.Parent = pg

local label = Instance.new("TextLabel")
label.Name = "TrollBanner"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0.30, 0)
label.Size = UDim2.new(0.7, 0, 0.06, 0)
label.BackgroundTransparency = 1
label.FontFace = PIXEL
label.TextScaled = true
label.TextColor3 = Color3.fromRGB(255, 40, 40)
label.Text = ""
label.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(0, 0, 0)
stroke.Thickness = 3
stroke.Parent = label

local sizeConstraint = Instance.new("UITextSizeConstraint")
sizeConstraint.MaxTextSize = 22  -- cap so TextScaled never blows up huge on small/mobile screens
sizeConstraint.MinTextSize = 8   -- floor so it stays legible on very narrow phones
sizeConstraint.Parent = label

local token = 0
local function showBanner(messageFmt, duration)
	duration = duration or TrollConfig.BANNER_SECONDS
	token += 1
	local myToken = token
	gui.Enabled = true
	task.spawn(function()
		for remaining = duration, 1, -1 do
			if myToken ~= token then return end
			label.Text = string.format(messageFmt, remaining)
			label.TextTransparency = 0
			TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 0.15 }):Play()
			task.wait(1)
		end
		if myToken ~= token then return end
		gui.Enabled = false
	end)
end

TrollNotify.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.banner == "trolled" then
		local by = tostring(data.by or "someone")
		showBanner("You have been trolled by " .. by .. "! (%ds)", data.duration)
	elseif data.banner == "buyer" then
		local target = tostring(data.target or "the seeker")
		showBanner("You trolled " .. target .. "! (%ds)", data.duration)
	end
	-- effect cues (data.effect) are handled by TrollEffectsClient; ignored here.
end)
