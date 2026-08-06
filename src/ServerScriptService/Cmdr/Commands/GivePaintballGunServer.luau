local PaintballGunGiver = require(script.Parent.Parent.Parent.Modules.PaintballGunGiver)

return function(context, player: Player?)
	player = player or context.Executor
	if not player then
		return "No player provided."
	end

	PaintballGunGiver.GiveGun(player)

	return `Gave a paintball gun to {player.Name}.`
end
