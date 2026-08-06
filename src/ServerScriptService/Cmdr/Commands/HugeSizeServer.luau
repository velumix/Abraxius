local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ModifierUtils = require(ServerScriptService.Modules.ModifierUtils)

local SCALE_OBJECTS = { "BodyDepthScale", "BodyHeightScale", "BodyWidthScale", "HeadScale" }

local function scaleCharacter(character: Model, scale: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	for _, objectName in ipairs(SCALE_OBJECTS) do
		local scaleValue = humanoid:FindFirstChild(objectName)
		if scaleValue and scaleValue:IsA("NumberValue") then
			scaleValue.Value = scale
		end
	end
end

return function(_context, scale: number, targetName: string)
	scale = tonumber(scale) or 2
	scale = math.clamp(scale, 0.5, 5)

	local nameToFind = tostring(targetName or ""):lower()

	-- If a name was given, try to scale only that player.
	if nameToFind ~= "" then
		local matchedPlayer = nil
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Name:lower() == nameToFind or player.DisplayName:lower() == nameToFind then
				matchedPlayer = player
				break
			end
		end

		if not matchedPlayer then
			return "Player not found: " .. tostring(targetName)
		end

		matchedPlayer:SetAttribute("HugeSizeScale", scale)
		if matchedPlayer.Character then
			scaleCharacter(matchedPlayer.Character, scale)
		end
		return `Sized {matchedPlayer.Name} to {scale}x`
	end

	-- No name given: scale every hider/seeker in the round.
	ModifierUtils.forEachPlayerInRound(function(player: Player)
		player:SetAttribute("HugeSizeScale", scale)
		if player.Character then
			scaleCharacter(player.Character, scale)
		end
	end)

	return `Sized up all in-round players to {scale}x`
end
