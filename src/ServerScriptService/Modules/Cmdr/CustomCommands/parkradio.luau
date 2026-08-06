local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Mince = require(ReplicatedStorage.Modules.Mince)

return {
	Name = "parkradio",
	Aliases = {"pr"},
	Description = "Play a Park Radio sequence (random or by ID)",
	Group = "Admin",
	Args = {
		{
			Type = "positiveInteger",
			Name = "id",
			Description = "Fact ID to play (omit for random)",
			Optional = true,
		},
	},
	Run = function(context, id)
		local handler = Mince:Get("ParkRadioHandler")
		if not handler then
			return "ParkRadioHandler not found."
		end

		local entry
		if id then
			local config = Mince.Config.ParkRadioConfig
			if not config or not config.Entries then
				return "ParkRadioConfig not found."
			end
			for _, e in ipairs(config.Entries) do
				if e.Id == id then
					entry = e
					break
				end
			end
			if not entry then
				return "Fact ID " .. id .. " not found."
			end
		else
			entry = handler.PickRandomFact and handler.PickRandomFact()
			if not entry then
				return "No facts available."
			end
		end

		if id and handler.PlayFact then
			task.spawn(function()
				handler.PlayFact(entry)
			end)
			return "Playing sequence: " .. entry.Subject .. " (ID: " .. entry.Id .. ")"
		elseif not id and handler.PlayFacts then
			local fact2 = handler.DrawFact and handler.DrawFact(nil, entry)
			task.spawn(function()
				local ok, err = pcall(function()
					handler.PlayFacts({entry, fact2})
				end)
				if not ok then
					warn("[ParkRadio CMD ERROR] " .. tostring(err))
				end
			end)
			return "Playing sequences: " .. entry.Subject .. " (ID: " .. entry.Id .. "), " .. fact2.Subject .. " (ID: " .. fact2.Id .. ")"
		end
		return "PlayFact not available."
	end,
}
