local TypeCheck = {
	TypesSet = {
		["AttributeIndex"] = {"string"},
		["AttributeValue"] = {"string","boolean","number","UDim","UDim2",
			"BrickColor","Color3","Vector2","Vector3","CFrame","NumberSequence",
			"ColorSequence","NumberRange","Rect","Font"}
	} 
} 

function TypeCheck.Init() 
	-- Create fuzzy finders. 
	for _,TypeSet in TypeCheck.TypesSet do 
		for _,Value in TypeSet do 
			TypeSet[Value] = true 
		end
	end
end

function TypeCheck.Set(Name,Value) 
	local TypeSet = TypeCheck.TypesSet[Name] 
	if not TypeSet then error(`No TypesSet by the name of {Name or ("<TypeCheck1>")}.`) end 
	local __Type , __SubType = typeof(Value) , nil 
	if __Type == "Instance" then 
		__SubType = Value.ClassName
	elseif __Type == "table" then 
		__SubType = Value.__type
	end
	
	local IsAllowed = TypeSet[__Type] 
	if not IsAllowed then 
		error(`TypeCheckError: Cannot use type {__SubType or __Type} for '{Name}'.`)
	end
end


TypeCheck.Init()
return TypeCheck