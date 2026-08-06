local HttpService = game:GetService("HttpService")

local MinceFolder = script.Parent.Parent.Parent
local StateFolder = script.Parent.States

local Signal = require(MinceFolder.Signal)
local Rbnsr = require(MinceFolder.rbnsr)

local TUtil = {}
local InstanceIDs = {}
local InstanceID = 0

type Path = string | { any }

-- // Table management

-- Creates a copy of a table, second arg details whether or not the copy is deep
function TUtil.Copy(t, deep)
	if not deep then
		return (table.clone(t))
	end
	local function DeepCopy(tbl)
		local tCopy = table.clone(tbl)
		for k, v in tCopy do
			if type(v) == "table" then
				tCopy[k] = DeepCopy(v)
			end
		end
		return tCopy
	end
	return DeepCopy(t)
end

-- Recursively removes any data in which the index matches IndexToRemove
function TUtil.RecursiveRemoveIndex(IndexToRemove, Proxy)
	for Index, Value in Proxy.Indexes do
		Index = TUtil.UnserializeArray(Index)

		local IsValid = TUtil.FirstPartOfArrayMatches(IndexToRemove, Index)
		if not IsValid then continue end

		Proxy.Indexes[Index] = nil
	end
end

-- // Array indexing stuff

-- Takes a string or table i.e. "Table.SubTable.Data" / {"Table", "SubTable", "Data"} and finds Table.SubTable.Data
function TUtil.GetPath(Path: Path, TableToSearch: { any })
	local Path = type(Path) == 'string' and string.split(Path, ".") or Path
	local CurrentTable = TableToSearch

	if #Path > 1 then
		for Iteration, Index in ipairs(Path) do
			if Iteration < #Path then
				CurrentTable = CurrentTable[Index]
			else
				return CurrentTable[Index]
			end
		end
	else
		return CurrentTable[Path[1]]
	end
end

-- Returns true if first part of array2 matches array1
function TUtil.FirstPartOfArrayMatches(Array1, Array2)
	local IsValid = true
	for i=1, #Array1 do
		if Array2[i] ~= Array1[i] then
			IsValid = false
			break
		end
	end

	return IsValid
end

-- // Serialization

local function GenerateInstanceID(Inst: Instance) -- Incremental, the smallest possible way to do this
	local ID = InstanceID + 1
	InstanceID += 1
	InstanceIDs[Inst] = ID

	Inst.Destroying:Once(function()
		InstanceIDs[Inst] = nil
	end)

	return ID
end

local function GetInstanceFromID(IDToCheck: number)
	for Inst, ID in InstanceIDs do
		if IDToCheck == ID then
			return Inst
		end
	end
end

-- Generates serialized version of array for storing in lookup table
function TUtil.SerializeArray(Array) -- So that we can create lookup tables of indexes that are arrays i.e. {"Table", "SubTable"}
	local NewArray = {}
	for Index, Value in Array do
		if typeof(Value) == 'Instance' then
			NewArray[Index] = `INS:{InstanceIDs[Value] or GenerateInstanceID(Value)}`
		elseif type(Value) == 'table' then
			NewArray[Index] = `TBL:{Rbnsr.Serialize(Value)}`
		elseif type(Value) == 'userdata' then
			NewArray[Index] = `USR:{Rbnsr.Serialize({Value})}`
		elseif type(Value) == 'boolean' then
			NewArray[Index] = `BOO:{tostring(Value)}`
		elseif type(Value) == 'string' then
			NewArray[Index] = `STR:{Value}`
		elseif type(Value) == `number` then
			NewArray[Index] = `NUM:{Value}`
		else
			error("Can't serialize ".. typeof(Value))
		end
	end
	return Rbnsr.Serialize(NewArray)
end

-- Unserializes array back into array
function TUtil.UnserializeArray(Array)
	local NewArray = Rbnsr.Deserialize(Array)
	for Index, Value in NewArray do
		local DataType = string.sub(Value, 1, 4)
		local Value = string.sub(Value, 5, #Value)
		if DataType == "INS:" then
			NewArray[Index] = GetInstanceFromID(tonumber(Value))
		elseif DataType == 'TBL:' then
			NewArray[Index] = Rbnsr.Deserialize(Value)
		elseif DataType == 'USR:' then
			NewArray[Index] = Rbnsr.Deserialize(Value)[1]
		elseif DataType == 'BOO:' then
			NewArray[Index] = Value == 'true'
		elseif DataType == 'STR:' then
			NewArray[Index] = Value
		elseif DataType == 'NUM:' then
			NewArray[Index] = tonumber(Value)
		end
	end
	return NewArray
end

return TUtil
