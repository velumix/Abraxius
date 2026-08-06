local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

-- Independent buff, runs concurrent with round modifiers
function module.execute(params)
	Knit.GetService("AdminSeekerService"):Start(params and params.duration)
end

return module