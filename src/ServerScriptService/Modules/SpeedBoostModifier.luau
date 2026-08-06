local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))

local SpeedBoostModifier = {}

local caches = {}
local boundHumanoids: { [Player]: Humanoid? } = {}
local connections: {
	playerAdded: RBXScriptConnection?,
	charAdded: { [Player]: RBXScriptConnection? },
	speedChanged: { [Player]: RBXScriptConnection? },
} = {
	playerAdded = nil,
	charAdded = {},
	speedChanged = {},
}

local function applyToPlayer(player: Player, multiplier: number)
	multiplier = tonumber(multiplier) or 2
	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local function applyWhenMovable()
		-- Reverse Race replaces characters several times while changing roles.
		-- A deferred WalkSpeed callback from the previous body must never replace
		-- the cache belonging to the seeker's current body.
		if
			player.Character ~= character
			or boundHumanoids[player] ~= humanoid
			or not ModifierUtils.inRound(player)
			or not humanoid.Parent
		then
			return
		end

		local current = humanoid.WalkSpeed
		if current <= 0 then
			return
		end

		local cache = caches[player]
		if not cache or cache.humanoid ~= humanoid then
			cache = {
				humanoid = humanoid,
				walkSpeed = current,
				appliedSpeed = nil,
			}
			caches[player] = cache
		end

		if cache.appliedSpeed ~= nil and current ~= cache.appliedSpeed then
			-- Another match state (role placement, seeker release, revive, etc.)
			-- supplied a new base speed. Remember it before recalculating the boost.
			cache.walkSpeed = current
		end

		local boostedSpeed = cache.walkSpeed * multiplier
		cache.appliedSpeed = boostedSpeed
		if current ~= boostedSpeed then
			humanoid.WalkSpeed = boostedSpeed
		end
	end

	if boundHumanoids[player] ~= humanoid then
		if connections.speedChanged[player] then
			connections.speedChanged[player]:Disconnect()
		end
		boundHumanoids[player] = humanoid
		connections.speedChanged[player] = humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			task.defer(applyWhenMovable)
		end)
	end

	applyWhenMovable()
end

local function applyToCharacterWhenReady(player: Player, character: Model, multiplier: number)
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			local child = character:WaitForChild("Humanoid", 10)
			humanoid = if child and child:IsA("Humanoid") then child else nil
		end
		if not humanoid or player.Character ~= character or not ModifierUtils.inRound(player) then
			return
		end
		applyToPlayer(player, multiplier)
	end)
end

local function restorePlayer(player: Player)
	if connections.speedChanged[player] then
		connections.speedChanged[player]:Disconnect()
		connections.speedChanged[player] = nil
	end
	boundHumanoids[player] = nil

	local cache = caches[player]
	if not cache then
		return
	end
	caches[player] = nil

	local humanoid = cache.humanoid
	if humanoid and humanoid.Parent and humanoid.WalkSpeed == cache.appliedSpeed and cache.walkSpeed > 0 then
		humanoid.WalkSpeed = cache.walkSpeed
	end
end

function SpeedBoostModifier.buildOptions(duration: number?, multiplier: number?)
	multiplier = tonumber(multiplier) or 2
	if multiplier <= 0 then
		multiplier = 2
	end

	local function applyAll()
		for _, player in ipairs(Players:GetPlayers()) do
			if ModifierUtils.inRound(player) then
				applyToPlayer(player, multiplier)
			elseif caches[player] or connections.speedChanged[player] then
				restorePlayer(player)
			end
		end
	end

	local function onStart()
		applyAll()

		connections.charAdded = {}
		for _, player in ipairs(Players:GetPlayers()) do
			connections.charAdded[player] = player.CharacterAdded:Connect(function(character)
				if ModifierUtils.inRound(player) then
					applyToCharacterWhenReady(player, character, multiplier)
				end
			end)
		end

		connections.playerAdded = Players.PlayerAdded:Connect(function(player)
			connections.charAdded[player] = player.CharacterAdded:Connect(function(character)
				if ModifierUtils.inRound(player) then
					applyToCharacterWhenReady(player, character, multiplier)
				end
			end)
		end)
	end

	local function onStop()
		if connections.playerAdded then
			connections.playerAdded:Disconnect()
			connections.playerAdded = nil
		end

		if connections.charAdded then
			for player, conn in pairs(connections.charAdded) do
				pcall(function()
					conn:Disconnect()
				end)
				restorePlayer(player)
			end
			table.clear(connections.charAdded)
		end

		if connections.speedChanged then
			for player, conn in pairs(connections.speedChanged) do
				pcall(function()
					conn:Disconnect()
				end)
				connections.speedChanged[player] = nil
				boundHumanoids[player] = nil
			end
		end
		table.clear(caches)
		table.clear(boundHumanoids)
	end

	return {
		duration = duration,
		onStart = onStart,
		onTick = applyAll,
		tickInterval = 0.5,
		onStop = onStop,
		meta = { multiplier = multiplier },
	}
end

Players.PlayerRemoving:Connect(function(player)
	caches[player] = nil
	boundHumanoids[player] = nil
	if connections.speedChanged then
		local conn = connections.speedChanged[player]
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
			connections.speedChanged[player] = nil
		end
	end
	if connections.charAdded then
		local conn = connections.charAdded[player]
		if conn then
			pcall(function()
				conn:Disconnect()
			end)
			connections.charAdded[player] = nil
		end
	end
end)

return SpeedBoostModifier
