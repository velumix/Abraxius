local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

Knit.PlayerScripts = Knit.Player:WaitForChild("PlayerScripts")

Knit.Components = Knit.PlayerScripts:WaitForChild("Components")
Knit.Modules = Knit.PlayerScripts:WaitForChild("Modules")
Knit.Controllers = Knit.PlayerScripts:WaitForChild("Controllers")

-- Load components (they self-register via Component.new when required)
for _, module in Knit.Components:GetDescendants() do
	if module:IsA("ModuleScript") then
		require(module)
	end
end

Knit.AddControllers(Knit.Controllers)

Knit.Start({ ServicePromises = false }):catch(warn)
