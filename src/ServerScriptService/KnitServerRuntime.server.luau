local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.Modules = ServerScriptService.Modules
Knit.Components = ServerScriptService.Components

-- Auto-require every Knit Service (Services/*Service) and Component so they self-register
-- before Knit.Start. The game's existing Manager scripts live outside these folders and are
-- untouched.
for _, dependency in ServerScriptService:GetDescendants() do
	local isModuleScript = dependency:IsA("ModuleScript")
	local isComponent = dependency:IsDescendantOf(ServerScriptService.Components)
	local isService = dependency:IsDescendantOf(ServerScriptService.Services) and dependency.Name:match("Service$")

	if isModuleScript and (isComponent or isService) then
		local ok, err = pcall(require, dependency)
		if not ok then
			warn(`[KnitBoot] Failed to load {dependency:GetFullName()}:\n{err}`)
		end
	end
end

Knit.Start({ ServicePromises = false })
	:andThen(function()
		--
	end)
	:catch(warn)
