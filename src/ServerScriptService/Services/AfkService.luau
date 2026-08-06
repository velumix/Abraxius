local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local AfkTag = require(ServerScriptService.AfkTag)
local BackKnife = require(ServerScriptService.BackKnife)
local Placement = require(ServerScriptService.MatchManager.MatchPlacement)

local MatchManager = ServerScriptService:WaitForChild("MatchManager")
local GetPhase = MatchManager:WaitForChild("GetPhase", 10)
if not GetPhase then
	warn("[AfkService] MatchManager.GetPhase not found; AFK phase gate will default to INTERMISSION")
end

local function currentPhase()
	if not GetPhase then
		return "INTERMISSION"
	end
	local ok, phase = pcall(function()
		return GetPhase:Invoke()
	end)
	return ok and phase or "INTERMISSION"
end

local afkState = {}
local toggleListeners = {}

local AfkService = Knit.CreateService({
	Name = "AfkService",

	Client = {
		AfkChanged = Knit.CreateSignal(),

		SetAfk = function(self, player, isAfk)
			if not player then
				return
			end
			isAfk = isAfk and true or false

			if isAfk then
				local phase = currentPhase()
				if phase == "HIDE" or phase == "ROUND" then
					self.AfkChanged:Fire(player, false)
					return
				end
			end

			local wasAfk = afkState[player.UserId] == true
			if isAfk == wasAfk then
				self.AfkChanged:Fire(player, isAfk)
				return
			end

			afkState[player.UserId] = isAfk or nil
			AfkTag.setAfk(player, isAfk)

			player:SetAttribute("InMatch", false)
			Placement.clearDesiredPlacement(player)
			Placement.setLobbyRespawn(player)
			BackKnife.refresh(player)

			self.AfkChanged:Fire(player, isAfk)
			for _, cb in ipairs(toggleListeners) do
				task.spawn(function()
					pcall(cb, player, isAfk)
				end)
			end
		end,
	},

	IsAfk = function(self, player)
		return player and afkState[player.UserId] == true
	end,

	OnToggle = function(self, callback)
		table.insert(toggleListeners, callback)
	end,

	KnitStart = function(self)
		local ok, err = pcall(function()
			Players.PlayerRemoving:Connect(function(plr)
				afkState[plr.UserId] = nil
			end)
		end)
		if not ok then
			warn("[AfkService] KnitStart failed: " .. tostring(err))
		end
	end,
})

return AfkService
