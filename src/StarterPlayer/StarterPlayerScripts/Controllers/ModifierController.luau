local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ModifierController = Knit.CreateController({
	Name = "ModifierController",
})

local activeIds = {}

local function notify(title: string, text: string, duration: number)
	task.defer(function()
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = title,
				Text = text,
				Duration = duration,
			})
		end)
	end)
end

function ModifierController:KnitInit() end

function ModifierController:KnitStart()
	local modifierService = Knit.GetService("ModifierService")

	modifierService.StateChanged:Connect(function(state)
		state = state or {}
		local newIds = {}
		for _, mod in ipairs(state) do
			newIds[mod.id] = mod
			if not activeIds[mod.id] then
				notify("MODIFIER ACTIVATED", mod.name, 5)
			end
		end
		for id in pairs(activeIds) do
			if not newIds[id] then
				notify("MODIFIER ENDED", id, 4)
			end
		end
		activeIds = newIds
	end)

	modifierService.Countdown:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		notify(
			(data.text or "MODIFIER"):upper() .. " IN",
			tostring(data.seconds or 0),
			1
		)
	end)
end

return ModifierController
