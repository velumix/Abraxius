local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local KnifeSkinManager = require(ReplicatedStorage:WaitForChild("KnifeSkinManager"))
local CRATE_NAME = "Sports Crate"
local MODEL_NAME = "RobuxCase"
local deadline = KnifeSkinManager.crateExpiry(CRATE_NAME)

local interactives = workspace:WaitForChild("LobbyInteractives")
local crate = interactives:FindFirstChild(MODEL_NAME, true)
local waited = 0
while not crate and waited < 30 do
	task.wait(0.25); waited += 0.25
	crate = interactives:FindFirstChild(MODEL_NAME, true)
end
if not crate then
	warn("[JurassicTimerClient] RobuxCase not found")
	return
end

local timerPart = crate:WaitForChild("TimerPart", 10)
local billboard = timerPart and timerPart:WaitForChild("BillboardGui", 10)
local label = billboard and billboard:WaitForChild("TimerText", 10)
if not label then
	warn("[JurassicTimerClient] TimerText label not found")
	return
end

local BADGE_SHIMMER_RANGE = 0.5
local BADGE_SHIMMER_TIME = 1.6
local function animateBadgeGradient(grad)
	if not grad or grad:GetAttribute("ShimmerAnim") then return end
	grad:SetAttribute("ShimmerAnim", true)
	grad.Offset = Vector2.new(-BADGE_SHIMMER_RANGE, grad.Offset.Y)
	TweenService:Create(
		grad,
		TweenInfo.new(BADGE_SHIMMER_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Offset = Vector2.new(BADGE_SHIMMER_RANGE, grad.Offset.Y) }
	):Play()
end
task.spawn(function()
	local descPart = crate:WaitForChild("DescriptionPart", 10)
	local descBillboard = descPart and descPart:WaitForChild("BillboardGui", 10)
	local description = descBillboard and descBillboard:WaitForChild("Description", 10)
	local grad = description and description:WaitForChild("UIGradient", 10)
	if grad then animateBadgeGradient(grad) end
end)

local function formatRemaining(seconds)
	seconds = math.max(0, math.floor(seconds or 0))
	local days = math.floor(seconds / 86400)
	local hours = math.floor((seconds % 86400) / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%dd %dh %dm %ds", days, hours, mins, secs)
end

local function refresh()
	if not deadline or deadline <= 0 then
		label.Text = "--d --h --m --s"
		return
	end
	local remaining = deadline - os.time()
	if remaining <= 0 then
		label.Text = "EXPIRED"
	else
		label.Text = formatRemaining(remaining)
	end
end

refresh()
task.spawn(function()
	while true do
		refresh()
		task.wait(1)
	end
end)
