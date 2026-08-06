-- ResultClient: shows the round-end win banner ("<player> has won the round!" or
-- "Hiders Win!"), color-coded, with a fade in/out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local RoundResult = Remotes:WaitForChild("RoundResult")

local SEEKER_COLOR = Color3.fromRGB(150, 60, 60)
local HIDER_COLOR = Color3.fromRGB(70, 130, 90)

local function getParts()
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:WaitForChild("ResultGui")
	local banner = gui:WaitForChild("Banner")
	return banner, banner:WaitForChild("Text")
end

RoundResult.OnClientEvent:Connect(function(text, side)
	local banner, label = getParts()
	label.Text = text or ""
	banner.BackgroundColor3 = (side == "Seeker") and SEEKER_COLOR or HIDER_COLOR

	banner.Visible = true
	banner.BackgroundTransparency = 1
	label.TextTransparency = 1

	local inInfo = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(banner, inInfo, {BackgroundTransparency = 0.15}):Play()
	TweenService:Create(label, inInfo, {TextTransparency = 0}):Play()

	task.delay(4.5, function()
		local outInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(banner, outInfo, {BackgroundTransparency = 1}):Play()
		local t = TweenService:Create(label, outInfo, {TextTransparency = 1})
		t:Play()
		t.Completed:Connect(function()
			banner.Visible = false
		end)
	end)
end)
