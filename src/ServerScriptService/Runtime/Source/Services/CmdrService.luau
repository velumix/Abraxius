local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local Cmdr = require(Modules.Cmdr)

local CmdrService = {}

function CmdrService:Setup()
	Cmdr:RegisterDefaultCommands()

	local cmdrFolder = Modules:FindFirstChild("Cmdr")
	if not cmdrFolder then return end

	local builtInCommands = cmdrFolder:FindFirstChild("BuiltInCommands")
	if builtInCommands then
		local uiFolder = builtInCommands:FindFirstChild("UI")
		if uiFolder then
			Cmdr:RegisterCommandsIn(uiFolder)
		end
	end

	local customCommands = cmdrFolder:FindFirstChild("CustomCommands")
	if customCommands then
		Cmdr:RegisterCommandsIn(customCommands)
	end

	Cmdr.Registry:RegisterHook("BeforeRun", function(context)
		if RunService:IsStudio() then
			return nil
		end
		local executor = context.Executor
		if executor and executor.UserId == game.CreatorId then
			return nil
		end
		return "You don't have permission to run this command."
	end)
end

return CmdrService
