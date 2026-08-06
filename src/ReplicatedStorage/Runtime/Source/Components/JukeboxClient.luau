local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Player = Players.LocalPlayer
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Mince = require(Modules.Mince)
local JukeboxInterface = require(Modules.UI.Components.JukeboxInterface)

local InteractIndicator = Mince:Get("InteractIndicator")

local JukeboxClient = Mince.Component {
	Tag = "Jukebox",
}




local function findProxy(instance)
	if instance:IsA("BasePart") and instance.Name:lower() == "proxy" then
		return instance
	end

	for _, descendant in ipairs(instance:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name:lower() == "proxy" then
			return descendant
		end
	end

	return nil
end

local function isInteractionPart(part)
	return part and part:IsA("BasePart") and part.Name:lower() ~= "speaker"
end

local function pickInteractionPart(instance)
	local proxyPart = findProxy(instance)
	if proxyPart then
		return proxyPart
	end

	if isInteractionPart(instance) then
		return instance
	end

	if instance.PrimaryPart and isInteractionPart(instance.PrimaryPart) then
		return instance.PrimaryPart
	end

	if instance:IsA("Model") then
		for _, descendant in ipairs(instance:GetDescendants()) do
			if isInteractionPart(descendant) then
				return descendant
			end
		end
	end

	return nil
end

function JukeboxClient:Construct()
	self.InteractionPart = pickInteractionPart(self.Instance)
	self.Connections = {}

	if not self.InteractionPart then
		warn("Jukebox component is missing a BasePart for interaction", self.Instance:GetFullName())
		return
	end

	self.Indicator = InteractIndicator.new(self.InteractionPart)
	self.Prompt = self.Indicator.ProximityPrompt
	self.Prompt.ObjectText = self.Instance:GetAttribute("JukeboxPromptText") or "Jukebox"
	self.Prompt.ActionText = "Open"
	self.Prompt.KeyboardKeyCode = Enum.KeyCode.E
	self.Prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	self.Prompt.MaxActivationDistance = self.Instance:GetAttribute("JukeboxPromptRange") or 12
	self.Prompt:SetAttribute("IsJukeboxPrompt", true)

	table.insert(self.Connections, self.Prompt.Triggered:Connect(function(player)
		if player ~= Player then
			return
		end
		JukeboxInterface:Show(self)
	end))

	table.insert(self.Connections, self.Prompt.PromptHidden:Connect(function()
		if JukeboxInterface:IsActive(self) then
			JukeboxInterface:Hide()
		end
	end))

	if self.Instance.Destroying then
		table.insert(self.Connections, self.Instance.Destroying:Connect(function()
			if JukeboxInterface:IsActive(self) then
				JukeboxInterface:Hide()
			end
		end))
	else
		table.insert(self.Connections, self.Instance.AncestryChanged:Connect(function(_, parent)
			if parent then
				return
			end
			if JukeboxInterface:IsActive(self) then
				JukeboxInterface:Hide()
			end
		end))
	end
end

function JukeboxClient:Destruct()
	for _, connection in ipairs(self.Connections or {}) do
		connection:Disconnect()
	end
	self.Connections = nil

	if JukeboxInterface:IsActive(self) then
		JukeboxInterface:Hide()
	end
end

return JukeboxClient
