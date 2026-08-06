local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local EventDefinitions = require(ReplicatedStorage.Config.EventDefinitions)

type CancelFailure = { eventName: string, error: unknown }

local function displayList(eventNames: { string }): string
	local names: { string } = {}
	for _, eventName in ipairs(eventNames) do
		table.insert(names, EventDefinitions.getDisplayName(eventName))
	end
	return table.concat(names, ", ")
end

local function cancelAllGlobalEvents()
	local result = Knit.GetService("EventService"):forceCancelAllGlobalEvents()
	local cancelled: { string } = result.cancelled or {}
	local failed: { CancelFailure } = result.failed or {}

	if #cancelled == 0 and #failed == 0 then
		return "No active global events to cancel."
	end

	local message = ""
	if #cancelled > 0 then
		message = "Cancelled global events: " .. displayList(cancelled)
	end

	if #failed > 0 then
		local failedNames: { string } = {}
		for _, item in ipairs(failed) do
			table.insert(failedNames, EventDefinitions.getDisplayName(item.eventName) .. " (" .. tostring(item.error) .. ")")
		end
		local failedText = "Failed to cancel: " .. table.concat(failedNames, ", ")
		message = if message == "" then failedText else message .. "; " .. failedText
	end

	return message
end

return function(_context, EventName: string?)
	if EventName == nil or EventName == "" then
		return cancelAllGlobalEvents()
	end

	local definition = EventDefinitions.get(EventName)
	if not definition then
		return "Event not found: " .. EventName
	end

	local ok = Knit.GetService("EventService"):forceCancel(EventName)
	if ok then
		return "Cancelled global event: " .. EventDefinitions.getDisplayName(EventName) .. " (all servers)"
	end
	return "Failed to cancel global event: " .. EventDefinitions.getDisplayName(EventName)
end
