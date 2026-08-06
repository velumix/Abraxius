local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ModifierCoordinator = {}

-- AdminSeeker/ChaosButton excluded: orthogonal, run concurrently
local FAMILY = {
	ColorSwap = function() Knit.GetService("EventService"):endLocal("ColorSwap") end,
	PaintFloor = function() Knit.GetService("EventService"):endLocal("PaintFloor") end,
	PaintBucketEvent = function() Knit.GetService("EventService"):endLocal("PaintBucketEvent") end,
	PaintMutation = function() Knit.GetService("EventService"):endLocal("PaintMutation") end,
	SmallSize = function() Knit.GetService("EventService"):endLocal("SmallSize") end,
	SpeedBoost = function() Knit.GetService("EventService"):endLocal("SpeedBoost") end,
}

local FAMILY_EVENTS = { "ColorSwap", "PaintFloor", "PaintBucketEvent", "PaintMutation", "SmallSize", "SpeedBoost" }

function ModifierCoordinator.cancelAllExcept(exclude: string?)
	for key, cancel in FAMILY do
		if key ~= exclude then
			pcall(cancel)
		end
	end
end

function ModifierCoordinator.cancelGlobalSiblings(exclude: string?)
	if FAMILY[exclude] == nil then
		return
	end
	local eventService = Knit.GetService("EventService")
	for _, name in FAMILY_EVENTS do
		if name ~= exclude then
			pcall(function()
				eventService:forceCancel(name)
			end)
		end
	end
end

return ModifierCoordinator
