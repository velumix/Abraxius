local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer
local CollectionService = game:GetService("CollectionService")

local Modules = ReplicatedStorage.Modules

local Mince = require(Modules.Mince)
local UI = require(Modules.UI)

local Hatch = Mince.Component {
	Tag = "Hatch",
}

function Hatch:Setup()
	self.IsSwimming = Player:GetAttribute("Swimming")
	Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		self.IsSwimming = Player:GetAttribute("Swimming")
		self:UpdatePromptState()
	end)
end

function Hatch:GameStart()
	self.SwimEvent = Mince:GetEvent("Swim")
end

function Hatch:Trigger()
	local character = Player.Character
	if not character or not character.PrimaryPart then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			local isDouble = tool.Name == "DoubleDPV" or tool:GetAttribute("DoubleDPV") == true
			if not isDouble and CollectionService then
				isDouble = CollectionService:HasTag(tool, "DoubleDPV")
			end
			if isDouble then
				humanoid:UnequipTools()
				break
			end
		end
	end

	local rightVector = self.Proximity.CFrame.RightVector
	local isSwimming = self.IsSwimming

	if isSwimming == nil then
		isSwimming = Player:GetAttribute("Swimming")
	end

	local shouldDive
	if isSwimming == nil then
		local side = (character.PrimaryPart.Position - self.Proximity.Position):Dot(rightVector)
		shouldDive = side <= 0
	else
		shouldDive = not isSwimming
	end

	local offset = shouldDive and 15 or -10

	self.Blink(function()
		local activeCharacter = Player.Character
		if not activeCharacter or not activeCharacter.PrimaryPart then
			return
		end

		self.SwimEvent:Fire(shouldDive)

		local targetPosition = self.Instance.Position + rightVector * offset
		activeCharacter:PivotTo(CFrame.new(targetPosition, self.Instance.Position))
	end)
end

function Hatch:GetPlayerSide()
	if not Player.Character or not Player.Character.PrimaryPart then
		return 0
	end

	local RightVector = self.Proximity.CFrame.RightVector
	local CharacterPosition = Player.Character.PrimaryPart.Position
	return (CharacterPosition - self.Proximity.Position):Dot(RightVector)
end

function Hatch:IsPlayerOnReentrySide()
	return self:GetPlayerSide() > 0
end

function Hatch:UpdatePromptState()
	if not self.Prompt then return end

	local isSwimming = self.IsSwimming
	if isSwimming == nil then
		isSwimming = Player:GetAttribute("Swimming")
	end

	if isSwimming == nil then
		isSwimming = self:IsPlayerOnReentrySide()
	end

	if isSwimming then
		self.Prompt.ObjectText = "Enter Observatory"
	else
		self.Prompt.ObjectText = "Dive"
	end

	self.Prompt.Enabled = true
end

function Hatch:Construct()
	local InteractIndicator = Mince:Get("InteractIndicator")

	self.SwimmingController = Mince:Get("SwimmingController")
	self.Exhibit = Mince:Get("Exhibit")

	self.Blink = function(callback)
		UI.FadeExhibitIn(0.3, function()
			if callback then callback() end
			task.spawn(function()
				task.wait(0.3)
				UI.FadeExhibitOut(0.3)
			end)
		end)
	end

	self.Proximity = self.Instance:FindFirstChild("Proximity")

	if not self.Proximity then
		warn("Hatch is missing a Proximity part", self.Instance)
		return
	end

	self.Proximity:SetAttribute("Hatch", true)

	self.Prompt = InteractIndicator.new(self.Proximity).ProximityPrompt
	self.Prompt.ObjectText = "Dive"
	self.Prompt:SetAttribute("IsHatchPrompt", true)

	self.PromptStyle = self.Prompt:GetAttribute("Type")

	self.Prompt.Triggered:Connect(function(player)
		if Player ~= player then return end
		self:Trigger()
	end)

	self:UpdatePromptState()

	RunService.Heartbeat:Connect(function()
		if Player.Character and Player.Character.PrimaryPart then
			self:UpdatePromptState()
		end
	end)

end

return Hatch