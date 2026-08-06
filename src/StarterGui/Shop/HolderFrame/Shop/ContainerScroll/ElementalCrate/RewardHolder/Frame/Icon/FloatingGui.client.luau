local TweenService = game:GetService("TweenService")
local gui = script.Parent

local tweenInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local targetPosition = gui.Position + UDim2.new(0, 0, 0.05, 0)

local tween = TweenService:Create(gui, tweenInfo, {Position = targetPosition})

tween:Play()
