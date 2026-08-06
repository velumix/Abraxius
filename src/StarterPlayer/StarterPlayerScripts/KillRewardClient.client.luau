-- KillRewardClient: when the local player (a seeker) earns coins for a kill, show floating "+N Coins"
-- text above their character that drifts up and fades, and play the coin-reward sound. Driven by the
-- server's KillReward remote (fired to the killer with the coin amount). Purely cosmetic feedback;
-- the actual coin award happens server-side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local KillReward = Remotes:WaitForChild("KillReward")

-- play game.SoundService.CoinReward, cloned + routed through the SFX SoundGroup so the Settings SFX
-- volume slider applies (same pattern the crate shop uses for this sound).
local function playCoinReward()
	local tmpl = SoundService:FindFirstChild("CoinReward")
	if not tmpl or not tmpl:IsA("Sound") then return end
	local s = tmpl:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function()
		if s then s:Destroy() end
	end)
end

-- spawn a floating "+N Coins" label above the player's head that drifts up and fades over ~1.2s.
local function showFloatingText(amount)
	local char = player.Character
	local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
	if not head then return end

	-- anchor the billboard to a tiny invisible part so it can float independently of the moving head
	local anchor = Instance.new("Part")
	anchor.Name = "CoinRewardAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Anchored = true
	anchor.CFrame = head.CFrame * CFrame.new(0, 2.5, 0)
	anchor.Parent = workspace

	local bb = Instance.new("BillboardGui")
	bb.Name = "CoinRewardBillboard"
	bb.Size = UDim2.fromScale(4, 1.2)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 80
	bb.LightInfluence = 0
	bb.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "+" .. amount .. " Coins"
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(255, 215, 0)   -- gold
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = bb

	-- drift the anchor up while the text fades out, then clean everything up.
	local RISE = 2.5      -- studs to float upward
	local DUR = 1.2       -- seconds
	local info = TweenInfo.new(DUR, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = anchor.CFrame * CFrame.new(0, RISE, 0) }):Play()
	-- fade the text + stroke over the same window (start the fade slightly delayed so it's readable first)
	task.delay(DUR * 0.35, function()
		local fade = TweenInfo.new(DUR * 0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(label, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
	task.delay(DUR + 0.1, function()
		if anchor then anchor:Destroy() end
	end)
end

KillReward.OnClientEvent:Connect(function(amount)
	amount = tonumber(amount) or 0
	if amount <= 0 then return end
	playCoinReward()
	showFloatingText(amount)
end)

print("[KillRewardClient] ready (floating +Coins text + sound on kill)")
