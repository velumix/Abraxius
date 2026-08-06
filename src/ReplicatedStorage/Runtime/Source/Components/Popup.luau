local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)

local Popup = Mince.Component {
	Tag = "Popup";
}

function Popup:Construct()
	self.Connections = {}
	self.Prompt = Instance.new("ProximityPrompt", self.Instance)

	self.Prompt.ActionText = "Inspect"
	self.Prompt.ObjectText = "Inspect"
	self.Prompt:SetAttribute("Type","Radial")
	self.Prompt.Style = Enum.ProximityPromptStyle.Custom

	self.Attributes = self.Instance:GetAttributes()

	task.spawn(function()
		if self.Attributes.ScreenGui then
			self.ScreenGui = PlayerGui:FindFirstChild(self.Attributes.ScreenGui)
			if not self.ScreenGui then
				warn("ScreenGui not found", self.Attributes.ScreenGui)
			end

			self.CloseButton = self.ScreenGui:FindFirstChild("CloseButton", true)

			if not self.CloseButton then
				warn("CloseButton not found", self.Attributes.ScreenGui)
			end

			self.Connections["Close"] = self.CloseButton.MouseButton1Click:Connect(function()
				self.ScreenGui.Enabled = false
			end)

		end

		self.Connections["Triggered"] = self.Prompt.Triggered:Connect(function()
			if self.ScreenGui then
				self.ScreenGui.Enabled = not self.ScreenGui.Enabled
			end
		end)
	end)

end

return Popup