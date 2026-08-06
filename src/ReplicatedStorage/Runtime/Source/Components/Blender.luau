local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local Assets = ReplicatedStorage.Assets

local Player = Players.LocalPlayer

local Mince = require(Modules.Mince)

local Blender = Mince.Component {
	Tag = "Blender",
	Blenders = {},
}

function Blender:Construct()
	self.Model = self.Instance
	self.Part = self.Model:FindFirstChild("Base")

	self.Model:SetAttribute("InUse", false)
	self.CameraPart = self.Model:FindFirstChild("CameraPart")

	if not self.CameraPart then
		error("Blender: No CameraPart found in model")
	end

	if not self.Part then
		error("Blender: No Base part found in model")
	end

	self.Indicator = self.InteractIndicator.new(self.Part)
	self.Prompt = self.Indicator.ProximityPrompt
	self.Prompt.ObjectText = "Use Blender"

	self.Connections = {
		self.Prompt.Triggered:Connect(function(player)
			if player == Player then
				self:OnInteract()
			end
		end),

		self.Model:GetAttributeChangedSignal("InUse"):Connect(function()
			self.Prompt.Enabled = not self.Model:GetAttribute("InUse")
		end),
	}


end

function Blender:OnInteract()
	local Character = Player.Character

	if not Character then
		return warn("Blender: No character found", Player.Name)
	end
	print("Blender: Interacted with", self.Model.Name)
	self.Model:SetAttribute("InUse", true)
end

function Blender:Setup()
	self.InteractIndicator = Mince:Get("InteractIndicator")


end


return Blender