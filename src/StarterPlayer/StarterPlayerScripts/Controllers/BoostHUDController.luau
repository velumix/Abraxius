local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local BoostConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("BoostConfig"))
local EventDefinitions = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("EventDefinitions"))
local Luck = require(ReplicatedStorage:WaitForChild("SparkMod"):WaitForChild("Luck"))

local BoostHUDController = Knit.CreateController({
	Name = "BoostHUDController",
})

local TOOLTIP_SIZE = Vector2.new(190, 48)
local TOOLTIP_MARGIN = 8
local TOOLTIP_CURSOR_OFFSET = Vector2.new(14, 18)
local TIMED_EVENT_BOOSTS = {
	SpeedBoost = {
		layoutOrder = 2,
	},
	SmallSize = {
		layoutOrder = 3,
	},
}

function BoostHUDController:_formatTime(seconds)
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	return string.format("%d:%02d", minutes, remainder)
end

function BoostHUDController:_remainingFor(modifier)
	if not modifier or not modifier.expiresAt then
		return 0
	end
	return math.max(0, modifier.expiresAt - os.time())
end

function BoostHUDController:_setTooltip(config, remaining, owner)
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else self.hud.AbsoluteSize
	local mouse = UserInputService:GetMouseLocation()
	local x = mouse.X + TOOLTIP_CURSOR_OFFSET.X
	local y = mouse.Y + TOOLTIP_CURSOR_OFFSET.Y

	if x + TOOLTIP_SIZE.X > viewport.X - TOOLTIP_MARGIN then
		x = mouse.X - TOOLTIP_CURSOR_OFFSET.X - TOOLTIP_SIZE.X
	end
	if y + TOOLTIP_SIZE.Y > viewport.Y - TOOLTIP_MARGIN then
		y = mouse.Y - TOOLTIP_CURSOR_OFFSET.Y - TOOLTIP_SIZE.Y
	end

	x = math.clamp(x, TOOLTIP_MARGIN, viewport.X - TOOLTIP_MARGIN - TOOLTIP_SIZE.X)
	y = math.clamp(y, TOOLTIP_MARGIN, viewport.Y - TOOLTIP_MARGIN - TOOLTIP_SIZE.Y)

	self.tooltip.Position = UDim2.fromOffset(x, y)
	self.tooltip.Text = string.format("%s\n%s left", config.displayName, self:_formatTime(remaining))
	self.tooltipOwner = owner
	self.tooltip.Visible = true
end

function BoostHUDController:_hideTooltip(owner)
	if self.tooltip and (owner == nil or self.tooltipOwner == owner) then
		self.tooltip.Visible = false
		self.tooltipOwner = nil
	end
end

function BoostHUDController:_shake(button)
	local original = button.Rotation
	local tweens = {
		TweenService:Create(button, TweenInfo.new(0.055), { Rotation = original - 12 }),
		TweenService:Create(button, TweenInfo.new(0.055), { Rotation = original + 12 }),
		TweenService:Create(button, TweenInfo.new(0.055), { Rotation = original - 7 }),
		TweenService:Create(button, TweenInfo.new(0.055), { Rotation = original }),
	}
	task.spawn(function()
		for _, tween in ipairs(tweens) do
			tween:Play()
			tween.Completed:Wait()
		end
	end)
end

function BoostHUDController:_clearButton()
	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end
	if self.activeButton then
		self.activeButton:Destroy()
		self.activeButton = nil
	end
	self.activeModifier = nil
	self:_hideTooltip("Luck")
end

function BoostHUDController:_isBoostModifier(modifier)
	return modifier.source == BoostConfig.EventSource or modifier.source == BoostConfig.CommandSource
end

function BoostHUDController:_chooseLuckModifier()
	local best = nil
	for _, modifier in ipairs(Luck:GetModifiers(BoostConfig.Channel)) do
		if self:_isBoostModifier(modifier) and modifier.expiresAt then
			if not best or modifier.amount > best.amount then
				best = modifier
			end
		end
	end
	return best
end

function BoostHUDController:_renderModifier(modifier)
	local config = modifier and BoostConfig.fromMultiplier(modifier.amount)
	if not modifier or not config then
		self:_clearButton()
		return
	end

	if self.activeModifier == modifier and self.activeButton then
		return
	end

	self:_clearButton()
	self.activeModifier = modifier

	local button = self.template:Clone()
	button.Name = "Luck_" .. config.id
	button.LayoutOrder = 1
	button.Visible = true
	button.Image = displayConfig.image or ""
	button.Rotation = 0
	button.Parent = self.boostsFrame
	self.activeButton = button

	local timeLabel = button:FindFirstChild("TimeLabel")
	if timeLabel and timeLabel:IsA("TextLabel") then
		timeLabel.Text = self:_formatTime(self:_remainingFor(modifier))
	end

	button.MouseEnter:Connect(function()
		self:_setTooltip(config, self:_remainingFor(modifier), "Luck")
	end)
	button.MouseLeave:Connect(function()
		self:_hideTooltip("Luck")
	end)
	button.MouseButton1Click:Connect(function()
		self:_shake(button)
	end)

	self.updateConnection = RunService.RenderStepped:Connect(function()
		local remaining = self:_remainingFor(modifier)
		if remaining <= 0 then
			self:_clearButton()
			return
		end
		if timeLabel and timeLabel:IsA("TextLabel") then
			timeLabel.Text = self:_formatTime(remaining)
		end
		if self.tooltip.Visible and self.tooltipOwner == "Luck" then
			self:_setTooltip(config, remaining, "Luck")
		end
	end)
end

function BoostHUDController:_remainingForEvent(event)
	if not event then
		return 0
	end
	if event.paused then
		return math.max(0, event.paused)
	end
	if not event.endsAt then
		return 0
	end
	return math.max(0, event.endsAt - os.time())
end

function BoostHUDController:_clearEventButton(eventName)
	local updateConnection = self.eventUpdateConnections[eventName]
	if updateConnection then
		updateConnection:Disconnect()
		self.eventUpdateConnections[eventName] = nil
	end
	local button = self.eventButtons[eventName]
	if button then
		button:Destroy()
		self.eventButtons[eventName] = nil
	end
	self.eventEndsAt[eventName] = nil
	self:_hideTooltip(eventName)
end

function BoostHUDController:_renderEventButton(eventName)
	local config = TIMED_EVENT_BOOSTS[eventName]
	local event = config and self.eventController and self.eventController.activeEvents[eventName]
	if not config or not event then
		self:_clearEventButton(eventName)
		return
	end

	local displayName = EventDefinitions.getDisplayName(eventName, event.config)
	local renderKey = tostring(event.endsAt) .. "|" .. displayName
	if self.eventButtons[eventName] and self.eventEndsAt[eventName] == renderKey then
		return
	end

	self:_clearEventButton(eventName)
	self.eventEndsAt[eventName] = renderKey
	local displayConfig = {
		displayName = displayName,
		image = EventDefinitions.getIcon(eventName, event.config),
	}

	local button = self.template:Clone()
	button.Name = eventName
	button.LayoutOrder = config.layoutOrder
	button.Visible = true
	button.Image = displayConfig.image or ""
	button.Rotation = 0
	button.Parent = self.boostsFrame
	self.eventButtons[eventName] = button

	local timeLabel = button:FindFirstChild("TimeLabel")
	local function remaining()
		return self:_remainingForEvent(self.eventController.activeEvents[eventName])
	end
	if timeLabel and timeLabel:IsA("TextLabel") then
		timeLabel.Text = self:_formatTime(remaining())
	end

	button.MouseEnter:Connect(function()
		self:_setTooltip(displayConfig, remaining(), eventName)
	end)
	button.MouseLeave:Connect(function()
		self:_hideTooltip(eventName)
	end)
	button.MouseButton1Click:Connect(function()
		self:_shake(button)
	end)

	self.eventUpdateConnections[eventName] = RunService.RenderStepped:Connect(function()
		local activeEvent = self.eventController.activeEvents[eventName]
		if not activeEvent then
			self:_clearEventButton(eventName)
			return
		end
		local timeRemaining = self:_remainingForEvent(activeEvent)
		if timeRemaining <= 0 then
			self:_clearEventButton(eventName)
			return
		end
		if timeLabel and timeLabel:IsA("TextLabel") then
			timeLabel.Text = self:_formatTime(timeRemaining)
		end
		if self.tooltip.Visible and self.tooltipOwner == eventName then
			self:_setTooltip(displayConfig, timeRemaining, eventName)
		end
	end)
end

function BoostHUDController:_refresh()
	self:_renderModifier(self:_chooseLuckModifier())
end

function BoostHUDController:_bindLuck()
	task.spawn(function()
		Luck:ListModifiersAsync(BoostConfig.Channel)
		self:_refresh()
	end)

	self.modifierAppliedConnection = Luck.ModifierApplied:Connect(function(modifier)
		if modifier.channel == BoostConfig.Channel then
			self:_refresh()
		end
	end)

	self.modifierRemovedConnection = Luck.ModifierRemoved:Connect(function(channel)
		if channel == BoostConfig.Channel then
			self:_refresh()
		end
	end)
end

function BoostHUDController:_bindEventBoosts()
	self.eventController = Knit.GetController("EventController")
	self.eventAddedConnection = self.eventController.EventAdded:Connect(function(eventName)
		if TIMED_EVENT_BOOSTS[eventName] then
			self:_renderEventButton(eventName)
		end
	end)
	self.eventRemovedConnection = self.eventController.EventRemoved:Connect(function(eventName)
		if TIMED_EVENT_BOOSTS[eventName] then
			self:_clearEventButton(eventName)
		end
	end)
	self.eventOverriddenConnection = self.eventController.EventOverridden:Connect(function(eventName)
		if TIMED_EVENT_BOOSTS[eventName] then
			self:_renderEventButton(eventName)
		end
	end)
	self.eventPausedConnection = self.eventController.EventPaused:Connect(function(eventName)
		if TIMED_EVENT_BOOSTS[eventName] then
			self:_renderEventButton(eventName)
		end
	end)
	self.eventResumedConnection = self.eventController.EventResumed:Connect(function(eventName)
		if TIMED_EVENT_BOOSTS[eventName] then
			self:_renderEventButton(eventName)
		end
	end)
	for eventName in TIMED_EVENT_BOOSTS do
		self:_renderEventButton(eventName)
	end
end

function BoostHUDController:_setupHud()
	local player = Players.LocalPlayer
	self.hud = player:WaitForChild("PlayerGui"):WaitForChild("Hud")
	self.boostsFrame = self.hud:WaitForChild("Boosts")
	self.template = self.boostsFrame:WaitForChild("Template")
	self.template.Visible = false

	self.tooltip = Instance.new("TextLabel")
	self.tooltip.Name = "BoostTooltip"
	self.tooltip.AnchorPoint = Vector2.new(0, 0)
	self.tooltip.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	self.tooltip.BackgroundTransparency = 0.08
	self.tooltip.BorderSizePixel = 0
	self.tooltip.Font = Enum.Font.FredokaOne
	self.tooltip.TextColor3 = Color3.fromRGB(255, 255, 255)
	self.tooltip.TextSize = 16
	self.tooltip.TextWrapped = true
	self.tooltip.Visible = false
	self.tooltip.ZIndex = 200
	self.tooltip.Size = UDim2.fromOffset(TOOLTIP_SIZE.X, TOOLTIP_SIZE.Y)
	self.tooltip.Parent = self.hud
	Instance.new("UICorner", self.tooltip).CornerRadius = UDim.new(0, 8)
end

function BoostHUDController:KnitStart()
	self.activeButton = nil
	self.activeModifier = nil
	self.updateConnection = nil
	self.eventButtons = {}
	self.eventUpdateConnections = {}
	self.eventEndsAt = {}
	self.tooltipOwner = nil

	local initOk, initErr = pcall(function()
		Luck:Init()
	end)
	if not initOk then
		warn("[BoostHUDController] Luck init failed: " .. tostring(initErr))
		return
	end

	local setupOk, setupErr = pcall(function()
		self:_setupHud()
		self:_bindLuck()
		self:_bindEventBoosts()
	end)
	if not setupOk then
		warn("[BoostHUDController] setup failed: " .. tostring(setupErr))
	end
end

return BoostHUDController