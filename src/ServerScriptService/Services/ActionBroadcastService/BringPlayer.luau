local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")

local module = {}

function module.execute(params)
	local userId = params.userId
	local targetPlaceId = params.targetPlaceId
	local targetJobId = params.targetJobId
	if
		typeof(userId) ~= "number"
		or typeof(targetPlaceId) ~= "number"
		or typeof(targetJobId) ~= "string"
	then
		return
	end

	local player = Players:GetPlayerByUserId(userId)
	if not player then return end

	local reservedAccessCode = params.reservedAccessCode

	local ok, err = pcall(function()
		if typeof(reservedAccessCode) == "string" and reservedAccessCode ~= "" then
			local options = Instance.new("TeleportOptions")
			options.ReservedServerAccessCode = reservedAccessCode
			TeleportService:TeleportAsync(targetPlaceId, { player }, options)
		else
			TeleportService:TeleportToPlaceInstance(targetPlaceId, targetJobId, player)
		end
	end)
	if not ok then
		warn(`[BringPlayer] teleport failed: {err}`)
	end
end

return module
