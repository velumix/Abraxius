local PropertyService = {
	_IDENTITY = "PropertyService",
	_AUTHOR = "Whim#2127",
	_VERSION = "v0.1.5",
	_DESCRIPTION = "A Progmatic API Dump.",
	_LICENSE = [[
    MIT LICENSE
    Copyright (c) 2022 Theron Akubuiro
    Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:
    The above copyright notice and this permission notice shall be included
    in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    ]],
	API = {
		Classes = {},
		Enums = {
			EnumTypes = {}
		} 
	},
	Checks = {
		Defaults = {},
		Valid = {}
	},
	Registry = {
		__Queue ={},
		__Address ={},
	},
	DeepValues = { -- Deep Values are Values that are set before and after parenting 
		["Attachment"] = {
			["CFrame"] = true 	
		} 
	}, 
	PostValues = { -- Post Values are set after parenting.
		["Attachment"] = {
			["WorldCFrame"] = CFrame.new(Vector3.new(0,0,0))
		}
	},
	AlwaysSave = {
		["Attachment"] = {
			["CFrame"] = true, -- Negates parenting Transformation
		}
	},
	NeverSave = {
		["PVInstance"] = {
			["CFrame"] = true,   -- No point of saving the entire CFrame matrix. 
		},
		["Attachment"] = {
			["WorldCFrame"] = true, -- Causes werid transformations
			["WorldPosition"] = true, -- Causes werid transformations
		} 
	} ,
	Persistance = {
		Registry = {}, 
	} 
} 


PropertyService.Warn = function(Str,...) 
	warn(("[PropertyService]: %s"):format(Str),...)
end
PropertyService.Error = function(Str,...) 
	error(("[PropertyService]: %s"):format(Str),...)
end


function PropertyService.IsCreatable(ClassName) 
	local __Cache = PropertyService.Checks.Valid[ClassName] 
	if not __Cache then 
		PropertyService.Checks.Valid[ClassName] = pcall(function() 
			Instance.new(ClassName)
		end)
		__Cache = PropertyService.Checks.Valid[ClassName]
	end
	return __Cache
end

function PropertyService.GetDefaults(ClassName,Property) 
	local instanceDefault = PropertyService.Checks.Defaults[ClassName]
	if not instanceDefault then 
		PropertyService.Checks.Defaults[ClassName] = Instance.new(ClassName) 
		instanceDefault = PropertyService.Checks.Defaults[ClassName]
	end
	local Success , Result = pcall(function() 
		return instanceDefault[Property]
	end)
	if Success then 
		return Result 	 
	end
end

function PropertyService.GetClass(ClassName) 
	return PropertyService.API.Classes[ClassName]
end

function PropertyService.BuildAPI() 
	local APIDump = require(script.Dumps.APIDump)
	
	local SuperClassRefer = {} 
	-- Build Classes
	for Index,Item in ipairs(APIDump.Classes) do
		PropertyService.API.Classes[Item.Name] = Item
		Item.Properties = {} 
		if Item.Members then 
			for i,Member in ipairs(Item.Members) do 
				if Member.MemberType == "Property" then 
					Item.Properties[Member.Name] = Member
				end
				Member.Is = function(MatchTag) 
					for _,ItemTag in ipairs(Member.Tags or {})  do
						if ItemTag == MatchTag then 
							return true 
						end
					end
					return false 
				end
			end
			
			Item.IsA = function(ClassName)
				local IsClass = Item.Name == ClassName 
				local NextClass = Item 
				while NextClass and not IsClass do 
					local RealNextClass = NextClass.SuperClass 
					if RealNextClass  then
						IsClass = RealNextClass.Name == ClassName
						NextClass = RealNextClass
					else 
						break 
					end
				end
				
				return IsClass
			end
			
			Item.GetMasterClass = function(StepFunction) 
				local NextClass = Item 
				while NextClass do 
					local RealNextClass = NextClass.SuperClass 
					if RealNextClass  then
						if StepFunction then StepFunction(RealNextClass) end 
						NextClass = RealNextClass
					else 
						return RealNextClass
					end
				end
			end
			Item.GetInhertitedProperties = function()
				local Properties = {} 
				local NextClass = Item 
				while NextClass do 
					for Name,Member in pairs(NextClass.Properties) do 
						Properties[Name] = Member
					end
					NextClass = NextClass.SuperClass 
				end
				return Properties
			end
			
			Item.ReadScriptiableInhertitedProperties = function(ReadFn) 
				for PropertyName,PropertyInfo in Item.GetInhertitedProperties() do 
					if PropertyInfo.Is("ReadOnly") then 
						continue
					end
					if PropertyName == "Parent" then 
						continue;
					end
					if PropertyInfo.Security then 
						if typeof(PropertyInfo.Security) == "string" then 
							if PropertyInfo.Security ~= "None" then 
								continue;
							end
						else 
							if PropertyInfo.Security.Read ~= "None" or PropertyInfo.Security.Write ~= "None" then 
								continue;
							end
						end
					end
					
					_= ReadFn and ReadFn(PropertyName,PropertyInfo)
				end
			end
		end
	end
	-- Actually Setup superclasses 
	for Index,Item in ipairs(APIDump.Classes) do
		if Item.Superclass then
			local SuperClassItem = PropertyService.API.Classes[Item.Superclass] 
			if SuperClassItem then
				Item.SuperClass = SuperClassItem
			end		
		end
	end
end
PropertyService.BuildAPI() 
return PropertyService