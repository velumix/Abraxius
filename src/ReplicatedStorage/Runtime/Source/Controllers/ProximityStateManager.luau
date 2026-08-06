local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local Player = Players.LocalPlayer

local Mince = require(Modules.Mince)

local ProximityStateManager = {
	Name = "ProximityStateManager",

	IsSwimming = false,
	IsSitting = false,
	ProximityHandler = nil,

	Initialized = false,
}

function ProximityStateManager:Initialize()
	if self.Initialized then return end

	self.ProximityHandler = Mince:Get("ProximityHandler")

	if not self.ProximityHandler then
		warn("ProximityStateManager: Failed to get ProximityHandler")
		return
	end

	self.IsSwimming = Player:GetAttribute("Swimming") or false

	Player:GetAttributeChangedSignal("Swimming"):Connect(function()
		self.IsSwimming = Player:GetAttribute("Swimming") or false
		print("ProximityStateManager: Swimming state changed to:", self.IsSwimming)
		self:UpdateProximityState()
	end)

	if Player.Character and Player.Character:FindFirstChild("Humanoid") then
		self:ConnectHumanoidEvents(Player.Character.Humanoid)
	end

	Player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		self:ConnectHumanoidEvents(humanoid)
	end)

	self.Initialized = true
	self:UpdateProximityState()
end

function ProximityStateManager:ConnectHumanoidEvents(humanoid)
	self.IsSitting = humanoid.Sit

	humanoid:GetPropertyChangedSignal("Sit"):Connect(function()
		self.IsSitting = humanoid.Sit
		self:UpdateProximityState()
	end)

	self:UpdateProximityState()
end

function ProximityStateManager:UpdateProximityState()
	if not self.ProximityHandler then
		warn("ProximityStateManager: ProximityHandler not available")
		return
	end

	local shouldDisable = self.IsSwimming or self.IsSitting

	if shouldDisable then
		self.ProximityHandler:SetAllEnabled(false)
	else
		self.ProximityHandler:SetAllEnabled(true)
	end
end

function ProximityStateManager:Setup()
	self:Initialize()
end

function ProximityStateManager:GameStart()

end

return ProximityStateManager
