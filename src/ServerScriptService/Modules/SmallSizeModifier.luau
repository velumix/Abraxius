local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local ModifierUtils = require(ServerScriptService.Modules:WaitForChild("ModifierUtils"))

local SmallSizeModifier = {}

local caches = {}
local connections: {
	playerAdded: RBXScriptConnection?,
	charAdded: { [Player]: RBXScriptConnection? },
} = {
	playerAdded = nil,
	charAdded = {},
}

local function isHider(player: Player): boolean
	return ModifierUtils.inRound(player) and ModifierUtils.getRole(player) == "Hider"
end

local function getBodyScales(humanoid: Humanoid): { [string]: NumberValue? }
	return {
		BodyDepthScale = humanoid:FindFirstChild("BodyDepthScale") :: NumberValue?,
		BodyHeightScale = humanoid:FindFirstChild("BodyHeightScale") :: NumberValue?,
		BodyWidthScale = humanoid:FindFirstChild("BodyWidthScale") :: NumberValue?,
		HeadScale = humanoid:FindFirstChild("HeadScale") :: NumberValue?,
	}
end

local function applyToCharacter(
	player: Player,
	character: Model,
	scale: number,
	speedMult: number,
	jumpPower: number,
	jumpHeight: number
)
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local cache = caches[player]
	if not cache then
		cache = {}
		caches[player] = cache
	end

	cache.walkSpeed = humanoid.WalkSpeed
	cache.hipHeight = humanoid.HipHeight
	cache.jumpPower = humanoid.JumpPower
	cache.jumpHeight = humanoid.JumpHeight

	cache.bodyScales = {}
	for name, obj in pairs(getBodyScales(humanoid)) do
		if obj then
			cache.bodyScales[name] = obj.Value
		end
	end

	for _, obj in pairs(getBodyScales(humanoid)) do
		if obj then
			obj.Value = scale
		end
	end

	humanoid.WalkSpeed = cache.walkSpeed * speedMult
	humanoid.HipHeight = cache.hipHeight * scale
	humanoid.JumpPower = jumpPower
	humanoid.JumpHeight = jumpHeight
end

local function restorePlayer(player: Player)
	local cache = caches[player]
	if not cache then
		return
	end
	caches[player] = nil

	local character = player.Character
	if not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	if cache.bodyScales then
		local scales = getBodyScales(humanoid)
		for name, value in pairs(cache.bodyScales) do
			local obj = scales[name]
			if obj then
				obj.Value = value
			end
		end
	end

	if cache.walkSpeed then
		humanoid.WalkSpeed = cache.walkSpeed
	end
	if cache.hipHeight then
		humanoid.HipHeight = cache.hipHeight
	end
	if cache.jumpPower then
		humanoid.JumpPower = cache.jumpPower
	end
	if cache.jumpHeight then
		humanoid.JumpHeight = cache.jumpHeight
	end
end

function SmallSizeModifier.buildOptions(
	duration: number?,
	scale: number?,
	speedMult: number?,
	jumpPower: number?,
	jumpHeight: number?
)
	scale = scale or 0.5
	speedMult = speedMult or 1.2
	jumpPower = jumpPower or 80
	jumpHeight = jumpHeight or 15

	local function applyToHider(player: Player)
		if not isHider(player) then
			return
		end
		applyToCharacter(player, player.Character, scale, speedMult, jumpPower, jumpHeight)
	end

	local function onStart()
		for _, player in ipairs(Players:GetPlayers()) do
			applyToHider(player)
		end

		connections.charAdded = {}
		for _, player in ipairs(Players:GetPlayers()) do
			connections.charAdded[player] = player.CharacterAdded:Connect(function()
				applyToHider(player)
			end)
		end

		connections.playerAdded = Players.PlayerAdded:Connect(function(player)
			connections.charAdded[player] = player.CharacterAdded:Connect(function()
				applyToHider(player)
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
	end

	return {
		duration = duration,
		onStart = onStart,
		onStop = onStop,
		meta = { scale = scale },
	}
end

Players.PlayerRemoving:Connect(function(player)
	caches[player] = nil
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

return SmallSizeModifier
