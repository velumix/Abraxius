local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CmdrController = {
	Name = "CmdrController",
}

local Cmdr = nil

function CmdrController:Setup()
	local CmdrClient = ReplicatedStorage:WaitForChild("CmdrClient", 10)
	if not CmdrClient then
		warn("[CmdrController] CmdrClient not found in ReplicatedStorage")
		return
	end

	local success, result = pcall(function()
		return require(CmdrClient)
	end)

	if not success then
		warn("[CmdrController] Failed to load CmdrClient:", result)
		return
	end

	Cmdr = result

	Cmdr:SetPlaceName("Rangers")
	Cmdr:SetEnabled(true)

	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		return nil
	end)
end

return CmdrController
