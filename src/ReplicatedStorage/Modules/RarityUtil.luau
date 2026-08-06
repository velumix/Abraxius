-- Modules // Services -- 
local ReplicatedStorage = game:GetService("ReplicatedStorage") 
local ConfigLocation = ReplicatedStorage.Runtime.Config.Shared.Rarities	

local RarityUtility = {
	Rarities = {},
	
	RarityCount = 0 
} 



function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end



function RarityUtility.GetRarity(RarityNameID)
	return RarityUtility.Rarities[RarityNameID]
end

function RarityUtility.Init()  
	local Raritys 
	if ConfigLocation then 
		Raritys = require(ConfigLocation)
	end
	
	for RarityNameID,RarityTable in Raritys  do
		local RarityInfoTable = {
			Data = RarityTable
		} 
		
		RarityInfoTable.Order = RarityTable.Order or 1		
		RarityInfoTable.Name = RarityTable.Text
		
		RarityInfoTable.Graident = ColorSequence.new{
			ColorSequenceKeypoint.new(0,RarityTable.AltColor1 or RarityTable.PrimaryColor),
			ColorSequenceKeypoint.new(1,RarityTable.AltColor2 or RarityTable.PrimaryColor)
		}
		
		RarityInfoTable.RarityColorArray = function() 
			return {RarityTable.PrimaryColor,RarityTable.AltColor1,RarityTable.AltColor2}
		end
		
		RarityUtility.Rarities[RarityNameID] = RarityInfoTable
	end 
end


RarityUtility.Init() 

return RarityUtility