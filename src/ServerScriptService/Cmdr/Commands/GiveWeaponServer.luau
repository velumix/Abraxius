local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KnifeSkinManager = require(ReplicatedStorage.KnifeSkinManager)

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local function svc(n) local ok, s = pcall(function() return Knit.GetService(n) end) return ok and s or nil end
local _inv
local function invSvc() if not _inv then _inv = svc("DataService") end return _inv end

return function(_context, player: Player, weapon: string)
	if weapon == "All" then
		for _, skin in ipairs(KnifeSkinManager.SKINS) do
			invSvc():GrantWeaponOnce(player, skin.id)
		end
		return `Granted all knives to {player.Name}.`
	end

	invSvc():AddWeapon(player, weapon)
	local def = KnifeSkinManager.getSkin(weapon)
	return `Granted {def and def.name or weapon} to {player.Name}.`
end
