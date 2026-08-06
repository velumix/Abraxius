local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local module = {}

-- runs per-server, incl. source via exec echo
function module.execute(params)
	Knit.GetService("HiddenAdminService"):Spawn(params and params.amount)
end


return module