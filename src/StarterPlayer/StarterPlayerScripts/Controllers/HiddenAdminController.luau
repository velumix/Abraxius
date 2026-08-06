local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local HiddenAdminController = Knit.CreateController({
	Name = "HiddenAdminController",
})

function HiddenAdminController:KnitInit() end
function HiddenAdminController:KnitStart() end

return HiddenAdminController
