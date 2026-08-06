local ReplicatedStorage = game:GetService("ReplicatedStorage")

local openBundleShowcase = ReplicatedStorage:WaitForChild("GameRemotes"):WaitForChild("OpenBundleShowcase")

return function(context)
	local player = context.Executor
	if not player then
		return "This command must be run by a player."
	end

	openBundleShowcase:FireClient(player)
	return "Opening bundle showroom..."
end
