local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return function(_context, bossName: string)
	local ok, result = pcall(function()
		return Knit.GetService("BossService"):Spawn(bossName)
	end)

	if not ok then
		return "Failed to spawn boss: " .. tostring(result)
	end

	return result
end
