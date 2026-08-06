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
		local data = ds:Get(player)
		if not data then
			error("Data not loaded for " .. player.Name)
		end
		data.StarterPack = { ExpiresAt = 0, Purchased = false }
		ds:Save(player)
	end)

	if not ok then
		return "Failed to reset starter pack data: " .. tostring(err)
	end

	return `Reset starter pack data for {player.Name}.`
end
