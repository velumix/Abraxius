-- ObbyWinnerPadClient: drives the ObbyWinnerPad's countdown TextLabel.
--   reward   -> start the live 5-minute countdown
--   cooldown -> (re)start the live countdown shown on the label
-- The label shows "READY!" when the pad can be claimed, otherwise an MM:SS countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local ObbyPadResult = Remotes:WaitForChild("ObbyPadResult")
local ObbyPadQuery = Remotes:WaitForChild("ObbyPadQuery")

-- Resolve the pad and its countdown label. These live deep in Workspace
-- (ObbyWinnerPad > ObbyText [Part] > ObbyText [BillboardGui] > TextLabel) and replicate to the client
-- piece-by-piece, so the parts may NOT exist yet when this script first runs. Using FindFirstChild
-- here (which does NOT wait) previously returned nil and threw "attempt to index nil", killing the
-- whole script so the countdown/popup never worked. We WaitForChild down the chain instead, with a
-- timeout so a genuinely-missing pad can't yield forever.
local lobbyInteractives = Workspace:WaitForChild("LobbyInteractives")
local pad = lobbyInteractives:WaitForChild("ObbyWinnerPad", 30)
if not pad then
	warn("[ObbyWinnerPadClient] ObbyWinnerPad not found under LobbyInteractives; aborting")
	return
end
-- the countdown label lives at ObbyWinnerPad.ObbyText.ObbyText.TextLabel -- wait down each level
local labelHost = pad:WaitForChild("ObbyText", 30)
local labelGui = labelHost and labelHost:WaitForChild("ObbyText", 30)
local label = labelGui and labelGui:WaitForChild("TextLabel", 30)

local PIXEL = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

-- floating "+20 COINS" that rises and fades above the pad — same look as the in-round coin popup
-- (PressStart2P, gold text, dark stroke, rise + fade).
local function showRewardPopup(amount)
	local worldPos = pad.Position + Vector3.new(0, 3, 0)
	local anchor = Instance.new("Part")
	anchor.Name = "ObbyRewardPopupAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(worldPos)
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 200, 0, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	billboard.Parent = anchor

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.FontFace = PIXEL
	lbl.Text = "+" .. tostring(amount or 0) .. " COINS"
	lbl.TextColor3 = Color3.fromRGB(255, 215, 90)
	lbl.TextScaled = true
	lbl.Parent = billboard
	local stroke = Instance.new("UIStroke", lbl)
	stroke.Color = Color3.fromRGB(60, 40, 0)
	stroke.Thickness = 2
	local tsc = Instance.new("UITextSizeConstraint", lbl); tsc.MaxTextSize = 22

	local RISE = 4
	local DURATION = 0.9
	local goalCF = CFrame.new(worldPos + Vector3.new(0, RISE, 0))
	local tweenInfo = TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, tweenInfo, { CFrame = goalCF }):Play()
	TweenService:Create(lbl, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()

	task.delay(DURATION + 0.1, function()
		if anchor then anchor:Destroy() end
	end)
end

-- play the coin reward sound (same as the group reward chest) when the pad actually pays out
local function playCoinReward()
	local template = SoundService:FindFirstChild("CoinReward")
	if not template then return end
	local s = template:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end  -- obey the Settings SFX slider
	s.Parent = SoundService
	s:Play()
	s.Ended:Connect(function() s:Destroy() end)
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.5, function()
		if s and s.Parent then s:Destroy() end
	end)
end

-- ===== live countdown =====
local cooldownEnds = 0  -- os.clock()-based deadline; <= now means ready

local function formatMS(seconds)
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

if label then
	RunService.Heartbeat:Connect(function()
		local remaining = cooldownEnds - os.clock()
		if remaining <= 0 then
			label.Text = "READY!"
		else
			label.Text = formatMS(remaining)
		end
	end)
end

ObbyPadResult.OnClientEvent:Connect(function(result)
	if type(result) ~= "table" then return end
	if result.kind == "reward" then
		cooldownEnds = os.clock() + (result.remaining or 0)
		showRewardPopup(result.amount or 20)  -- floating "+20 COINS", only on an actual reward
		playCoinReward()                       -- and the coin reward sound
	elseif result.kind == "cooldown" then
		cooldownEnds = os.clock() + (result.remaining or 0)
	end
end)

-- seed the timer with our current cooldown on join
task.defer(function()
	ObbyPadQuery:FireServer()
end)
