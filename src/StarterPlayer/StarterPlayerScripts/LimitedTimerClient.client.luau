-- LimitedTimerClient: renders the global 14-day countdown on the LimitedTimePad's
-- TimerPart. Reads the absolute deadline published by the server (ReplicatedStorage.GameRemotes.
-- LimitedOfferDeadline) and updates every second. Because the deadline is an absolute UNIX
-- timestamp and os.time() returns UTC seconds, the countdown is identical across all servers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local deadlineValue = Remotes:WaitForChild("LimitedOfferDeadline")

-- locate the timer label on the pad. With StreamingEnabled the LobbyInteractives folder exists
-- before its children stream in, so poll for the pad instead of a one-shot FindFirstChild (which
-- could return nil on join and permanently warn out even though the pad arrives moments later).
local interactives = workspace:WaitForChild("LobbyInteractives")
local pad = interactives:FindFirstChild("LimitedTimePad", true)
local waited = 0
while not pad and waited < 30 do
	task.wait(0.25); waited += 0.25
	pad = interactives:FindFirstChild("LimitedTimePad", true)
end
if not pad then
	warn("[LimitedTimerClient] LimitedTimePad not found")
	return
end
local timerPart = pad:WaitForChild("TimerPart", 10)
local billboard = timerPart and timerPart:WaitForChild("BillboardGui", 10)
local label = billboard and billboard:WaitForChild("TimerText", 10)
if not label then
	warn("[LimitedTimerClient] TimerText label not found")
	return
end

-- ===== Animate the DescriptionPart's gradient (same side-to-side shimmer as the shop badges) =====
-- Slide the UIGradient Offset side to side (a back-and-forth color shimmer), matching the shop's
-- animateBadgeGradient: -0.5 -> +0.5 over 1.6s, Sine InOut, infinite, autoreverse. Guarded by a
-- ShimmerAnim attribute so it only ever starts one tween per gradient.
local TweenService = game:GetService("TweenService")
local BADGE_SHIMMER_RANGE = 0.5   -- how far the gradient offset slides each way (0..1 of the band)
local BADGE_SHIMMER_TIME = 1.6    -- seconds for one side of the slide
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
	local descPart = pad:WaitForChild("DescriptionPart", 10)
	local descBillboard = descPart and descPart:WaitForChild("BillboardGui", 10)
	local description = descBillboard and descBillboard:WaitForChild("Description", 10)
	local grad = description and description:WaitForChild("UIGradient", 10)
	if grad then
		animateBadgeGradient(grad)
	else
		warn("[LimitedTimerClient] DescriptionPart Description UIGradient not found on LimitedTimePad")
	end
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
	local deadline = deadlineValue.Value
	if deadline <= 0 then
		label.Text = "--d --h --m --s"  -- not resolved yet
		return
	end
	local remaining = deadline - os.time()
	if remaining <= 0 then
		label.Text = "EXPIRED"
	else
		label.Text = formatRemaining(remaining)
	end
end

-- update once immediately, then every second
refresh()
deadlineValue.Changed:Connect(refresh)

task.spawn(function()
	while true do
		refresh()
		task.wait(1)
	end
end)
