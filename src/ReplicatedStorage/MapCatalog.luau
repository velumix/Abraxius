local MapCatalog = {
	{ name = "City", productId = 3605348600, thumbnail = "rbxassetid://116719028944578", creator = "" },
	{ name = "Island", productId = 3605348233, thumbnail = "rbxassetid://119492584206504", creator = "" },
	{ name = "Grocery Store", productId = 3605348566, thumbnail = "rbxassetid://138575750526667", creator = "" },
	{ name = "Military Farm", productId = 3605348475, thumbnail = "rbxassetid://109042826185931", creator = "" },
	{ name = "Night Shift", productId = 3605348413, thumbnail = "rbxassetid://83811680838344", creator = "" },
	{ name = "Back Rooms", productId = 3605348345, thumbnail = "rbxassetid://103672903434653", creator = "" },
	{ name = "Party Hall", productId = 3605574153, thumbnail = "rbxassetid://132194282917282", creator = "" },
	{ name = "School", productId = 3606548526, thumbnail = "rbxassetid://133739982935936", creator = "" },
	{ name = "Oversized PC", productId = 3607988035, thumbnail = "rbxassetid://90729532449159", creator = "" },
	{ name = "Pyramids", productId = 3608956036, thumbnail = "rbxassetid://95368857800265", creator = "" },
}

local byName = {}
local byProduct = {}
for index, entry in ipairs(MapCatalog) do
	entry.order = index
	byName[entry.name] = entry
	byProduct[entry.productId] = entry
end

function MapCatalog.get(name)
	return byName[name]
end

function MapCatalog.getByProduct(productId)
	return byProduct[productId]
end

function MapCatalog.list()
	local list = {}
	for _, entry in ipairs(MapCatalog) do
		list[#list + 1] = entry
	end
	return list
end

return MapCatalog
