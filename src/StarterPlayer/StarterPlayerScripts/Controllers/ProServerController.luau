local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Component = require(ReplicatedStorage.Packages.Component)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ProServerConfig = require(ReplicatedStorage.Config.ProServerConfig)

local ProServerController = Knit.CreateController({ Name = "ProServerController" })

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal)

local MatchmakingComponent = Component.new({
	Tag = ProServerConfig.Tag,
	Ancestors = { workspace },
})

function MatchmakingComponent:Construct()
	self._trove = Trove.new()
end

function MatchmakingComponent:Start()
	local host = self:GetPromptHost()
	if not host then
		warn(`[MatchmakingComponent] tagged instance {self.Instance:GetFullName()} has no BasePart for a prompt`)
		return
	end

	local prompt = host:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ProServerPrompt"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0.1
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = host
	end

	prompt.ActionText = "View"
	prompt.ObjectText = "Pro Servers"
	self.Prompt = prompt
end

function MatchmakingComponent:Stop()
	self._trove:Destroy()
	self.Prompt = nil
end

function MatchmakingComponent:GetPromptHost()
	local instance = self.Instance
	if instance:IsA("BasePart") or instance:IsA("Attachment") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return instance:FindFirstChildWhichIsA("BasePart", true)
end

local function rounded(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function stroke(parent, color, thickness, transparency)
	local uiStroke = Instance.new("UIStroke")
	uiStroke.Color = color
	uiStroke.Thickness = thickness
	uiStroke.Transparency = transparency or 0
	uiStroke.Parent = parent
	return uiStroke
end

local function makeLabel(parent, text, size, position, textSize, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.FontFace = FONT
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = textSize
	constraint.Parent = label
	return label
end

local function makeButton(parent, text, size, position, color)
	local button = Instance.new("TextButton")
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.FontFace = FONT
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Size = size
	button.Position = position
	button.AutoButtonColor = true
	button.Parent = parent
	rounded(button, 6)

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = 18
	constraint.Parent = button
	return button
end

function ProServerController:CreateGui()
	if self.Gui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ProServerGui"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.BackgroundColor3 = Color3.fromRGB(8, 10, 18)
	dim.BackgroundTransparency = 0.45
	dim.BorderSizePixel = 0
	dim.Size = UDim2.fromScale(1, 1)
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.38, 0.5)
	panel.BackgroundColor3 = Color3.fromRGB(38, 39, 44)
	panel.BorderSizePixel = 0
	panel.Active = true
	panel.Parent = dim
	rounded(panel, 6)
	stroke(panel, Color3.fromRGB(12, 12, 14), 6)

	local sizeConstraint = Instance.new("UISizeConstraint")
	sizeConstraint.MinSize = Vector2.new(360, 330)
	sizeConstraint.MaxSize = Vector2.new(600, 460)
	sizeConstraint.Parent = panel

	local title = makeLabel(panel, "PRO SERVERS", UDim2.fromScale(0.84, 0.14), UDim2.fromScale(0.08, 0.035), 36, Color3.fromRGB(255, 229, 64))
	stroke(title, Color3.fromRGB(95, 48, 0), 2)
	makeLabel(panel, "30+ Wins", UDim2.fromScale(0.84, 0.08), UDim2.fromScale(0.08, 0.165), 28)

	local description = makeLabel(panel, "Quick join a Pro lobby or enter a server code.", UDim2.fromScale(0.84, 0.09), UDim2.fromScale(0.08, 0.245), 20, Color3.fromRGB(226, 232, 244))
	description.Font = Enum.Font.GothamBold

	local currentCodeLabel = makeLabel(panel, "", UDim2.fromScale(0.84, 0.045), UDim2.fromScale(0.08, 0.305), 18, Color3.fromRGB(255, 225, 98))
	currentCodeLabel.Font = Enum.Font.GothamBold
	self.CurrentCodeLabel = currentCodeLabel

	local list = Instance.new("ScrollingFrame")
	list.Name = "ServerList"
	list.Position = UDim2.fromScale(0.06, 0.35)
	list.Size = UDim2.fromScale(0.88, 0.3)
	list.CanvasSize = UDim2.fromScale(0, 1)
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Color3.fromRGB(0, 205, 255)
	list.BorderSizePixel = 0
	list.BackgroundColor3 = Color3.fromRGB(13, 35, 58)
	list.BackgroundTransparency = 0
	list.BottomImage = ""
	list.MidImage = ""
	list.TopImage = ""
	list.Parent = panel
	rounded(list, 6)
	stroke(list, Color3.fromRGB(0, 206, 255), 2)
	self.ServerList = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	makeLabel(panel, "Join by code", UDim2.fromScale(0.44, 0.06), UDim2.fromScale(0.08, 0.76), 20, Color3.fromRGB(255, 255, 255))

	local input = Instance.new("TextBox")
	input.Name = "JoinCodeInput"
	input.PlaceholderText = "Enter access code"
	input.ClearTextOnFocus = false
	input.BackgroundColor3 = Color3.fromRGB(31, 43, 82)
	input.BorderSizePixel = 0
	input.FontFace = FONT
	input.Text = ""
	input.TextColor3 = Color3.fromRGB(255, 255, 255)
	input.TextSize = 18
	input.TextXAlignment = Enum.TextXAlignment.Center
	input.Size = UDim2.fromScale(0.48, 0.07)
	input.Position = UDim2.fromScale(0.08, 0.82)
	input.Parent = panel
	rounded(input, 6)
	stroke(input, Color3.fromRGB(0, 206, 255), 2)
	self.JoinCodeInput = input

	self.CodeJoinButton = makeButton(panel, "JOIN CODE", UDim2.fromScale(0.34, 0.07), UDim2.fromScale(0.58, 0.82), Color3.fromRGB(0, 196, 255))
	self.JoinButton = makeButton(panel, "QUICK JOIN", UDim2.fromScale(0.4, 0.07), UDim2.fromScale(0.08, 0.69), Color3.fromRGB(94, 225, 71))
	self.JoinButton.TextColor3 = Color3.fromRGB(40, 24, 4)

	self.StatusLabel = makeLabel(panel, "Checking your wins...", UDim2.fromScale(0.84, 0.07), UDim2.fromScale(0.08, 0.89), 19, Color3.fromRGB(255, 221, 83))
	self.StatusLabel.Font = Enum.Font.GothamBold

	local close = makeButton(panel, "X", UDim2.fromOffset(38, 38), UDim2.fromScale(0.89, 0.04), Color3.fromRGB(230, 55, 47))
	close.Font = Enum.Font.GothamBold
	stroke(close, Color3.fromRGB(120, 20, 20), 2)

	local function closeGui()
		gui.Enabled = false
		self:StopRefreshLoop()
	end

	close.MouseButton1Click:Connect(closeGui)
	dim.MouseButton1Click:Connect(closeGui)
	panel.InputBegan:Connect(function() end)
	self.JoinButton.MouseButton1Click:Connect(function() self:QuickJoin() end)
	self.CodeJoinButton.MouseButton1Click:Connect(function() self:JoinByCode(input.Text) end)

	self.Gui = gui
	self.Panel = panel
end

function ProServerController:RenderServers(servers)
	for _, child in ipairs(self.ServerList:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end

	servers = servers or {}
	if #servers == 0 then
		makeLabel(self.ServerList, "No active pro lobbies right now.", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 20, Color3.fromRGB(180, 190, 220))
		self.ServerList.CanvasSize = UDim2.fromScale(0, 0.5)
		return
	end

	for index, server in ipairs(servers) do
		local row = Instance.new("Frame")
		row.Name = `Server{index}`
		row.Size = UDim2.fromScale(1, 0.28)
		row.BackgroundColor3 = Color3.fromRGB(20, 68, 108)
		row.BorderSizePixel = 0
		row.Parent = self.ServerList
		rounded(row, 6)
		stroke(row, Color3.fromRGB(0, 206, 255), 1, 0.05)

		makeLabel(row, string.format("%s's lobby", tostring(server.creatorName or "Unknown")), UDim2.fromScale(0.6, 0.35), UDim2.fromScale(0.04, 0.09), 18)
		makeLabel(row, string.format("%s - %s players", tostring(server.status or "Ready"), tostring(server.playerCount or 0)), UDim2.fromScale(0.3, 0.35), UDim2.fromScale(0.04, 0.49), 16, Color3.fromRGB(160, 222, 255))
		makeLabel(row, string.format("Code: %s", tostring(server.code or "?")), UDim2.fromScale(0.56, 0.35), UDim2.fromScale(0.04, 0.72), 16, Color3.fromRGB(255, 225, 98))

		local join = makeButton(row, self.Eligible and "JOIN" or "LOCKED", UDim2.fromScale(0.22, 0.82), UDim2.fromScale(0.76, 0.09), self.Eligible and Color3.fromRGB(52, 168, 83) or Color3.fromRGB(114, 118, 132))
		join.Active = self.Eligible
		join.Interactable = self.Eligible
		join.MouseButton1Click:Connect(function()
			self:JoinByCode(server.code)
		end)
	end

	self.ServerList.CanvasSize = UDim2.fromScale(0, #servers * 0.31 + 0.06)
end

function ProServerController:SetJoining(isJoining)
	self.Joining = isJoining
	self.JoinButton.Active = not isJoining
	self.JoinButton.Interactable = not isJoining
	self.JoinButton.Text = isJoining and "JOINING..." or "QUICK JOIN"
	self.CodeJoinButton.Active = not isJoining
	self.CodeJoinButton.Interactable = not isJoining
	self.CodeJoinButton.Text = isJoining and "JOINING..." or (self.Eligible and "JOIN CODE" or "JOIN LOCKED")
end

function ProServerController:ApplyStatus(status)
	local wins = tonumber(status and status.wins) or 0
	local requiredWins = tonumber(status and status.requiredWins) or ProServerConfig.RequiredWins
	local remaining = math.max(0, requiredWins - wins)
	self.Eligible = status and status.eligible
	local currentCode = status and status.currentServerCode
	if self.CurrentCodeLabel then
		if type(currentCode) == "string" and currentCode ~= "" then
			self.CurrentCodeLabel.Text = `Your server code: {currentCode}`
		else
			self.CurrentCodeLabel.Text = ""
		end
	end

	if self.Eligible then
		self.StatusLabel.Text = `You have {wins} wins. Pro Server access unlocked.`
		self.StatusLabel.TextColor3 = Color3.fromRGB(156, 255, 174)
		self.JoinButton.BackgroundColor3 = Color3.fromRGB(94, 225, 71)
		self.CodeJoinButton.BackgroundColor3 = Color3.fromRGB(0, 196, 255)
	else
		self.StatusLabel.Text = `Locked: you have {wins} wins. Win {remaining} more to join.`
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
		self.JoinButton.BackgroundColor3 = Color3.fromRGB(112, 116, 130)
		self.CodeJoinButton.BackgroundColor3 = Color3.fromRGB(96, 101, 121)
	end

	self:SetJoining(false)
	self:RenderServers(status and status.servers or ProServerConfig.PreviewServers)
end

function ProServerController:StopRefreshLoop()
	if self.StatusRefreshLoop then
		task.cancel(self.StatusRefreshLoop)
		self.StatusRefreshLoop = nil
	end
end

function ProServerController:RefreshStatus()
	if not self.Gui or not self.Gui.Enabled then
		return
	end

	local ok, status = pcall(function()
		return self.ProServerService:GetStatus()
	end)
	if ok and type(status) == "table" then
		self:ApplyStatus(status)
	else
		self.StatusLabel.Text = "Could not refresh pro server list."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
	end
end

function ProServerController:Open()
	self:CreateGui()
	self.Gui.Enabled = true
	self.Panel.Size = UDim2.fromScale(0.38, 0.46)
	TweenService:Create(self.Panel, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.42, 0.48),
	}):Play()

	self.StatusLabel.Text = "Checking pro lobbies..."
	self.StatusLabel.TextColor3 = Color3.fromRGB(160, 222, 255)
	self:RefreshStatus()

	self:StopRefreshLoop()
	self.StatusRefreshLoop = task.spawn(function()
		while self.Gui and self.Gui.Enabled do
			task.wait(ProServerConfig.Registry.ListRefreshInterval)
			self:RefreshStatus()
		end
	end)
end

function ProServerController:QuickJoin()
	if self.Joining then return end
	self:SetJoining(true)
	local ok, result = pcall(function()
		return self.ProServerService:QuickJoin()
	end)
	if not ok or type(result) ~= "table" then
		self.StatusLabel.Text = "Could not start Pro Server join. Try again."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
		self:SetJoining(false)
		return
	end
	if not result.ok then
		if result.reason == "notEnoughWins" then
			self:ApplyStatus(result)
		elseif result.reason == "cooldown" then
			self.StatusLabel.Text = `Wait {tonumber(result.retryAfter) or 1}s before trying again.`
			self.StatusLabel.TextColor3 = Color3.fromRGB(255, 221, 83)
			self:SetJoining(false)
		elseif result.reason == "registryBusy" then
			self.StatusLabel.Text = "Pro Servers are busy. Try again in a moment."
			self.StatusLabel.TextColor3 = Color3.fromRGB(255, 221, 83)
			self:SetJoining(false)
		elseif result.reason == "studioUnsupported" then
			self.StatusLabel.Text = "Publish the game to test Pro Server teleport."
			self.StatusLabel.TextColor3 = Color3.fromRGB(255, 221, 83)
			self:SetJoining(false)
		else
			self.StatusLabel.Text = "Teleport failed. Try again in a moment."
			self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
			self:SetJoining(false)
		end
	end
end

function ProServerController:JoinByCode(accessCode)
	if self.Joining then return end
	if not self.Eligible then
		self.StatusLabel.Text = "You need 30 wins to join Pro lobbies."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
		return
	end
	if type(accessCode) ~= "string" or accessCode:gsub("%s", "") == "" then
		self.StatusLabel.Text = "Enter a valid access code."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
		return
	end

	self:SetJoining(true)
	local ok, result = pcall(function()
		return self.ProServerService:JoinByCode(accessCode)
	end)
	if not ok or type(result) ~= "table" then
		self.StatusLabel.Text = "Could not join with that code."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
		self:SetJoining(false)
		return
	end
	if result.ok then
		self.StatusLabel.Text = "Joining pro lobby..."
		self.StatusLabel.TextColor3 = Color3.fromRGB(160, 222, 255)
		return
	end

	if result.reason == "lobbyUnavailable" then
		self.StatusLabel.Text = "That lobby is not active."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
	elseif result.reason == "cooldown" then
		self.StatusLabel.Text = `Wait {tonumber(result.retryAfter) or 1}s before trying again.`
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 221, 83)
	elseif result.reason == "registryBusy" then
		self.StatusLabel.Text = "Pro Servers are busy. Try again in a moment."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 221, 83)
	elseif result.reason == "studioUnsupported" then
		self.StatusLabel.Text = "Publish the game to test Pro Server teleport."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 221, 83)
	else
		self.StatusLabel.Text = "Could not join. Try again in a moment."
		self.StatusLabel.TextColor3 = Color3.fromRGB(255, 154, 154)
	end
	self:SetJoining(false)
end

function ProServerController:MountMatchmaking(component)
	if not component.Prompt then return end
	self:UnmountMatchmaking(component)
	self.ComponentTroves[component] = Trove.new()
	self.ComponentTroves[component]:Add(component.Prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer and triggeringPlayer ~= player then return end
		self:Open()
	end))
end

function ProServerController:UnmountMatchmaking(component)
	local trove = self.ComponentTroves[component]
	if trove then
		trove:Destroy()
		self.ComponentTroves[component] = nil
	end
end

function ProServerController:WatchMatchmakingComponents()
	MatchmakingComponent.Started:Connect(function(component)
		self:MountMatchmaking(component)
	end)
	MatchmakingComponent.Stopped:Connect(function(component)
		self:UnmountMatchmaking(component)
	end)
	for _, component in ipairs(MatchmakingComponent:GetAll()) do
		self:MountMatchmaking(component)
	end
end

function ProServerController:KnitStart()
	self.ProServerService = Knit.GetService("ProServerService")
	self.ComponentTroves = setmetatable({}, { __mode = "k" })
	self:CreateGui()
	self:WatchMatchmakingComponents()
end

return ProServerController
