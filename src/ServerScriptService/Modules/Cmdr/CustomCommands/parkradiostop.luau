local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Mince = require(ReplicatedStorage.Modules.Mince)

return {
	Name = "parkradiostop",
	Aliases = {"prstop"},
	Description = "Stop Park Radio playback",
	Group = "Admin",
	Args = {},
	Run = function(context)
		local handler = Mince:Get("ParkRadioHandler")
		if not handler then
			return "ParkRadioHandler not found."
		end
		if handler.Cancel then
			handler.Cancel()
			return "Park Radio stopped."
		end
		return "Cancel not available."
	end,
}
