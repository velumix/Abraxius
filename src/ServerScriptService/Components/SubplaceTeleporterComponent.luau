local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Component = require(ReplicatedStorage.Packages.Component)

local GetEnv = require(ReplicatedStorage.GetEnv)

local DEBOUNCE_TIME = 5
local MAX_RETRIES = 3
local RETRY_DELAY = 2

local SubplaceTeleporterComponent = Component.new({
	Tag = "SubplaceTeleporter",
	Ancestors = { workspace },
})

function SubplaceTeleporterComponent:Start()
	local instance = self.Instance
	local place = instance:GetAttribute("Place")
	
	if not place then
		warn("SubplaceTeleporter has no Place attribute")
		return
	end
	
	local subplaceId = GetEnv:GetPlaceIdByName(place)
	if not subplaceId then
		warn("Subplace specified does not exist in GetEnv")
		return
	end
		
	local debounces = {}

	instance.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then return end

		local userId = player.UserId
		if debounces[userId] then return end
		debounces[userId] = true

		local accessCode
		local ok, err

		for i = 1, MAX_RETRIES do
			ok, err = pcall(function()
				accessCode = TeleportService:ReserveServerAsync(subplaceId)
			end)
			if ok and accessCode then break end
			warn(`[ReserveServer {i}] failed:`, err)
			task.wait(RETRY_DELAY)
		end

		if not accessCode then
			debounces[userId] = nil
			return
		end

		for i = 1, MAX_RETRIES do
			ok, err = pcall(function()
				TeleportService:TeleportToPrivateServer(subplaceId, accessCode, {player})
			end)
			if ok then break end
			warn(`[Teleport {i}] failed:`, err)
			task.wait(RETRY_DELAY)
		end

		if not ok then
			debounces[userId] = nil
			return
		end

		task.delay(DEBOUNCE_TIME, function()
			debounces[userId] = nil
		end)
	end)
end

return SubplaceTeleporterComponent
