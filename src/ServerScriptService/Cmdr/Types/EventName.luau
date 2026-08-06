local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(cmdr)
	local CmdrEventScope = require(ReplicatedStorage.Util.CmdrEventScope)
	local eventNames: { string } = {}

	local function refreshEventNames()
		eventNames = {}
		local EventDefinitions = require(ReplicatedStorage.Config.EventDefinitions)
		for name, def in EventDefinitions.getAll() do
			if def.command ~= false and name ~= "Luck" then
				table.insert(eventNames, name)
			end
		end
		table.sort(eventNames)
	end

	local eventNameType = {
		Transform = function(text: string): { string }
			refreshEventNames()
			local lower = text:lower()
			local matches: { string } = {}
			local exact: string? = nil
			for _, name in ipairs(eventNames) do
				if name:lower() == lower then
					exact = name
				end
				if name:lower():sub(1, #lower) == lower then
					table.insert(matches, name)
				end
			end
			-- exact match wins over prefix ambiguity
			if exact then matches = { exact } end
			CmdrEventScope.lastEvent = if #matches == 1 then matches[1] else nil
			return matches
		end,

		Validate = function(matches: { string }): (boolean, string)
			return #matches == 1, "No event with that name could be found."
		end,

		Autocomplete = function(matches: { string }): { string }
			refreshEventNames()
			return matches
		end,

		Parse = function(matches: { string }): string
			return matches[1]
		end,
	}

	cmdr:RegisterType("eventName", eventNameType)
end
