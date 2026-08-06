
local Mince = _G.MinceRef
local Players = game:GetService("Players")

local CreateCharacterAddons = function()
	local LocalPlayer = Players.LocalPlayer 
	local UponNewCharacter = function(Character : Model) 
		local Humanoid : Humanoid = Character:WaitForChild("Humanoid")
		local HumanoidRootPart : BasePart = Character:WaitForChild("HumanoidRootPart") 
		
		Mince.Character = Character 
		Mince.HumanoidRootPart = HumanoidRootPart 
		Mince.Humanoid = Humanoid 
		
		Humanoid.Died:Connect(function()
			Mince.Character = nil
			Mince.HumanoidRootPart = nil
			Mince.Humanoid = nil 
		end)
	end

	LocalPlayer.CharacterAdded:Connect(UponNewCharacter)
	if LocalPlayer.Character then 
		UponNewCharacter(LocalPlayer.Character)
	end
end
return { 
	Identity = function(ThisIdentity) 
		if ThisIdentity == "Client" then 
			CreateCharacterAddons() 
		end
	end 
}