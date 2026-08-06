local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local TRIGGER_PADDING = 1

local pg = player:WaitForChild("PlayerGui")
local shopGui = pg:WaitForChild("Shop")
local openShopEvent = shopGui:WaitForChild("OpenShop")
local closeShopEvent = shopGui:WaitForChild("CloseShop")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local stockValue = Remotes:WaitForChild("FrozenKnifeStock")
local function offerExpired()
	return stockValue.Value <= 0
end

local interactives = workspace:WaitForChild("LobbyInteractives")
local pad = interactives:FindFirstChild("LimitedTimePad2", true)
local waited = 0
while not pad and waited < 30 do
	task.wait(0.25)
	waited += 0.25
	pad = interactives:FindFirstChild("LimitedTimePad2", true)
end
if not pad then
	warn("[LimitedScythePadClient] LimitedTimePad2 not found")
	return
end

local inRange = false
local dismissedInRange = false

closeShopEvent.Event:Connect(function()
	if inRange then
		dismissedInRange = true
	end
end)

RunService.Heartbeat:Connect(function()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	
	local localPos = pad.CFrame:PointToObjectSpace(hrp.Position)
	local halfX = pad.Size.X / 2 + TRIGGER_PADDING
	local halfZ = pad.Size.Z / 2 + TRIGGER_PADDING
	local nowInRange = math.abs(localPos.X) <= halfX and math.abs(localPos.Z) <= halfZ
	
	if nowInRange and not inRange then
		inRange = true
		if not dismissedInRange and not offerExpired() then
			openShopEvent:Fire("frozenknife")
		end
	elseif not nowInRange and inRange then
		inRange = false
		dismissedInRange = false
		closeShopEvent:Fire()
	end
end)
