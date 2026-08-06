local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Input = require(ReplicatedStorage.Modules.Input)

local EFFECT_DURATION = 0.11
local START_SIZE = 4
local END_SIZE = 13

local CursorClickEffect = {}

function CursorClickEffect:SetTargetGui(targetGui)
	self.TargetGui = targetGui
end

function CursorClickEffect:IsEnabled()
	local targetGui = self.TargetGui
	if not targetGui or not targetGui.Parent then
		return false
	end
	if targetGui:IsA("ScreenGui") then
		return targetGui.Enabled
	end
	if targetGui:IsA("GuiObject") then
		return targetGui.Visible
	end
	return false
end

function CursorClickEffect:CreateEffectLayer()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("CursorClickEffects")
	if existing and existing:IsA("ScreenGui") then
		return existing
	end

	local layer = Instance.new("ScreenGui")
	layer.Name = "CursorClickEffects"
	layer.DisplayOrder = 1000
	layer.IgnoreGuiInset = true
	layer.ResetOnSpawn = false
	layer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	layer.Parent = playerGui
	return layer
end

function CursorClickEffect:Emit(position)
	if not self.EffectLayer or not self.EffectLayer.Parent then
		self.EffectLayer = self:CreateEffectLayer()
	end

	local effect = Instance.new("Frame")
	effect.Name = "ClickEffect"
	effect.AnchorPoint = Vector2.new(0.5, 0.5)
	effect.Position = UDim2.fromOffset(position.X, position.Y)
	effect.Size = UDim2.fromOffset(START_SIZE, START_SIZE)
	effect.BackgroundColor3 = Color3.fromRGB(235, 248, 255)
	effect.BackgroundTransparency = 0.2
	effect.BorderSizePixel = 0
	effect.ZIndex = 1000
	effect.Parent = self.EffectLayer

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = effect

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(105, 205, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.05
	stroke.Parent = effect

	local tweenInfo = TweenInfo.new(EFFECT_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local effectTween = TweenService:Create(effect, tweenInfo, {
		Size = UDim2.fromOffset(END_SIZE, END_SIZE),
		BackgroundTransparency = 1,
	})
	TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()
	effectTween.Completed:Once(function()
		effect:Destroy()
	end)
	effectTween:Play()
end

function CursorClickEffect:Start()
	if self.Started then
		return
	end
	self.Started = true
	self.EffectLayer = self:CreateEffectLayer()
	self.Mouse = Input.Mouse.new()
	self.Touch = Input.Touch.new()

	self.Mouse.LeftDown:Connect(function()
		if self:IsEnabled() then
			self:Emit(self.Mouse:GetPosition())
		end
	end)
	self.Touch.TouchStarted:Connect(function(touch)
		if self:IsEnabled() then
			self:Emit(Vector2.new(touch.Position.X, touch.Position.Y))
		end
	end)
end

return {
	Client = {
		CursorClickEffect = CursorClickEffect,
	},
	Identity = function(identity)
		if identity == "Client" then
			task.defer(function()
				CursorClickEffect:Start()
			end)
		end
	end,
}
