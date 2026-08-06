local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Mince = require(ReplicatedStorage.Modules.Mince)

return {
	Name = "parkradiotoggle",
	Aliases = {"prtoggle"},
	Description = "Toggle Park Radio on or off",
	Group = "Admin",
	Args = {},
	Run = function(context)
		local handler = Mince:Get("ParkRadioHandler")
		if not handler then
			return "ParkRadioHandler not found."
		end
		if handler.SetEnabled then
			local current = Players.LocalPlayer:GetAttribute("ParkRadioEnabled")
			if current == nil then
				current = true
			end
			local newState = not current
			handler.SetEnabled(newState)
			return "Park Radio " .. (newState and "enabled" or "disabled") .. "."
		end
		return "SetEnabled not available."
	end,
}
