local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IS_SERVER = RunService:IsServer()

local MapManager
if IS_SERVER then
	local ServerScriptService = game:GetService("ServerScriptService")
	MapManager = require(ServerScriptService:WaitForChild("MapManager"))
end

local DIRECTORY_NAME = "MapDirectory"

local function publishDirectory()
	local dir = ReplicatedStorage:FindFirstChild(DIRECTORY_NAME)
	if not dir then
		dir = Instance.new("Folder")
		dir.Name = DIRECTORY_NAME
		dir.Parent = ReplicatedStorage
	end
	dir:ClearAllChildren()
	for _, m in ipairs(MapManager.listMaps()) do
		local sv = Instance.new("StringValue")
		sv.Name = m.Name
		sv.Value = m.Name
		sv.Parent = dir
	end
end

local function mapNames(): { string }
	local out = {}
	if IS_SERVER then
		for _, m in ipairs(MapManager.listMaps()) do
			table.insert(out, m.Name)
		end
	else
		local dir = ReplicatedStorage:FindFirstChild(DIRECTORY_NAME)
		if dir then
			for _, sv in ipairs(dir:GetChildren()) do
				if sv:IsA("StringValue") then
					table.insert(out, sv.Value)
				end
			end
		end
	end
	table.sort(out)
	return out
end

local function findMap(value: string): string?
	local lowered = string.lower(value)
	for _, name in mapNames() do
		if string.lower(name) == lowered then
			return name
		end
	end
	return nil
end

local mapType = {
	Transform = function(text: string)
		return findMap(text) or text
	end,

	Validate = function(value: string)
		if not IS_SERVER and #mapNames() == 0 then
			return true
		end
		return findMap(value) ~= nil, ('"%s" is not a valid map.'):format(tostring(value))
	end,

	Autocomplete = function(value: string)
		local matches = {}
		local lowered = string.lower(value)
		for _, name in mapNames() do
			if string.sub(string.lower(name), 1, #lowered) == lowered then
				table.insert(matches, name)
			end
		end
		return matches
	end,

	Parse = function(value: string)
		return value
	end,
}

return function(registry)
	registry:RegisterType("mapType", mapType)
	if IS_SERVER then
		publishDirectory()
	end
end
