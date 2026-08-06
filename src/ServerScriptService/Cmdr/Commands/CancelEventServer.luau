local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local EventDefinitions = require(ReplicatedStorage.Config.EventDefinitions)

return function(_context, EventName)
	local definition = EventDefinitions.get(EventName)
	if not definition then
		return "Event not found: " .. EventName
	end

	-- local teardown even if started globally
	Knit.GetService("EventService"):endLocal(EventName)
	return "Cancelled event on this server: " .. EventDefinitions.getDisplayName(EventName)
end