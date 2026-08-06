local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return function(context, player: Player?)
	if not player then
		player = context.Executor
	end
	
	if not player then
		return "No player provided."
	end

	local ds = Knit.GetService("DataService")
	if not ds then
		return "DataService unavailable."
	end

	local ok, err = pcall(function()
		ds:WaitForData(player)
		ds:Wipe(player)
	end)

	if not ok then
		return "Failed to wipe data: " .. tostring(err)
	end

	return `Wiped data for {player.Name}.`
end
