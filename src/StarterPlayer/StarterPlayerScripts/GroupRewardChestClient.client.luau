-- GroupRewardChestClient: reacts to the server's chest outcomes and drives the TimerText.
--   reward     -> play the CoinReward sound
--   notingroup -> prompt the player to join the community group
--   cooldown   -> (re)start the live 24h countdown shown in TimerText
-- TimerText shows "READY!" when the chest can be claimed, otherwise a HH:MM:SS countdown.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local GroupService = game:GetService("GroupService")
local GuiService = game:GetService("GuiService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local GROUP_ID = 133797237

local PIXEL = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

-- floating "+N COINS" that rises and fades over the PLAYER's position (same look as the coin popups)
local function showRewardPopup(amount)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local worldPos = hrp.Position + Vector3.new(0, 3, 0)

	local anchor = Instance.new("Part")
	anchor.Name = "ChestRewardPopupAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(worldPos)
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 220, 0, 50)
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

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local GroupChestResult = Remotes:WaitForChild("GroupChestResult")
local GroupChestQuery = Remotes:WaitForChild("GroupChestQuery")

local chest = Workspace:WaitForChild("LobbyInteractives"):FindFirstChild("GroupRewardChest", true)
local timerText = chest:FindFirstChild("TimerText", true)

-- ===== live countdown =====
local cooldownEnds = 0  -- os.clock()-based deadline; <= now means ready

local function formatHMS(seconds)
	seconds = math.max(0, math.floor(seconds))
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local s = seconds % 60
	return string.format("%02d:%02d:%02d", h, m, s)
end

if timerText then
	RunService.Heartbeat:Connect(function()
		local remaining = cooldownEnds - os.clock()
		if remaining <= 0 then
			timerText.Text = "READY!"
		else
			timerText.Text = formatHMS(remaining)
		end
	end)
end

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

local promptingJoin = false
local function promptJoinGroup()
	if promptingJoin then return end
	promptingJoin = true

	-- Native in-experience community join modal (GroupService:PromptJoinAsync, released Dec 2025).
	-- This is the current, correct API. It only works in the LIVE/published game — in Studio
	-- playtests it no-ops or errors, which is expected. We log the outcome and, if the native prompt
	-- didn't result in membership (failed, ineligible, dismissed, or unavailable on this client),
	-- fall back to opening the group page so the player can still join.
	local ok, status = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)
	promptingJoin = false

	-- Success states: the player joined via the prompt (Joined) or was already a member (AlreadyMember).
	-- (The enum is None / Joined / JoinRequestPending / AlreadyMember — there is no "Member" value.)
	if ok and (status == Enum.GroupMembershipStatus.Joined or status == Enum.GroupMembershipStatus.AlreadyMember) then
		-- joined (or already in) -> immediately re-attempt the claim so they get the reward now
		GroupChestQuery:FireServer("claim")
		return
	end

	warn(("[GroupRewardChestClient] PromptJoinAsync ok=%s status=%s — falling back to group page")
		:format(tostring(ok), tostring(status)))

	-- Fallback: open the community group page in the in-experience browser so they can join there.
	pcall(function()
		GuiService:OpenBrowserWindow("https://www.roblox.com/communities/" .. GROUP_ID)
	end)
end

GroupChestResult.OnClientEvent:Connect(function(result)
	if type(result) ~= "table" then return end
	if result.kind == "reward" then
		playCoinReward()
		showRewardPopup(result.amount or 100)  -- floating "+N COINS" over the player
		cooldownEnds = os.clock() + (result.remaining or 0)
	elseif result.kind == "cooldown" then
		cooldownEnds = os.clock() + (result.remaining or 0)
	elseif result.kind == "notingroup" then
		promptJoinGroup()
	end
end)

-- seed the timer with our current cooldown on join
task.defer(function()
	GroupChestQuery:FireServer()
end)
