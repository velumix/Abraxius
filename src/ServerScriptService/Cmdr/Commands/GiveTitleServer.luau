local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage:WaitForChild("Packages"):WaitForChild("Knit"))
local TitleDefinitions = require(ReplicatedStorage:WaitForChild("TitleDefinitions"))

local _data
local function dataSvc()
	if not _data then
		local ok, s = pcall(function() return Knit.GetService("DataService") end)
		if ok then _data = s end
	end
	return _data
end

return function(_context, player: Player, titleId: string, equip)
	local ds = dataSvc()
	if not ds then return "DataService unavailable." end
	if not TitleDefinitions.get(titleId) then
		return `Unknown title '{titleId}'. Known: {table.concat(TitleDefinitions.ids(), ", ")}`
	end
	if equip == nil then equip = true end
	ds:GrantTitle(player, titleId, true)
	if equip then
		ds:EquipTitle(player, titleId)
	end
	return `Gave title '{titleId}' to {player.Name}{equip and " (equipped)" or ""}.`
end
