local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local GetEnv = require(ReplicatedStorage.GetEnv)

return function(registry)
	registry:RegisterHook("BeforeRun", function(context): string?
		if not GetEnv:isProdEnv() then
			return nil
		end

		local player: Player = context.Executor
		local AdminService = Knit.GetService("AdminService")

		if AdminService:IsAdmin(player) then
			return nil
		end

		return "You do not have permission to run this function."
	end)
end
