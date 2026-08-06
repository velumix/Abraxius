local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local stockValue = Remotes:WaitForChild("FrozenKnifeStock")
local capValue = Remotes:WaitForChild("FrozenKnifeStockCap")

local interactives = workspace:WaitForChild("LobbyInteractives")
local pad = interactives:FindFirstChild("LimitedTimePad2", true)
local waited = 0
while not pad and waited < 30 do
	task.wait(0.25)
	waited += 0.25
	pad = interactives:FindFirstChild("LimitedTimePad2", true)
end
if not pad then
	warn("[LimitedStockClient] LimitedTimePad2 not found")
	return
end
local timerPart = pad:WaitForChild("TimerPart", 10)
local billboard = timerPart and timerPart:WaitForChild("BillboardGui", 10)
local label = billboard and billboard:WaitForChild("TimerText", 10)
if not label then
	warn("[LimitedStockClient] TimerText label not found on LimitedTimePad2")
	return
end

local TweenService = game:GetService("TweenService")
local BADGE_SHIMMER_RANGE = 0.5
local BADGE_SHIMMER_TIME = 1.6
local function animateBadgeGradient(grad)
	if not grad or grad:GetAttribute("ShimmerAnim") then
		return
	end
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
		warn("[LimitedStockClient] DescriptionPart Description UIGradient not found on LimitedTimePad2")
	end
end)

local function refresh()
	local remaining = stockValue.Value
	local cap = capValue.Value > 0 and capValue.Value or 2000
	if remaining <= 0 then
		label.Text = "SOLD OUT"
	else
		label.Text = string.format("%d/%d", remaining, cap)
	end
end

refresh()
stockValue.Changed:Connect(refresh)
capValue.Changed:Connect(refresh)
