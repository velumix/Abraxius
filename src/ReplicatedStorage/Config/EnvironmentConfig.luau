--!strict
-- @author Velumix
-- @version 0.0.1
-- Studio data policy:
-- - default: in-memory mock profiles
-- - game attribute UseStudioLiveData=true: persistent development store
-- - published servers: persistent production store
local RunService = game:GetService("RunService")

--[=[
	@class EnvironmentConfig
	@server
	Resolves safe mock, development, and production profile environments.
]=]
local EnvironmentConfig = {}

-- Resolved environment contract used internally and by editor tooling.
export type Environment = {
	Name: "StudioMock" | "StudioDevelopment" | "Production",
	StoreName: string,
	UseMockData: boolean,
	IsProduction: boolean,
}

--[=[
	Resolves the current environment. Studio never returns the production store.

	@return table -- Contains `Name`, `StoreName`, `UseMockData`, and `IsProduction`.
]=]
function EnvironmentConfig.Resolve(): Environment
	if RunService:IsStudio() then
		if game:GetAttribute("UseStudioLiveData") == true then
			local studioDevelopment: Environment = {
				Name = "StudioDevelopment",
				StoreName = "PlayerProfiles_Development_v1",
				UseMockData = false,
				IsProduction = false,
			}
			return table.freeze(studioDevelopment)
		end

		local studioMock: Environment = {
			Name = "StudioMock",
			StoreName = "PlayerProfiles_Development_v1",
			UseMockData = true,
			IsProduction = false,
		}
		return table.freeze(studioMock)
	end

	local production: Environment = {
		Name = "Production",
		StoreName = "PlayerProfiles_Production_v1",
		UseMockData = false,
		IsProduction = true,
	}
	return table.freeze(production)
end

return table.freeze(EnvironmentConfig)
