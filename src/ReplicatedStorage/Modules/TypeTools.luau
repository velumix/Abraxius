local TypeTools = {} 

function TypeTools.AntiNaN(...) 
	local Values = {...} 
	
	for _, Value in Values do 
		if typeof(Value) ~= "number" then error("Value is not a number!") end 
		if Value ~= Value then error("Value is nan!") end 
	end
end

function TypeTools.TypeCheckValueArray(TypeArray, ...) 
	local Values = {...} 
	if #Values ~= #TypeArray then 
		error("Greater or lesser amount of required paramaters.")
	end

	-- This get's the subclass, of objects.
	local TypeOf = function(Value) 
		local Type = typeof(Value)  
		if Type == "Instance" then 
			Type = Value.ClassName
		end
		if Type == "table" then 
			if Value.__type then 
				Type = Value.__type
			end
		end
		return Type 
	end

	for i=1,#TypeArray do 
		if typeof(TypeArray[i]) == "table" then 
			local Match, Format = false, ""; 
			for Index, PotMatch in TypeArray[i] do 
				if PotMatch == Values[i] then Match = true end

				Format ..= tostring(PotMatch) 
				if Index ~= #TypeArray[1] then 
					Format ..= ", "
				end
			end

			if not Match then 
				error(`Expected Value(s) {Format} for ({TypeArray.ValidatingArr and TypeArray.ValidatingArr[i] or TypeArray.Validating or "paramater"})[{i}] instead got '{Values[i]}'.`)
			end

			continue; 
		end

		local ValueType = TypeOf(Values[i]) 
		local Match = false 
		-- Accepts both superclass an subclasses.
		if ValueType == TypeArray[i] then 
			Match = true
		end		
		if typeof(Values[i]) == TypeArray[i] then 
			Match = true 
		end

		if not Match then 
			error(`Expected '{TypeArray[i]}' as ({TypeArray.ValidatingArr and TypeArray.ValidatingArr[i] or TypeArray.Validating or "paramater"})[{i}] instead got '{ValueType}'.`)
		end
	end

	return ... 
end

return TypeTools 