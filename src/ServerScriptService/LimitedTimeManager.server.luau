local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Constants"))

local Remotes = ReplicatedStorage:WaitForChild("GameRemotes")

local deadlineValue = Remotes:FindFirstChild("LimitedOfferDeadline")
if not deadlineValue then
	deadlineValue = Instance.new("NumberValue")
	deadlineValue.Name = "LimitedOfferDeadline"
	deadlineValue.Value = 0
	deadlineValue.Parent = Remotes
end

deadlineValue.Value = Constants.LimitedTimePack.Deadline or 0
