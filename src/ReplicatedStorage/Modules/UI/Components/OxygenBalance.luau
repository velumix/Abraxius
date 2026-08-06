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

local ANIMATION = {
	IntroDuration = 0.35,
	IntroDelay = 0.1,
	FlashDuration = 0.15,
	PulseDuration = 0.3,
	BarUpdateDuration = 0.25,
	BarShadowDuration = 0.6,
	CriticalPulseInterval = 1.5,
}

local THRESHOLDS = {
	Medium = 0.5,
	Low = 0.3,
	Critical = 0.15,
}

local OVERLAY = {
	WarningColor = Color3.fromRGB(255, 185, 110),
	WarningMinTransparency = 0.35,
	WarningMaxTransparency = 0.85,
	CriticalColor = Color3.fromRGB(190, 20, 20),
	CriticalTransparency = 0.3,
	CriticalPulseTransparency = 0.5,
	TweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	PulseTweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	Gradient = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.6, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	}),
	VignetteGradient = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0),
	}),
}

local OxygenBalance = {
	_interface = nil,
	_connections = {},
	_loaded = false,
	_visible = false,
	_isPulsing = false,
	_lastPercentage = 1,
	_lastMaxOxygen = 30,
	_lastOxygen = 30,
	_temporaryShowTimer = nil,
	_vignettePulsing = false,
	_hasNotified = false,
	_hasNotifiedLow = false,
}

function OxygenBalance:_createUI()
	if self.ScreenGui then
		return
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "OxygenBalance"
	screenGui.DisplayOrder = 20
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent = PlayerGui

	local container = UIFactory.createFrame(screenGui, {
		Name = "Container",
		Size = UDim2.new(0, 110, 0, 28),
		Position = UDim2.new(1, -6, 0, 36),
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
		BackgroundColor3 = UIColors.OxygenHigh,
		ZIndex = 3,
	}, {
		Corner = UDim.new(0, 2),
	})
	accent.BackgroundTransparency = 0.2

	local icon = UIFactory.createTextLabel(container, {
		Name = "Icon",
		Size = UDim2.new(0, 18, 1, 0),
		Position = UDim2.new(0, 4, 0, 0),
		Text = "💨",
		TextColor3 = UIColors.OxygenHigh,
		TextSize = 16,
		Font = Enum.Font.GothamBold,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})

	local barBackground = UIFactory.createFrame(container, {
		Name = "BarBackground",
		Size = UDim2.new(1, -28, 1, -8),
		Position = UDim2.new(0, 24, 0, 4),
		BackgroundColor3 = UIColors.OxygenBarBackground,
		ZIndex = 2,
	}, {
		Corner = UDim.new(0, 4),
	})

	local barShadow = UIFactory.createFrame(barBackground, {
		Name = "BarShadow",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = UIColors.OxygenHigh,
		BackgroundTransparency = 0.5,
		ZIndex = 3,
	}, {
		Corner = UDim.new(0, 4),
	})

	local barFill = UIFactory.createFrame(barBackground, {
		Name = "BarFill",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = UIColors.OxygenHigh,
		ZIndex = 4,
	}, {
		Corner = UDim.new(0, 4),
	})

	local oxygenText = UIFactory.createTextLabel(barBackground, {
		Name = "OxygenText",
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text = "30",
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
		BackgroundColor3 = UIColors.OxygenHigh,
		BackgroundTransparency = 1,
		ZIndex = 1,
	}, {
		Corner = UDim.new(0, 10),
	})

	local scale = UIFactory.createUITweenScale(container, {
		Name = "Scale",
		Scale = 0.92,
	})

	local warningOverlay = UIFactory.createFrame(screenGui, {
		Name = "OxygenVignette",
		Size = UDim2.fromScale(1.1, 1.1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		BackgroundColor3 = OVERLAY.WarningColor,
		ZIndex = 100,
		Visible = false,
	}, {
		Gradient = {
			Transparency = OVERLAY.VignetteGradient,
			Rotation = 0,
		},
		Corner = UDim.new(0, 0)
	})

	self.ScreenGui = screenGui
	self.Container = container
	self.Accent = accent
	self.Icon = icon
	self.BarBackground = barBackground
	self.BarFill = barFill
	self.BarShadow = barShadow
	self.OxygenText = oxygenText
	self.Glow = glow
	self.Scale = scale
	self.Vignette = warningOverlay
end

function OxygenBalance:_connectEvents()
	local oxygenComm = Mince:GetEvent("OxygenEvents")
	if not oxygenComm then
		warn("OxygenBalance could not acquire OxygenEvents")
		return
	end

	local OxygenSync = oxygenComm:Extend("OxygenSync")

	local connection = OxygenSync.Event:Connect(function(data)
		self:_updateDisplay(data)
	end)

	table.insert(self._connections, connection)

	local characterConnection = LocalPlayer.CharacterAdded:Connect(function()
		self:_onCharacterRespawn()
	end)

	table.insert(self._connections, characterConnection)
end

function OxygenBalance:_onCharacterRespawn()
	if self._visible then
		self:_hide()
	end

	self._loaded = false
	self._isPulsing = false
	self._lastPercentage = 1
	self._vignettePulsing = false
	self._hasNotified = false
	self._hasNotifiedLow = false
	self:_hideVignette(true)

	if self.Scale then
		self.Scale.Scale = 0.92
	end
end

function OxygenBalance:_disconnectOverlayConnection(field)
	local connection = self[field]
	if connection then
		connection:Disconnect()
		self[field] = nil
	end
end

function OxygenBalance:_showVignette(color: Color3)
	local vignette = self.Vignette
	if not vignette then
		return
	end

	vignette.BackgroundColor3 = color
	vignette.Visible = true
	vignette.BackgroundTransparency = OVERLAY.CriticalTransparency

	if not self._vignettePulsing then
		self:_startVignettePulse()
	end
end

function OxygenBalance:_startVignettePulse()
	local vignette = self.Vignette
	if not vignette or self._vignettePulsing then
		return
	end

	self._vignettePulsing = true

	local function doPulse()
		if not self._vignettePulsing or not vignette.Visible then
			self._vignettePulsing = false
			return
		end

		local pulse = TweenService:Create(vignette, OVERLAY.PulseTweenInfo, {
			BackgroundTransparency = OVERLAY.CriticalPulseTransparency
		})

		pulse.Completed:Connect(function()
			if not self._vignettePulsing or not vignette.Visible then
				self._vignettePulsing = false
				return
			end

			local pulseBack = TweenService:Create(vignette, OVERLAY.PulseTweenInfo, {
				BackgroundTransparency = OVERLAY.CriticalTransparency
			})

			pulseBack.Completed:Connect(function()
				task.wait(0.1)
				doPulse()
			end)

			pulseBack:Play()
		end)

		pulse:Play()
	end

	doPulse()
end

function OxygenBalance:_hideVignette(immediate: boolean?)
	local vignette = self.Vignette
	if not vignette then
		return
	end

	self._vignettePulsing = false

	if immediate then
		vignette.BackgroundTransparency = 1
		vignette.Visible = false
		return
	end

	TweenService:Create(vignette, OVERLAY.TweenInfo, {
		BackgroundTransparency = 1,
	}):Play()

	task.delay(OVERLAY.TweenInfo.Time, function()
		if vignette and vignette.BackgroundTransparency >= 0.99 then
			vignette.Visible = false
		end
	end)
end

function OxygenBalance:_show()
	if not self.Container then
		return
	end

	if self._visible then
		self.Container.Visible = true
		return
	end

	self._visible = true
	self.Container.Visible = true
	self.Scale.Scale = 0.85

	local introTween = TweenService:Create(self.Scale, TweenInfo.new(ANIMATION.IntroDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, ANIMATION.IntroDelay), {
		Scale = 1,
	})

	introTween:Play()
	self._loaded = true
end

function OxygenBalance:_hide()
	if not self.Container or not self._visible then
		return
	end

	self._visible = false

	local exitTween = TweenService:Create(self.Scale, TweenInfo.new(ANIMATION.IntroDuration, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Scale = 0.85,
	})

	exitTween.Completed:Connect(function()
		if not self._visible then
			self.Container.Visible = false
		end
	end)

	exitTween:Play()
end

function OxygenBalance:_updateDisplay(data)
	if not self.Container or not data then
		warn("Container or data is nil. Container:", self.Container ~= nil, "Data:", data ~= nil)
		return
	end

	if not data.Oxygen or not data.MaxOxygen then
		warn("Missing oxygen data. Oxygen:", data.Oxygen, "MaxOxygen:", data.MaxOxygen)
		return
	end

	local percentage = math.clamp(data.Oxygen / data.MaxOxygen, 0, 1)
	local displayOxygen = math.ceil(data.Oxygen)
	local maxOxygenChanged = self._lastMaxOxygen ~= data.MaxOxygen
	local isSwimming = data.IsSwimming == true
	local shouldShow = data.Oxygen < data.MaxOxygen or maxOxygenChanged or isSwimming

	if maxOxygenChanged then
		self._lastMaxOxygen = data.MaxOxygen

		if self._temporaryShowTimer then
			task.cancel(self._temporaryShowTimer)
		end

		if not self._visible then
			self:_show()
		end

		self._temporaryShowTimer = task.delay(2, function()
			if data.Oxygen >= data.MaxOxygen and self._visible then
				self:_hide()
			end
			self._temporaryShowTimer = nil
		end)
	end

	if shouldShow and not self._visible then
		self:_show()
	elseif not shouldShow and self._visible and not self._temporaryShowTimer then
		self:_hide()
		return
	end

	if not self._visible then
		return
	end

	if self.OxygenText then
		self.OxygenText.Text = string.format("%d/%d", displayOxygen, data.MaxOxygen)
	end

	local color = self:_getColorForPercentage(percentage)
	local targetSize = UDim2.new(percentage, 0, 1, 0)


	local oxygenChanged = data.Oxygen ~= self._lastOxygen
	if oxygenChanged then
		if data.Oxygen > self._lastOxygen then
			self:_pulseGain()
		end
		self._lastOxygen = data.Oxygen
	end

	self.BarFill.Size = targetSize
	self.BarFill.BackgroundColor3 = color

	if self.BarShadow then
		TweenService:Create(self.BarShadow, TweenInfo.new(ANIMATION.BarShadowDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = targetSize,
			BackgroundColor3 = color
		}):Play()
	end

	TweenService:Create(self.Icon, TweenInfo.new(ANIMATION.BarUpdateDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextColor3 = color
	}):Play()

	TweenService:Create(self.Accent, TweenInfo.new(ANIMATION.BarUpdateDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundColor3 = color
	}):Play()

	if percentage <= THRESHOLDS.Critical and data.Oxygen > 0 then
		self:_pulseWarning(color)
	elseif data.Oxygen <= 0 then
		self:_pulseCritical(color)
	end

	if data.Oxygen <= 0 then
		self:_showVignette(OVERLAY.CriticalColor)

		if not self._hasNotified then
			self._hasNotified = true
			self._interface.Notify("You're out of oxygen!", "Warning", 5)
		end
	else
		self._hasNotified = false
		if percentage <= THRESHOLDS.Low then
			self:_showVignette(OVERLAY.WarningColor)

			if not self._hasNotifiedLow then
				self._hasNotifiedLow = true
				self._interface.Notify("Oxygen running low!", "Warning", 5)
			end
		else
			self._hasNotifiedLow = false
			self:_hideVignette()
		end
	end

	self._lastPercentage = percentage
end

function OxygenBalance:_getColorForPercentage(percentage: number): Color3
	if percentage <= THRESHOLDS.Critical then
		return UIColors.OxygenCritical
	elseif percentage <= THRESHOLDS.Low then
		return UIColors.OxygenLow
	elseif percentage <= THRESHOLDS.Medium then
		return UIColors.OxygenMedium
	else
		return UIColors.OxygenHigh
	end
end

function OxygenBalance:_pulseGain()
	if not self.Glow then return end

	self.Glow.BackgroundColor3 = UIColors.OxygenHigh
	self.Glow.BackgroundTransparency = 1

	local glowIn = TweenService:Create(self.Glow, TweenInfo.new(ANIMATION.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.2,
	})

	glowIn.Completed:Connect(function()
		TweenService:Create(self.Glow, TweenInfo.new(ANIMATION.PulseDuration * 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
	end)

	glowIn:Play()
end

function OxygenBalance:_pulseWarning(color: Color3)
	if self._isPulsing then
		return
	end

	self._isPulsing = true

	local glow = self.Glow
	if glow then
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = 1

		local glowIn = TweenService:Create(glow, TweenInfo.new(ANIMATION.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.2,
		})

		glowIn.Completed:Connect(function()
			TweenService:Create(glow, TweenInfo.new(ANIMATION.PulseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()
			task.delay(ANIMATION.PulseDuration, function()
				self._isPulsing = false
			end)
		end)

		glowIn:Play()
	else
		self._isPulsing = false
	end
end

function OxygenBalance:_pulseCritical(color: Color3)
	if self._isPulsing then
		return
	end

	self._isPulsing = true

	local container = self.Container
	local glow = self.Glow

	if container then
		TweenService:Create(container, TweenInfo.new(ANIMATION.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.1
		}):Play()

		task.delay(ANIMATION.FlashDuration, function()
			if container.Parent then
				TweenService:Create(container, TweenInfo.new(ANIMATION.PulseDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = ANIMATION.ContainerTransparency or 0.3
				}):Play()
			end
		end)
	end

	if glow then
		glow.BackgroundColor3 = color
		glow.BackgroundTransparency = 1

		local glowIn = TweenService:Create(glow, TweenInfo.new(ANIMATION.FlashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.15,
		})

		glowIn.Completed:Connect(function()
			TweenService:Create(glow, TweenInfo.new(ANIMATION.PulseDuration * 1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				BackgroundTransparency = 1,
			}):Play()

			task.delay(ANIMATION.PulseDuration * 1.5, function()
				self._isPulsing = false
			end)
		end)

		glowIn:Play()
	else
		self._isPulsing = false
	end
end

function OxygenBalance.Show()
	if OxygenBalance.Container then
		OxygenBalance:_show()
	end
end

function OxygenBalance.Hide()
	if OxygenBalance.Container then
		OxygenBalance:_hide()
	end
end

function OxygenBalance.Destroy()
	for _, connection in ipairs(OxygenBalance._connections) do
		connection:Disconnect()
	end
	table.clear(OxygenBalance._connections)

	OxygenBalance:_hideVignette(true)

	if OxygenBalance.ScreenGui then
		OxygenBalance.ScreenGui:Destroy()
		OxygenBalance.ScreenGui = nil
		OxygenBalance.Container = nil
		OxygenBalance.Icon = nil
		OxygenBalance.BarFill = nil
		OxygenBalance.BarShadow = nil
		OxygenBalance.BarBackground = nil
		OxygenBalance.OxygenText = nil
		OxygenBalance.Accent = nil
		OxygenBalance.Scale = nil
		OxygenBalance.Glow = nil
		OxygenBalance.Vignette = nil
	end

	OxygenBalance._loaded = false
	OxygenBalance._visible = false
end

function OxygenBalance.Init(interface)
	OxygenBalance._interface = interface
	OxygenBalance:_createUI()
	OxygenBalance:_connectEvents()
end

return OxygenBalance
