local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return function(_context, scope: string, duration: number?)
	if scope == "global" then
		Knit.GetService("ActionBroadcastService"):broadcast("AdminSeeker", { duration = duration })
		return "Admin seeker powers granted on all servers."
	end

	local ok, result = Knit.GetService("AdminSeekerService"):Start(duration)
	if not ok then
		return result
	end
	return `Admin seeker powers given to {result} (this server).`
end