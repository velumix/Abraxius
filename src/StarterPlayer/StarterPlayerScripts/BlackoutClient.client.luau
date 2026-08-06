-- BlackoutClient: blacks out the seeker's screen during the hide phase so they can't
-- see where hiders go. Server fires Blackout(true) at hide start, Blackout(false) on release.
-- Shows a live countdown using the StateChanged timer while blacked out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local Blackout = Remotes:WaitForChild("Blackout")
local StateChanged = Remotes:WaitForChild("StateChanged")

local active = false

local function getParts()
	local pg = player:WaitForChild("PlayerGui")
	local gui = pg:WaitForChild("BlackoutGui")
	local black = gui:WaitForChild("Black")
	local center = black:WaitForChild("Center")
	return black, center:WaitForChild("Timer"), center:FindFirstChild("Role"), center:FindFirstChild("Title"), center:FindFirstChild("Subtitle")
end

local function fmt(t)
	t = math.max(0, math.floor(t or 0))
	local m = math.floor(t / 60)
	local s = t % 60
	return string.format("%d:%02d", m, s)
end

local RED = "220,70,70"
local function rich(rgb, text)
	return string.format('<font color="rgb(%s)">%s</font>', rgb, tostring(text))
end

local function styleLine(lbl, yOffset)
	lbl.RichText = true
	lbl.TextScaled = false
	lbl.TextSize = 32
	lbl.TextWrapped = false
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextXAlignment = Enum.TextXAlignment.Center
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.AnchorPoint = Vector2.new(0.5, 0.5)
	lbl.Position = UDim2.new(0.5, 0, 0.5, yOffset)
	lbl.Size = UDim2.new(1, 0, 0, 40)
end

local function styleParts(timer, role, title, subtitle)
	if timer then
		styleLine(timer, 0)
	end
	if role then
		styleLine(role, 40)
		role.Text = "You are a " .. rich(RED, "Seeker") .. ". Get ready to hunt!"
	end
	if title then title.Visible = false end
	if subtitle then subtitle.Visible = false end
end

local function setTimer(timer, timeLeft)
	if timer then
		timer.Text = rich(RED, "Time Until You're Released: ") .. fmt(timeLeft)
	end
end

Blackout.OnClientEvent:Connect(function(show, duration)
	active = show and true or false
	local black, timer, role, title, subtitle = getParts()
	styleParts(timer, role, title, subtitle)
	black.Visible = active
	if timer then timer.Visible = active end
	if role then role.Visible = active end
	if active then
		setTimer(timer, duration or 0)
		-- play the "Sus" sound the instant the seeker's black screen appears
		local SoundService = game:GetService("SoundService")
		local template = SoundService:FindFirstChild("Sus")
		if template then
			local s = template:Clone()
			local sfx = SoundService:FindFirstChild("SFX")
			if sfx then s.SoundGroup = sfx end
			s.Parent = SoundService
			s:Play()
			task.delay((s.TimeLength > 0 and s.TimeLength or 5) + 0.2, function()
				if s then s:Destroy() end
			end)
		end
	end
end)

-- While blacked out, drive the big countdown from the server's hide-phase timer.
-- Also clear locally when the server leaves HIDE, so a missed Blackout(false) cannot stick forever.
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end

	if data.state and data.state ~= "HIDE" then
		active = false
		local black, timer, role = getParts()
		black.Visible = false
		if timer then timer.Visible = false end
		if role then role.Visible = false end
		return
	end

	if not active then return end
	local _, timer = getParts()
	if data.timeLeft ~= nil then
		setTimer(timer, data.timeLeft)
	end
end)
