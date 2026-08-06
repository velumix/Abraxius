local SpeedBoostService = {
	Name = "SpeedBoostService",
	ActiveBoosts = {},
	BaseSpeed = {},
}

local function getBaseSpeed(player)
	local base = SpeedBoostService.BaseSpeed[player]
	if base == nil then
		base = player and player:GetAttribute("SwimSpeedMultiplier")
		if typeof(base) ~= "number" then
			base = 1
			if player then
				player:SetAttribute("SwimSpeedMultiplier", base)
			end
		end
		SpeedBoostService.BaseSpeed[player] = base
	end
	return base
end

local function getTotalMultiplier(boosts)
	local total = 1
	for _, multiplier in pairs(boosts) do
		if typeof(multiplier) == "number" then
			total *= multiplier
		end
	end
	return total
end

function SpeedBoostService:Apply(player, source, multiplier)
	if not player or not source or typeof(multiplier) ~= "number" then
		return
	end

	local boosts = self.ActiveBoosts[player]
	if not boosts then
		boosts = {}
		self.ActiveBoosts[player] = boosts
	end

	boosts[source] = multiplier

	local base = getBaseSpeed(player)
	local total = getTotalMultiplier(boosts)
	player:SetAttribute("SwimSpeedMultiplier", base * total)
end

function SpeedBoostService:Clear(player, source)
	if not player or not source then
		return
	end

	local boosts = self.ActiveBoosts[player]
	if not boosts then
		return
	end

	boosts[source] = nil

	if not next(boosts) then
		self.ActiveBoosts[player] = nil
		local base = self.BaseSpeed[player]
		if base ~= nil then
			player:SetAttribute("SwimSpeedMultiplier", base)
		end
		self.BaseSpeed[player] = nil
		return
	end

	local base = getBaseSpeed(player)
	local total = getTotalMultiplier(boosts)
	player:SetAttribute("SwimSpeedMultiplier", base * total)
end

function SpeedBoostService:SetBase(player, base)
	if not player or typeof(base) ~= "number" then
		return
	end

	self.BaseSpeed[player] = base

	local boosts = self.ActiveBoosts[player]
	if boosts then
		local total = getTotalMultiplier(boosts)
		player:SetAttribute("SwimSpeedMultiplier", base * total)
	else
		player:SetAttribute("SwimSpeedMultiplier", base)
	end
end

function SpeedBoostService:CleanupPlayer(player)
	self.ActiveBoosts[player] = nil
	self.BaseSpeed[player] = nil
end

return SpeedBoostService
