-- Hashing function for multiple values input -> hash 
local MicroID = require(script.Parent.MicroID)


local RefMutate = {
	ConvMethod = {}, 
	InstanceRef = "____Ref0000", 
} 


function RefMutate.ConvMethod.Instance(ConvInstance : Instance)
	-- Client/Server incomputable. The idea is that a registry is always done before ever attempted on the client. 
	ConvInstance:SetAttribute(RefMutate.InstanceRef, ConvInstance:GetAttribute(RefMutate.InstanceRef) or MicroID.gent()) 
	return ConvInstance:GetAttribute(RefMutate.InstanceRef)
end

function RefMutate.ConvMethod.Generic(Value : any) 
	-- Attempt to convert to string, if not possible, return the type of the value. 
	local Success, Result = pcall(function() 
		return tostring(Value)
	end) 
	
	if not Success then 
		return typeof(Value)
	end
	
	return Result 
end

function RefMutate.Typeof(Value : any) 
	local FirstType = typeof(Value) 
	
	if FirstType == "Instance" then 
		return Value.ClassName, FirstType
	elseif FirstType == "table" and Value.__type then 
		return Value.__type
	else 
		return FirstType
	end
end

function RefMutate.Convert(Value : any) 
	local RawType, HeadType = RefMutate.Typeof(Value)
	local ConvertMethod = RefMutate.ConvMethod[HeadType or RawType] or RefMutate.ConvMethod.Generic 
	local ThisStringValue = ConvertMethod(Value, RawType) 

	return `{RawType}<>{ThisStringValue}`
end

return RefMutate  