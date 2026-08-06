local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local Mince = require(Modules.Mince)

local Statistics = Mince:Get("Statistics")

local SwimmingService = {
	Name = "SwimmingService";
}

local SwimEvent = Mince:GetEvent("Swim")

SwimEvent.Event:Connect(function(Player, shouldSwim)
	local character = Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		Player:SetAttribute("Swimming", false)
		return
	end

	local wasSwimming = Player:GetAttribute("Swimming") == true

	if shouldSwim then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		Player:SetAttribute("Swimming", true)

		if not wasSwimming then
			if Statistics then
				Statistics:Record(Player, "DiveCount", 1)
			end

			local oxygen = character and character:GetAttribute("Oxygen")
			local maxOxygen = character and character:GetAttribute("MaxOxygen")
			print(Player.Name, "started diving - Oxygen:", oxygen, "MaxOxygen:", maxOxygen)
		end
	else
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
		Player:SetAttribute("Swimming", false)
		print(Player.Name, "stopped diving")
	end
end)

function SwimmingService:SetupCharacter(Character)
	local Player = Players:GetPlayerFromCharacter(Character)
	Player:SetAttribute("Swimming", false)

	Character.AncestryChanged:Connect(function()
		if Character.Parent == nil then
		end
	end)

end

Players.PlayerAdded:Connect(function(Player)
	Player.CharacterAdded:Connect(function(Character)
		SwimmingService:SetupCharacter(Character)
	end)
end)

return SwimmingService