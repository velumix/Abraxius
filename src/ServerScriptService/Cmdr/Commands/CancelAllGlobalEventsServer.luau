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

return function(_context)
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
