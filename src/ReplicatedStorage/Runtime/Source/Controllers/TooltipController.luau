local Players = game:GetService("Players")
local Player = Players.LocalPlayer

local PlayerGui = Player:WaitForChild("PlayerGui")
local TweenService = game:GetService("TweenService")

local Mouse = Player:GetMouse()
local TooltipController = {}
TooltipController.__index = TooltipController

local ScannerMouse = PlayerGui:WaitForChild("ScannerMouse")

local BlankID = "rbxassetid://2317070865"

local outerRing = ScannerMouse.Main.OuterRing
local innerRing = ScannerMouse.Main.InnerRing

local Info = TweenInfo.new(
	6,
	Enum.EasingStyle.Linear,
	Enum.EasingDirection.Out,
	-1
)

local Tweens = {
	OuterRing = TweenService:Create(outerRing, Info, {
		Rotation = 360
	});
	InnerRing = TweenService:Create(innerRing, Info, {
		Rotation = -360
	});
}

function TooltipController.Setup()
	TooltipController.UI = PlayerGui.ToolTip
	TooltipController.TooltipFrame = TooltipController.UI.Main
	TooltipController.TooltipText = TooltipController.TooltipFrame.TextLabel

	TooltipController.UI.Enabled = true

	TooltipController.SetIcon("")
	TooltipController.SetText("")

	TooltipController.UI.AncestryChanged:Connect(function()
		if not TooltipController.UI.Parent then
			TooltipController.SetIcon("")
			TooltipController.SetText("")
		end
	end)

	return TooltipController
end

function TooltipController.Start()
	TooltipController.UI.Parent = PlayerGui
end

function TooltipController.Stop()
	TooltipController.UI.Parent = nil
end

function TooltipController.UpdatePosition(mouseX, mouseY)
	if TooltipController.UI.Parent then
		TooltipController.TooltipFrame.Position = UDim2.new(0, mouseX + 15, 0, mouseY + 15)
		ScannerMouse.Main.Position = UDim2.new(0, mouseX, 0, mouseY)
	end
end

function TooltipController.SetText(text)
	TooltipController.TooltipText.Text = text or ""
	TooltipController.TooltipFrame.Visible = text ~= nil and text ~= ""
end

function TooltipController.SetIcon(IconName)
	if IconName == "MagnifyingGlass" then
		ScannerMouse.Main.Visible = true
		Tweens.OuterRing:Play()
		Tweens.InnerRing:Play()
		Mouse.Icon = BlankID
	else
		ScannerMouse.Main.Visible = false
		Tweens.OuterRing:Cancel()
		Tweens.InnerRing:Cancel()
		Mouse.Icon = ""
	end
end

return TooltipController