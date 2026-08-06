local DrinkNameGenerator = {}

local function categorizeIngredients(mixingOrder: {string})
	local categories = {
		coffee = 0,
		espresso = 0,
		milk = 0,
		cream = 0,
		matcha = 0,
		syrups = {},
		syrupCount = 0,
		syrupCounts = {}
	}
	for _, ingredient in ipairs(mixingOrder) do
		if ingredient == "Coffee" then
			categories.coffee = categories.coffee + 1
		elseif ingredient == "Espresso" then
			categories.espresso = categories.espresso + 1
		elseif ingredient == "Milk" then
			categories.milk = categories.milk + 1
		elseif ingredient == "Cream" then
			categories.cream = categories.cream + 1
		elseif ingredient == "Matcha" then
			categories.matcha = categories.matcha + 1
		elseif tostring(ingredient):match("Syrup") then
			categories.syrupCount = categories.syrupCount + 1
			local syrupName = tostring(ingredient):gsub("Syrup", "")
			if not categories.syrupCounts[syrupName] then
				categories.syrupCounts[syrupName] = 0
				table.insert(categories.syrups, syrupName)
			end
			categories.syrupCounts[syrupName] = categories.syrupCounts[syrupName] + 1
		end
	end

	return categories
end

local function getSyrupNameWithIntensity(syrupName: string, count: number): string
	local intensityPrefixes = {
		[1] = "",
		[2] = "Double ",
		[3] = "Triple "
	}
	local prefix = intensityPrefixes[count] or ""
	return prefix .. syrupName
end

local function getFormattedSyrupName(categories)
	local syrups, syrupCounts = categories.syrups, categories.syrupCounts
	if #syrups == 1 then
		local syrupName = syrups[1]
		local count = syrupCounts[syrupName]
		return getSyrupNameWithIntensity(syrupName, count)
	elseif #syrups == 2 then
		local syrup1 = getSyrupNameWithIntensity(syrups[1], syrupCounts[syrups[1]])
		local syrup2 = getSyrupNameWithIntensity(syrups[2], syrupCounts[syrups[2]])
		return syrup1 .. " " .. syrup2
	else
		local bestSyrup = syrups[1]
		local bestCount = syrupCounts[bestSyrup]

		for _, syrup in ipairs(syrups) do
			if syrupCounts[syrup] > bestCount then
				bestSyrup = syrup
				bestCount = syrupCounts[syrup]
			end
		end

		return getSyrupNameWithIntensity(bestSyrup, bestCount)
	end
end

local function getEspressoBasedName(categories)
	local espresso, milk, cream, syrupCount = categories.espresso, categories.milk, categories.cream, categories.syrupCount
	local totalIngredients = categories.coffee + espresso + milk + cream + categories.matcha + syrupCount

	if totalIngredients == 1 then
		return "Espresso"
	elseif totalIngredients == 2 then
		if espresso == 2 then 
			return "Doppio"
		elseif milk == 1 then 
			return "Macchiato"
		elseif cream >= 1 then
			return "Espresso con Panna"
		elseif syrupCount >= 1 then 
			return getFormattedSyrupName(categories) .. " Shot"
		end
	elseif totalIngredients == 3 then
		if espresso == 1 and milk == 2 then
			return "Cortado"
		elseif espresso == 2 and milk == 1 then
			return "Flat White"
		elseif milk >= 1 and syrupCount >= 1 then
			return getFormattedSyrupName(categories) .. " Latte"
		elseif syrupCount >= 2 then
			return getFormattedSyrupName(categories) .. " Shot"
		end
	elseif totalIngredients == 4 then
		if milk >= 2 and syrupCount == 0 then
			return "Cappuccino"
		elseif milk >= 1 and syrupCount >= 1 then
			return getFormattedSyrupName(categories) .. " Latte"
		elseif syrupCount >= 1 then 
			return getFormattedSyrupName(categories) .. " Shot"
		else 
			return "Cappuccino"
		end
	elseif totalIngredients >= 5 then
		if milk >= 1 then
			return getFormattedSyrupName(categories) .. " Latte"
		else
			return getFormattedSyrupName(categories) .. " Shot"
		end
	end

	return "Latte"
end

local function getCoffeeBasedName(categories)
	local coffee, milk, cream, syrupCount = categories.coffee, categories.milk, categories.cream, categories.syrupCount
	local totalIngredients = categories.coffee + categories.espresso + milk + cream + categories.matcha + syrupCount

	if totalIngredients == 1 then
		return "Americano"
	elseif totalIngredients == 2 then
		if milk == 1 then return "Cafe au Lait"
		elseif cream >= 1 then return "Cafe con Crema"
		elseif syrupCount >= 1 then return getFormattedSyrupName(categories) .. " Coffee"
		elseif coffee == 2 then return "Long Black"
		end
	elseif totalIngredients >= 3 then
		if milk >= 1 and syrupCount >= 1 then return getFormattedSyrupName(categories) .. " Cafe au Lait"
		elseif milk >= 2 then return "Breve"
		elseif syrupCount >= 1 then 
			return getFormattedSyrupName(categories) .. " Coffee"
		end
	end

	if syrupCount == 0 and milk == 0 then
		return "Long Black"
	else
		return "House Coffee"
	end
end

local function getMixedCoffeeEspressoName(categories)
	local coffee, espresso, milk, cream, syrupCount = categories.coffee, categories.espresso, categories.milk, categories.cream, categories.syrupCount
	local totalIngredients = coffee + espresso + milk + cream + categories.matcha + syrupCount

	if totalIngredients == 2 then
		return "Red Eye"
	elseif totalIngredients == 3 then
		if syrupCount >= 1 then
			return getFormattedSyrupName(categories) .. " Black Eye"
		elseif milk == 1 then
			return "Gibraltar"
		else
			return "Black Eye"
		end
	elseif totalIngredients == 4 then
		if coffee == 2 and espresso == 2 then
			return "Cafe Bombon"
		elseif milk >= 1 and syrupCount >= 1 then
			return getFormattedSyrupName(categories) .. " Gibraltar"
		elseif syrupCount >= 1 then
			return getFormattedSyrupName(categories) .. " Romano"
		elseif milk > 0 then
			return "Gibraltar"
		else
			return "Black Eye"
		end
	elseif totalIngredients >= 5 then
		if milk >= 1 and syrupCount >= 1 then
			return getFormattedSyrupName(categories) .. " Breve"
		elseif syrupCount >= 1 then
			return getFormattedSyrupName(categories) .. " Dead Eye"
		elseif milk > 0 then
			return "Cafe con Leche"
		else
			return "Dead Eye"
		end
	else
		return "Black Eye"
	end
end

local function getMatchaBasedName(categories)
	local matcha, milk, cream, syrupCount = categories.matcha, categories.milk, categories.cream, categories.syrupCount
	local totalIngredients = categories.coffee + categories.espresso + milk + cream + matcha + syrupCount

	if totalIngredients == 1 then
		return "Matcha Tea"
	elseif totalIngredients == 2 and milk == 1 then
		return "Matcha Latte"
	elseif totalIngredients == 2 and cream >= 1 then
		return "Matcha con Panna"
	elseif syrupCount >= 1 then
		return getFormattedSyrupName(categories) .. " Matcha"
	end
	return "Matcha Latte"
end

local function getDirtyMatchaName(categories)
	if categories.milk > 0 then 
		return "Dirty Matcha Latte"
	else 
		return "Dirty Matcha"
	end
end

local function getMilkOnlyName(categories)
	if categories.syrupCount >= 1 then
		return getFormattedSyrupName(categories) .. " Steamer"
	end
	return "Steamed Milk"
end

local function getSyrupOnlyName(categories)
	return "Syrup Shot"
end

local function getIconicCoffeeName(categories)
	local coffee, espresso, milk, cream, matcha = categories.coffee, categories.espresso, categories.milk, categories.cream, categories.matcha
	local syrupCount = categories.syrupCount

	if espresso > 0 and coffee == 0 and matcha == 0 then
		return getEspressoBasedName(categories)
	end

	if coffee > 0 and espresso == 0 and matcha == 0 then
		return getCoffeeBasedName(categories)
	end

	if coffee > 0 and espresso > 0 and matcha == 0 then
		return getMixedCoffeeEspressoName(categories)
	end

	if matcha > 0 and coffee == 0 and espresso == 0 then
		return getMatchaBasedName(categories)
	end

	if matcha > 0 and (coffee > 0 or espresso > 0) then
		return getDirtyMatchaName(categories)
	end

	if coffee == 0 and espresso == 0 and matcha == 0 and (milk > 0 or cream > 0) then
		return getMilkOnlyName(categories)
	end

	if coffee == 0 and espresso == 0 and matcha == 0 and milk == 0 and syrupCount > 0 then
		return getSyrupOnlyName(categories)
	end

	return "House Special"
end

function DrinkNameGenerator.GenerateName(mixingOrder: {string}, liquidTypes: any, cupType: string): string
	if not mixingOrder or #mixingOrder == 0 then
		return "Empty Cup"
	end
	local categories = categorizeIngredients(mixingOrder)
	return getIconicCoffeeName(categories)
end

function DrinkNameGenerator.GenerateDescription(mixingOrder: {string}): string
	local count = #mixingOrder
	if count == 1 then
		return "Pure " .. mixingOrder[1]:lower() .. " experience"
	elseif count == 2 then
		return "Perfect balance of " .. mixingOrder[1] .. " and " .. mixingOrder[2]
	elseif count == 3 then
		return "Artfully crafted with " .. table.concat(mixingOrder, ", ", 1, 2) .. " and " .. mixingOrder[3]
	elseif count == 4 then
		return "Full-bodied blend: " .. table.concat(mixingOrder, " + ")
	else
		return "Expertly crafted coffee creation"
	end
end

return DrinkNameGenerator