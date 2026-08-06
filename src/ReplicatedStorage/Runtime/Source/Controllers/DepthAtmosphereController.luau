local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local DepthAtmosphereController = {
	Name = "DepthAtmosphereController",
	ColorCorrection = nil,
	OriginalSettings = nil,
	OriginalLighting = nil,
}

local MAX_DEPTH = 150
local OBSERVATORY_DEPTH = 50
local TRANSITION_TIME = 1

function DepthAtmosphereController:GameStart()
	self:CacheColorCorrection()
	self:ListenToDepth()
end

function DepthAtmosphereController:CacheColorCorrection()
	self.ColorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
	if not self.ColorCorrection then
		self.ColorCorrection = Instance.new("ColorCorrectionEffect")
		self.ColorCorrection.Parent = Lighting
	end

	self.OriginalSettings = {
		Brightness = self.ColorCorrection.Brightness,
		Contrast = self.ColorCorrection.Contrast,
		Saturation = self.ColorCorrection.Saturation,
		TintColor = self.ColorCorrection.TintColor,
	}

	self.OriginalLighting = {
		Brightness = Lighting.Brightness,
	}
end

function DepthAtmosphereController:ListenToDepth()
	local oxygenComm = Mince:GetEvent("OxygenEvents")
	local OxygenSync = oxygenComm:Extend("OxygenSync")
	OxygenSync.Event:Connect(function(data)
		local depth = math.abs(data.Depth or 0)
		local isSwimming = data.IsSwimming
		if isSwimming then
			self:UpdateEffects(depth)
		else
			self:ResetEffects()
		end
	end)
end

function DepthAtmosphereController:UpdateEffects(depth)
	if not self.ColorCorrection or not self.OriginalSettings then return end

	local depthDifference = depth - OBSERVATORY_DEPTH
	local depthPercent

	if depthDifference < 0 then
		depthPercent = depthDifference / OBSERVATORY_DEPTH
	else
		depthPercent = depthDifference / (MAX_DEPTH - OBSERVATORY_DEPTH)
	end

	local originalTint = self.OriginalSettings.TintColor

	local tween = TweenService:Create(
		self.ColorCorrection,
		TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{
			Brightness = self.OriginalSettings.Brightness + (-0.1 * depthPercent),
			Saturation = self.OriginalSettings.Saturation + (-0.3 * depthPercent),
			TintColor = Color3.new(
				math.clamp(originalTint.R * (1 - 0.2 * depthPercent), 0, 1),
				math.clamp(originalTint.G * (1 - 0.12 * depthPercent), 0, 1),
				math.clamp(originalTint.B * (1 + 0.1 * depthPercent), 0, 1)
			)
		}
	)
	tween:Play()

	local lightingTween = TweenService:Create(
		Lighting,
		TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{
			Brightness = self.OriginalLighting.Brightness * (1 - 0.5 * depthPercent)
		}
	)
	lightingTween:Play()
end

function DepthAtmosphereController:ResetEffects()
	if not self.ColorCorrection or not self.OriginalSettings then return end

	local tween = TweenService:Create(
		self.ColorCorrection,
		TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		self.OriginalSettings
	)
	tween:Play()

	local lightingTween = TweenService:Create(
		Lighting,
		TweenInfo.new(TRANSITION_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		self.OriginalLighting
	)
	lightingTween:Play()
end

return DepthAtmosphereController
