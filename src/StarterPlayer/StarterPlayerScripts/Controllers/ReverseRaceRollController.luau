-- Reverse Race target roll: a crate-style horizontal reel that spins across player headshots +
-- display names and lands on the selected target. Driven by the ReverseRaceRoll RemoteEvent.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ReverseRaceRollController = Knit.CreateController({
	Name = "ReverseRaceRollController",
})

local CELL_W = 150
local CELL_GAP = 14
local SLOT_W = CELL_W + CELL_GAP

-- Known-valid user ids to borrow a headshot from when a player's id is < 0 (Studio test
-- "Player1/2/3" bots have negative ids, whose thumbnails don't resolve).
local FALLBACK_USER_IDS = { 1, 156, 261, 1103712, 2032622, 13365322, 261, 968108950 }

local function headshot(userId)
	if userId < 0 then
		userId = FALLBACK_USER_IDS[math.random(1, #FALLBACK_USER_IDS)]
	end
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

function ReverseRaceRollController:KnitStart()
	local player = Players.LocalPlayer
	local pg = player:WaitForChild("PlayerGui")
	local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
	local rollRemote = remotes:WaitForChild("ReverseRaceRoll")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ReverseRaceRoll"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 70
	gui.Enabled = false
	gui.Parent = pg

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.35
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local titleLabel = Instance.new("TextLabel")
	titleLabel.AnchorPoint = Vector2.new(0.5, 0)
	titleLabel.Position = UDim2.new(0.5, 0, 0.24, 0)
	titleLabel.Size = UDim2.fromOffset(640, 52)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.FredokaOne
	titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	titleLabel.TextStrokeTransparency = 0
	titleLabel.TextScaled = true
	titleLabel.Text = "Selecting the next hider..."
	titleLabel.Parent = backdrop
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = 40
	tc.Parent = titleLabel

	local reel = Instance.new("Frame")
	reel.Name = "Reel"
	reel.AnchorPoint = Vector2.new(0.5, 0.5)
	reel.Position = UDim2.new(0.5, 0, 0.5, 0)
	reel.Size = UDim2.new(0.57, 0, 0, CELL_W + 44)
	reel.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	reel.BackgroundTransparency = 0.15
	reel.BorderSizePixel = 0
	reel.ClipsDescendants = true
	reel.Parent = backdrop
	Instance.new("UICorner", reel).CornerRadius = UDim.new(0, 12)

	local indicator = Instance.new("Frame")
	indicator.AnchorPoint = Vector2.new(0.5, 0.5)
	indicator.Position = UDim2.new(0.5, 0, 0.5, 0)
	indicator.Size = UDim2.new(0, 4, 1, -10)
	indicator.BackgroundColor3 = Color3.fromRGB(255, 200, 90)
	indicator.BorderSizePixel = 0
	indicator.ZIndex = 5
	indicator.Parent = reel

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.AnchorPoint = Vector2.new(0, 0.5)
	strip.Position = UDim2.new(0, 0, 0.5, 0)
	strip.Size = UDim2.new(0, 100, 1, 0)
	strip.BackgroundTransparency = 1
	strip.Parent = reel

	local function clearStrip()
		for _, c in ipairs(strip:GetChildren()) do
			c:Destroy()
		end
	end

	local function makeCell(userId, name, layoutOrder)
		local cell = Instance.new("Frame")
		cell.Name = "Cell"
		cell.LayoutOrder = layoutOrder
		cell.AnchorPoint = Vector2.new(0, 0.5)
		cell.Position = UDim2.new(0, (layoutOrder - 1) * SLOT_W, 0.5, 0)
		cell.Size = UDim2.fromOffset(CELL_W, CELL_W + 34)
		cell.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		cell.BorderSizePixel = 0
		cell.Parent = strip
		Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 10)
		local img = Instance.new("ImageLabel")
		img.AnchorPoint = Vector2.new(0.5, 0)
		img.Position = UDim2.new(0.5, 0, 0, 8)
		img.Size = UDim2.fromOffset(CELL_W - 24, CELL_W - 24)
		img.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		img.Image = headshot(userId)
		img.Parent = cell
		Instance.new("UICorner", img).CornerRadius = UDim.new(0, 8)
		local nm = Instance.new("TextLabel")
		nm.AnchorPoint = Vector2.new(0.5, 1)
		nm.Position = UDim2.new(0.5, 0, 1, -6)
		nm.Size = UDim2.new(1, -10, 0, 24)
		nm.BackgroundTransparency = 1
		nm.Font = Enum.Font.GothamBold
		nm.TextColor3 = Color3.fromRGB(255, 255, 255)
		nm.TextScaled = true
		nm.Text = name
		nm.Parent = cell
		local nc = Instance.new("UITextSizeConstraint")
		nc.MaxTextSize = 16
		nc.Parent = nm
		return cell
	end

	local function playSpinSound()
		local t = SoundService:FindFirstChild("Spin")
		if not t then
			return
		end
		local s = t:Clone()
		local sfx = SoundService:FindFirstChild("SFX")
		if sfx then
			s.SoundGroup = sfx
		end
		s.Parent = SoundService
		s:Play()
		task.delay(4, function()
			if s then
				s:Destroy()
			end
		end)
	end

	local rolling = false
	rollRemote.OnClientEvent:Connect(function(data)
		if rolling then
			return
		end
		if type(data) ~= "table" or type(data.players) ~= "table" or #data.players == 0 or not data.winnerUserId then
			return
		end
		rolling = true
		clearStrip()
		titleLabel.Text = "Selecting the next hider..."
		gui.Enabled = true

		local list = data.players
		local winnerName = data.winnerName or "?"
		local TOTAL = 40
		local winnerIndex = TOTAL - 4
		for i = 1, TOTAL do
			local entry
			if i == winnerIndex then
				entry = { userId = data.winnerUserId, name = winnerName }
			else
				entry = list[math.random(1, #list)]
			end
			makeCell(entry.userId, entry.name, i)
		end
		strip.Size = UDim2.new(0, TOTAL * SLOT_W, 1, 0)

		task.wait(0.05)
		local reelW = reel.AbsoluteSize.X
		local function xForIndex(idx)
			local cellCenter = (idx - 1) * SLOT_W + CELL_W / 2
			return reelW / 2 - cellCenter
		end
		strip.Position = UDim2.new(0, xForIndex(1), 0.5, 0)
		local targetX = xForIndex(winnerIndex)
		local dur = data.duration or 3.5
		playSpinSound()
		local tween = TweenService:Create(
			strip,
			TweenInfo.new(dur, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0, targetX, 0.5, 0) }
		)
		tween:Play()
		tween.Completed:Wait()
		strip.Position = UDim2.new(0, targetX, 0.5, 0)

		for _, c in ipairs(strip:GetChildren()) do
			if c:IsA("Frame") and c.LayoutOrder == winnerIndex then
				local stroke = Instance.new("UIStroke")
				stroke.Color = Color3.fromRGB(255, 200, 90)
				stroke.Thickness = 4
				stroke.Transparency = 1
				stroke.Parent = c
				task.spawn(function()
					for _ = 1, 3 do
						stroke.Transparency = 0
						task.wait(0.14)
						stroke.Transparency = 1
						task.wait(0.14)
					end
					stroke.Transparency = 0 -- stays on
				end)
			end
		end
		titleLabel.Text = winnerName .. " is the target!"
		task.wait(1.5)
		gui.Enabled = false
		rolling = false
	end)

	print("[ReverseRaceRollController] ready")
end

return ReverseRaceRollController
