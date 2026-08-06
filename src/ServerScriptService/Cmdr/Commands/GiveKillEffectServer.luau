local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KillEffectManager = require(ReplicatedStorage.KillEffectManager)

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local function svc(n) local ok, s = pcall(function() return Knit.GetService(n) end) return ok and s or nil end
local _inv
local function invSvc() if not _inv then _inv = svc("DataService") end return _inv end

return function(_context, player: Player, effect: string)
	if effect == "All" then
		for _, def in ipairs(KillEffectManager.EFFECTS) do
			invSvc():AddKillEffect(player, def.id)
		end
		return `Granted all kill effects to {player.Name}.`
	end

	invSvc():AddKillEffect(player, effect)
	local def = KillEffectManager.getEffect(effect)
	return `Granted {def and def.name or effect} kill effect to {player.Name}.`
end
