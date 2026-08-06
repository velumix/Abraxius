local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local AdminAnnounceSound = require(ReplicatedStorage.Modules.AdminAnnounceSound)

return function(context: { Executor: Player? }, scope: string, message: string)
	local who = if context.Executor then tostring(context.Executor.Name) else "Server"

	AdminAnnounceSound.Play()

	if scope == "global" then
		Knit.GetService("ActionBroadcastService"):broadcast("Announce", { name = who, message = message })
		return "Announced to all servers."
	end

	Knit.GetService("NotificationService"):BroadcastPreset("ADMIN", who .. ": " .. message)
	return "Announced to this server."
end
