local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

return function(_context, key, value)
	if not Knit.GetService("ConfigParamService"):Broadcast(key, value) then
		return `Unknown config key '{key}'`
	end
	return `Set '{key}' = {tostring(value)} across all servers.`
end
