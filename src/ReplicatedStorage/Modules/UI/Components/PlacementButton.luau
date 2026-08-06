local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local UIColors = require(game.ReplicatedStorage.Modules.UI.UIColors)
local PlacementButton = {}

local COLORS = {
	Background = UIColors.PlacementBackground,
	BackgroundHover = UIColors.PlacementBackgroundHover,
	Text = UIColors.Text,
	Border = UIColors.Border,
}

local placementButton
local currentCallback

local function getPlacementButton()
	if placementButton then return placementButton end

	local gui = Instance.new("ScreenGui")
	gui.Name = "PlacementButtonSystem"
	gui.DisplayOrder = 45
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

	local button = Instance.new("TextButton", gui)
	button.Name = "PlacementButton"
	button.Size = UDim2.new(0, 50, 0, 50)
	button.Position = UDim2.new(1, -70, 0.5, 0)
	button.AnchorPoint = Vector2.new(0, 0.5)
	button.BackgroundColor3 = COLORS.Background
	button.BorderSizePixel = 0
	button.Text = "🥤"
	button.TextSize = 20
	button.TextColor3 = COLORS.Text
	button.Font = Enum.Font.SourceSansBold
	button.Visible = false

	local corner = Instance.new("UICorner", button)
	corner.CornerRadius = UDim.new(0, 12)

	local stroke = Instance.new("UIStroke", button)
	stroke.Color = COLORS.Border
	stroke.Thickness = 2

	button.MouseEnter:Connect(function()
		local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.BackgroundHover})
		tween:Play()
	end)

	button.MouseLeave:Connect(function()
		local tween = TweenService:Create(button, TweenInfo.new(0.2), {BackgroundColor3 = COLORS.Background})
		tween:Play()
	end)

	button.Activated:Connect(function()
		if currentCallback then
			currentCallback()
		end
	end)

	placementButton = {GUI = gui, Button = button}
	return placementButton
end

function PlacementButton.Show(callback)
	if not UserInputService.TouchEnabled then
		return -- Only show on touch devices
	end

	local system = getPlacementButton()
	currentCallback = callback
	system.Button.Visible = true

	system.Button.Size = UDim2.new(0, 0, 0, 0)
	local tween = TweenService:Create(system.Button, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
		Size = UDim2.new(0, 50, 0, 50)
	})
	tween:Play()
end

function PlacementButton.Hide()
	if not placementButton then return end

	local tween = TweenService:Create(placementButton.Button, TweenInfo.new(0.2), {
		Size = UDim2.new(0, 0, 0, 0)
	})
	tween:Play()

	tween.Completed:Connect(function()
		placementButton.Button.Visible = false
		currentCallback = nil
	end)
end

return PlacementButton
