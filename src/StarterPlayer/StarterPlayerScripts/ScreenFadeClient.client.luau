-- ScreenFadeClient: full-screen black fade driven by the ScreenFade remote.
-- Server: ScreenFade:FireClient(player, action, opts)
--   "in"  -> fade to black
--   "out" -> fade back to clear

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local ScreenFade = Remotes:WaitForChild("ScreenFade")
local StateChanged = Remotes:WaitForChild("StateChanged")

local pg = player:WaitForChild("PlayerGui")
local gui = pg:WaitForChild("ScreenFadeGui")
local black = gui:WaitForChild("Black")
local message = black:WaitForChild("Message")
local msgStroke = message:FindFirstChildOfClass("UIStroke")

local token = 0
local DEFAULT_MAX_HOLD = 20

local function log(action, info)
	--print(string.format("[ScreenFadeClient] %s | token=%d | %s", tostring(action), token, tostring(info)))
end

local function playSound(name)
	if not name then return end
	local t = SoundService:FindFirstChild(name)
	if not t then return end
	local s = t:Clone()
	local sfx = SoundService:FindFirstChild("SFX")
	if sfx then s.SoundGroup = sfx end
	s.Parent = SoundService
	s:Play()
	task.delay((s.TimeLength > 0 and s.TimeLength or 3) + 0.2, function() s:Destroy() end)
end

local function setMessage(text)
	if text and text ~= "" then
		message.Text = text
		message.TextTransparency = 0
		if msgStroke then msgStroke.Transparency = 0 end
	else
		message.Text = ""
		message.TextTransparency = 1
		if msgStroke then msgStroke.Transparency = 1 end
	end
end

fadeIn = function(opts)
	opts = opts or {}
	token += 1
	local myToken = token
	local fadeTime = opts.fadeTime or 0.4

	log("in", "fadeTime=" .. fadeTime .. " msg=" .. tostring(opts.message) .. " hold=" .. tostring(opts.hold) .. " maxHold=" .. tostring(opts.maxHold))
	black.Visible = true
	playSound(opts.sound)

	if fadeTime <= 0 then
		black.BackgroundTransparency = 0
		setMessage(opts.message)
	else
		TweenService:Create(black, TweenInfo.new(fadeTime), { BackgroundTransparency = 0 }):Play()
		task.delay(fadeTime, function()
			if myToken ~= token then return end
			setMessage(opts.message)
		end)
	end

	if opts.autoOut and opts.hold then
		task.delay(math.max(fadeTime, 0) + opts.hold, function()
			if myToken ~= token then return end
			fadeOut({ fadeTime = fadeTime })
		end)
	end

	local maxHold = opts.maxHold
	if maxHold == nil then
		maxHold = DEFAULT_MAX_HOLD
	end
	if maxHold and maxHold > 0 then
		task.delay(math.max(fadeTime, 0) + maxHold, function()
			if myToken ~= token then return end
			fadeOut({ fadeTime = 0.35 })
		end)
	end
end

fadeOut = function(opts)
	opts = opts or {}
	token += 1
	local myToken = token
	local fadeTime = opts.fadeTime or 0.4
	log("out", "fadeTime=" .. fadeTime)
	setMessage(nil)
	local tween = TweenService:Create(black, TweenInfo.new(fadeTime), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Connect(function()
		if myToken == token then
			black.Visible = false
			log("out.completed", "hidden")
		else
			log("out.completed", "stale token=" .. myToken .. " current=" .. token)
		end
	end)
	-- Hide the frame even if a stale tween completes after a newer fade-in has taken over.
	task.delay(fadeTime + 0.5, function()
		if myToken ~= token and black.BackgroundTransparency >= 0.99 then
			black.Visible = false
		end
	end)
end

ScreenFade.OnClientEvent:Connect(function(action, opts)
	if action == "in" then
		fadeIn(opts)
	elseif action == "out" then
		fadeOut(opts)
	end
end)

-- Force-clear the fade whenever the server returns us to a lobby state.
local LOBBY_STATES = { INTERMISSION = true, LOBBY = true, WAITING = true, AFK = true }
StateChanged.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.state and LOBBY_STATES[data.state] then
		log("state.clear", tostring(data.state))
		black.Visible = false
		black.BackgroundTransparency = 1
		setMessage(nil)
		token += 1
	end
end)
