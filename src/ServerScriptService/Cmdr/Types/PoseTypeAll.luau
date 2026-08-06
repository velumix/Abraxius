local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PoseConfig = require(ReplicatedStorage:WaitForChild("PoseConfig"))

local ALL = "All"

local function poseExists(id: string): boolean
	for _, def in ipairs(PoseConfig.POSES) do
		if def.id == id then
			return true
		end
	end
	return false
end

local function options(): { string }
	local out = { ALL }
	for _, def in ipairs(PoseConfig.POSES) do
		table.insert(out, def.id)
	end
	return out
end

local poseTypeAll = {
	Transform = function(text: string)
		if string.lower(text) == string.lower(ALL) then
			return ALL
		end
		for _, def in ipairs(PoseConfig.POSES) do
			if string.lower(def.id) == string.lower(text) then
				return def.id
			end
		end
		return text
	end,

	Validate = function(value: string)
		return value == ALL or poseExists(value), `"{value}" is not a valid pose.`
	end,

	Autocomplete = function(value: string)
		local matches = {}
		for _, name in options() do
			if string.sub(string.lower(name), 1, #value) == string.lower(value) then
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
	registry:RegisterType("poseTypeAll", poseTypeAll)
end
