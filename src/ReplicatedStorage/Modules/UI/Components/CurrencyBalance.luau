local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local UIFolder = Modules:WaitForChild("UI")
local Mince = require(Modules:WaitForChild("Mince"))
local UIColors = require(UIFolder:WaitForChild("UIColors"))
local UIFactory = require(UIFolder:WaitForChild("UIFactory"))

local StateFolder = ReplicatedStorage.Modules.Mince.Addons.state:WaitForChild("States")

local function GetCurrencyStateName(userId)
	return "Currency_" .. tostring(userId)
end

local function GetEcoPointsStateName(userId)
	return "EcoPoints_" .. tostring(userId)
end

local function WaitForState(stateName, timeout)
	timeout = timeout or 30
	local startTime = os.clock()
	local warned = false

	while true do
		if StateFolder:FindFirstChild(stateName) then
			return Mince:GetState(stateName)
		end

		if not warned and os.clock() - startTime > timeout then
			warn("Timed out waiting for Mince state, continuing to wait:", stateName)
			warned = true
		end

		StateFolder.ChildAdded:Wait()
	end
end

local ANIMATION = {
	IntroDuration = 0.35,
	IntroDelay = 0.1,

	FlashDuration = 0.1,
	FadeDuration = 0.25,
	FadeDelay = 0.35,

	RotationDuration = 0.15,
	RotationAngle = 8,
	RotationReturn = 0.25,

	PulseScaleGain = 1.08,
	PulseScaleLoss = 1.04,
	PulseDuration = 0.2,
	PulseReturn = 0.35,

	GlowDuration = 0.15,
	GlowFadeOut = 0.6,
	GlowTransparency = 0.2,

	ContainerTransparency = 0.3,
	ContainerPulseTransparency = 0.1,
	ContainerPulseDuration = 0.1,
	ContainerReturn = 0.4,
}

local CurrencyBalance = {
	_connections = {},
	_interface = nil,
	_loaded = false,
	_stateConnected = false,
}

local function formatNumber(amount: number): string
	local formatted = tostring(amount)

	if amount >= 1000 then
		formatted = string.reverse(formatted):gsub("(%d%d%d)", "%1,"):gsub(",$", "")
		formatted = string.reverse(formatted)
	end

	return formatted
end

local function createChangeText(amount: number): string
	local prefix = if amount > 0 then "+" else "-"
	return prefix .. formatNumber(math.abs(amount))
end

function CurrencyBalance:_createUI()
	if self.ScreenGui then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "CurrencyBalance"
	screenGui.DisplayOrder = 20
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = PlayerGui

	local container = UIFactory.createFrame(screenGui, {
		Name = "Container",
		Size = UDim2.new(0, 85, 0, 28),
		Position = UDim2.new(1, -6, 0, 4),
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
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
	})

	local accent = UIFactory.createFrame(container, {
		Name = "Accent",
		Size = UDim2.new(0, 2, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = UIColors.Warning,
		ZIndex = 3,
	}, {
		Corner = UDim.new(0, 2),
	})
	accent.BackgroundTransparency = 0.2

	local icon = UIFactory.createTextLabel(container, {
		Name = "Icon",
		Size = UDim2.new(0, 18, 1, 0),
		Position = UDim2.new(0, 4, 0, 0),
		Text = "💰",
		TextColor3 = UIColors.Warning,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	local balanceLabel = UIFactory.createTextLabel(container, {
		Name = "BalanceLabel",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 24, 0, 0),
		Text = "0",
		TextColor3 = UIColors.White,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})

	local glow = UIFactory.createFrame(container, {
		Name = "Glow",
		Size = UDim2.new(1, 4, 1, 4),
		Position = UDim2.new(0, -2, 0, -2),
		BackgroundColor3 = UIColors.Warning,
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, {
		Corner = UDim.new(0, 10),
	})

	local scale = UIFactory.createUITweenScale(container, {
		Name = "Scale",
		Scale = 0.92,
	})

	local ecoContainer = UIFactory.createFrame(screenGui, {
		Name = "EcoContainer",
		Size = UDim2.new(0, 85, 0, 28),
		Position = UDim2.new(1, -96, 0, 4),
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
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
		},
	})

	local ecoAccent = UIFactory.createFrame(ecoContainer, {
		Name = "Accent",
		Size = UDim2.new(0, 2, 1, 0),
		Position = UDim2.new(0, 0, 0, 0),
		BackgroundColor3 = UIColors.Success,
		ZIndex = 3,
	}, {
		Corner = UDim.new(0, 2),
	})
	ecoAccent.BackgroundTransparency = 0.2

	local ecoIcon = UIFactory.createTextLabel(ecoContainer, {
		Name = "Icon",
		Size = UDim2.new(0, 18, 1, 0),
		Position = UDim2.new(0, 4, 0, 0),
		Text = "♻️",
		TextColor3 = UIColors.Success,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	local ecoLabel = UIFactory.createTextLabel(ecoContainer, {
		Name = "BalanceLabel",
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.new(0, 24, 0, 0),
		Text = "0",
		TextColor3 = UIColors.White,
		TextSize = 15,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})

	local ecoScale = UIFactory.createUITweenScale(ecoContainer, {
		Name = "Scale",
		Scale = 0.92,
	})

	self.ScreenGui = screenGui

	self.Container = container
	self.Icon = icon
	self.BalanceLabel = balanceLabel
	self.Glow = glow
	self.Scale = scale

	self.EcoContainer = ecoContainer
	self.EcoIcon = ecoIcon
	self.EcoLabel = ecoLabel
	self.EcoScale = ecoScale
end

function CurrencyBalance:_connectState()
	if self._stateConnected then
		return
	end
	self._stateConnected = true

	local currencyState = WaitForState(GetCurrencyStateName(LocalPlayer.UserId))
	local ecoState = WaitForState(GetEcoPointsStateName(LocalPlayer.UserId))

	local isFirstCurrency = true
	local currencyConnection = currencyState:Observe("Balance", function(newBalance, oldBalance)
		local change = oldBalance ~= nil and (newBalance - oldBalance) or 0
		self:_updateBalance(newBalance, change, isFirstCurrency)
		if isFirstCurrency then
			isFirstCurrency = false
			self:_show()
		end
	end)
	table.insert(self._connections, currencyConnection)

	local isFirstEco = true
	local ecoConnection = ecoState:Observe("Balance", function(newBalance, oldBalance)
		local change = oldBalance ~= nil and (newBalance - oldBalance) or 0
		self:_updateEcoBalance(newBalance, change, isFirstEco)
		if isFirstEco then
			isFirstEco = false
			self:_show()
		end
	end)
	table.insert(self._connections, ecoConnection)
end

function CurrencyBalance:_show()
	if not self.Container or self._loaded then
		if self.Container then self.Container.Visible = true end
		if self.EcoContainer then self.EcoContainer.Visible = true end
		return
	end

	self.Container.Visible = true
	self.EcoContainer.Visible = true

	self.Scale.Scale = 0.85
	self.EcoScale.Scale = 0.85

	local introTween = TweenService:Create(self.Scale, TweenInfo.new(ANIMATION.IntroDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, ANIMATION.IntroDelay), {
		Scale = 1,
	})
	local ecoIntroTween = TweenService:Create(self.EcoScale, TweenInfo.new(ANIMATION.IntroDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, ANIMATION.IntroDelay), {
		Scale = 1,
	})

	introTween:Play()
	ecoIntroTween:Play()
	self._loaded = true
end

function CurrencyBalance:_updateBalance(newBalance: number, changeAmount: number, suppressAnimation: boolean?)
	if not self.Container then
		return
	end

	self.BalanceLabel.Text = formatNumber(math.floor(newBalance))

	if suppressAnimation or changeAmount == 0 then
		return
	end

	self:_animateChange(changeAmount)
end

function CurrencyBalance:_updateEcoBalance(newBalance: number, changeAmount: number, suppressAnimation: boolean?)
	if not self.EcoContainer then
		return
	end

	self.EcoLabel.Text = formatNumber(math.floor(newBalance))

	if suppressAnimation or changeAmount == 0 then
		return
	end

	self:_animateEcoChange(changeAmount)
end

function CurrencyBalance:_animateEcoChange(changeAmount: number)
	if not self.EcoScale then
		return
	end

	local icon = self.EcoIcon
	local isGain = changeAmount > 0

	if icon then
		local originalRotation = icon.Rotation
		local targetRotation = isGain and 360 or -360

		TweenService:Create(icon, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = targetRotation
		}):Play()

		task.delay(0.5, function()
			icon.Rotation = 0
		end)
	end

	local newScale = self.EcoScale
	local targetScale = isGain and ANIMATION.PulseScaleGain or ANIMATION.PulseScaleLoss

	local pulseTween = TweenService:Create(newScale, TweenInfo.new(ANIMATION.PulseDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = targetScale,
	})

	local pulseConn
	pulseConn = pulseTween.Completed:Connect(function()
		if pulseConn then
			pulseConn:Disconnect()
		end
		TweenService:Create(newScale, TweenInfo.new(ANIMATION.PulseReturn, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)
	pulseTween:Play()
end

function CurrencyBalance:_animateChange(changeAmount: number)
	if not self.Scale then
		return
	end

	local icon = self.Icon
	local container = self.Container
	local isGain = changeAmount > 0

	if icon then
		local flashColor = isGain and UIColors.Success or UIColors.Error
		local originalColor = UIColors.Warning

		TweenService:Create(icon, TweenInfo.new(ANIMATION.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextColor3 = flashColor,
		}):Play()

		local originalRotation = icon.Rotation
		local targetRotation = isGain and ANIMATION.RotationAngle or -ANIMATION.RotationAngle

		TweenService:Create(icon, TweenInfo.new(ANIMATION.RotationDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Rotation = targetRotation
		}):Play()

		task.delay(ANIMATION.RotationDuration, function()
			if icon.Parent then
				TweenService:Create(icon, TweenInfo.new(ANIMATION.RotationReturn, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
					Rotation = originalRotation
				}):Play()
			end
		end)

		task.delay(ANIMATION.FadeDelay, function()
			if icon.Parent then
				TweenService:Create(icon, TweenInfo.new(ANIMATION.FadeDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
					TextColor3 = originalColor
				}):Play()
			end
		end)
	end

	local newScale = self.Scale
	local targetScale = isGain and ANIMATION.PulseScaleGain or ANIMATION.PulseScaleLoss

	local pulseTween = TweenService:Create(newScale, TweenInfo.new(ANIMATION.PulseDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = targetScale,
	})

	local pulseConn
	pulseConn = pulseTween.Completed:Connect(function()
		if pulseConn then
			pulseConn:Disconnect()
			pulseConn = nil
		end
		TweenService:Create(newScale, TweenInfo.new(ANIMATION.PulseReturn, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Scale = 1,
		}):Play()
	end)
	pulseTween:Play()

	local glow = self.Glow
	if glow then
		local glowColor = isGain and UIColors.Success or UIColors.Error
		glow.BackgroundColor3 = glowColor
		glow.BackgroundTransparency = 1

		local glowIn = TweenService:Create(glow, TweenInfo.new(ANIMATION.GlowDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = ANIMATION.GlowTransparency,
		})
		local glowConn
		glowConn = glowIn.Completed:Connect(function()
			if glowConn then
				glowConn:Disconnect()
				glowConn = nil
			end
			TweenService:Create(glow, TweenInfo.new(ANIMATION.GlowFadeOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()
		end)
		glowIn:Play()
	end

	if container then
		TweenService:Create(container, TweenInfo.new(ANIMATION.ContainerPulseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = ANIMATION.ContainerPulseTransparency
		}):Play()

		task.delay(ANIMATION.ContainerPulseDuration, function()
			if container.Parent then
				TweenService:Create(container, TweenInfo.new(ANIMATION.ContainerReturn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = ANIMATION.ContainerTransparency
				}):Play()
			end
		end)
	end
end

function CurrencyBalance.Show()
	if CurrencyBalance.Container then
		CurrencyBalance.Container.Visible = true
	end
end

function CurrencyBalance.Hide()
	if CurrencyBalance.Container then
		CurrencyBalance.Container.Visible = false
	end
	if CurrencyBalance.EcoContainer then
		CurrencyBalance.EcoContainer.Visible = false
	end
end

function CurrencyBalance.Destroy()
	for _, connection in ipairs(CurrencyBalance._connections) do
		connection:Disconnect()
	end
	table.clear(CurrencyBalance._connections)

	if CurrencyBalance.ScreenGui then
		CurrencyBalance.ScreenGui:Destroy()
		CurrencyBalance.ScreenGui = nil
		CurrencyBalance.Container = nil
		CurrencyBalance.BalanceLabel = nil
		CurrencyBalance.Icon = nil
		CurrencyBalance.Scale = nil
		CurrencyBalance.Glow = nil

		CurrencyBalance.EcoContainer = nil
		CurrencyBalance.EcoLabel = nil
		CurrencyBalance.EcoIcon = nil
		CurrencyBalance.EcoScale = nil
	end

	CurrencyBalance._stateConnected = false
	CurrencyBalance._loaded = false
end

function CurrencyBalance.Init(interface)
	CurrencyBalance._interface = interface
	CurrencyBalance:_createUI()
	CurrencyBalance:_connectState()
end

return CurrencyBalance
