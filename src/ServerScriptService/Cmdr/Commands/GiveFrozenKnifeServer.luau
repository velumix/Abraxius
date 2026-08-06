local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnifeSkinManager = require(ReplicatedStorage.KnifeSkinManager)
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

	local effect
	local ok, err = pcall(function()
		ds:WaitForData(player)
		effect = KnifeSkinManager.rollGuaranteedEffect()
		ds:AddWeapon(player, "frozen", effect)
		ds:Save(player)
	end)

	if not ok then
		return "Failed to give Frozen Knife: " .. tostring(err)
	end

	return `Gave {player.Name} a Frozen Knife with mutation {KnifeSkinManager.effectName(effect)}.`
end
