local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PoseConfig = require(ReplicatedStorage.PoseConfig)

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local function svc(n) local ok, s = pcall(function() return Knit.GetService(n) end) return ok and s or nil end
local _inv
local function invSvc() if not _inv then _inv = svc("DataService") end return _inv end

local function poseName(id: string): string
	for _, def in ipairs(PoseConfig.POSES) do
		if def.id == id then
			return def.name
		end
	end
	return id
end

return function(_context, player: Player, pose: string)
	if pose == "All" then
		for _, def in ipairs(PoseConfig.POSES) do
			invSvc():GrantPose(player, def.id)
		end
		return `Granted all poses to {player.Name}.`
	end

	invSvc():GrantPose(player, pose)
	return `Granted {poseName(pose)} pose to {player.Name}.`
end
