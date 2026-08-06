local Workspace = game:GetService("Workspace")

local FOLDER_NAME = "ColoringBook"

local function bookFolder()
	local active = Workspace:FindFirstChild("ActiveMap")
	return active and active:FindFirstChild(FOLDER_NAME) or nil
end

local function pageIds()
	local out = {}
	local book = bookFolder()
	if book then
		for _, page in ipairs(book:GetChildren()) do
			table.insert(out, page.Name)
		end
	end
	table.sort(out)
	return out
end

local pageType = {
	Transform = function(text)
		return text
	end,

	Validate = function(value)
		return type(value) == "string" and value ~= "", "Provide a page id (e.g. Page1)."
	end,

	Autocomplete = function(value)
		local matches = {}
		local lowered = string.lower(value)
		for _, name in ipairs(pageIds()) do
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
	registry:RegisterType("coloringBookPage", pageType)
end