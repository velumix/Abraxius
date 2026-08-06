local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIFolder = Modules:WaitForChild("UI")
local UIColors = require(UIFolder:WaitForChild("UIColors"))
local UIFactory = require(UIFolder:WaitForChild("UIFactory"))

local ANIMATION = {
	IntroDuration = 0.35,
	IntroDelay = 0.15,
	FlashDuration = 0.15,
	PulseDuration = 0.3,
	BarUpdateDuration = 0.25,
	BarShadowDuration = 0.6,
	ShakeDuration = 0.1,
	ShakeIntensity = 3,
	HealGlowDuration = 0.4,
}

local THRESHOLDS = {
	Low = 0.3,
	Critical = 0.15,
}

local HealthBalance = {
	_interface = nil,
	_connections = {},
	_loaded = false,
	_visible = false,
	_lastHealth = 0,
	_maxHealth = 100,
	_isShaking = false,
}

function HealthBalance:_createUI()
	if self.ScreenGui then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HealthBalance"
	screenGui.DisplayOrder = 20
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = PlayerGui

	local container = UIFactory.createFrame(screenGui, {
		Name = "Container",
		Size = UDim2.new(0, 110, 0, 28),
		Position = UDim2.new(1, -6, 0, 68),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = UIColors.Button,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 2,
	}, {
		Corner = UDim.new(0, 8),
		Stroke = {
			Color = UIColors.Stroke,
			Transparency = 0.7,
			Thickness = 1,
		},
		Padding = {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 8),
			PaddingTop = UDim.new(0, 5),
			PaddingBottom = UDim.new(0, 5),
		},
	})

	local accent = UIFactory.createFrame(container, {
		Name = "Accent",
		Size = UDim2.new(0, 2, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = UIColors.Success,
		ZIndex = 3,
	}, {
		Corner = UDim.new(0, 2),
	})
	accent.BackgroundTransparency = 0.2

	local icon = UIFactory.createTextLabel(container, {
		Name = "Icon",
		Size = UDim2.new(0, 18, 1, 0),
		Position = UDim2.new(0, 4, 0, 0),
		Text = "❤️",
		TextColor3 = UIColors.Success,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	local barBackground = UIFactory.createFrame(container, {
		Name = "BarBackground",
		Size = UDim2.new(1, -28, 1, -8),
		Position = UDim2.new(0, 24, 0, 4),
		BackgroundColor3 = UIColors.OxygenBackground,
		BackgroundTransparency = 0.3,
		ZIndex = 2,
	}, {
		Corner = UDim.new(0, 4),
	})

	local barShadow = UIFactory.createFrame(barBackground, {
		Name = "BarShadow",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = UIColors.Success,
		BackgroundTransparency = 0.5,
		ZIndex = 3,
	}, {
		Corner = UDim.new(0, 4),
	})

	local barFill = UIFactory.createFrame(barBackground, {
		Name = "BarFill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = UIColors.Success,
		ZIndex = 4,
	}, {
		Corner = UDim.new(0, 4),
	})

	local healthText = UIFactory.createTextLabel(barBackground, {
		Name = "HealthText",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "100",
		TextColor3 = UIColors.White,
		TextSize = 10,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		ZIndex = 5,
	}, {
		Stroke = {
			Color = UIColors.Black,
			Transparency = 0.5,
			Thickness = 1,
		},
	})

	local glow = UIFactory.createFrame(container, {
		Name = "Glow",
		Size = UDim2.new(1, 4, 1, 4),
		Position = UDim2.new(0, -2, 0, -2),
		BackgroundColor3 = UIColors.Success,
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, {
		Corner = UDim.new(0, 10),
	})

	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = container

	self.ScreenGui = screenGui
	self.Container = container
	self.Icon = icon
	self.BarFill = barFill
	self.BarShadow = barShadow
	self.BarBackground = barBackground
	self.HealthText = healthText
	self.Accent = accent
	self.Scale = scale
	self.Glow = glow
end

function HealthBalance:_updateDisplay(health: number, maxHealth: number)
	if not self.Container or not self.BarFill then return end

	local percentage = math.clamp(health / maxHealth, 0, 1)
	local displayHealth = math.ceil(health)
	local oldPercentage = math.clamp(self._lastHealth / self._maxHealth, 0, 1)

	self._lastHealth = health
	self._maxHealth = maxHealth

	if health >= maxHealth then
		if self._visible then
			self:_hide()
		end
		return
	elseif not self._visible and self._loaded then
		self:_show()
	end

	if self.HealthText then
		self.HealthText.Text = tostring(displayHealth)
	end

	local targetColor = UIColors.Success
	if percentage <= THRESHOLDS.Critical then
		targetColor = UIColors.Error
	elseif percentage <= THRESHOLDS.Low then
		targetColor = UIColors.Warning
	end


	self.BarFill.Size = UDim2.new(percentage, 0, 1, 0)
	self.BarFill.BackgroundColor3 = targetColor

	if self.BarShadow then
		TweenService:Create(self.BarShadow, TweenInfo.new(ANIMATION.BarShadowDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(percentage, 0, 1, 0),
			BackgroundColor3 = targetColor,
		}):Play()
	end

	if self.Accent then
		TweenService:Create(self.Accent, TweenInfo.new(ANIMATION.BarUpdateDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundColor3 = targetColor,
		}):Play()
	end
end

function HealthBalance:_animateDamage()
	if self._isShaking or not self.Container then return end
	self._isShaking = true

	local originalPosition = self.Container.Position
	local shakeSequence = {
		UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset + ANIMATION.ShakeIntensity, originalPosition.Y.Scale, originalPosition.Y.Offset),
		UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset - ANIMATION.ShakeIntensity, originalPosition.Y.Scale, originalPosition.Y.Offset),
		originalPosition,
	}

	local function shake(index)
		if index > #shakeSequence then
			self._isShaking = false
			return
		end

		TweenService:Create(self.Container, TweenInfo.new(ANIMATION.ShakeDuration / 3, Enum.EasingStyle.Linear), {
			Position = shakeSequence[index],
		}).Completed:Connect(function()
			shake(index + 1)
		end)

		TweenService:Create(self.Container, TweenInfo.new(ANIMATION.ShakeDuration / 3, Enum.EasingStyle.Linear), {
			Position = shakeSequence[index],
		}):Play()
	end

	shake(1)

	if self.Glow then
		self.Glow.BackgroundColor3 = UIColors.Error
		self.Glow.BackgroundTransparency = 1

		local glowIn = TweenService:Create(self.Glow, TweenInfo.new(ANIMATION.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.15,
		})

		glowIn.Completed:Connect(function()
			TweenService:Create(self.Glow, TweenInfo.new(ANIMATION.PulseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()
		end)

		glowIn:Play()
	end
end

function HealthBalance:_animateHeal()
	if not self.Glow then return end

	self.Glow.BackgroundColor3 = UIColors.Success
	self.Glow.BackgroundTransparency = 1

	local glowIn = TweenService:Create(self.Glow, TweenInfo.new(ANIMATION.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.2,
	})

	glowIn.Completed:Connect(function()
		TweenService:Create(self.Glow, TweenInfo.new(ANIMATION.HealGlowDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
	end)

	glowIn:Play()
end

function HealthBalance:_show()
	if not self.Container or self._visible then return end

	self._visible = true
	self.Container.Visible = true

	TweenService:Create(self.Scale, TweenInfo.new(ANIMATION.IntroDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

function HealthBalance:_hide()
	if not self.Container or not self._visible then return end

	self._visible = false

	local tween = TweenService:Create(self.Scale, TweenInfo.new(ANIMATION.IntroDuration * 0.7, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Scale = 0,
	})

	tween.Completed:Connect(function()
		if self.Container then
			self.Container.Visible = false
		end
	end)

	tween:Play()
end

function HealthBalance:_connectEvents()
	local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")

	local function onHealthChanged(health)
		local maxHealth = humanoid.MaxHealth

		if not self._loaded then
			self._lastHealth = health
			self._maxHealth = maxHealth
			self._loaded = true

			if health < maxHealth then
				task.wait(ANIMATION.IntroDelay)
				self:_updateDisplay(health, maxHealth)
				self:_show()
			end
			return
		end

		local oldHealth = self._lastHealth
		self:_updateDisplay(health, maxHealth)

		if health < oldHealth then
			self:_animateDamage()
		elseif health > oldHealth and health < maxHealth then
			self:_animateHeal()
		end
	end

	table.insert(self._connections, humanoid:GetPropertyChangedSignal("Health"):Connect(function()
		onHealthChanged(humanoid.Health)
	end))

	table.insert(self._connections, humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(function()
		self:_updateDisplay(humanoid.Health, humanoid.MaxHealth)
	end))

	table.insert(self._connections, humanoid.Died:Connect(function()
		self:_hide()
	end))

	table.insert(self._connections, LocalPlayer.CharacterAdded:Connect(function(newCharacter)
		for _, connection in ipairs(self._connections) do
			connection:Disconnect()
		end
		table.clear(self._connections)

		self._loaded = false
		self._visible = false
		if self.Container then
			self.Container.Visible = false
			self.Scale.Scale = 0
		end

		task.wait(0.5)
		self:_connectEvents()
	end))

	onHealthChanged(humanoid.Health)
end

function HealthBalance.Show()
	if HealthBalance.Container then
		HealthBalance:_show()
	end
end

function HealthBalance.Hide()
	if HealthBalance.Container then
		HealthBalance:_hide()
	end
end

function HealthBalance.Destroy()
	for _, connection in ipairs(HealthBalance._connections) do
		connection:Disconnect()
	end
	table.clear(HealthBalance._connections)

	if HealthBalance.ScreenGui then
		HealthBalance.ScreenGui:Destroy()
		HealthBalance.ScreenGui = nil
		HealthBalance.Container = nil
		HealthBalance.Icon = nil
		HealthBalance.BarFill = nil
		HealthBalance.BarShadow = nil
		HealthBalance.BarBackground = nil
		HealthBalance.HealthText = nil
		HealthBalance.Accent = nil
		HealthBalance.Scale = nil
		HealthBalance.Glow = nil
	end

	HealthBalance._loaded = false
	HealthBalance._visible = false
end

function HealthBalance.Init(interface)
	HealthBalance._interface = interface
	HealthBalance:_createUI()
	HealthBalance:_connectEvents()
end

return HealthBalance
