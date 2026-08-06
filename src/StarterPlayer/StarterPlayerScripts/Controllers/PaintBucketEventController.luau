local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Knit = require(ReplicatedStorage.Packages.Knit)

local PaintBucketEventController = Knit.CreateController({
	Name = "PaintBucketEventController",
})

local function sendNotification(data)
	task.defer(function()
		pcall(function()
			StarterGui:SetCore("SendNotification", {
				Title = data.title or "PAINT BUCKET EVENT",
				Text = data.text or "",
				Duration = data.duration or 5,
			})
		end)
	end)
end

function PaintBucketEventController:KnitInit() end

function PaintBucketEventController:KnitStart()
	local service = Knit.GetService("PaintBucketEventService")

	service.Notify:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.title or data.text then
			sendNotification(data)
		end
	end)
end

return PaintBucketEventController
