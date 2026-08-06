local Workspace = game:GetService("Workspace")

local FOLDER_NAME = "ColoringBook"

local function bookFolder()
	local active = Workspace:FindFirstChild("ActiveMap")
	return active and active:FindFirstChild(FOLDER_NAME) or nil
end

local function partIds()
	local names = {}
	local seen = {}
	local book = bookFolder()
	if book then
		for _, page in ipairs(book:GetChildren()) do
			for _, part in ipairs(page:GetChildren()) do
				if not seen[part.Name] then
					seen[part.Name] = true
					table.insert(names, part.Name)
				end
			end
		end
	end
	table.sort(names)
	table.insert(names, 1, "all")
	return names
end

local partType = {
	Transform = function(text)
		return text
	end,

	Validate = function(value)
		return type(value) == "string" and value ~= "", "Provide a part id (e.g. Book1) or 'all'."
	end,

	Autocomplete = function(value)
		local matches = {}
		local lowered = string.lower(value)
		for _, name in ipairs(partIds()) do
			if string.sub(string.lower(name), 1, #lowered) == lowered then
				table.insert(matches, name)
			end
		end
		return matches
	end,

	Parse = function(value)
		return value
	end,
}

return function(registry)
	registry:RegisterType("coloringBookPart", partType)
end