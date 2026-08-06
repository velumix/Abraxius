
local Util = {} 

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

function table_eq(table1, table2)
	local avoid_loops = {}
	local function recurse(t1, t2)
		-- compare value types
		if type(t1) ~= type(t2) then return false end
		-- Base case: compare simple values
		if type(t1) ~= "table" then return t1 == t2 end
		-- Now, on to tables.
		-- First, let's avoid looping forever.
		if avoid_loops[t1] then return avoid_loops[t1] == t2 end
		avoid_loops[t1] = t2
		-- Copy keys from t2
		local t2keys = {}
		local t2tablekeys = {}
		for k, _ in pairs(t2) do
			if type(k) == "table" then table.insert(t2tablekeys, k) end
			t2keys[k] = true
		end
		-- Let's iterate keys from t1
		for k1, v1 in pairs(t1) do
			local v2 = t2[k1]
			if type(k1) == "table" then
				-- if key is a table, we need to find an equivalent one.
				local ok = false
				for i, tk in ipairs(t2tablekeys) do
					if table_eq(k1, tk) and recurse(v1, t2[tk]) then
						table.remove(t2tablekeys, i)
						t2keys[tk] = nil
						ok = true
						break
					end
				end
				if not ok then return false end
			else
				-- t1 has a key which t2 doesn't have, fail.
				if v2 == nil then return false end
				t2keys[k1] = nil
				if not recurse(v1, v2) then return false end
			end
		end
		-- if t2 has a key which t1 doesn't have, fail.
		if next(t2keys) then return false end
		return true
	end
	return recurse(table1, table2)
end

function updipairs(Arrays)
	if not Arrays then return function() end end 
	
	local ArrayIndex, Index, ResetNext = 1, 0, false 
	return function ()
		if ResetNext then 
			Index = 0; ResetNext = false 
			if Arrays[ArrayIndex] and #Arrays[ArrayIndex] == 0 then return end 
		end 
		local CurrentArray = Arrays[ArrayIndex] 
		if not CurrentArray then return end 

		Index += 1 
		if CurrentArray[Index+1] == nil then ArrayIndex += 1;ResetNext = true  end
		return Index, CurrentArray[Index]
	end
end

function dipairs(...) 
	return updipairs({...})
end

function dpairs(...) 
	local Arrays = {...}
	local ArrayIndex, LastIndex, ResetNext = 1, nil, false 
	return function ()
		if ResetNext then LastIndex = nil; ResetNext = false  end 
		local CurrentArray = Arrays[ArrayIndex] 
		if not CurrentArray then return end 
		
		LastIndex =  next(CurrentArray, LastIndex) 
		if CurrentArray[LastIndex] == nil then ArrayIndex += 1;ResetNext = true  end
		return LastIndex, CurrentArray[LastIndex]
	end
end

local function ReconcileTable(target, template)
	for k, v in template do
		if type(k) == "string" then
			if target[k] == nil then
				if type(v) == "table" then
					target[k] = deepcopy(v)
				else
					target[k] = v
				end
			elseif type(target[k]) == "table" and type(v) == "table" then
				ReconcileTable(target[k], v)
			end
		end
	end
end

-- spairs CC BY-SA 4.0) Michal Kottman
-- EXTREMELY USEFUL 
function spairs(t)
	local keys = {}
	for k in pairs(t) do keys[#keys+1] = k end
	table.sort(keys)
	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

Util.spairs = spairs 

Util.dpairs = dpairs
Util.dipairs = dipairs 
Util.updipairs = updipairs 

Util.TableEq = table_eq
Util.Deepcopy = deepcopy 
Util.ReconcileTable = ReconcileTable

function Util.DotIndex(ThisTable : {}, DotIndex : string) : any 
	local Index = DotIndex:split(".")
	local Result = ThisTable
	for _, Index in ipairs(Index) do
		Result = Result[Index]
		if Result == nil then return nil end
	end
	return Result
end

function Util.AttributeTable(TInstance : Instance) 
	return setmetatable({}, {
		__call = function(_, Index) 
			return TInstance:GetAttributeChangedSignal(Index)
		end,
		__index = function(_, Index) 
			return TInstance:GetAttribute(Index)
		end,
		__newindex = function(_, Index, Value)  
			TInstance:SetAttribute(Index, Value)
		end,
	})
end

function Util.AssertTypes(InputValue, ValueTypeOf, ThisFormat) 
	local InputValueTypeof = typeof(InputValue) 
	ThisFormat = ThisFormat or "Expected type '%s' got type '%s'"
	ValueTypeOf = ValueTypeOf or "nil"
	return InputValueTypeof == ValueTypeOf, ThisFormat:format(ValueTypeOf, InputValueTypeof)
end

function Util.CreateFuzzyFinder(List) 
	local Finder = {} 
	
	for _,Value in ipairs(List) do 
		Finder[Value] = true 
	end
	
	return Finder
end

return Util