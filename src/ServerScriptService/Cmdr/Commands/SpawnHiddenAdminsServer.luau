local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return function(_context, scope: string, amount: number?)
	if scope == "global" then
		Knit.GetService("ActionBroadcastService"):broadcast("SpawnHiddenAdmins", { amount = amount })
		return "Spawned hidden admins on all servers."
	end

	local ok, result = Knit.GetService("HiddenAdminService"):Spawn(amount)
	if not ok then
		return result
	end
	return result

end