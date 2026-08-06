-- CoinSoundClient: on coin pickup, shows a floating "+N" that rises and fades at the coin's
-- world position. The pickup SOUND is now played server-side as a 3D positional sound at the
-- coin (so nearby players incl. the seeker hear it) — this client only handles the popup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local CoinCollected = Remotes:WaitForChild("CoinCollected")

local PIXEL = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

-- floating "+N" that rises and fades at a world position
local function showPopup(worldPos, value, currencyType)
	if typeof(worldPos) ~= "Vector3" then return end
	local isFirework = currencyType == "Firework"
	-- an invisible anchor part to hold the BillboardGui in the world
	local anchor = Instance.new("Part")
	anchor.Name = "CoinPopupAnchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(worldPos)
	anchor.Parent = Workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 120, 0, 50)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 200
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.FontFace = PIXEL
	if isFirework then
		label.Text = "+" .. tostring(value or 1) .. " Firework"
		label.TextColor3 = Color3.fromRGB(255, 90, 90)
	else
		label.Text = "+" .. tostring(value or 1)
		label.TextColor3 = Color3.fromRGB(255, 215, 90)
	end
	label.TextScaled = true
	label.Parent = billboard
	local stroke = Instance.new("UIStroke", label)
	stroke.Color = isFirework and Color3.fromRGB(80, 0, 0) or Color3.fromRGB(60, 40, 0)
	stroke.Thickness = 2
	local tsc = Instance.new("UITextSizeConstraint", label); tsc.MaxTextSize = 24

	-- rise up + fade out
	local RISE = 4       -- studs it floats up
	local DURATION = 0.9
	local goalCF = CFrame.new(worldPos + Vector3.new(0, RISE, 0))
	local tweenInfo = TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, tweenInfo, { CFrame = goalCF }):Play()
	TweenService:Create(label, tweenInfo, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()

	task.delay(DURATION + 0.1, function()
		if anchor then anchor:Destroy() end
	end)
end

CoinCollected.OnClientEvent:Connect(function(worldPos, value, currencyType)
	showPopup(worldPos, value, currencyType)
end)
