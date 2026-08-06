-- Modules // Services
local ReplicatedStorage = game:GetService("ReplicatedStorage") 

local Mince = require(ReplicatedStorage.Modules.Mince)

local SoundHandler = Mince:Get("SoundHandler")
local SequenceHandler = Mince:Get("SequenceHandler")

local SequenceController = {} 

local SEQUENCE_SCENES = {
	"InsideOpenOcean",
	"AquaticaLogo",
	"Spawn"
}

function SequenceController.DoSequence(EndSequence)
	local stopConnection
	stopConnection = SequenceHandler.StopSequence:Connect(function()
		if stopConnection then
			stopConnection:Disconnect()
		end
		EndSequence()
	end)

	local function cleanupAndEnd()
		if stopConnection then
			stopConnection:Disconnect()
		end
		EndSequence()
	end

	SequenceHandler:StartCinematicBars() 

	-- Play through scenes until one is skipped or all complete
	for _, sceneName in ipairs(SEQUENCE_SCENES) do
		if SequenceHandler.SkipScene then
			return cleanupAndEnd()
		end
		SequenceHandler:PlayScene(sceneName)
	end

	cleanupAndEnd()
end

function SequenceController:Setup() 
	SequenceHandler:WhenStarted("TestSequence", SequenceController.DoSequence) 
end

return SequenceController