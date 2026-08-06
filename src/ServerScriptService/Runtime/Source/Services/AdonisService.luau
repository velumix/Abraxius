local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Adonis = require(ReplicatedStorage.Modules.Adonis)

local AdonisService = {
	Name = "AdonisService",
}

function AdonisService:StartDeferred()
	local result = Adonis({
		Loader = script,
		LoaderVersion = "Velumix edit",
		SilentStartup = true,
	})

	if result ~= "SUCCESS" then
		error(`Adonis failed to start: {tostring(result)}`)
	end
end

return AdonisService
