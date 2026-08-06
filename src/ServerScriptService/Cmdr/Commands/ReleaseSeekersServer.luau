local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

return function(_context)
	local ok, service = pcall(function()
		return Knit.GetService("PaintingBossService")
	end)
	if not ok or not service then
		return "PaintingBossService is not loaded."
	end

	service:ReleaseSeekers()
	return "Seekers released."
end
