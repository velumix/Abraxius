local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local AdminAnnounceSound = require(ReplicatedStorage.Modules.AdminAnnounceSound)

local module = {}

-- runs per-server (incl. source via exec echo); ActionBroadcastService fans this cross-server
function module.execute(params)
	if type(params) ~= "table" then return end
	AdminAnnounceSound.Play()
	Knit.GetService("NotificationService"):BroadcastPreset("ADMIN", tostring(params.name) .. ": " .. tostring(params.message))
end

return module
