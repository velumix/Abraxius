local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer.PlayerGui

local Modules = ReplicatedStorage.Modules
local UIColors = require(Modules.UI.UIColors)
local Mince = require(Modules.Mince)

local CLOSE_TWEEN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local HOVER_SCALE_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local QUALITY_SETTINGS = {
	{
		Level = 1,
		Name = "Low Quality",
		Icon = "Performance",
		Status = "Best performance, minimal effects",
		Color = UIColors.Button
	},
	{
		Level = 2,
		Name = "Medium Quality",
		Icon = "Balanced",
		Status = "Balanced performance and visuals",
		Color = UIColors.ButtonHover
	},
	{
		Level = 3,
		Name = "High Quality",
		Icon = "Recommended",
		Status = "Best visuals, recommended",
		Color = UIColors.ButtonPressed
	}
}

local QualitySelector = {}

function QualitySelector.Init(UI)
	local self = QualitySelector
	self.UI = UI
	self.Buttons = {}
	self.Connections = {}
	self.SelectedLevel = nil

	self.GUI = PlayerGui:WaitForChild("QualitySelector") :: ScreenGui
	self.Main = self.GUI:WaitForChild("Main") :: Frame
	self.Shadow = self.GUI:WaitForChild("Shadow") :: Frame
	self.Content = self.Main:WaitForChild("Content") :: Frame
	self.Container = self.Content:WaitForChild("Container") :: ScrollingFrame

	self.Template = self.Container:WaitForChild("Template") :: TextButton

	self:CreateButtons(self.Template)
	self.Template.Parent = nil

	Mince:WhenStart(function()
		local SequenceHandler = Mince:Get("SequenceHandler")
		if SequenceHandler then
			SequenceHandler.StopSequence:Connect(function()
				self.GUI.Enabled = true
			end)
		else
			self.GUI.Enabled = true
		end
	end)

	return self
end

function QualitySelector:CreateButtons(template)
	for _, qualitySetting in ipairs(QUALITY_SETTINGS) do
		local button = template:Clone()
		button.Parent = self.Container
		button.BackgroundColor3 = qualitySetting.Color

		button.StatusLabel.Text = qualitySetting.Status
		button.StatusLabel.TextColor3 = UIColors.White
		button.NameLabel.Text = qualitySetting.Name
		button.NameLabel.TextColor3 = UIColors.White
		button.CurrentIcon.Text = qualitySetting.Icon
		button.CurrentIcon.TextColor3 = UIColors.White

		table.insert(self.Buttons, button)

		table.insert(self.Connections, button.MouseEnter:Connect(function()
			self:PreviewQuality(qualitySetting.Level)
			TweenService:Create(button, HOVER_SCALE_TWEEN, {
				BackgroundColor3 = button.BackgroundColor3:Lerp(UIColors.White, 0.25),
				Size = UDim2.new(1, 8, button.Size.Y.Scale, button.Size.Y.Offset)
			}):Play()
		end))

		table.insert(self.Connections, button.MouseLeave:Connect(function()
			TweenService:Create(button, HOVER_SCALE_TWEEN, {
				BackgroundColor3 = qualitySetting.Color,
				Size = UDim2.new(1, 0, button.Size.Y.Scale, button.Size.Y.Offset)
			}):Play()
		end))

		table.insert(self.Connections, button.Activated:Connect(function()
			self:SelectQuality(qualitySetting.Level)
		end))
	end
end

function QualitySelector:PreviewQuality(qualityLevel : number)
	if self.SelectedLevel == qualityLevel then return end
	self.SelectedLevel = qualityLevel
	self.UI.Settings:ApplyQualityPreset(qualityLevel)
end

function QualitySelector:SelectQuality(qualityLevel : number)
	self.SelectedLevel = qualityLevel
	self:Close()
end

function QualitySelector:Close()
	if not self.Main then return end

	self.Main.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Main.Position = UDim2.fromScale(0.5, 0.5)

	local closeTween = TweenService:Create(self.Main, CLOSE_TWEEN, {
		Size = UDim2.new(0, 0, 0, 0)
	})

	closeTween:Play()
	closeTween.Completed:Connect(function()
		self.GUI.Enabled = false
	end)
end

return QualitySelector